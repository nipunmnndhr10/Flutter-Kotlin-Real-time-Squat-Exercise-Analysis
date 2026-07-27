import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flt_kotlin_pose/core/constants/app_constants.dart';
import 'package:flt_kotlin_pose/screens/auth/loginscreen.dart';
import 'package:flt_kotlin_pose/screens/workout/workout_screen.dart';
import 'package:flt_kotlin_pose/screens/dashboard/home_screen.dart';
import 'package:flt_kotlin_pose/screens/dashboard/history_screen.dart';
import 'package:flt_kotlin_pose/screens/dashboard/profile_screen.dart';
import 'package:flt_kotlin_pose/services/notification_service.dart';

const kPrimary = Color(0xFFC5F014);
const kSecondary = Color(0xFF81C784);
const kBackground = Color(0xFFF9F9F9);
const kSurface = Color(0xFFF0F0F0);
const kTextPrimary = Color(0xFF1A1A1A);
const kTextMuted = Color(0xFF757575);

class DashboardScreen extends StatefulWidget {
  final String userName;
  const DashboardScreen({super.key, required this.userName});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  int totalSquats = 0;
  int weeklySquatsTotal = 0;
  int weeklyForm = 100;
  int allTimeForm = 100;
  int topForm = 0;
  List<int> weeklySquats = List.filled(7, 0);
  List<Map<String, dynamic>> _workouts = [];
  List<Map<String, dynamic>> _backendNotifications = [];
  final Set<int> _shownNotificationIds = {};
  bool _isLoading = true;
  String? _error;
  String _currentUserName = '';
  String _joinedDate = '';
  String _profilePictureUrl = '';
  bool _hasLoggedInBefore = false;
  int _weeksAgo = 0;
  Timer? _notificationTimer;

  Future<void> _markNotificationsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null || token.isEmpty) return;

      final dio = Dio(
        BaseOptions(
          baseUrl: kApiBaseUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      await dio.put('/notifications/mark-read');
      setState(() {
        for (var n in _backendNotifications) {
          n['is_read'] = true;
        }
      });
    } catch (_) {}
  }

  Future<void> _clearNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null || token.isEmpty) return;

      final dio = Dio(
        BaseOptions(
          baseUrl: kApiBaseUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      await dio.delete('/notifications/clear-all');
      setState(() {
        _backendNotifications.clear();
      });
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _currentUserName = widget.userName;
    LocalNotificationService().init();
    _loadWorkouts();
    // Auto-refresh notifications every 30 seconds
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchNotifications(),
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null || token.isEmpty) return;

      final dio = Dio(
        BaseOptions(
          baseUrl: kApiBaseUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final notifResponse = await dio.get('/notifications/my-notifications');
      if (notifResponse.data is List && mounted) {
        final newNotifs = (notifResponse.data as List).cast<Map<String, dynamic>>();

        // Trigger system notification banner for newly arrived notifications
        for (var n in newNotifs) {
          final id = n['id'] as int? ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final isRead = n['is_read'] == true || n['is_read'] == 1;

          if (!_shownNotificationIds.contains(id)) {
            _shownNotificationIds.add(id);
            if (!isRead && _shownNotificationIds.length > newNotifs.length) {
              LocalNotificationService().showNotification(
                id: id,
                title: n['title']?.toString() ?? 'SquatMate Notification',
                body: n['message']?.toString() ?? 'You have a new alert.',
              );
            }
          }
        }

        setState(() {
          _backendNotifications = newNotifs;
        });
      }
    } catch (_) {}
  }

  void _updateStatsFromWorkouts() {
    int allTimeTotal = 0;
    int weekTotal = 0;
    final List<int> weekData = List.filled(7, 0);

    double weekFormSum = 0;
    int weekFormCount = 0;

    double allTimeFormSum = 0;
    int allTimeFormCount = 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final DateTime targetWeekStart;
    final DateTime targetWeekEnd;

    if (_weeksAgo == 0) {
      // Rolling 7 days (today - 6 days through end of today) so recent workout activity never vanishes on Monday morning
      targetWeekStart = today.subtract(const Duration(days: 6));
      targetWeekEnd = today.add(const Duration(days: 1));
    } else {
      final mostRecentMonday = today.subtract(Duration(days: now.weekday - 1));
      targetWeekStart = mostRecentMonday.subtract(Duration(days: 7 * _weeksAgo));
      targetWeekEnd = targetWeekStart.add(const Duration(days: 7));
    }

    for (final w in _workouts) {
      final repsStr = w['total_reps']?.toString() ?? '0';
      final reps = int.tryParse(repsStr) ?? 0;
      allTimeTotal += reps;

      double formVal = 100.0;
      if (w['form_score'] != null || w['formScore'] != null) {
        formVal = ((w['form_score'] ?? w['formScore']) as num).toDouble();
      } else if (reps > 0) {
        var rawFaults = w['fault_summary_json'] ?? w['faultSummaryJson'];
        if (rawFaults is String) {
          try {
            rawFaults = jsonDecode(rawFaults);
          } catch (_) {
            rawFaults = {};
          }
        }
        final fMap = rawFaults as Map? ?? {};
        const weights = <String, double>{
          'knee_valgus': 2.5,
          'knee_cave': 2.5,
          'left_knee_cave': 2.5,
          'right_knee_cave': 2.5,
          'chest_up': 2.2,
          'lean_forward': 2.2,
          'go_deeper': 1.5,
          'shallow_depth': 1.5,
          'too_low': 1.0,
        };
        double pts = 0.0;
        fMap.forEach((k, c) {
          if (c is num && c > 0) {
            final w = weights[k.toString().toLowerCase()] ?? 1.5;
            final eff = c <= 2 ? c * 0.5 : c.toDouble();
            pts += eff * w;
          }
        });
        formVal = (100.0 - (pts / reps) * 15).clamp(0.0, 100.0);
      }
      allTimeFormSum += formVal;
      allTimeFormCount++;

      final startedAt = DateTime.tryParse(
        w['started_at']?.toString() ?? '',
      )?.toLocal();
      if (startedAt != null) {
        if (!startedAt.isBefore(targetWeekStart) &&
            startedAt.isBefore(targetWeekEnd)) {
          final dayIndex = startedAt.weekday % 7;
          weekData[dayIndex] += reps;
          weekTotal += reps;

          weekFormSum += formVal;
          weekFormCount++;
        }
      }
    }

    totalSquats = allTimeTotal;
    weeklySquatsTotal = weekTotal;
    weeklySquats = weekData;

    weeklyForm = weekFormCount > 0
        ? (weekFormSum / weekFormCount).round()
        : 0;
    allTimeForm = allTimeFormCount > 0
        ? (allTimeFormSum / allTimeFormCount).round()
        : 0;
    topForm = weeklyForm;
  }

  Future<void> _loadWorkouts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final savedName = prefs.getString('user_name');
      final savedJoinedDate = prefs.getString('joined_date');
      final savedPicUrl = prefs.getString('profile_picture_url');
      final hasLoggedInBefore = prefs.getBool('has_logged_in_before') ?? false;

      if (!prefs.containsKey('has_logged_in_before')) {
        await prefs.setBool('has_logged_in_before', true);
      }

      if (token == null || token.isEmpty) {
        _redirectToLogin();
        return;
      }

      final dio = Dio(
        BaseOptions(
          baseUrl: kApiBaseUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      // Fetch user profile from backend
      try {
        final profileResponse = await dio.get('/auth/me');
        final profileData = profileResponse.data;
        if (profileData != null) {
          if (profileData['full_name'] != null) {
            final fullName = profileData['full_name'].toString();
            if (fullName.isNotEmpty) {
              await prefs.setString('user_name', fullName);
              _currentUserName = fullName;
            }
          }
          if (profileData['created_at'] != null) {
            final createdAt = DateTime.tryParse(
              profileData['created_at'].toString(),
            );
            if (createdAt != null) {
              final months = [
                'Jan',
                'Feb',
                'Mar',
                'Apr',
                'May',
                'Jun',
                'Jul',
                'Aug',
                'Sep',
                'Oct',
                'Nov',
                'Dec',
              ];
              _joinedDate = '${months[createdAt.month - 1]} ${createdAt.year}';
              await prefs.setString('joined_date', _joinedDate);
            }
          }
          if (profileData['profile_picture_url'] != null) {
            final picUrl = profileData['profile_picture_url'].toString();
            if (picUrl.isNotEmpty) {
              final fullPicUrl = picUrl.startsWith('http')
                  ? picUrl
                  : '$kApiBaseUrl$picUrl';
              await prefs.setString('profile_picture_url', fullPicUrl);
              _profilePictureUrl = fullPicUrl;
            }
          }
        }
      } catch (_) {
        // Fallback to local storage if profile fetch fails (e.g., network error).
        // 401 Unauthorized is caught by the outer catch block.
      }

      try {
        final notifResponse = await dio.get('/notifications/my-notifications');
        if (notifResponse.data is List) {
          _backendNotifications = (notifResponse.data as List)
              .cast<Map<String, dynamic>>();
        }
      } catch (_) {}

      final response = await dio.get('/workouts/');
      final workouts = (response.data as List).cast<Map<String, dynamic>>();

      setState(() {
        if (_currentUserName.isEmpty &&
            savedName != null &&
            savedName.isNotEmpty) {
          _currentUserName = savedName;
        }
        if (_joinedDate.isEmpty &&
            savedJoinedDate != null &&
            savedJoinedDate.isNotEmpty) {
          _joinedDate = savedJoinedDate;
        }
        if (_profilePictureUrl.isEmpty &&
            savedPicUrl != null &&
            savedPicUrl.isNotEmpty) {
          _profilePictureUrl = savedPicUrl;
        }
        _hasLoggedInBefore = hasLoggedInBefore;
        _workouts = workouts;
        _updateStatsFromWorkouts();
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _redirectToLogin();
      } else {
        setState(() {
          _error = 'Failed to load workouts';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Something went wrong';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteWorkout(int sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null || token.isEmpty) {
      _redirectToLogin();
      return;
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: kApiBaseUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    await dio.delete('/workouts/$sessionId');

    setState(() {
      _workouts.removeWhere((w) => w['id'] == sessionId);
      _updateStatsFromWorkouts();
    });
  }

  Future<void> _renameWorkout(int sessionId, String newName) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null || token.isEmpty) {
      _redirectToLogin();
      return;
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: kApiBaseUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    await dio.patch(
      '/workouts/$sessionId/name',
      data: {'session_name': newName},
    );

    setState(() {
      final index = _workouts.indexWhere((w) => w['id'] == sessionId);
      if (index != -1) {
        _workouts[index]['session_name'] = newName;
      }
    });
  }

  void _redirectToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _getGreeting() {
    if (!_hasLoggedInBefore) {
      return 'Welcome back,';
    }
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good morning,';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon,';
    } else if (hour >= 17 && hour < 22) {
      return 'Good evening,';
    } else {
      return 'Good night,';
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    _redirectToLogin();
  }

  void _openCamera() {
    setState(() => _currentIndex = 1);
  }

  void _changeWeek(int delta) {
    setState(() {
      _weeksAgo += delta;
      if (_weeksAgo < 0) _weeksAgo = 0;
      if (_weeksAgo > 8) _weeksAgo = 8;
      _updateStatsFromWorkouts();
    });
  }

  String _getDateRangeText() {
    if (_weeksAgo == 0) return 'Last 7 Days';
    if (_weeksAgo == 1) return 'Last Week';

    final now = DateTime.now();
    final mostRecentSunday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday % 7));
    final targetWeekStart = mostRecentSunday.subtract(
      Duration(days: 7 * _weeksAgo),
    );
    final targetWeekEnd = targetWeekStart.add(const Duration(days: 6));

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[targetWeekStart.month - 1]} ${targetWeekStart.day} - ${months[targetWeekEnd.month - 1]} ${targetWeekEnd.day}';
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: kPrimary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: kTextMuted)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadWorkouts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return IndexedStack(
      index: _currentIndex,
      children: [
        HomeScreen(
          userName: _currentUserName,
          greeting: _getGreeting(),
          profilePictureUrl: _profilePictureUrl,
          totalSquats: totalSquats,
          weeklySquatsTotal: weeklySquatsTotal,
          weeklyForm: weeklyForm,
          allTimeForm: allTimeForm,
          weeklySquats: weeklySquats,
          backendNotifications: _backendNotifications,
          onMarkNotificationsRead: _markNotificationsRead,
          onClearNotifications: _clearNotifications,
          onLogout: _logout,
          onOpenCamera: _openCamera,
          dateRangeText: _getDateRangeText(),
          hasPreviousWeek: _weeksAgo < 8,
          hasNextWeek: _weeksAgo > 0,
          onPreviousWeek: () => _changeWeek(1),
          onNextWeek: () => _changeWeek(-1),
        ),
        WorkoutScreen(
          onWorkoutSaved: () {
            _loadWorkouts();
            _fetchNotifications(); // Instantly refresh notifications after workout save
            LocalNotificationService().showNotification(
              id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              title: 'Workout Recorded! 🏋️',
              body: 'Your squat session has been saved successfully.',
            );
            setState(() => _currentIndex = 0);
          },
        ),
        HistoryScreen(
          userName: _currentUserName,
          greeting: _getGreeting(),
          profilePictureUrl: _profilePictureUrl,
          onLogout: _logout,
          workouts: _workouts,
          onDeleteWorkout: _deleteWorkout,
          onRenameWorkout: _renameWorkout,
        ),
        ProfileScreen(
          userName: _currentUserName,
          greeting: _getGreeting(),
          joinedDate: _joinedDate.isNotEmpty ? _joinedDate : 'Unknown',
          profilePictureUrl: _profilePictureUrl,
          workouts: _workouts,
          onLogout: _logout,
          onProfilePictureUpdated: (newUrl) {
            setState(() {
              _profilePictureUrl = newUrl;
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111710) : kBackground;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          if (i == 0 || i == 2) {
            _loadWorkouts();
          }
        },
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF111710) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1C2419) : const Color(0xFFE8E8E8);
    final selectedColor = isDark ? const Color(0xFF82D616) : const Color.fromARGB(255, 144, 175, 19);
    final unselectedColor = isDark ? const Color(0xFF6B7767) : const Color(0xFF5F5F5F);

    const items = [
      (Icons.home_outlined, 'Home'),
      (Icons.fitness_center_outlined, 'Workout'),
      (Icons.history_outlined, 'History'),
      (Icons.person_outline, 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: navBg,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (index) {
              final isSelected = currentIndex == index;

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[index].$1,
                        size: 24,
                        color: isSelected ? selectedColor : unselectedColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[index].$2,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected ? selectedColor : unselectedColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? selectedColor
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

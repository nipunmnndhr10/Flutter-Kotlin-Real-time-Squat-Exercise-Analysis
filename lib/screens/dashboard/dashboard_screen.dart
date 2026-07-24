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
  bool _isLoading = true;
  String? _error;
  String _currentUserName = '';
  String _joinedDate = '';
  String _profilePictureUrl = '';
  bool _hasLoggedInBefore = false;
  int _weeksAgo = 0;

  @override
  void initState() {
    super.initState();
    _currentUserName = widget.userName;
    _loadWorkouts();
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
    final mostRecentMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final targetWeekStart = mostRecentMonday.subtract(
      Duration(days: 7 * _weeksAgo),
    );
    final targetWeekEnd = targetWeekStart.add(const Duration(days: 7));

    for (final w in _workouts) {
      final repsStr = w['total_reps']?.toString() ?? '0';
      final reps = int.tryParse(repsStr) ?? 0;
      allTimeTotal += reps;

      final formVal = (w['form_score'] ?? w['formScore'] as num?)?.toDouble() ?? 100.0;
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

    weeklyForm = weekFormCount > 0 ? (weekFormSum / weekFormCount).round() : 100;
    allTimeForm = allTimeFormCount > 0 ? (allTimeFormSum / allTimeFormCount).round() : 100;
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
    if (_weeksAgo == 0) return 'This Week';
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
          onLogout: _logout,
          onOpenCamera: _openCamera,
          dateRangeText: _getDateRangeText(),
          hasPreviousWeek: _weeksAgo < 8,
          hasNextWeek: _weeksAgo > 0,
          onPreviousWeek: () => _changeWeek(1),
          onNextWeek: () => _changeWeek(-1),
        ),
        WorkoutScreen(
          onWorkoutSaved: () async {
            await _loadWorkouts();
            if (mounted) {
              setState(() => _currentIndex = 0);
            }
          },
        ),
        HistoryScreen(
          userName: _currentUserName,
          greeting: _getGreeting(),
          profilePictureUrl: _profilePictureUrl,
          onLogout: _logout,
          workouts: _workouts,
          onDeleteWorkout: _deleteWorkout,
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
    return Scaffold(
      backgroundColor: kBackground,
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
    const selectedColor = Color.fromARGB(255, 144, 175, 19);
    const unselectedColor = Color(0xFF5F5F5F);

    const items = [
      (Icons.home_outlined, 'Home'),
      (Icons.fitness_center_outlined, 'Workout'),
      (Icons.history_outlined, 'History'),
      (Icons.person_outline, 'Profile'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8E8E8), width: 1)),
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
                          color: isSelected ? selectedColor : Colors.transparent,
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

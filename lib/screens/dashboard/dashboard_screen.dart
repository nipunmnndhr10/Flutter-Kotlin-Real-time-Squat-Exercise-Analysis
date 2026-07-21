import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flt_kotlin_pose/core/constants/app_constants.dart';
import 'package:flt_kotlin_pose/screens/auth/loginscreen.dart';
import 'package:flt_kotlin_pose/screens/workout/workout_screen.dart';
import 'package:flt_kotlin_pose/screens/dashboard/home_screen.dart';
import 'package:flt_kotlin_pose/screens/dashboard/history_screen.dart';
import 'package:flt_kotlin_pose/screens/dashboard/profile_screen.dart';

const kPrimary = Color(0xFF4CAF50);
const kSecondary = Color(0xFF81C784);
const kBackground = Color(0xFFF9F9F9);
const kSurface = Color(0xFFE8F5E9);
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
  int topForm = 0;
  List<int> weeklySquats = List.filled(7, 0);
  List<Map<String, dynamic>> _workouts = [];
  bool _isLoading = true;
  String? _error;
  String _currentUserName = '';
  String _joinedDate = '';
  bool _hasLoggedInBefore = false;
  int _weeksAgo = 0;

  @override
  void initState() {
    super.initState();
    _currentUserName = widget.userName;
    _loadWorkouts();
  }

  void _updateStatsFromWorkouts() {
    int total = 0;
    final List<int> weekData = List.filled(7, 0);

    final now = DateTime.now();
    final mostRecentSunday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday % 7));
    final targetWeekStart = mostRecentSunday.subtract(Duration(days: 7 * _weeksAgo));
    final targetWeekEnd = targetWeekStart.add(const Duration(days: 7));

    for (final w in _workouts) {
      final reps = (w['total_reps'] as num?)?.toInt() ?? 0;
      total += reps;

      final startedAt = DateTime.tryParse(w['started_at']?.toString() ?? '');
      if (startedAt != null) {
        if (!startedAt.isBefore(targetWeekStart) && startedAt.isBefore(targetWeekEnd)) {
          final dayIndex = startedAt.weekday % 7;
          weekData[dayIndex] += reps;
        }
      }
    }

    totalSquats = total;
    weeklySquats = weekData;
  }

  Future<void> _loadWorkouts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final savedName = prefs.getString('user_name');
      final savedJoinedDate = prefs.getString('joined_date');
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
            final createdAt = DateTime.tryParse(profileData['created_at'].toString());
            if (createdAt != null) {
              final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
              _joinedDate = '${months[createdAt.month - 1]} ${createdAt.year}';
              await prefs.setString('joined_date', _joinedDate);
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
        if (_currentUserName.isEmpty && savedName != null && savedName.isNotEmpty) {
          _currentUserName = savedName;
        }
        if (_joinedDate.isEmpty && savedJoinedDate != null && savedJoinedDate.isNotEmpty) {
          _joinedDate = savedJoinedDate;
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
    final mostRecentSunday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday % 7));
    final targetWeekStart = mostRecentSunday.subtract(Duration(days: 7 * _weeksAgo));
    final targetWeekEnd = targetWeekStart.add(const Duration(days: 6));
    
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
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
          totalSquats: totalSquats,
          topForm: topForm,
          weeklySquats: weeklySquats,
          onLogout: _logout,
          onOpenCamera: _openCamera,
          dateRangeText: _getDateRangeText(),
          hasPreviousWeek: _weeksAgo < 8,
          hasNextWeek: _weeksAgo > 0,
          onPreviousWeek: () => _changeWeek(1),
          onNextWeek: () => _changeWeek(-1),
        ),
        const WorkoutScreen(),
        HistoryScreen(
          userName: _currentUserName,
          greeting: _getGreeting(),
          onLogout: _logout,
          workouts: _workouts,
          onDeleteWorkout: _deleteWorkout,
        ),
        ProfileScreen(
          userName: _currentUserName,
          greeting: _getGreeting(),
          joinedDate: _joinedDate.isNotEmpty ? _joinedDate : 'Unknown',
          onLogout: _logout,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: kPrimary,
        unselectedItemColor: kTextMuted,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_outlined),
            activeIcon: Icon(Icons.fitness_center),
            label: 'Workouts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Workout History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

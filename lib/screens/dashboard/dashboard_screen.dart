import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flt_kotlin_pose/core/constants/app_constants.dart';
import 'package:flt_kotlin_pose/screens/auth/loginscreen.dart';
import 'package:flt_kotlin_pose/screens/workout/workout_screen.dart';

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
  bool _hasLoggedInBefore = false;

  @override
  void initState() {
    super.initState();
    _currentUserName = widget.userName;
    _loadWorkouts();
  }

  void _updateStatsFromWorkouts() {
    int total = 0;
    final List<int> weekData = List.filled(7, 0);

    for (final w in _workouts) {
      final reps = (w['total_reps'] as num?)?.toInt() ?? 0;
      total += reps;

      // Aggregate by day of week for the chart
      final startedAt = DateTime.tryParse(w['started_at']?.toString() ?? '');
      if (startedAt != null) {
        final dayIndex = startedAt.weekday % 7; // 0=Sun, 1=Mon, ... 6=Sat
        weekData[dayIndex] += reps;
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
        if (profileData != null && profileData['full_name'] != null) {
          final fullName = profileData['full_name'].toString();
          if (fullName.isNotEmpty) {
            await prefs.setString('user_name', fullName);
            _currentUserName = fullName;
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening camera…'),
        backgroundColor: kPrimary,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _startWorkout() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting workout…'),
        backgroundColor: kSecondary,
        duration: Duration(seconds: 1),
      ),
    );
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

    switch (_currentIndex) {
      case 1:
        return const WorkoutScreen();
      case 2:
        return _buildWorkoutHistory();
      case 3:
        return _buildProfile();
      case 0:
      default:
        return _buildDashboardHome();
    }
  }

  Widget _buildDashboardHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            userName: _currentUserName,
            greeting: _getGreeting(),
            onLogout: _logout,
          ),
          const SizedBox(height: 24),
          _CameraButton(onTap: _openCamera),
          const SizedBox(height: 20),
          _StatRow(totalSquats: totalSquats, topForm: topForm),
          const SizedBox(height: 24),
          _WeeklyChart(data: weeklySquats),
          const SizedBox(height: 24),
          _RecommendedWorkoutSection(onPlay: _startWorkout),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProfile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            userName: _currentUserName,
            greeting: _getGreeting(),
            onLogout: _logout,
          ),
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    color: kSurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: kPrimary, size: 48),
                ),
                const SizedBox(height: 16),
                Text(
                  _currentUserName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Fitness Enthusiast',
                  style: TextStyle(fontSize: 14, color: kTextMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _ProfileDetailRow(
                  icon: Icons.person_outline,
                  label: 'Name',
                  value: _currentUserName,
                ),
                const Divider(height: 24, color: Colors.black12),
                _ProfileDetailRow(
                  icon: Icons.fitness_center_outlined,
                  label: 'Favorite Workout',
                  value: 'Squats',
                ),
                const Divider(height: 24, color: Colors.black12),
                _ProfileDetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Joined',
                  value: 'July 2026',
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.logout),
              label: const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: _Header(
            userName: _currentUserName,
            greeting: _getGreeting(),
            onLogout: _logout,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Workout History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
        ),
        Expanded(
          child: _workouts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_toggle_off_rounded,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Workouts Yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Start a workout to see your history here!',
                        style: TextStyle(fontSize: 14, color: kTextMuted),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  itemCount: _workouts.length,
                  itemBuilder: (context, index) {
                    final workout = _workouts[index];
                    return _WorkoutHistoryCard(
                      workout: workout,
                      onTap: () => _showWorkoutDetails(workout),
                      onLongPress: () => _showDeleteConfirmation(workout),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showWorkoutDetails(Map<String, dynamic> workout) {
    showDialog(
      context: context,
      builder: (context) {
        final duration = workout['duration_seconds'] ?? 0;
        final minutes = duration ~/ 60;
        final seconds = duration % 60;
        final durationText = minutes > 0
            ? '${minutes}m ${seconds}s'
            : '${seconds}s';

        final startedAt = workout['started_at'] != null
            ? DateTime.tryParse(workout['started_at'].toString())
            : null;

        final startedAtText = startedAt != null
            ? '${startedAt.day}/${startedAt.month}/${startedAt.year} ${startedAt.hour.toString().padLeft(2, '0')}:${startedAt.minute.toString().padLeft(2, '0')}'
            : '-';

        final faults = workout['fault_summary_json'];
        final List<Widget> faultWidgets = [];
        if (faults is Map && faults.isNotEmpty) {
          faults.forEach((key, value) {
            final readableKey = key.toString().replaceAll('_', ' ');
            final capitalizedKey = readableKey.isNotEmpty
                ? '${readableKey[0].toUpperCase()}${readableKey.substring(1)}'
                : readableKey;
            faultWidgets.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '• $capitalizedKey',
                      style: const TextStyle(fontSize: 13, color: kTextPrimary),
                    ),
                    Text(
                      'x$value',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            );
          });
        } else {
          faultWidgets.add(
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0x1A4CAF50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: kPrimary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Perfect Form! No faults detected.',
                    style: TextStyle(
                      fontSize: 12,
                      color: kPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0x1F4CAF50),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fitness_center,
                          color: kPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Session Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kTextPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.close,
                          color: kTextMuted,
                          size: 20,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Workout started on $startedAtText',
                    style: const TextStyle(fontSize: 13, color: kTextMuted),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailCard(
                          label: 'Total Reps',
                          value: '${workout['total_reps']}',
                          icon: Icons.repeat_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDetailCard(
                          label: 'Duration',
                          value: durationText,
                          icon: Icons.timer_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailCard(
                          label: 'Min Knee Angle',
                          value:
                              '${(workout['min_knee_angle'] as num?)?.toStringAsFixed(1) ?? '-'}°',
                          icon: Icons.transform,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDetailCard(
                          label: 'Avg Knee Angle',
                          value:
                              '${(workout['avg_knee_angle'] as num?)?.toStringAsFixed(1) ?? '-'}°',
                          icon: Icons.functions,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailCard(
                          label: 'Min Hip Angle',
                          value:
                              '${(workout['min_hip_angle'] as num?)?.toStringAsFixed(1) ?? '-'}°',
                          icon: Icons.transform,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDetailCard(
                          label: 'Avg Hip Angle',
                          value:
                              '${(workout['avg_hip_angle'] as num?)?.toStringAsFixed(1) ?? '-'}°',
                          icon: Icons.functions,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Camera: ${workout['camera'] ?? '-'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: kTextMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Target Angle: ${(workout['target_angle_threshold'] as num?)?.toStringAsFixed(1) ?? '-'}°',
                        style: const TextStyle(
                          fontSize: 12,
                          color: kTextMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.black12, height: 1),
                  const SizedBox(height: 16),
                  const Text(
                    'Form Faults',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...faultWidgets,
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: kPrimary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: kTextMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> workout) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool deleting = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Delete Workout?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: deleting
                  ? const SizedBox(
                      height: 80,
                      child: Center(
                        child: CircularProgressIndicator(color: kPrimary),
                      ),
                    )
                  : const Text(
                      'Are you sure you want to permanently delete this workout session? This cannot be undone.',
                    ),
              actions: deleting
                  ? []
                  : [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: kTextMuted),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          setStateDialog(() {
                            deleting = true;
                          });
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await _deleteWorkout(workout['id']);
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Workout session deleted successfully',
                                ),
                                backgroundColor: kPrimary,
                              ),
                            );
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            setStateDialog(() {
                              deleting = false;
                            });
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Failed to delete workout session',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
            );
          },
        );
      },
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

class _Header extends StatelessWidget {
  final String userName;
  final String greeting;
  final VoidCallback onLogout;

  const _Header({
    required this.userName,
    required this.greeting,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: kSurface,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person_outline, color: kPrimary, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(fontSize: 12, color: kTextMuted),
              ),
              Text(
                userName,
                style: const TextStyle(
                  fontSize: 16,
                  color: kTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.notifications_outlined,
            color: kTextPrimary,
            size: 20,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onLogout,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.logout_outlined,
              color: Colors.red,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

class _CameraButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CameraButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: kPrimary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_outline, color: Colors.white, size: 24),
            SizedBox(width: 10),
            Text(
              'Camera Setup',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final int totalSquats;
  final int topForm;
  const _StatRow({required this.totalSquats, required this.topForm});

  String _fmt(int n) {
    if (n >= 1000) {
      final s = n.toString();
      return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(label: 'Total Squats', value: _fmt(totalSquats)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _StatCard(
            label: 'Top Form',
            value: '$topForm%',
            valueColor: kPrimary,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _StatCard({
    required this.label,
    required this.value,
    this.valueColor = kTextPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: kTextMuted)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final List<int> data;
  const _WeeklyChart({required this.data});
  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    final maxVal = data.reduce((a, b) => a > b ? a : b).toDouble();
    final today = DateTime.now().weekday % 7;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Squats in last 7 Days',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final fraction = maxVal > 0 ? data[i] / maxVal : 0.0;
                final isToday = i == today;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          data[i] > 0 ? '${data[i]}' : '',
                          style: const TextStyle(
                            fontSize: 10,
                            color: kTextMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          height: 80 * fraction,
                          decoration: BoxDecoration(
                            color: isToday ? kPrimary : kSecondary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _days[i],
                          style: TextStyle(
                            fontSize: 10,
                            color: isToday ? kPrimary : kTextMuted,
                            fontWeight: isToday
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendedWorkoutSection extends StatelessWidget {
  final VoidCallback onPlay;
  const _RecommendedWorkoutSection({required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommended Workout',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: kTextPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _WorkoutCard(
          title: 'Killer Leg Workout (Squats)',
          subtitle: '45 Min  •  Advanced',
          onPlay: onPlay,
        ),
      ],
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onPlay;
  const _WorkoutCard({
    required this.title,
    required this.subtitle,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: kTextMuted),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onPlay,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0x1F4CAF50),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: kPrimary,
                size: 22,
              ),
            ),
          ),
        ],
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

class _WorkoutHistoryCard extends StatelessWidget {
  final Map<String, dynamic> workout;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _WorkoutHistoryCard({
    required this.workout,
    required this.onTap,
    required this.onLongPress,
  });

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr;
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
    final month = months[dt.month - 1];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$month ${dt.day}, ${dt.year} at $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final type = (workout['workout_type'] ?? 'squat').toString();
    final capitalizedType = type.isNotEmpty
        ? '${type[0].toUpperCase()}${type.substring(1)}'
        : 'Squat';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0x1F4CAF50),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    color: kPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$capitalizedType Session',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDateTime(workout['started_at']),
                        style: const TextStyle(fontSize: 12, color: kTextMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${workout['total_reps']} Reps',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${workout['duration_seconds']}s',
                      style: const TextStyle(
                        fontSize: 11,
                        color: kTextMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ProfileDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: kPrimary, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: kTextMuted, fontSize: 14)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: kTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

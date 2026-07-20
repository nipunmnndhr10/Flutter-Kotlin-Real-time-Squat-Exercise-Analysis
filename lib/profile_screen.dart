import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_config.dart';
import 'loginscreen.dart';

const kPrimary = Color(0xFF2E7D32);
const kPrimaryBackground = Color(0xFFE8F5E9);
const kTextPrimary = Color(0xFF1A1A1A);
const kTextSecondary = Color(0xFF757575);
const kBackground = Color(0xFFF5F5F5);

class ProfileScreen extends StatefulWidget {
  final String userName;
  const ProfileScreen({super.key, required this.userName});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isLoggingOut = false;
  String? _errorMessage;

  String _userName = '';
  String _userEmail = '';
  String _avatarLetter = 'U';

  int _totalWorkouts = 0;
  int _totalSquats = 0;
  int _bestForm = 0;
  int _totalFaults = 0;
  int _totalMinutes = 0;
  double _avgKneeAngle = 0;
  double _avgHipAngle = 0;
  List<dynamic> _recentWorkouts = [];

  @override
  void initState() {
    super.initState();
    _userName = widget.userName;
    _avatarLetter = _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U';
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        setState(() {
          _errorMessage = 'Please login again';
          _isLoading = false;
        });
        return;
      }

      final dio = Dio();

      final userResponse = await dio.get(
        '${AppConfig.apiBaseUrl}/auth/me',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (userResponse.statusCode == 200) {
        final userData = userResponse.data;
        setState(() {
          _userName = userData['full_name'] ?? widget.userName;
          _userEmail = userData['email'] ?? 'No email';
          _avatarLetter = _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U';
        });
      }

      final workoutsResponse = await dio.get(
        '${AppConfig.apiBaseUrl}/workouts/',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (workoutsResponse.statusCode == 200) {
        final List<dynamic> workouts = workoutsResponse.data;
        _processWorkoutData(workouts);
      }

      setState(() {
        _isLoading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _errorMessage = 'Connection error: ${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading profile';
        _isLoading = false;
      });
    }
  }

  void _processWorkoutData(List<dynamic> workouts) {
    if (workouts.isEmpty) return;

    _totalWorkouts = workouts.length;
    _totalSquats = workouts.fold(0, (sum, w) => sum + (w['total_reps'] as int? ?? 0));
    _totalMinutes = workouts.fold(0, (sum, w) => sum + ((w['duration_seconds'] as int? ?? 0) ~/ 60));

    _bestForm = workouts.fold(0, (best, w) {
      final angle = (w['avg_knee_angle'] as num?)?.toInt() ?? 0;
      return angle > best ? angle : best;
    });

    int totalFaults = 0;
    for (final w in workouts) {
      final faultSummary = w['fault_summary_json'] as Map?;
      if (faultSummary != null) {
        totalFaults += faultSummary.values.fold<int>(0, (sum, v) => sum + ((v as num?)?.toInt() ?? 0));
      }
    }
    _totalFaults = totalFaults;

    double totalKnee = 0;
    double totalHip = 0;
    for (final w in workouts) {
      totalKnee += (w['avg_knee_angle'] as num?)?.toDouble() ?? 0;
      totalHip += (w['avg_hip_angle'] as num?)?.toDouble() ?? 0;
    }
    _avgKneeAngle = _totalWorkouts > 0 ? totalKnee / _totalWorkouts : 0;
    _avgHipAngle = _totalWorkouts > 0 ? totalHip / _totalWorkouts : 0;

    _recentWorkouts = workouts.take(3).toList();
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.remove('access_token');
      await prefs.remove('user_id');
      await prefs.remove('user_name');
      await prefs.remove('user_email');

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      setState(() => _isLoggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error logging out. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchProfileData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: kPrimary),
                  SizedBox(height: 16),
                  Text(
                    'Loading profile...',
                    style: TextStyle(color: kTextSecondary),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: kTextSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchProfileData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchProfileData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _ProfileHeader(
                          name: _userName,
                          email: _userEmail,
                          avatarLetter: _avatarLetter,
                        ),
                        const SizedBox(height: 20),
                        _StatsGrid(
                          totalWorkouts: _totalWorkouts,
                          totalSquats: _totalSquats,
                          bestForm: _bestForm,
                          totalFaults: _totalFaults,
                          totalMinutes: _totalMinutes,
                          avgKneeAngle: _avgKneeAngle,
                          avgHipAngle: _avgHipAngle,
                        ),
                        const SizedBox(height: 20),
                        if (_recentWorkouts.isNotEmpty)
                          _RecentActivity(workouts: _recentWorkouts),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoggingOut ? null : _logout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoggingOut
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.logout, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Log Out',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            color: kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final String avatarLetter;

  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.avatarLetter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kPrimary, const Color(0xFF4CAF50)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                avatarLetter,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: kPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final int totalWorkouts;
  final int totalSquats;
  final int bestForm;
  final int totalFaults;
  final int totalMinutes;
  final double avgKneeAngle;
  final double avgHipAngle;

  const _StatsGrid({
    required this.totalWorkouts,
    required this.totalSquats,
    required this.bestForm,
    required this.totalFaults,
    required this.totalMinutes,
    required this.avgKneeAngle,
    required this.avgHipAngle,
  });

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      children: [
        _StatCard(
          icon: Icons.fitness_center,
          value: '$totalWorkouts',
          label: 'Workouts',
          color: kPrimary,
        ),
        _StatCard(
          icon: Icons.repeat,
          value: '$totalSquats',
          label: 'Total Squats',
          color: const Color(0xFF1E88E5),
        ),
        _StatCard(
          icon: Icons.verified,
          value: '$bestForm%',
          label: 'Best Form',
          color: const Color(0xFFFF8F00),
        ),
        _StatCard(
          icon: Icons.warning,
          value: '$totalFaults',
          label: 'Total Faults',
          color: const Color(0xFFE53935),
        ),
        _StatCard(
          icon: Icons.timer,
          value: '${_formatTime(totalMinutes)}',
          label: 'Total Time',
          color: const Color(0xFF8E24AA),
        ),
        _StatCard(
          icon: Icons.assessment,
          value: '${avgKneeAngle.toStringAsFixed(1)}°',
          label: 'Avg Knee',
          color: const Color(0xFF00897B),
        ),
      ],
    );
  }

  String _formatTime(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m';
    }
    return '${minutes}m';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  final List<dynamic> workouts;

  const _RecentActivity({required this.workouts});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...workouts.map((w) => _RecentItem(workout: w)).toList(),
        ],
      ),
    );
  }
}

class _RecentItem extends StatelessWidget {
  final dynamic workout;

  const _RecentItem({required this.workout});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(workout['started_at'] as String);
    final formattedDate = '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    final reps = workout['total_reps'] as int? ?? 0;
    final duration = workout['duration_seconds'] as int? ?? 0;
    final minutes = duration ~/ 60;
    final kneeAngle = (workout['avg_knee_angle'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kPrimaryBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.fitness_center,
              color: kPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$reps squats • ${minutes}min',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
                Text(
                  '$formattedDate • ${kneeAngle.toStringAsFixed(1)}° knee angle',
                  style: const TextStyle(
                    fontSize: 12,
                    color: kTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: kPrimaryBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${reps} reps',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
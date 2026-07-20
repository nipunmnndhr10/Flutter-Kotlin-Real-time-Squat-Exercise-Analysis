import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_config.dart';

const kPrimary = Color(0xFF2E7D32);
const kPrimaryBackground = Color(0xFFE8F5E9);
const kTextPrimary = Color(0xFF1A1A1A);
const kTextSecondary = Color(0xFF757575);
const kBackground = Color(0xFFF5F5F5);

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  int _totalWorkouts = 0;
  int _totalSquats = 0;
  int _bestForm = 0;
  int _totalFaults = 0;
  int _totalMinutes = 0;
  double _avgKneeAngle = 0;
  double _avgHipAngle = 0;
  List<dynamic> _allWorkouts = [];

  @override
  void initState() {
    super.initState();
    _fetchProgressData();
  }

  Future<void> _fetchProgressData() async {
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

      final response = await Dio().get(
        '${AppConfig.apiBaseUrl}/workouts/',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        _allWorkouts = response.data;
        _calculateStats();
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load data';
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      setState(() {
        _errorMessage = 'Connection error: ${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading progress';
        _isLoading = false;
      });
    }
  }

  void _calculateStats() {
    if (_allWorkouts.isEmpty) return;

    _totalWorkouts = _allWorkouts.length;
    _totalSquats = _allWorkouts.fold(0, (sum, w) => sum + (w['total_reps'] as int? ?? 0));
    _totalMinutes = _allWorkouts.fold(0, (sum, w) => sum + ((w['duration_seconds'] as int? ?? 0) ~/ 60));

    _bestForm = _allWorkouts.fold(0, (best, w) {
      final angle = (w['avg_knee_angle'] as num?)?.toInt() ?? 0;
      return angle > best ? angle : best;
    });

    int totalFaults = 0;
    for (final w in _allWorkouts) {
      final faultSummary = w['fault_summary_json'] as Map?;
      if (faultSummary != null) {
        totalFaults += faultSummary.values.fold<int>(0, (sum, v) => sum + ((v as num?)?.toInt() ?? 0));
      }
    }
    _totalFaults = totalFaults;

    double totalKnee = 0;
    double totalHip = 0;
    for (final w in _allWorkouts) {
      totalKnee += (w['avg_knee_angle'] as num?)?.toDouble() ?? 0;
      totalHip += (w['avg_hip_angle'] as num?)?.toDouble() ?? 0;
    }
    _avgKneeAngle = _totalWorkouts > 0 ? totalKnee / _totalWorkouts : 0;
    _avgHipAngle = _totalWorkouts > 0 ? totalHip / _totalWorkouts : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text(
          'Progress',
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
            onPressed: _fetchProgressData,
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
                    'Loading progress...',
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
                        onPressed: _fetchProgressData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchProgressData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [kPrimary, const Color(0xFF4CAF50)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _SummaryStat(
                                value: '$_totalWorkouts',
                                label: 'Workouts',
                                icon: Icons.fitness_center,
                              ),
                              _SummaryStat(
                                value: '$_totalSquats',
                                label: 'Squats',
                                icon: Icons.repeat,
                              ),
                              _SummaryStat(
                                value: '$_bestForm%',
                                label: 'Best Form',
                                icon: Icons.verified,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
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
                                'Performance Stats',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: kTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              GridView(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1.5,
                                ),
                                children: [
                                  _ProgressStat(
                                    label: 'Total Faults',
                                    value: '$_totalFaults',
                                    icon: Icons.warning,
                                    color: const Color(0xFFE53935),
                                  ),
                                  _ProgressStat(
                                    label: 'Total Time',
                                    value: _formatTime(_totalMinutes),
                                    icon: Icons.timer,
                                    color: const Color(0xFF8E24AA),
                                  ),
                                  _ProgressStat(
                                    label: 'Avg Knee Angle',
                                    value: '${_avgKneeAngle.toStringAsFixed(1)}°',
                                    icon: Icons.assessment,
                                    color: const Color(0xFF00897B),
                                  ),
                                  _ProgressStat(
                                    label: 'Avg Hip Angle',
                                    value: '${_avgHipAngle.toStringAsFixed(1)}°',
                                    icon: Icons.assessment,
                                    color: const Color(0xFFFF8F00),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_allWorkouts.isNotEmpty)
                          Container(
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
                                  'Workout History',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: kTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ..._allWorkouts.take(5).map((w) => _HistoryItem(workout: w)).toList(),
                              ],
                            ),
                          ),
                        if (_allWorkouts.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(40),
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
                            child: const Column(
                              children: [
                                Icon(Icons.fitness_center, size: 64, color: kTextSecondary),
                                SizedBox(height: 16),
                                Text(
                                  'No workouts yet!',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: kTextPrimary,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Complete your first squat session\nto see progress here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: kTextSecondary),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
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

class _SummaryStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _SummaryStat({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

class _ProgressStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ProgressStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kPrimaryBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kTextPrimary,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: kTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final dynamic workout;

  const _HistoryItem({required this.workout});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(workout['started_at'] as String);
    final formattedDate = '${date.day}/${date.month}/${date.year}';
    final reps = workout['total_reps'] as int? ?? 0;
    final duration = workout['duration_seconds'] as int? ?? 0;
    final minutes = duration ~/ 60;
    final kneeAngle = (workout['avg_knee_angle'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kPrimaryBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.fitness_center,
              color: kPrimary,
              size: 18,
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
                  '$formattedDate • ${kneeAngle.toStringAsFixed(1)}° knee',
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
                fontSize: 11,
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
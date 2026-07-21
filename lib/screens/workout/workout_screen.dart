// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flt_kotlin_pose/core/constants/app_constants.dart';
import 'package:flt_kotlin_pose/screens/auth/loginscreen.dart';
import 'package:flt_kotlin_pose/screens/workout/pose_screen.dart';

const kPrimary = Color(0xFF4CAF50);
const kSecondary = Color(0xFF81C784);
const kBackground = Color(0xFFF9F9F9);
const kSurface = Color(0xFFE8F5E9);
const kTextPrimary = Color(0xFF1A1A1A);
const kTextMuted = Color(0xFF757575);

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Workout Session",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Start your squat workout and track your form in real-time.",
            style: TextStyle(fontSize: 14, color: kTextMuted),
          ),
          const SizedBox(height: 30),

          // Start Workout Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.fitness_center, size: 70, color: kPrimary),
                const SizedBox(height: 16),
                const Text(
                  "Squat Analysis",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "AI-powered squat tracking and form correction.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kTextMuted),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push<Map<String, dynamic>>(
                        context,
                        MaterialPageRoute(builder: (_) => const PoseScreen()),
                      );
                      if (!mounted || result == null) return;
                      await _showWorkoutSummaryDialog(result);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text(
                      "Start Workout",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Mistakes Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Common Mistakes",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kTextPrimary,
                  ),
                ),
                SizedBox(height: 12),
                _MistakeRow(mistake: "Knees caving in", count: 5),
                _MistakeRow(mistake: "Shallow squat depth", count: 3),
                _MistakeRow(mistake: "Back rounding", count: 2),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Workout Details Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Workout Details",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kTextPrimary,
                  ),
                ),
                SizedBox(height: 12),
                Text("• Real-time pose detection"),
                Text("• Automatic squat counting"),
                Text("• Form correction feedback"),
                Text("• Progress tracking"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showWorkoutSummaryDialog(Map<String, dynamic> summary) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Workout Summary'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryRow(
                label: 'Record ID',
                value: summary['id']?.toString() ?? 'Pending save',
              ),
              _SummaryRow(
                label: 'User',
                value: summary['userId']?.toString() ?? 'Authenticated user',
              ),
              _SummaryRow(
                label: 'Workout Type',
                value: summary['workoutType']?.toString() ?? '-',
              ),
              _SummaryRow(
                label: 'Started At',
                value: summary['startedAt']?.toString() ?? '-',
              ),
              _SummaryRow(
                label: 'Ended At',
                value: summary['endedAt']?.toString() ?? '-',
              ),
              _SummaryRow(
                label: 'Target Angle Threshold',
                value:
                    '${(summary['targetAngleThreshold'] as num?)?.toStringAsFixed(1) ?? '-'}°',
              ),
              _SummaryRow(
                label: 'Camera',
                value: summary['camera']?.toString() ?? '-',
              ),
              _SummaryRow(
                label: 'Fault Summary JSON',
                value: _formatFaultSummary(summary['faultSummaryJson']),
              ),
              const SizedBox(height: 4),
              _SummaryRow(
                label: 'Duration',
                value: '${summary['durationSeconds'] ?? '-'}s',
              ),
              _SummaryRow(
                label: 'Total Reps',
                value: summary['totalReps']?.toString() ?? '-',
              ),
              _SummaryRow(
                label: 'Avg Knee Angle',
                value:
                    '${(summary['avgKneeAngle'] as num?)?.toStringAsFixed(1) ?? '-'}°',
              ),
              _SummaryRow(
                label: 'Avg Hip Angle',
                value:
                    '${(summary['avgHipAngle'] as num?)?.toStringAsFixed(1) ?? '-'}°',
              ),
              _SummaryRow(
                label: 'Min Knee Angle',
                value:
                    '${(summary['minKneeAngle'] as num?)?.toStringAsFixed(1) ?? '-'}°',
              ),
              _SummaryRow(
                label: 'Min Hip Angle',
                value:
                    '${(summary['minHipAngle'] as num?)?.toStringAsFixed(1) ?? '-'}°',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _saveWorkoutSummary(summary);
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Workout saved successfully')),
                );
              } on DioException catch (e) {
                if (!dialogContext.mounted) return;
                if (e.response?.statusCode == 401) {
                  // Token expired — clear and redirect to login
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('access_token');
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Session expired. Please log in again.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to save workout: ${e.response?.data?['detail'] ?? e.message}',
                      ),
                    ),
                  );
                }
              } catch (error) {
                if (!dialogContext.mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed to save workout: $error')),
                );
              }
            },
            child: const Text('Save Workout'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Don't Save"),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveWorkoutSummary(Map<String, dynamic> summary) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null || token.isEmpty) {
      throw StateError('No access token found. Please log in again.');
    }

    final authedDio = Dio(
      BaseOptions(
        baseUrl: kApiBaseUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final payload = <String, dynamic>{
      'workout_type': summary['workoutType'],
      'started_at': summary['startedAt'],
      'ended_at': summary['endedAt'],
      'duration_seconds': summary['durationSeconds'],
      'target_angle_threshold': summary['targetAngleThreshold'],
      'camera': summary['camera'],
      'min_knee_angle': summary['minKneeAngle'],
      'avg_knee_angle': summary['avgKneeAngle'],
      'min_hip_angle': summary['minHipAngle'],
      'avg_hip_angle': summary['avgHipAngle'],
      'total_reps': summary['totalReps'],
      'fault_summary_json': summary['faultSummaryJson'],
    };

    await authedDio.post('/workouts/', data: payload);
  }

  String _formatFaultSummary(dynamic faultSummary) {
    if (faultSummary is! Map || faultSummary.isEmpty) {
      return '{}';
    }

    final entries = faultSummary.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    final buffer = StringBuffer('{');
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      buffer.write('"${entry.key}": ${entry.value}');
      if (i < entries.length - 1) buffer.write(', ');
    }
    buffer.write('}');
    return buffer.toString();
  }
}

// Mistake Row Widget
class _MistakeRow extends StatelessWidget {
  final String mistake;
  final int count;

  const _MistakeRow({required this.mistake, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "• $mistake",
            style: const TextStyle(color: kTextMuted, fontSize: 14),
          ),
          Text(
            "x$count",
            style: const TextStyle(
              color: kPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kTextMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

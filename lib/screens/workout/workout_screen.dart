// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flt_kotlin_pose/core/constants/app_constants.dart';
import 'package:flt_kotlin_pose/screens/auth/loginscreen.dart';
import 'package:flt_kotlin_pose/screens/workout/workout_loading_screen.dart';
import 'package:flt_kotlin_pose/screens/workout/workout_summary_dialog.dart';

// Kinetic Noir Color System (from start workout screen.md)
const kBackground = Color(0xFFFCF8F8);
const kSurface = Color(0xFFF6F3F2);
const kSurfaceContainerHigh = Color(0xFFEBE7E7);
const kSurfaceContainerHighest = Color(0xFFE5E2E1);
const kTextPrimary = Color(0xFF1C1B1B);
const kTextMuted = Color(0xFF696A6D);
const kPrimary = Color(0xFF506600);
const kPrimaryLime = Color(0xFFD9FE03); // Bright electric lime for CTA
const kSecondary = Color(0xFF006970);
const kSecondaryContainer = Color(0xFF00EEFC);

class WorkoutScreen extends StatefulWidget {
  final VoidCallback? onWorkoutSaved;
  const WorkoutScreen({super.key, this.onWorkoutSaved});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: kBackground,
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header: New Session
              Text(
                'New Session',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: kTextPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Position your camera to capture your full range of motion.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: kTextMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Image & Start Workout Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kSurfaceContainerHighest, width: 1),
                ),
                child: Column(
                  children: [
                    // Squat Pose Tracking Preview Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: Image.asset(
                          'assets/squat-posetrack.png',
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // START WORKOUT Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () async {
                          final result = await Navigator.push<Map<String, dynamic>>(
                            context,
                            MaterialPageRoute(builder: (_) => const WorkoutLoadingScreen()),
                          );
                          if (!mounted || result == null) return;
                          await _showWorkoutSummaryDialog(result);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryLime,
                          foregroundColor: kTextPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.play_circle_outline_rounded,
                              size: 22,
                              color: kTextPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'START WORKOUT',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: kTextPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Section Header: Get Started
              Text(
                'Get Started',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 14),

              // Info Card 1: AI Engine & Form Tracking
              _InfoCard(
                icon: Icons.psychology_outlined,
                title: 'AI Engine & Form Tracking',
                bulletPoints: const [
                  '3D Tracking: Analyzes live knee/hip angles, camera views, and movement phases.',
                  'Fault Detection: Automatically flags shallow depth, knee cave, chest collapse, or going too low.',
                ],
              ),

              const SizedBox(height: 14),

              // Info Card 2: What to Keep in Mind
              _InfoCard(
                icon: Icons.lightbulb_outline_rounded,
                title: 'What to Keep in Mind',
                bulletPoints: const [
                  'Side View is Best: Stand sideways to the camera for optimal depth tracking.',
                  'Optimal Setup: Place phone at hip height and ensure your full body is in frame.',
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showWorkoutSummaryDialog(Map<String, dynamic> summary) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return WorkoutSummaryDialog(
          summary: summary,
          onSave: () async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await _saveWorkoutSummary(summary);
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Workout saved successfully'),
                  backgroundColor: kPrimary,
                ),
              );
              if (widget.onWorkoutSaved != null) {
                widget.onWorkoutSaved!();
              }
            } on DioException catch (e) {
              if (!dialogContext.mounted) return;
              if (e.response?.statusCode == 401) {
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
          onDiscard: () {
            Navigator.of(dialogContext).pop();
          },
          onClose: () {
            Navigator.of(dialogContext).pop();
          },
        );
      },
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
      'duration_seconds': summary['durationSeconds'] ?? 0,
      'target_angle_threshold': summary['targetAngleThreshold'],
      'camera': summary['camera'],
      'min_knee_angle': summary['minKneeAngle'] ?? 0.0,
      'avg_knee_angle': summary['avgKneeAngle'] ?? 0.0,
      'min_hip_angle': summary['minHipAngle'] ?? 0.0,
      'avg_hip_angle': summary['avgHipAngle'] ?? 0.0,
      'total_reps': summary['totalReps'] ?? 0,
      'fault_summary_json': summary['faultSummaryJson'] ?? {},
    };

    await authedDio.post('/workouts/', data: payload);
  }


}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> bulletPoints;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.bulletPoints,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSurfaceContainerHighest, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kSecondaryContainer.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: kSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...bulletPoints.map(
            (point) => Padding(
              padding: const EdgeInsets.only(left: 52, bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: kTextMuted,
                      height: 1.4,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      point,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: kTextMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


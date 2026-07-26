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

// Dark Mode Edition Tokens
const kDarkBg = Color(0xFF111710);
const kDarkSurface = Color(0xFF1B2319);
const kDarkContainerHigh = Color(0xFF222B1F);
const kDarkTextMuted = Color(0xFF889684);
const kNeonLime = Color(0xFF82D616);

class WorkoutScreen extends StatefulWidget {
  final VoidCallback? onWorkoutSaved;
  const WorkoutScreen({super.key, this.onWorkoutSaved});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? kDarkBg : kBackground;
    final cardBg = isDark ? kDarkSurface : kSurface;
    final cardBorder = isDark ? const Color(0xFF222B1F) : kSurfaceContainerHighest;
    final titleColor = isDark ? Colors.white : kTextPrimary;
    final subtitleColor = isDark ? kDarkTextMuted : kTextMuted;

    return SafeArea(
      child: Scaffold(
        backgroundColor: bg,
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
                  color: titleColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Position your camera to capture your full range of motion.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: subtitleColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Image & Start Workout Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorder, width: 1),
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
                          final result =
                              await Navigator.push<Map<String, dynamic>>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const WorkoutLoadingScreen(),
                                ),
                              );
                          if (!mounted || result == null) return;
                          await _showWorkoutSummaryDialog(result);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? kNeonLime : kPrimaryLime,
                          foregroundColor: const Color(0xFF111710),
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
                              color: Color(0xFF111710),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'START WORKOUT',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF111710),
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
                  color: titleColor,
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
          onSave: (sessionName) async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await _saveWorkoutSummary(summary, sessionName);
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

  Future<void> _saveWorkoutSummary(
    Map<String, dynamic> summary,
    String? sessionName,
  ) async {
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

    final totalReps = (summary['totalReps'] as num?)?.toInt() ?? 0;
    final faultMap = summary['faultSummaryJson'] as Map? ?? {};

    int formScore = 100;
    if (totalReps > 0) {
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
      double weightedPoints = 0.0;
      faultMap.forEach((key, count) {
        if (count is num && count > 0) {
          final normKey = key.toString().toLowerCase();
          final w = weights[normKey] ?? 1.5;
          final effectiveCount = count <= 2 ? count * 0.5 : count.toDouble();
          weightedPoints += effectiveCount * w;
        }
      });
      final penalty = (weightedPoints / totalReps) * 15;
      formScore = (100 - penalty).clamp(0, 100).round();
    }

    final payload = <String, dynamic>{
      'session_name': sessionName,
      'started_at': summary['startedAt'],
      'ended_at': summary['endedAt'],
      'duration_seconds': summary['durationSeconds'] ?? 0,
      'target_angle_threshold': summary['targetAngleThreshold'],
      'camera': summary['camera'],
      'min_knee_angle': summary['minKneeAngle'] ?? 0.0,
      'avg_knee_angle': summary['avgKneeAngle'] ?? 0.0,
      'min_hip_angle': summary['minHipAngle'] ?? 0.0,
      'avg_hip_angle': summary['avgHipAngle'] ?? 0.0,
      'total_reps': totalReps,
      'form_score': formScore,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? kDarkSurface : kSurface;
    final cardBorder = isDark ? const Color(0xFF222B1F) : kSurfaceContainerHighest;
    final iconBg = isDark ? kDarkContainerHigh : kSecondaryContainer.withValues(alpha: 0.35);
    final iconColor = isDark ? kPrimaryLime : kSecondary;
    final titleColor = isDark ? Colors.white : kTextPrimary;
    final bulletColor = isDark ? kDarkTextMuted : kTextMuted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
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
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
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
                      color: bulletColor,
                      height: 1.4,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      point,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: bulletColor,
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

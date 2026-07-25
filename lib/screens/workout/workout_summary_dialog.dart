import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// Colors from Kinetic Noir (Light Mode)
const kSurface = Color(0xFFFCF8F8);
const kSurfaceContainer = Color(0xFFF0EDEC);
const kPrimaryLime = Color(0xFFCCFF00); // For the big save button
const kTextPrimary = Color(0xFF1C1B1B);
const kTextMuted = Color(0xFF696A6D);
const kErrorContainer = Color(0xFFFFDAD6);
const kOnErrorContainer = Color(0xFF93000A);
const kError = Color(0xFFBA1A1A);

class WorkoutSummaryDialog extends StatelessWidget {
  final Map<String, dynamic> summary;
  final VoidCallback? onSave;
  final VoidCallback? onDiscard;
  final VoidCallback onClose;
  final bool isHistoryView;

  const WorkoutSummaryDialog({
    super.key,
    required this.summary,
    this.onSave,
    this.onDiscard,
    required this.onClose,
    this.isHistoryView = false,
  });

  @override
  Widget build(BuildContext context) {
    // Extract and parse data
    final totalReps = summary['totalReps'] ?? summary['total_reps'] ?? 0;
    final duration = summary['durationSeconds'] ?? summary['duration_seconds'] ?? 0;
    
    // Hardcoded form score for now
    int formScore = 95;
    
    var rawFaults = summary['faultSummaryJson'] ?? summary['fault_summary_json'];
    if (rawFaults is String) {
      try {
        rawFaults = jsonDecode(rawFaults);
      } catch (_) {
        rawFaults = {};
      }
    }
    final faultMap = rawFaults as Map? ?? {};

    // Date formatting
    String dateStr = '';
    final endDateStr = summary['endedAt'] ?? summary['ended_at'];
    if (endDateStr != null) {
      try {
        final dt = DateTime.parse(endDateStr.toString()).toLocal();
        dateStr = DateFormat('MMM d, yyyy • h:mm a').format(dt);
      } catch (_) {
        dateStr = endDateStr.toString();
      }
    }

    final cameraMode = (summary['camera']?.toString() ?? 'UNKNOWN').toUpperCase();

    return Dialog(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 400,
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Form Score Circle
                    Center(
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: formScore / 100,
                              strokeWidth: 8,
                              backgroundColor: const Color(0xFFE5E2E1), // surface-container-highest
                              color: kPrimaryLime,
                              strokeCap: StrokeCap.round,
                            ),
                            Center(
                              child: Text(
                                '$formScore%',
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: kTextPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Title and Date
                    Text(
                      'Form Score',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary,
                      ),
                    ),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: kTextMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Top Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'TOTAL REPS',
                            value: totalReps.toString(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'DURATION',
                            value: '${duration}s',
                          ),
                        ),
                      ],
                    ),
                    
                    if (faultMap.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'FAULTS DETECTED',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                          color: kTextMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...faultMap.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _FaultCard(
                            faultName: e.key.toString(),
                            count: (e.value as num).toInt(),
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 24),
                    
                    // Kinematic Data Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'KINEMATIC DATA',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                            color: kTextMuted,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: kSurfaceContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'CAM: $cameraMode',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: kTextMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Kinematic Stats
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'AVG KNEE ANGLE',
                            value: '${(summary['avgKneeAngle'] ?? summary['avg_knee_angle'] as num?)?.toStringAsFixed(1) ?? '-'}°',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'AVG HIP ANGLE',
                            value: '${(summary['avgHipAngle'] ?? summary['avg_hip_angle'] as num?)?.toStringAsFixed(1) ?? '-'}°',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'MIN KNEE ANGLE',
                            value: '${(summary['minKneeAngle'] ?? summary['min_knee_angle'] as num?)?.toStringAsFixed(1) ?? '-'}°',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'MIN HIP ANGLE',
                            value: '${(summary['minHipAngle'] ?? summary['min_hip_angle'] as num?)?.toStringAsFixed(1) ?? '-'}°',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: kSurface,
                border: Border(
                  top: BorderSide(
                    color: kSurfaceContainer,
                    width: 1,
                  ),
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: isHistoryView
                  ? SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: onClose,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryLime,
                          foregroundColor: kTextPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Close',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: onSave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryLime,
                              foregroundColor: kTextPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Save Workout',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: onDiscard,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: kTextMuted,
                                    side: const BorderSide(color: kSurfaceContainer, width: 1.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Discard',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: onClose,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: kTextPrimary,
                                    side: const BorderSide(color: kSurfaceContainer, width: 1.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Close',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: kTextMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: kTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FaultCard extends StatelessWidget {
  final String faultName;
  final int count;

  const _FaultCard({required this.faultName, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kErrorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kErrorContainer.withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 12),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: kError,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  faultName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Occurred $count times during the set.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: kTextPrimary.withValues(alpha: 0.7),
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

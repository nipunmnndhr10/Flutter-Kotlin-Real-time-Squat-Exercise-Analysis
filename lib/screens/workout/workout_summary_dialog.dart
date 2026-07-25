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

class WorkoutSummaryDialog extends StatefulWidget {
  final Map<String, dynamic> summary;
  final Function(String)? onSave;
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
  State<WorkoutSummaryDialog> createState() => _WorkoutSummaryDialogState();
}

class _WorkoutSummaryDialogState extends State<WorkoutSummaryDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _scoreAnimation;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.summary['session_name'] ?? '';
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _scoreAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Cubic(0.1, 0.85, 0.15, 1.0),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  int _calculateFormScore(int reps, Map faultMap) {
    if (reps <= 0) return faultMap.isEmpty ? 100 : 0;

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
        // False-positive noise reduction: discount <= 2 occurrences by 50%
        final effectiveCount = count <= 2 ? count * 0.5 : count.toDouble();
        weightedPoints += effectiveCount * w;
      }
    });

    final penalty = (weightedPoints / reps) * 15;
    return (100 - penalty).clamp(0, 100).round();
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return kPrimaryLime; // Lime Green (>= 80%)
    if (score >= 65) return const Color(0xFFF1C40F); // Dark Yellow (65% - 79%)
    return const Color(0xFFFF5252); // Coral Red (< 65%)
  }

  @override
  Widget build(BuildContext context) {
    // Extract and parse data
    final totalReps =
        widget.summary['totalReps'] ?? widget.summary['total_reps'] ?? 0;
    final duration =
        widget.summary['durationSeconds'] ??
        widget.summary['duration_seconds'] ??
        0;

    var rawFaults =
        widget.summary['faultSummaryJson'] ??
        widget.summary['fault_summary_json'];
    if (rawFaults is String) {
      try {
        rawFaults = jsonDecode(rawFaults);
      } catch (_) {
        rawFaults = {};
      }
    }
    final faultMap = rawFaults as Map? ?? {};

    // Dynamic Form Score Calculation
    final computedScore = _calculateFormScore(totalReps as int, faultMap);
    final rawFormScore = widget.summary['form_score'] ?? widget.summary['formScore'];
    final formScore = (rawFormScore != null && (rawFormScore != 100 || faultMap.isEmpty))
        ? (rawFormScore as num).toInt()
        : computedScore;

    final scoreColor = _getScoreColor(formScore);

    // Date formatting
    String dateStr = '';
    final endDateStr = widget.summary['endedAt'] ?? widget.summary['ended_at'];
    if (endDateStr != null) {
      try {
        final dt = DateTime.parse(endDateStr.toString()).toLocal();
        dateStr = DateFormat('MMM d, yyyy • h:mm a').format(dt);
      } catch (_) {
        dateStr = endDateStr.toString();
      }
    }

    final cameraMode = (widget.summary['camera']?.toString() ?? 'UNKNOWN')
        .toUpperCase();

    return Dialog(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
          maxWidth: 400,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Form Score Circle with Sweeping Progress & Counter Animation
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          _animController.forward(from: 0.0);
                        },
                        child: SizedBox(
                          width: 124,
                          height: 124,
                          child: AnimatedBuilder(
                            animation: _scoreAnimation,
                            builder: (context, _) {
                              final rawProgress =
                                  (_scoreAnimation.value * formScore) / 100.0;
                              // Scale indicator slightly when < 100% so StrokeCap.round leaves a crisp visible gap
                              final displayProgress = formScore < 100
                                  ? (rawProgress * 0.96)
                                  : rawProgress;
                              final animatedScore =
                                  (_scoreAnimation.value * formScore).round();
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  CircularProgressIndicator(
                                    value: displayProgress,
                                    strokeWidth: 10,
                                    backgroundColor: const Color(0xFFE5E2E1),
                                    color: scoreColor,
                                    strokeCap: StrokeCap.round,
                                  ),
                                  Center(
                                    child: Text(
                                      '$animatedScore%',
                                      style: GoogleFonts.hankenGrotesk(
                                        fontSize: 34,
                                        fontWeight: FontWeight.w800,
                                        color: kTextPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

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
                    const SizedBox(height: 16),

                    if (!widget.isHistoryView) ...[
                      TextField(
                        controller: _nameController,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: kTextPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Name this workout (e.g., Leg Day)',
                          hintStyle: GoogleFonts.inter(
                            color: kTextMuted,
                            fontWeight: FontWeight.normal,
                          ),
                          filled: true,
                          fillColor: kSurfaceContainer,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ] else ...[
                      if (_nameController.text.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: kSurfaceContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _nameController.text,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary,
                            ),
                          ),
                        ),
                    ],

                    const SizedBox(height: 18),

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
                      const SizedBox(height: 20),
                      Text(
                        'FAULTS DETECTED',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                          color: kTextMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...faultMap.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _FaultCard(
                            faultName: e.key.toString(),
                            count: (e.value as num).toInt(),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ] else ...[
                      const SizedBox(height: 20),
                    ],

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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
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
                    const SizedBox(height: 8),

                    // Kinematic Stats
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'AVG KNEE ANGLE',
                            value:
                                '${(widget.summary['avgKneeAngle'] ?? widget.summary['avg_knee_angle'] as num?)?.toStringAsFixed(1) ?? '-'}°',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'AVG HIP ANGLE',
                            value:
                                '${(widget.summary['avgHipAngle'] ?? widget.summary['avg_hip_angle'] as num?)?.toStringAsFixed(1) ?? '-'}°',
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
                            value:
                                '${(widget.summary['minKneeAngle'] ?? widget.summary['min_knee_angle'] as num?)?.toStringAsFixed(1) ?? '-'}°',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'MIN HIP ANGLE',
                            value:
                                '${(widget.summary['minHipAngle'] ?? widget.summary['min_hip_angle'] as num?)?.toStringAsFixed(1) ?? '-'}°',
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
                  top: BorderSide(color: kSurfaceContainer, width: 1),
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: widget.isHistoryView
                  ? SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: widget.onClose,
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
                            onPressed: () {
                              if (widget.onSave != null) {
                                widget.onSave!(_nameController.text.trim());
                              }
                            },
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
                                  onPressed: widget.onDiscard,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: kTextMuted,
                                    side: const BorderSide(
                                      color: kSurfaceContainer,
                                      width: 1.5,
                                    ),
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
                                  onPressed: widget.onClose,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: kTextPrimary,
                                    side: const BorderSide(
                                      color: kSurfaceContainer,
                                      width: 1.5,
                                    ),
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

  String get formattedFaultName {
    final clean = faultName.replaceAll('_', ' ').trim();
    if (clean.isEmpty) return 'Fault Detected';
    return clean.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }

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
                  formattedFaultName,
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

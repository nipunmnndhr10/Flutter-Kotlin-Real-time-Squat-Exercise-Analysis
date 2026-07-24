import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kBackground = Color(0xFFFCF8F8);
const kSurface = Color(0xFFF6F3F2);
const kSurfaceContainerHigh = Color(0xFFEBE7E7);
const kSurfaceContainerHighest = Color(0xFFE5E2E1);
const kTextPrimary = Color(0xFF1C1B1B);
const kTextVariant = Color(0xFF444933);
const kTextMuted = Color(0xFF696A6D);
const kPrimary = Color(0xFF506600);
const kPrimaryContainer = Color(0xFFCCFF00);
const kOnPrimaryContainer = Color(0xFF5B7300);
const kSecondary = Color(0xFF006970);
const kSecondaryContainer = Color(0xFF00EEFC);
const kOutlineVariant = Color(0xFFC4C9AC);

class HistoryScreen extends StatelessWidget {
  final String userName;
  final String greeting;
  final String profilePictureUrl;
  final VoidCallback onLogout;
  final List<Map<String, dynamic>> workouts;
  final Future<void> Function(int sessionId) onDeleteWorkout;

  const HistoryScreen({
    super.key,
    required this.userName,
    required this.greeting,
    this.profilePictureUrl = '',
    required this.onLogout,
    required this.workouts,
    required this.onDeleteWorkout,
  });

  Map<String, int> _getThisWeekStats(List<Map<String, dynamic>> workouts) {
    final now = DateTime.now();
    final mondayThisWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    int sessionsCount = 0;
    int totalSeconds = 0;

    for (final w in workouts) {
      final startedAtStr = w['started_at']?.toString();
      if (startedAtStr != null && startedAtStr.isNotEmpty) {
        final dt = DateTime.tryParse(startedAtStr)?.toLocal();
        if (dt != null && !dt.isBefore(mondayThisWeek)) {
          sessionsCount++;
          final dur = w['duration_seconds'];
          final seconds = dur is num
              ? dur.toInt()
              : (int.tryParse(dur?.toString() ?? '0') ?? 0);
          totalSeconds += seconds;
        }
      }
    }

    final totalMinutes = (totalSeconds / 60).round();
    return {
      'sessions': sessionsCount,
      'minutes': totalMinutes,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = _getThisWeekStats(workouts);
    final thisWeekSessions = stats['sessions'] ?? 0;
    final thisWeekMinutes = stats['minutes'] ?? 0;

    return SafeArea(
      child: Scaffold(
        backgroundColor: kBackground,
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'History',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Review your past performance.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: kTextMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'THIS WEEK',
                      value: '$thisWeekSessions',
                      unit: 'Sessions',
                      icon: Icons.calendar_today_outlined,
                      iconColor: kSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'TOTAL MINUTES',
                      value: '$thisWeekMinutes',
                      unit: 'min',
                      icon: Icons.timer_outlined,
                      iconColor: kPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Past Workouts',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                  height: 1.33,
                ),
              ),
              const SizedBox(height: 14),
              if (workouts.isEmpty)
                _buildEmptyState()
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: workouts.length,
                  itemBuilder: (context, index) {
                    final workout = workouts[index];
                    return _WorkoutHistoryCard(
                      workout: workout,
                      onTap: () => _showWorkoutDetails(context, workout),
                      onLongPress: () => _showLongPressOptions(context, workout),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSurfaceContainerHighest, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 56,
            color: kTextMuted,
          ),
          const SizedBox(height: 14),
          Text(
            'No Workouts Yet',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start a workout to see your history here!',
            style: GoogleFonts.inter(fontSize: 14, color: kTextMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showLongPressOptions(BuildContext context, Map<String, dynamic> workout) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: kSurfaceContainerHigh,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: kTextPrimary),
                  title: Text(
                    'View Session Details',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      color: kTextPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showWorkoutDetails(context, workout);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(
                    'Delete Workout Session',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      color: Colors.red,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showDeleteConfirmation(context, workout);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWorkoutDetails(BuildContext context, Map<String, dynamic> workout) {
    showDialog(
      context: context,
      builder: (context) {
        final duration = workout['duration_seconds'] ?? 0;
        final minutes = duration ~/ 60;
        final seconds = duration % 60;
        final durationText = minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';

        final startedAt = workout['started_at'] != null
            ? DateTime.tryParse(workout['started_at'].toString())?.toLocal()
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
                      style: GoogleFonts.inter(fontSize: 13, color: kTextPrimary),
                    ),
                    Text(
                      'x$value',
                      style: GoogleFonts.jetBrainsMono(
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
                color: const Color(0x1A506600),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: kPrimary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Perfect Form! No faults detected.',
                    style: GoogleFonts.inter(
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
          backgroundColor: kBackground,
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
                        decoration: const BoxDecoration(
                          color: Color(0x1A506600),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fitness_center,
                          color: kPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Session Details',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: kTextPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close, color: kTextMuted, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Workout started on $startedAtText',
                    style: GoogleFonts.jetBrainsMono(fontSize: 12, color: kTextMuted),
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
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: kTextMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Target Angle: ${(workout['target_angle_threshold'] as num?)?.toStringAsFixed(1) ?? '-'}°',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: kTextMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.black12, height: 1),
                  const SizedBox(height: 16),
                  Text(
                    'Form Faults',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 16,
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
                      child: Text(
                        'Done',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
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
        border: Border.all(color: kSurfaceContainerHighest, width: 1),
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
                style: GoogleFonts.inter(
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
            style: GoogleFonts.jetBrainsMono(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Map<String, dynamic> workout) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool deleting = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: kBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Delete Workout?',
                style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.bold),
              ),
              content: deleting
                  ? const SizedBox(
                      height: 80,
                      child: Center(
                        child: CircularProgressIndicator(color: kPrimary),
                      ),
                    )
                  : Text(
                      'Are you sure you want to permanently delete this workout session? This cannot be undone.',
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
              actions: deleting
                  ? []
                  : [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(color: kTextMuted),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          setStateDialog(() {
                            deleting = true;
                          });
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await onDeleteWorkout(workout['id']);
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Workout session deleted successfully'),
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
                                content: Text('Failed to delete workout session'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: Text(
                          'Delete',
                          style: GoogleFonts.inter(
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
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color iconColor;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kTextMuted,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(
                icon,
                size: 16,
                color: iconColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: kTextPrimary,
              height: 1.0,
              letterSpacing: -0.36,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            unit,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: kTextMuted,
            ),
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

  String _formatWorkoutDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    final dt = DateTime.tryParse(dateStr)?.toLocal();
    if (dt == null) return dateStr;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final workoutDate = DateTime(dt.year, dt.month, dt.day);

    final hourNum = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    final timeStr = '${hourNum.toString().padLeft(2, '0')}:$minute $ampm';

    if (workoutDate == today) {
      return 'Today, $timeStr';
    } else if (workoutDate == yesterday) {
      return 'Yesterday, $timeStr';
    } else {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final month = months[dt.month - 1];
      return '$month ${dt.day}, $timeStr';
    }
  }

  @override
  Widget build(BuildContext context) {
    const String workoutTitle = 'Squats';

    final durationSec = workout['duration_seconds'];
    final seconds = durationSec is num
        ? durationSec.toInt()
        : (int.tryParse(durationSec?.toString() ?? '0') ?? 0);

    final durationText = seconds >= 60
        ? '${(seconds / 60).round()} min'
        : '$seconds sec';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSurfaceContainerHighest, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0x1A506600),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    color: kPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workoutTitle,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatWorkoutDateTime(workout['started_at']),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          color: kTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  durationText,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

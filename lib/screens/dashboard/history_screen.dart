import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flt_kotlin_pose/screens/workout/workout_summary_dialog.dart';

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

enum _HistoryFilter { all, thisWeek, thisMonth, highForm }

class HistoryScreen extends StatefulWidget {
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

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _HistoryFilter _selectedFilter = _HistoryFilter.all;

  List<Map<String, dynamic>> _memoizedWorkouts = [];
  List<Map<String, dynamic>>? _lastWorkouts;
  _HistoryFilter? _lastFilter;

  List<Map<String, dynamic>> get _filteredWorkouts {
    if (identical(widget.workouts, _lastWorkouts) && _selectedFilter == _lastFilter) {
      return _memoizedWorkouts;
    }

    final sorted = List<Map<String, dynamic>>.from(widget.workouts)..sort((a, b) {
      final dtA = DateTime.tryParse(a['started_at']?.toString() ?? '') ?? DateTime(1970);
      final dtB = DateTime.tryParse(b['started_at']?.toString() ?? '') ?? DateTime(1970);
      return dtB.compareTo(dtA);
    });

    if (_selectedFilter == _HistoryFilter.all) {
      _memoizedWorkouts = sorted;
    } else {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final mondayThisWeek = today.subtract(Duration(days: now.weekday - 1));

      _memoizedWorkouts = sorted.where((w) {
        final startedAtStr = w['started_at']?.toString();
        final dt = startedAtStr != null ? DateTime.tryParse(startedAtStr)?.toLocal() : null;

        if (_selectedFilter == _HistoryFilter.thisWeek) {
          if (dt == null) return false;
          return !dt.isBefore(mondayThisWeek);
        } else if (_selectedFilter == _HistoryFilter.thisMonth) {
          if (dt == null) return false;
          return dt.year == now.year && dt.month == now.month;
        } else if (_selectedFilter == _HistoryFilter.highForm) {
          final formVal = (w['form_score'] ?? w['formScore'] as num?)?.toDouble() ?? 100.0;
          return formVal >= 90.0;
        }
        return true;
      }).toList();
    }

    _lastWorkouts = widget.workouts;
    _lastFilter = _selectedFilter;
    return _memoizedWorkouts;
  }

  @override
  Widget build(BuildContext context) {
    final displayWorkouts = _filteredWorkouts;

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
              _HistorySummaryRow(workouts: widget.workouts),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Past Workouts',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary,
                    ),
                  ),
                  PopupMenuButton<_HistoryFilter>(
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    menuPadding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 140, maxWidth: 165),
                    position: PopupMenuPosition.under,
                    popUpAnimationStyle: AnimationStyle(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.fastOutSlowIn,
                      reverseDuration: const Duration(milliseconds: 140),
                      reverseCurve: Curves.easeInCubic,
                    ),
                    initialValue: _selectedFilter,
                    onSelected: (_HistoryFilter newFilter) {
                      setState(() => _selectedFilter = newFilter);
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: kSurfaceContainerHighest, width: 1),
                    ),
                    color: kSurface,
                    elevation: 6,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _HistoryFilter.all,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.clear_all_rounded,
                              size: 16,
                              color: _selectedFilter == _HistoryFilter.all ? kPrimary : kTextMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'All Workouts',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: _selectedFilter == _HistoryFilter.all ? FontWeight.w700 : FontWeight.w500,
                                color: _selectedFilter == _HistoryFilter.all ? kPrimary : kTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: _HistoryFilter.thisWeek,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.date_range_rounded,
                              size: 16,
                              color: _selectedFilter == _HistoryFilter.thisWeek ? kPrimary : kTextMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'This Week',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: _selectedFilter == _HistoryFilter.thisWeek ? FontWeight.w700 : FontWeight.w500,
                                color: _selectedFilter == _HistoryFilter.thisWeek ? kPrimary : kTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: _HistoryFilter.thisMonth,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 16,
                              color: _selectedFilter == _HistoryFilter.thisMonth ? kPrimary : kTextMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'This Month',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: _selectedFilter == _HistoryFilter.thisMonth ? FontWeight.w700 : FontWeight.w500,
                                color: _selectedFilter == _HistoryFilter.thisMonth ? kPrimary : kTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: _HistoryFilter.highForm,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.stars_rounded,
                              size: 16,
                              color: _selectedFilter == _HistoryFilter.highForm ? kPrimary : kTextMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'High Form (≥90%)',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: _selectedFilter == _HistoryFilter.highForm ? FontWeight.w700 : FontWeight.w500,
                                color: _selectedFilter == _HistoryFilter.highForm ? kPrimary : kTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _selectedFilter != _HistoryFilter.all ? kPrimary.withAlpha(25) : kSurfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedFilter != _HistoryFilter.all ? kPrimary.withAlpha(100) : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 14,
                            color: _selectedFilter != _HistoryFilter.all ? kPrimary : kTextMuted,
                          ),
                          const SizedBox(width: 5),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 150),
                            child: Text(
                              _selectedFilter == _HistoryFilter.all
                                  ? 'Filter'
                                  : _selectedFilter == _HistoryFilter.thisWeek
                                      ? 'Week'
                                      : _selectedFilter == _HistoryFilter.thisMonth
                                          ? 'Month'
                                          : 'High Form',
                              key: ValueKey(_selectedFilter),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _selectedFilter != _HistoryFilter.all ? kPrimary : kTextPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 16,
                            color: _selectedFilter != _HistoryFilter.all ? kPrimary : kTextMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: KeyedSubtree(
                  key: ValueKey(_selectedFilter),
                  child: displayWorkouts.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: displayWorkouts.length,
                          itemBuilder: (context, index) {
                            final workout = displayWorkouts[index];
                            return _WorkoutHistoryCard(
                              workout: workout,
                              onTap: () => _showWorkoutDetails(context, workout),
                              onLongPress: () => _showLongPressOptions(context, workout),
                            );
                          },
                        ),
                ),
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
      builder: (_) => WorkoutSummaryDialog(
        summary: workout,
        isHistoryView: true,
        onClose: () => Navigator.of(context).pop(),
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
                            await widget.onDeleteWorkout(workout['id']);
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

class _HistorySummaryRow extends StatefulWidget {
  final List<Map<String, dynamic>> workouts;
  const _HistorySummaryRow({required this.workouts});

  @override
  State<_HistorySummaryRow> createState() => _HistorySummaryRowState();
}

class _HistorySummaryRowState extends State<_HistorySummaryRow> {
  bool _isWeekly = true; // Default: THIS WEEK

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

  Map<String, int> _getAllTimeStats(List<Map<String, dynamic>> workouts) {
    int totalSeconds = 0;
    for (final w in workouts) {
      final dur = w['duration_seconds'];
      final seconds = dur is num
          ? dur.toInt()
          : (int.tryParse(dur?.toString() ?? '0') ?? 0);
      totalSeconds += seconds;
    }
    final totalMinutes = (totalSeconds / 60).round();
    return {
      'sessions': workouts.length,
      'minutes': totalMinutes,
    };
  }

  @override
  Widget build(BuildContext context) {
    final weekStats = _getThisWeekStats(widget.workouts);
    final allTimeStats = _getAllTimeStats(widget.workouts);

    final sessionsVal = _isWeekly ? weekStats['sessions'] ?? 0 : allTimeStats['sessions'] ?? 0;
    final sessionsTitle = _isWeekly ? 'THIS WEEK' : 'ALL TIME';

    final minutesVal = _isWeekly ? weekStats['minutes'] ?? 0 : allTimeStats['minutes'] ?? 0;

    void toggle() => setState(() => _isWeekly = !_isWeekly);

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: sessionsTitle,
            value: '$sessionsVal',
            unit: 'Sessions',
            icon: Icons.calendar_today_outlined,
            iconColor: kSecondary,
            onTap: toggle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            title: 'TOTAL MINUTES',
            value: '$minutesVal',
            unit: 'min',
            icon: Icons.timer_outlined,
            iconColor: kPrimary,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
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
        ),
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

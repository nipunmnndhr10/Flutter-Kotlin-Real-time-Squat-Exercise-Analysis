import 'package:flutter/material.dart';

const kPrimary = Color(0xFF4CAF50);
const kSecondary = Color(0xFF81C784);
const kBackground = Color(0xFFF9F9F9);
const kSurface = Color(0xFFE8F5E9);
const kTextPrimary = Color(0xFF1A1A1A);
const kTextMuted = Color(0xFF757575);

class HistoryScreen extends StatelessWidget {
  final String userName;
  final String greeting;
  final VoidCallback onLogout;
  final List<Map<String, dynamic>> workouts;
  final Future<void> Function(int sessionId) onDeleteWorkout;

  const HistoryScreen({
    super.key,
    required this.userName,
    required this.greeting,
    required this.onLogout,
    required this.workouts,
    required this.onDeleteWorkout,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: _Header(
            userName: userName,
            greeting: greeting,
            onLogout: onLogout,
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
          child: workouts.isEmpty
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
                  itemCount: workouts.length,
                  itemBuilder: (context, index) {
                    final workout = workouts[index];
                    return _WorkoutHistoryCard(
                      workout: workout,
                      onTap: () => _showWorkoutDetails(context, workout),
                      onLongPress: () => _showDeleteConfirmation(context, workout),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showWorkoutDetails(BuildContext context, Map<String, dynamic> workout) {
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

  void _showDeleteConfirmation(BuildContext context, Map<String, dynamic> workout) {
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
                            await onDeleteWorkout(workout['id']);
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

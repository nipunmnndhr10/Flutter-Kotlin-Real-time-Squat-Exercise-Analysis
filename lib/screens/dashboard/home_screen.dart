import 'package:flutter/material.dart';

const kPrimary = Color(0xFF4CAF50);
const kSecondary = Color(0xFF81C784);
const kBackground = Color(0xFFF9F9F9);
const kSurface = Color(0xFFE8F5E9);
const kTextPrimary = Color(0xFF1A1A1A);
const kTextMuted = Color(0xFF757575);

class HomeScreen extends StatelessWidget {
  final String userName;
  final String greeting;
  final int totalSquats;
  final int topForm;
  final List<int> weeklySquats;
  final VoidCallback onLogout;
  final VoidCallback onOpenCamera;

  final String dateRangeText;
  final bool hasPreviousWeek;
  final bool hasNextWeek;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;

  const HomeScreen({
    super.key,
    required this.userName,
    required this.greeting,
    required this.totalSquats,
    required this.topForm,
    required this.weeklySquats,
    required this.onLogout,
    required this.onOpenCamera,
    required this.dateRangeText,
    required this.hasPreviousWeek,
    required this.hasNextWeek,
    required this.onPreviousWeek,
    required this.onNextWeek,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            userName: userName,
            greeting: greeting,
            onLogout: onLogout,
          ),
          const SizedBox(height: 24),
          _CameraButton(onTap: onOpenCamera),
          const SizedBox(height: 20),
          _StatRow(totalSquats: totalSquats, topForm: topForm),
          const SizedBox(height: 24),
          _WeeklyChart(
            data: weeklySquats,
            dateRangeText: dateRangeText,
            hasPreviousWeek: hasPreviousWeek,
            hasNextWeek: hasNextWeek,
            onPreviousWeek: onPreviousWeek,
            onNextWeek: onNextWeek,
          ),
          const SizedBox(height: 16),
        ],
      ),
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

class _CameraButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CameraButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: kPrimary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_outline, color: Colors.white, size: 24),
            SizedBox(width: 10),
            Text(
              'Camera Setup',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final int totalSquats;
  final int topForm;
  const _StatRow({required this.totalSquats, required this.topForm});

  String _fmt(int n) {
    if (n >= 1000) {
      final s = n.toString();
      return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(label: 'Total Squats', value: _fmt(totalSquats)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _StatCard(
            label: 'Top Form',
            value: '$topForm%',
            valueColor: kPrimary,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _StatCard({
    required this.label,
    required this.value,
    this.valueColor = kTextPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: kTextMuted)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final List<int> data;
  final String dateRangeText;
  final bool hasPreviousWeek;
  final bool hasNextWeek;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;

  const _WeeklyChart({
    required this.data,
    required this.dateRangeText,
    required this.hasPreviousWeek,
    required this.hasNextWeek,
    required this.onPreviousWeek,
    required this.onNextWeek,
  });
  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    final maxVal = data.isEmpty ? 0.0 : data.reduce((a, b) => a > b ? a : b).toDouble();
    final today = DateTime.now().weekday % 7;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: hasPreviousWeek ? onPreviousWeek : null,
                color: hasPreviousWeek ? kTextPrimary : Colors.black12,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Text(
                dateRangeText,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: hasNextWeek ? onNextWeek : null,
                color: hasNextWeek ? kTextPrimary : Colors.black12,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final fraction = maxVal > 0 ? data[i] / maxVal : 0.0;
                final isToday = i == today;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          data[i] > 0 ? '${data[i]}' : '',
                          style: const TextStyle(
                            fontSize: 10,
                            color: kTextMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          height: 80 * fraction,
                          decoration: BoxDecoration(
                            color: isToday ? kPrimary : kSecondary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _days[i],
                          style: TextStyle(
                            fontSize: 10,
                            color: isToday ? kPrimary : kTextMuted,
                            fontWeight: isToday
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}


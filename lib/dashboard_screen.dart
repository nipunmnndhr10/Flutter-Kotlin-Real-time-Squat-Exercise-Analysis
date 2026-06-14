import 'package:flutter/material.dart';
import 'workout_screen.dart';

const kPrimary     = Color(0xFF4CAF50);
const kSecondary   = Color(0xFF81C784);
const kBackground  = Color(0xFFF9F9F9);
const kSurface     = Color(0xFFE8F5E9);
const kTextPrimary = Color(0xFF1A1A1A);
const kTextMuted   = Color(0xFF757575);

class DashboardScreen extends StatefulWidget {
  final String userName;
  const DashboardScreen({super.key, required this.userName});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final int totalSquats = 1250;
  final int topForm = 98;
  final List<int> weeklySquats = [4, 8, 6, 12, 10, 7, 9];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(userName: widget.userName),
              const SizedBox(height: 24),
              _CameraButton(onTap: _openCamera),
              const SizedBox(height: 20),
              _StatRow(totalSquats: totalSquats, topForm: topForm),
              const SizedBox(height: 24),
              _WeeklyChart(data: weeklySquats),
              const SizedBox(height: 24),
              _RecommendedWorkoutSection(onPlay: _startWorkout),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) {
  if (i == 1) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const WorkoutScreen(),
      ),
    );
    return;
  }

  setState(() => _currentIndex = i);
},
      ),
    );
  }

  void _openCamera() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening camera…'), backgroundColor: kPrimary, duration: Duration(seconds: 1)),
    );
  }

  void _startWorkout() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting workout…'), backgroundColor: kSecondary, duration: Duration(seconds: 1)),
    );
  }
}

class _Header extends StatelessWidget {
  final String userName;
  const _Header({required this.userName});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: const BoxDecoration(color: kSurface, shape: BoxShape.circle),
          child: const Icon(Icons.person_outline, color: kPrimary, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Welcome back,', style: TextStyle(fontSize: 12, color: kTextMuted)),
              Text(userName, style: const TextStyle(fontSize: 16, color: kTextPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.notifications_outlined, color: kTextPrimary, size: 20),
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
        width: double.infinity, height: 56,
        decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(16)),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_outline, color: Colors.white, size: 24),
            SizedBox(width: 10),
            Text('Camera Setup', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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
        Expanded(child: _StatCard(label: 'Total Squats', value: _fmt(totalSquats))),
        const SizedBox(width: 14),
        Expanded(child: _StatCard(label: 'Top Form', value: '$topForm%', valueColor: kPrimary)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _StatCard({required this.label, required this.value, this.valueColor = kTextPrimary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: kTextMuted)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: valueColor)),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final List<int> data;
  const _WeeklyChart({required this.data});
  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    final maxVal = data.reduce((a, b) => a > b ? a : b).toDouble();
    final today = DateTime.now().weekday % 7;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Squats in last 7 Days',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTextPrimary)),
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
                        Text(data[i] > 0 ? '${data[i]}' : '', style: const TextStyle(fontSize: 10, color: kTextMuted)),
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
                        Text(_days[i], style: TextStyle(
                          fontSize: 10,
                          color: isToday ? kPrimary : kTextMuted,
                          fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                        )),
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

class _RecommendedWorkoutSection extends StatelessWidget {
  final VoidCallback onPlay;
  const _RecommendedWorkoutSection({required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recommended Workout',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kTextPrimary)),
        const SizedBox(height: 12),
        _WorkoutCard(title: 'Killer Leg Workout (Squats)', subtitle: '45 Min  •  Advanced', onPlay: onPlay),
      ],
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onPlay;
  const _WorkoutCard({required this.title, required this.subtitle, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: kTextMuted)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onPlay,
            child: Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(color: Color(0x1F4CAF50), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: kPrimary, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: kPrimary,
        unselectedItemColor: kTextMuted,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center_outlined), activeIcon: Icon(Icons.fitness_center), label: 'Workouts'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart_outlined), activeIcon: Icon(Icons.show_chart), label: 'Progress'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
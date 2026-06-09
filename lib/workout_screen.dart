import 'package:flutter/material.dart';
import'dashboard_screen.dart';
import 'pose_screen.dart';

const kPrimary     = Color(0xFF4CAF50);
const kSecondary   = Color(0xFF81C784);
const kBackground  = Color(0xFFF9F9F9);
const kSurface     = Color(0xFFE8F5E9);
const kTextPrimary = Color(0xFF1A1A1A);
const kTextMuted   = Color(0xFF757575);

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  int _currentIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
  backgroundColor: kBackground,
  elevation: 0,
  leading: IconButton(
    icon: const Icon(Icons.arrow_back, color: kTextPrimary),
    onPressed: () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const DashboardScreen(
            userName: 'Prayan Shrestha',
          ),
        ),
      );
    },
  ),
  title: const Text(
    "Workouts",
    style: TextStyle(
      color: kTextPrimary,
      fontWeight: FontWeight.bold,
    ),
  ),
),
      body: Padding(
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
        style: TextStyle(
          fontSize: 14,
          color: kTextMuted,
        ),
      ),

      const SizedBox(height: 30),

      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [

            const Icon(
              Icons.fitness_center,
              size: 70,
              color: kPrimary,
            ),

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
              style: TextStyle(
                color: kTextMuted,
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PoseScreen(),
                    ),
                  );
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
),
bottomNavigationBar: BottomNavigationBar(
  currentIndex: _currentIndex,
  selectedItemColor: kPrimary,
  unselectedItemColor: kTextMuted,
  type: BottomNavigationBarType.fixed,

  onTap: (index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const DashboardScreen(
            userName: 'Prayan Shrestha',
          ),
        ),
      );
    }

    if (index == 1) {
      return;
    }

    if (index == 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Progress screen coming soon'),
        ),
      );
    }

    if (index == 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile screen coming soon'),
        ),
      );
    }

    setState(() {
      _currentIndex = index;
    });
  },

  items: const [
    BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Home',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.fitness_center_outlined),
      activeIcon: Icon(Icons.fitness_center),
      label: 'Workouts',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.show_chart_outlined),
      activeIcon: Icon(Icons.show_chart),
      label: 'Progress',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ],
),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final String title;
  final String duration;
  final String level;
  final VoidCallback onStart;

  const _WorkoutCard({
    required this.title,
    required this.duration,
    required this.level,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            "$duration • $level",
            style: const TextStyle(
              color: kTextMuted,
            ),
          ),

          const SizedBox(height: 15),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text("Start Workout"),
            ),
          ),
        ],
      ),
    );
  }
}


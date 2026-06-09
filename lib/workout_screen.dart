import 'package:flutter/material.dart';

const kPrimary     = Color(0xFF4CAF50);
const kSecondary   = Color(0xFF81C784);
const kBackground  = Color(0xFFF9F9F9);
const kSurface     = Color(0xFFE8F5E9);
const kTextPrimary = Color(0xFF1A1A1A);
const kTextMuted   = Color(0xFF757575);

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kBackground,
        elevation: 0,
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
              "Recommended For You",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: kTextPrimary,
              ),
            ),

            const SizedBox(height: 20),

            _WorkoutCard(
              title: "Squat Master",
              duration: "15 Minutes",
              level: "Beginner",
              onStart: () {
                // Navigate to PoseScreen later
              },
            ),

            const SizedBox(height: 16),

            _WorkoutCard(
              title: "Leg Strength Builder",
              duration: "30 Minutes",
              level: "Intermediate",
              onStart: () {},
            ),

            const SizedBox(height: 16),

            _WorkoutCard(
              title: "Advanced Squat Challenge",
              duration: "45 Minutes",
              level: "Advanced",
              onStart: () {},
            ),
          ],
        ),
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
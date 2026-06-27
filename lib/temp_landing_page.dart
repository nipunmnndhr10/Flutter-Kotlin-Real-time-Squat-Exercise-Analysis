import 'package:flutter/material.dart';

import 'pose_screen.dart';

class TemporaryLandingPage extends StatelessWidget {
  const TemporaryLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Workout Landing',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF102A43),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Temporary page for starting and ending the squat workout session.',
                style: TextStyle(fontSize: 15, color: Color(0xFF52606D)),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const PoseScreen()));
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Workout Session'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: const Color(0xFF2ECC71),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

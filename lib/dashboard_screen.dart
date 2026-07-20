import 'package:flutter/material.dart';
import 'workout_screen.dart';

<<<<<<< HEAD
// ── Color Palette (matching reference design) ──
const kPrimary = Color(0xFF2E7D32); // Dark green
const kPrimaryLight = Color(0xFF4CAF50); // Light green
const kPrimaryBackground = Color(0xFFE8F5E9); // Very light green
const kCardGreen = Color(0xFFC8E6C9); // Green card background
const kDarkGreen = Color(0xFF1B5E20); // Darkest green
const kTextPrimary = Color(0xFF1A1A1A);
const kTextSecondary = Color(0xFF757575);
const kTextLight = Color(0xFFFFFFFF);
const kAccentOrange = Color(0xFFFF8F00);
const kAccentRed = Color(0xFFE53935);
const kAccentBlue = Color(0xFF1E88E5);
const kCardWhite = Color(0xFFFFFFFF);
const kBackground = Color(0xFFF5F5F5);
const kDivider = Color(0xFFE0E0E0);
=======
const kPrimary = Color(0xFF4CAF50);
const kSecondary = Color(0xFF81C784);
const kBackground = Color(0xFFF9F9F9);
const kSurface = Color(0xFFE8F5E9);
const kTextPrimary = Color(0xFF1A1A1A);
const kTextMuted = Color(0xFF757575);
>>>>>>> main

class DashboardScreen extends StatefulWidget {
  final String userName;
  const DashboardScreen({super.key, required this.userName});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
<<<<<<< HEAD
  int _selectedFeeling = 2;

  // Mock data for display
  final int sessionsDone = 2;
  final int sessionsTarget = 3;
  final int lastReps = 24;
  final int lastMinutes = 18;
  final int lastFaults = 2;
  final int recoveryPercentage = 58;
  final int kneeAngle = 94;
  final int hipAngle = 61;
=======
  final int totalSquats = 1250;
  final int topForm = 98;
  final List<int> weeklySquats = [4, 8, 6, 12, 10, 7, 9];
>>>>>>> main

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
<<<<<<< HEAD
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildReadyToTrainCard(),
              const SizedBox(height: 16),
              _buildThisWeekCard(),
              const SizedBox(height: 16),
              _buildHowAreYouFeeling(),
              const SizedBox(height: 16),
              _buildLastSessionSnapshot(),
              const SizedBox(height: 16),
              _buildRecoveryWindow(),
              const SizedBox(height: 16),
              _buildMovementAngles(),
              const SizedBox(height: 16),
              _buildFormCheck(),
              const SizedBox(height: 16),
              _buildYourJourney(),
              const SizedBox(height: 16),
              _buildLevelUp(),
=======
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
>>>>>>> main
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
<<<<<<< HEAD
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ============ HEADER ============
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kPrimary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.fitness_center, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 10),
        const Text(
          'SquatMate',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: kTextPrimary,
          ),
        ),
        const Spacer(),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kPrimaryBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.notifications_outlined, color: kTextPrimary, size: 22),
        ),
        const SizedBox(width: 8),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kPrimary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============ READY TO TRAIN CARD ============
  Widget _buildReadyToTrainCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFA5D6A7), Color(0xFF81C784)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'READY TO TRAIN!',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kDarkGreen,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "You're fresh — let's go! 💪",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Last session was 3 days ago',
            style: TextStyle(
              fontSize: 13,
              color: kTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Starting workout session...'),
                  backgroundColor: kPrimary,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: kDarkGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Start Session',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ THIS WEEK CARD ============
  Widget _buildThisWeekCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDivider),
      ),
      child: Row(
        children: [
          const Text(
            'THIS WEEK',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kTextSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Row(
            children: List.generate(sessionsTarget, (i) {
              final isDone = i < sessionsDone;
              return Container(
                margin: const EdgeInsets.only(left: 6),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDone ? kPrimary : kPrimaryBackground,
                  shape: BoxShape.circle,
                  border: isDone ? null : Border.all(color: kDivider),
                ),
                child: Icon(
                  isDone ? Icons.check : Icons.fitness_center,
                  size: 16,
                  color: isDone ? Colors.white : kTextSecondary,
                ),
              );
            }),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sessionsDone of $sessionsTarget sessions',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
              const Text(
                'On track ✅',
                style: TextStyle(
                  fontSize: 11,
                  color: kTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============ HOW ARE YOU FEELING ============
  Widget _buildHowAreYouFeeling() {
    final emojis = ['💪', '😊', '😐', '😩'];
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HOW ARE YOU FEELING?',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kTextSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(emojis.length, (index) {
              final isSelected = index == _selectedFeeling;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFeeling = index;
                  });
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isSelected ? kPrimary : kPrimaryBackground,
                    shape: BoxShape.circle,
                    border: isSelected ? null : Border.all(color: kDivider),
                  ),
                  child: Center(
                    child: Text(
                      emojis[index],
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ============ LAST SESSION SNAPSHOT ============
  Widget _buildLastSessionSnapshot() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LAST SESSION SNAPSHOT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kTextSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCircle(Icons.check, kPrimary, '$lastReps', 'REPS'),
              const SizedBox(width: 12),
              _buildStatCircle(Icons.timer_outlined, kAccentBlue, '$lastMinutes', 'MIN'),
              const SizedBox(width: 12),
              _buildStatCircle(Icons.warning_amber_rounded, kAccentOrange, '$lastFaults', 'FAULTS'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCircle(IconData icon, Color color, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: kPrimaryBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: kTextSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

// ============ RECOVERY WINDOW ============
Widget _buildRecoveryWindow() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kCardWhite,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: kDivider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RECOVERY WINDOW',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: kTextSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side - Progress
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Session ended • Ready to train',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: recoveryPercentage / 100,
                      minHeight: 8,
                      backgroundColor: kPrimaryBackground,
                      color: kPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$recoveryPercentage%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '14 hours to go',
                    style: TextStyle(
                      fontSize: 12,
                      color: kTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right side - Buttons
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  _buildSmallButton('WHY 72HR', Icons.info_outline),
                  const SizedBox(height: 6),
                  _buildSmallButton('RECOVERY', Icons.fitness_center), // Shortened
                  const SizedBox(height: 6),
                  _buildSmallButton('HISTORY', Icons.history), // Shortened
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildSmallButton(String text, IconData icon) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    decoration: BoxDecoration(
      color: kPrimaryBackground,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 12, color: kPrimary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: kPrimary,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    ),
  );
}

  // ============ YOUR MOVEMENT TODAY ============
  Widget _buildMovementAngles() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR MOVEMENT TODAY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kTextSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildAngleCard('Knee Angle', '$kneeAngle°', kPrimary),
              const SizedBox(width: 12),
              _buildAngleCard('Hip Angle', '$hipAngle°', kAccentBlue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAngleCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kPrimaryBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ FORM CHECK ============
  Widget _buildFormCheck() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FORM CHECK',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kTextSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildFormCheckItem(
            Icons.check_circle,
            kPrimary,
            'Knee Alignment',
            'No faults detected',
          ),
          const Divider(height: 24),
          _buildFormCheckItem(
            Icons.warning_amber_rounded,
            kAccentOrange,
            'Depth',
            '3 reps were shallow',
          ),
          const Divider(height: 24),
          _buildFormCheckItem(
            Icons.check_circle,
            kPrimary,
            'Posture',
            'Great chest position',
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kPrimaryBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '"Consistency beats perfection every time."',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: kTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCheckItem(IconData icon, Color color, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
=======
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) {
          if (i == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WorkoutScreen()),
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
      const SnackBar(
        content: Text('Opening camera…'),
        backgroundColor: kPrimary,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _startWorkout() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting workout…'),
        backgroundColor: kSecondary,
        duration: Duration(seconds: 1),
      ),
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
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: kSurface,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person_outline, color: kPrimary, size: 24),
        ),
>>>>>>> main
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
<<<<<<< HEAD
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: kTextSecondary,
=======
              const Text(
                'Welcome back,',
                style: TextStyle(fontSize: 12, color: kTextMuted),
              ),
              Text(
                userName,
                style: const TextStyle(
                  fontSize: 16,
                  color: kTextPrimary,
                  fontWeight: FontWeight.w600,
>>>>>>> main
                ),
              ),
            ],
          ),
        ),
<<<<<<< HEAD
      ],
    );
  }

  // ============ YOUR JOURNEY ============
  Widget _buildYourJourney() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDivider),
=======
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
>>>>>>> main
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
<<<<<<< HEAD
          const Text(
            'YOUR JOURNEY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kTextSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildJourneyItem(
                  'Mon, Oct 24',
                  'RECOVERED',
                  Icons.check_circle,
                  kPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildJourneyItem(
                  'Sun, Oct',
                  '$lastReps reps • $lastMinutes min',
                  Icons.fitness_center,
                  kAccentBlue,
                ),
              ),
            ],
          ),
=======
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
>>>>>>> main
        ],
      ),
    );
  }
<<<<<<< HEAD

  Widget _buildJourneyItem(String date, String status, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kPrimaryBackground,
        borderRadius: BorderRadius.circular(12),
=======
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
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
>>>>>>> main
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
<<<<<<< HEAD
          Text(
            date,
            style: const TextStyle(
              fontSize: 12,
=======
          const Text(
            'Squats in last 7 Days',
            style: TextStyle(
              fontSize: 15,
>>>>>>> main
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
<<<<<<< HEAD
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============ LEVEL UP ============
  Widget _buildLevelUp() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LEVEL UP',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kTextSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildLevelUpCard(
                  'Beginner\nSquat101',
                  Icons.play_circle_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLevelUpCard(
                  'Sumo\nWide Stance',
                  Icons.play_circle_outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelUpCard(String title, IconData icon) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kDarkGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              Icon(Icons.circle, size: 6, color: Colors.white54),
              SizedBox(width: 4),
              Icon(Icons.circle, size: 6, color: Colors.white54),
              SizedBox(width: 4),
              Icon(Icons.circle, size: 6, color: Colors.white54),
            ],
          ),
        ],
      ),
    );
  }

  // ============ BOTTOM NAVIGATION ============
  Widget _buildBottomNav() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home, 'Home', 0),
                  _buildNavItem(Icons.history, 'History', 1),
                  const SizedBox(width: 50),
                  _buildNavItem(Icons.show_chart, 'Progress', 2),
                  _buildNavItem(Icons.person, 'Profile', 3),
                ],
              ),
            ),
          ),
          Positioned(
            top: -20,
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Opening camera...'),
                    backgroundColor: kPrimary,
                  ),
                );
              },
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: kPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? kPrimary : kTextSecondary;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
        
        if (index == 1) {
          // History -> Workout
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const WorkoutScreen(),
            ),
          );
        } else if (index == 2) {
          // Progress -> Progress Screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ProgressScreen(),
            ),
          );
        } else if (index == 3) {
          // Profile -> Profile Screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ProfileScreen(),
            ),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
=======
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
>>>>>>> main
            ),
          ),
        ],
      ),
    );
  }
}

<<<<<<< HEAD
// ============ PROGRESS SCREEN ============
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text(
          'Progress',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: kPrimaryBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.show_chart,
                size: 40,
                color: kPrimary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Progress',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Total Workouts: 12',
              style: TextStyle(
                fontSize: 16,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Total Squats: 1,250',
              style: TextStyle(
                fontSize: 16,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Best Form Score: 98%',
              style: TextStyle(
                fontSize: 16,
                color: kTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ PROFILE SCREEN ============
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: kPrimary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kPrimary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.person,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'User',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'user@example.com',
              style: TextStyle(
                fontSize: 16,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 40),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Back to Dashboard',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
=======
class _RecommendedWorkoutSection extends StatelessWidget {
  final VoidCallback onPlay;
  const _RecommendedWorkoutSection({required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommended Workout',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: kTextPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _WorkoutCard(
          title: 'Killer Leg Workout (Squats)',
          subtitle: '45 Min  •  Advanced',
          onPlay: onPlay,
        ),
      ],
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onPlay;
  const _WorkoutCard({
    required this.title,
    required this.subtitle,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: kTextMuted),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onPlay,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0x1F4CAF50),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: kPrimary,
                size: 22,
              ),
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
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
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
>>>>>>> main

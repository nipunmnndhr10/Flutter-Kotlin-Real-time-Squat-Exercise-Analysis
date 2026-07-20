import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'workout_screen.dart';
import 'profile_screen.dart';
import 'progress_screen.dart';
import 'app_config.dart';

// ── Color Palette (matching reference design) ──
const kPrimary = Color(0xFF2E7D32);
const kPrimaryLight = Color(0xFF4CAF50);
const kPrimaryBackground = Color(0xFFE8F5E9);
const kCardGreen = Color(0xFFC8E6C9);
const kDarkGreen = Color(0xFF1B5E20);
const kTextPrimary = Color(0xFF1A1A1A);
const kTextSecondary = Color(0xFF757575);
const kAccentOrange = Color(0xFFFF8F00);
const kAccentRed = Color(0xFFE53935);
const kAccentBlue = Color(0xFF1E88E5);
const kCardWhite = Color(0xFFFFFFFF);
const kBackground = Color(0xFFF5F5F5);
const kDivider = Color(0xFFE0E0E0);

class DashboardScreen extends StatefulWidget {
  final String userName;
  const DashboardScreen({super.key, required this.userName});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  int _selectedFeeling = 2;

  // Real data from backend
  int _totalSquats = 0;
  int _topForm = 0;
  List<int> _weeklySquats = [0, 0, 0, 0, 0, 0, 0];
  int _totalWorkouts = 0;
  int _lastReps = 0;
  int _lastMinutes = 0;
  int _lastFaults = 0;
  double _avgKneeAngle = 0;
  double _avgHipAngle = 0;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        setState(() {
          _errorMessage = 'Please login again';
          _isLoading = false;
        });
        return;
      }

      final response = await Dio().get(
        '${AppConfig.apiBaseUrl}/workouts/',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> workouts = response.data;
        _processWorkoutData(workouts);
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load data';
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      setState(() {
        _errorMessage = 'Connection error: ${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _processWorkoutData(List<dynamic> workouts) {
    if (workouts.isEmpty) {
      _totalSquats = 0;
      _topForm = 0;
      _weeklySquats = [0, 0, 0, 0, 0, 0, 0];
      _totalWorkouts = 0;
      _lastReps = 0;
      _lastMinutes = 0;
      _lastFaults = 0;
      _avgKneeAngle = 0;
      _avgHipAngle = 0;
      return;
    }

    _totalWorkouts = workouts.length;
    _totalSquats = workouts.fold(0, (sum, w) => sum + (w['total_reps'] as int? ?? 0));

    _topForm = workouts.fold(0, (best, w) {
      final angle = (w['avg_knee_angle'] as num?)?.toInt() ?? 0;
      return angle > best ? angle : best;
    });

    final last = workouts.first;
    _lastReps = last['total_reps'] as int? ?? 0;
    _lastMinutes = (last['duration_seconds'] as int? ?? 0) ~/ 60;
    
    final faultSummary = last['fault_summary_json'] as Map?;
    if (faultSummary != null) {
      _lastFaults = faultSummary.values.fold<int>(
        0, 
        (sum, v) => sum + ((v as num?)?.toInt() ?? 0)
      );
    } else {
      _lastFaults = 0;
    }
    
    _avgKneeAngle = (last['avg_knee_angle'] as num?)?.toDouble() ?? 0;
    _avgHipAngle = (last['avg_hip_angle'] as num?)?.toDouble() ?? 0;

    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day - 6);

    for (int i = 0; i < 7; i++) {
      final day = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
      _weeklySquats[i] = workouts
          .where((w) {
            final date = DateTime.parse(w['started_at'] as String);
            return date.year == day.year &&
                date.month == day.month &&
                date.day == day.day;
          })
          .fold(0, (sum, w) => sum + (w['total_reps'] as int? ?? 0));
    }
  }

  Future<void> _refreshData() async {
    await _fetchDashboardData();
  }

  void _startWorkout() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WorkoutScreen()),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SafeArea(
          bottom: false,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: kTextSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _refreshData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
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
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
        ),
      ),
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
            onTap: _startWorkout,
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
    final sessionsDone = 2;
    final sessionsTarget = 3;
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
              _buildStatCircle(Icons.check, kPrimary, '$_lastReps', 'REPS'),
              const SizedBox(width: 12),
              _buildStatCircle(Icons.timer_outlined, kAccentBlue, '$_lastMinutes', 'MIN'),
              const SizedBox(width: 12),
              _buildStatCircle(Icons.warning_amber_rounded, kAccentOrange, '$_lastFaults', 'FAULTS'),
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
                        value: 0.58,
                        minHeight: 8,
                        backgroundColor: kPrimaryBackground,
                        color: kPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '58%',
                      style: TextStyle(
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
              Expanded(
                child: Column(
                  children: [
                    _buildSmallButton('WHY 72HR', Icons.info_outline),
                    const SizedBox(height: 6),
                    _buildSmallButton('RECOVERY', Icons.fitness_center),
                    const SizedBox(height: 6),
                    _buildSmallButton('HISTORY', Icons.history),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
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
              _buildAngleCard('Knee Angle', '${_avgKneeAngle.toStringAsFixed(0)}°', kPrimary),
              const SizedBox(width: 12),
              _buildAngleCard('Hip Angle', '${_avgHipAngle.toStringAsFixed(0)}°', kAccentBlue),
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
        const SizedBox(width: 12),
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
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: kTextSecondary,
                ),
              ),
            ],
          ),
        ),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  '$_lastReps reps • $_lastMinutes min',
                  Icons.fitness_center,
                  kAccentBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyItem(String date, String status, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kPrimaryBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            date,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
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
              onTap: _openCamera,
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const WorkoutScreen(),
            ),
          );
        } else if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ProgressScreen(),
            ),
          );
        } else if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileScreen(userName: widget.userName),
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
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// Static, visual-only dashboard screen.
/// All data shown here is hardcoded sample content for UI purposes —
/// there is no backend, persistence, or navigation wired up.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Local, UI-only state (no backend / persistence involved).
  int _selectedMood = 1;
  int _selectedNavIndex = 0;

  static const _green = Color(0xFF1DB954);
  static const _darkGreen = Color(0xFF0E5C36);
  static const _darkText = Color(0xFF1A1A1A);
  static const _mutedText = Color(0xFF888888);
  static const _lightGray = Color(0xFFF5F5F5);

  static const _sectionHeaderStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1,
    color: Color(0xFF444444),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightGray,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _buildReadyBanner(),
                    const SizedBox(height: 16),
                    _buildThisWeek(),
                    const SizedBox(height: 16),
                    _buildMoodCheck(),
                    const SizedBox(height: 16),
                    _buildLastSessionSnapshot(),
                    const SizedBox(height: 16),
                    _buildRecoveryWindow(),
                    const SizedBox(height: 16),
                    _buildMovementToday(),
                    const SizedBox(height: 16),
                    _buildRepDepthChart(),
                    const SizedBox(height: 16),
                    _buildFormCheck(),
                    const SizedBox(height: 16),
                    _buildYourJourney(),
                    const SizedBox(height: 16),
                    _buildLevelUp(),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: _green,
        elevation: 4,
        child: const Icon(Icons.camera_alt, color: Colors.white, size: 26),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _SquatMateBottomNav(
        selectedIndex: _selectedNavIndex,
        onTap: (i) => setState(() => _selectedNavIndex = i),
      ),
    );
  }

  // ─── TOP BAR ──────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.open_in_full, color: _green, size: 18),
          const SizedBox(width: 6),
          const Text(
            'SquatMate',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: _darkText,
            ),
          ),
          const Spacer(),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: const Icon(Icons.notifications_outlined,
                    size: 17, color: _darkText),
              ),
              Positioned(
                top: 5,
                right: 6,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 32,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _green, width: 1.5),
            ),
            child: const CircleAvatar(backgroundColor: Color(0xFF1A1A2E)),
          ),
        ],
      ),
    );
  }

  // ─── READY BANNER ─────────────────────────────────────────
  Widget _buildReadyBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F8EF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'READY TO TRAIN!',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _green,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  "You're fresh — let's go! 💪",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _darkText,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Last session was 3 days ago',
                  style: TextStyle(fontSize: 12, color: _mutedText),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Start Session'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildBodyFigure(),
        ],
      ),
    );
  }

  Widget _buildBodyFigure() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 90,
          height: 110,
          decoration: BoxDecoration(
            color: const Color(0xFFD4F0E0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.accessibility_new,
            size: 64,
            color: _green,
          ),
        ),
        Positioned(
          bottom: 8,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Legs are\nready!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── THIS WEEK ────────────────────────────────────────────
  Widget _buildThisWeek() {
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('THIS WEEK', style: _sectionHeaderStyle),
          const SizedBox(width: 12),
          _weekDot(done: true),
          const SizedBox(width: 6),
          _weekDot(done: true),
          const SizedBox(width: 6),
          _weekDot(done: false),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 12, color: Color(0xFF444444)),
                  children: [
                    TextSpan(
                        text: '2 of 3',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: ' sessions'),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'On track ✅',
                style: TextStyle(
                    fontSize: 11, color: _green, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weekDot({required bool done}) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: done ? _green : const Color(0xFFE0E0E0),
        shape: BoxShape.circle,
      ),
      child: Icon(
        done ? Icons.check : Icons.circle_outlined,
        color: done ? Colors.white : const Color(0xFFBBBBBB),
        size: 16,
      ),
    );
  }

  // ─── MOOD CHECK ───────────────────────────────────────────
  Widget _buildMoodCheck() {
    const moods = ['💪', '😐', '🥴', '😎'];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('HOW ARE YOU FEELING?', style: _sectionHeaderStyle),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(moods.length, (i) {
              final selected = _selectedMood == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedMood = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? _darkGreen : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(moods[i], style: const TextStyle(fontSize: 24)),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── LAST SESSION SNAPSHOT ────────────────────────────────
  Widget _buildLastSessionSnapshot() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text('LAST SESSION SNAPSHOT', style: _sectionHeaderStyle),
            SizedBox(width: 4),
            Text('🎯', style: TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _statCard(
              icon: Icons.replay,
              iconColor: _green,
              value: '24',
              label: 'REPS',
            ),
            const SizedBox(width: 10),
            _statCard(
              icon: Icons.timer_outlined,
              iconColor: const Color(0xFF2196F3),
              value: '18',
              label: 'MIN',
            ),
            const SizedBox(width: 10),
            _statCard(
              icon: Icons.warning_amber_rounded,
              iconColor: const Color(0xFFFF9800),
              value: '2',
              label: 'FAULTS',
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _darkText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: _mutedText,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── RECOVERY WINDOW ──────────────────────────────────────
  Widget _buildRecoveryWindow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text('RECOVERY WINDOW', style: _sectionHeaderStyle),
            SizedBox(width: 4),
            Text('⏱️', style: TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Session ended',
                      style: TextStyle(fontSize: 12, color: _mutedText)),
                  Row(
                    children: [
                      Icon(Icons.flag, size: 13, color: _green),
                      SizedBox(width: 4),
                      Text(
                        'Ready to train',
                        style: TextStyle(
                          fontSize: 12,
                          color: _green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 24,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Align(
                      alignment: const Alignment(0.65, -1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _darkGreen,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '58h',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          height: 8,
                          width: double.infinity,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 85,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF4CD787),
                                        Color(0xFF0E5C36),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 15,
                                child:
                                    Container(color: const Color(0xFFE0E0E0)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '14 hours to go',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: _darkText),
              ),
              const SizedBox(height: 2),
              const Text(
                'Optimal rest protects your gains',
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: _mutedText),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pillTag('WHY 72H?'),
                  _pillTag('MUSCLE RECOVERY'),
                  _pillTag('YOUR HISTORY'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pillTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600, color: _mutedText),
      ),
    );
  }

  // ─── YOUR MOVEMENT TODAY ──────────────────────────────────
  Widget _buildMovementToday() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text('YOUR MOVEMENT TODAY', style: _sectionHeaderStyle),
            SizedBox(width: 4),
            Text('📐', style: TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        _card(
          child: Column(
            children: [
              _angleRow(
                label: 'Knee Angle',
                value: '94°',
                bg: const Color(0xFFE8F8EF),
                accent: _green,
                icon: Icons.change_history,
              ),
              const SizedBox(height: 10),
              _angleRow(
                label: 'Hip Angle',
                value: '61°',
                bg: const Color(0xFFF0F0F0),
                accent: _darkText,
                icon: Icons.straighten,
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                height: 170,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CustomPaint(painter: _SquatFigurePainter()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _angleRow({
    required String label,
    required String value,
    required Color bg,
    required Color accent,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: _mutedText)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _darkText),
                ),
              ],
            ),
          ),
          Icon(icon, size: 20, color: accent),
        ],
      ),
    );
  }

  // ─── REP DEPTH CHART ──────────────────────────────────────
  Widget _buildRepDepthChart() {
    const repDepths = [
      78.0,
      66.0,
      85.0,
      72.0,
      42.0,
      88.0,
      62.0,
      70.0,
      76.0,
      90.0,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Text('REP DEPTH THIS SESSION', style: _sectionHeaderStyle),
                SizedBox(width: 4),
                Text('📊', style: TextStyle(fontSize: 12)),
              ],
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8EF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'BEST DEPTH: 94°',
                style: TextStyle(
                    fontSize: 10,
                    color: _darkGreen,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _card(
          child: Column(
            children: [
              SizedBox(
                height: 120,
                child: BarChart(
                  BarChartData(
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    barGroups: List.generate(repDepths.length, (i) {
                      final isShallow = repDepths[i] < 60;
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: repDepths[i],
                            color: isShallow
                                ? const Color(0xFFE57373)
                                : _green,
                            width: 16,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _legend(_green, 'AVG DEPTH: 58°'),
                  const SizedBox(width: 16),
                  _legend(const Color(0xFFE57373), 'SHALLOW REPS: 1'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: _mutedText)),
      ],
    );
  }

  // ─── FORM CHECK ───────────────────────────────────────────
  Widget _buildFormCheck() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text('FORM CHECK', style: _sectionHeaderStyle),
            SizedBox(width: 4),
            Text('🔍', style: TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        _card(
          child: Column(
            children: [
              _formRow(
                ok: true,
                title: 'Knee alignment',
                subtitle: 'No faults detected',
              ),
              _formRow(
                ok: false,
                title: 'Depth',
                subtitle: '3 reps were shallow',
                badge: 'GO DEEPER',
              ),
              _formRow(
                ok: true,
                title: 'Posture',
                subtitle: 'Great chest position',
                isLast: true,
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '"Consistency beats perfection every time."',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                    color: Color(0xFF555555),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _formRow({
    required bool ok,
    required String title,
    required String subtitle,
    String? badge,
    bool isLast = false,
  }) {
    final bg = ok ? const Color(0xFFEAF7EF) : const Color(0xFFFDEDED);
    final stripe = ok ? _green : const Color(0xFFE57373);
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: stripe, width: 4)),
      ),
      child: Row(
        children: [
          Text(ok ? '✅' : '⚠️', style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(fontSize: 11, color: _mutedText)),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE57373),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Text(
                    badge,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.error_outline,
                      color: Colors.white, size: 11),
                ],
              ),
            )
          else
            const Icon(Icons.check_circle_outline, color: _green, size: 18),
        ],
      ),
    );
  }

  // ─── YOUR JOURNEY ─────────────────────────────────────────
  Widget _buildYourJourney() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text('YOUR JOURNEY', style: _sectionHeaderStyle),
            SizedBox(width: 4),
            Text('🗓️', style: TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _journeyCard(
                date: 'Mon, Oct 24',
                badge: 'RECOVERED',
                reps: 24,
                duration: '18m',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _journeyCard(
                date: 'Sun, Oct 23',
                badge: 'RECOVERED',
                reps: 19,
                duration: '15m',
                faded: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _journeyCard({
    required String date,
    required String badge,
    required int reps,
    required String duration,
    bool faded = false,
  }) {
    final textColor = faded ? const Color(0xFFBBBBBB) : _darkText;
    final mutedColor = faded ? const Color(0xFFCCCCCC) : _mutedText;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: faded ? const Color(0xFFFAFAFA) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: faded
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            date,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: faded ? const Color(0xFFEFEFEF) : _green,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$badge ✅',
              style: TextStyle(
                color: faded ? const Color(0xFFBBBBBB) : Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.replay, size: 12, color: mutedColor),
              const SizedBox(width: 3),
              Text('$reps reps',
                  style: TextStyle(fontSize: 11, color: mutedColor)),
              const SizedBox(width: 8),
              Icon(Icons.timer_outlined, size: 12, color: mutedColor),
              const SizedBox(width: 3),
              Text(duration, style: TextStyle(fontSize: 11, color: mutedColor)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── LEVEL UP ─────────────────────────────────────────────
  Widget _buildLevelUp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text('LEVEL UP', style: _sectionHeaderStyle),
            SizedBox(width: 4),
            Text('⭐', style: TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _levelCard('Beginner\nSquat 101', _green),
            const SizedBox(width: 10),
            _levelCard('Sumo\nWide Stance', _darkText),
          ],
        ),
      ],
    );
  }

  Widget _levelCard(String title, Color color) {
    return Expanded(
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SHARED ───────────────────────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── SQUAT FIGURE DIAGRAM (static illustration) ───────────────────────────

class _SquatFigurePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width * 0.40;
    final headCenter = Offset(cx, size.height * 0.18);
    final headRadius = size.height * 0.095;

    final neck = Offset(cx, headCenter.dy + headRadius + 2);
    final hip = Offset(cx - size.width * 0.04, size.height * 0.55);
    final knee = Offset(hip.dx - size.width * 0.04, size.height * 0.78);
    final foot = Offset(knee.dx + size.width * 0.20, size.height * 0.94);
    final handTip = Offset(size.width * 0.86, size.height * 0.40);

    // Head
    canvas.drawCircle(headCenter, headRadius, bodyPaint);
    // Torso (leaning forward)
    canvas.drawLine(neck, hip, bodyPaint);
    // Extended arm
    canvas.drawLine(neck, handTip, bodyPaint);
    // Thigh
    canvas.drawLine(hip, knee, bodyPaint);
    // Shin
    canvas.drawLine(knee, foot, bodyPaint);

    // Knee angle arc (green)
    final kneeArcPaint = Paint()
      ..color = const Color(0xFF1DB954)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCircle(center: knee, radius: 20),
      0.2,
      2.1,
      false,
      kneeArcPaint,
    );

    // Hip angle indicator (small arrow)
    final hipArrowPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(hip.dx + 2, hip.dy + 4),
      Offset(hip.dx - 10, hip.dy + 20),
      hipArrowPaint,
    );

    // Labels
    final tpKnee = TextPainter(
      text: const TextSpan(
        text: '94°',
        style: TextStyle(
            color: Color(0xFF1DB954),
            fontSize: 13,
            fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpKnee.paint(canvas, Offset(knee.dx + 24, knee.dy - 8));

    final tpHip = TextPainter(
      text: const TextSpan(
        text: '61°',
        style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 11,
            fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpHip.paint(canvas, Offset(hip.dx - 38, hip.dy + 12));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── BOTTOM NAV (static, visual only) ─────────────────────────────────────

class _SquatMateBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _SquatMateBottomNav({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 6,
      color: Colors.white,
      elevation: 10,
      shadowColor: Colors.black12,
      child: SizedBox(
        height: 58,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Home',
              selected: selectedIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.history_outlined,
              activeIcon: Icons.history,
              label: 'History',
              selected: selectedIndex == 1,
              onTap: () => onTap(1),
            ),
            const SizedBox(width: 56),
            _NavItem(
              icon: Icons.show_chart_outlined,
              activeIcon: Icons.show_chart,
              label: 'Progress',
              selected: selectedIndex == 2,
              onTap: () => onTap(2),
            ),
            _NavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profile',
              selected: selectedIndex == 3,
              onTap: () => onTap(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF1DB954);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? activeIcon : icon,
                color: selected ? green : const Color(0xFFAAAAAA), size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? green : const Color(0xFFAAAAAA),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

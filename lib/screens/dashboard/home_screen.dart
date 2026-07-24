import 'package:flt_kotlin_pose/screens/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'dart:math' as math;

const kBackground = Color(0xFFF9F9F9);
const kLime = Color(0xFFC5F014);
const kOlive = Color(0xFF4C5E0E);
const kSurface = Color(0xFFF4F5F0);
const kTextPrimary = Color(0xFF1A1A1A);
const kTextMuted = Color(0xFF757575);
const kCardGradientStart = Color(0xFFF4EBE3);
const kCardGradientEnd = Color(0xFFE8F2D0);

const kSurfaceContainerHigh = Color(0xFFEBE7E7);
const kSurfaceContainerHighest = Color(0xFFE5E2E1);

class HomeScreen extends StatelessWidget {
  final String userName;
  final String greeting;
  final String profilePictureUrl;
  final int totalSquats;
  final int weeklySquatsTotal;
  final int weeklyForm;
  final int allTimeForm;
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
    this.profilePictureUrl = '',
    required this.totalSquats,
    required this.weeklySquatsTotal,
    required this.weeklyForm,
    required this.allTimeForm,
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
            profilePictureUrl: profilePictureUrl,
            onLogout: onLogout,
          ),
          const SizedBox(height: 24),
          _SquatSessionCard(onTap: onOpenCamera),
          const SizedBox(height: 16),
          _StatRow(
            totalSquats: totalSquats,
            weeklySquatsTotal: weeklySquatsTotal,
            weeklyForm: weeklyForm,
            allTimeForm: allTimeForm,
          ),
          const SizedBox(height: 24),
          _WeeklySection(data: weeklySquats),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String userName;
  final String greeting;
  final String profilePictureUrl;
  final VoidCallback onLogout;

  const _Header({
    required this.userName,
    required this.greeting,
    this.profilePictureUrl = '',
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: kSurface,
            shape: BoxShape.circle,
            image: profilePictureUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(profilePictureUrl),
                    fit: BoxFit.cover,
                    onError: (exception, stackTrace) {},
                  )
                : null,
          ),
          child: profilePictureUrl.isEmpty
              ? const Icon(Icons.person_outline, color: kOlive, size: 24)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: kTextMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                userName,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 22,
                  color: kTextPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const _NotificationButton(),
      ],
    );
  }
}

class _NotificationButton extends StatefulWidget {
  const _NotificationButton();

  @override
  State<_NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<_NotificationButton> {
  bool _hasUnread = true;

  final List<Map<String, String>> _notifications = [
    {
      'title': 'Daily Goal Achieved!',
      'body': 'You completed 30 squats today with a 94% form score.',
      'time': '10m ago',
      'icon': 'fitness',
    },
    {
      'title': 'Form Tip: Knee Alignment',
      'body': 'Keep your knees tracking over your toes for optimal depth.',
      'time': '2h ago',
      'icon': 'tip',
    },
    {
      'title': 'Streak Maintained!',
      'body': 'Great job keeping your workout streak active.',
      'time': 'Yesterday',
      'icon': 'streak',
    },
  ];

  void _showNotificationsSheet(BuildContext context) {
    setState(() => _hasUnread = false);

    showModalBottomSheet(
      context: context,
      backgroundColor: kBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: kSurfaceContainerHigh,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Notifications',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: kTextPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                      },
                      child: Text(
                        'Close',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kOlive,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._notifications.map((n) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kSurfaceContainerHighest, width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kOlive.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            n['icon'] == 'fitness'
                                ? Icons.fitness_center_rounded
                                : n['icon'] == 'tip'
                                    ? Icons.lightbulb_outline_rounded
                                    : Icons.local_fire_department_rounded,
                            size: 18,
                            color: kOlive,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      n['title']!,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: kTextPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    n['time']!,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11,
                                      color: kTextMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                n['body']!,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: kTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showNotificationsSheet(context),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Stack(
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              color: kTextPrimary,
              size: 26,
            ),
            if (_hasUnread)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: kOlive,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SquatSessionCard extends StatelessWidget {
  final VoidCallback onTap;
  const _SquatSessionCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kLime,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: SvgPicture.asset(
              'assets/squat-icon.svg',
              width: 200,
              height: 200,
              colorFilter: ColorFilter.mode(
                Colors.black.withAlpha(13),
                BlendMode.srcIn,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start your\nSquat Session',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: kOlive.withAlpha(230),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: kOlive,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.videocam_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Improve your form in real-time',
                          style: GoogleFonts.jetBrainsMono(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatefulWidget {
  final int totalSquats;
  final int weeklySquatsTotal;
  final int weeklyForm;
  final int allTimeForm;

  const _StatRow({
    required this.totalSquats,
    required this.weeklySquatsTotal,
    required this.weeklyForm,
    required this.allTimeForm,
  });

  @override
  State<_StatRow> createState() => _StatRowState();
}

class _StatRowState extends State<_StatRow> {
  bool _totalSquatsIsWeekly = true; // Default to LAST 7 DAYS
  bool _formScoreIsWeekly = true;   // Default to LAST 7 DAYS

  String _fmt(int n) {
    if (n >= 1000) {
      final s = n.toString();
      return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final squatsValue = _totalSquatsIsWeekly ? widget.weeklySquatsTotal : widget.totalSquats;
    final squatsBadge = _totalSquatsIsWeekly ? 'LAST 7 DAYS' : 'ALL TIME';

    final formValue = _formScoreIsWeekly ? widget.weeklyForm : widget.allTimeForm;
    final formBadge = _formScoreIsWeekly ? 'LAST 7 DAYS' : 'ALL TIME';

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total Squats',
            value: _fmt(squatsValue),
            badgeText: squatsBadge,
            onTap: () => setState(() => _totalSquatsIsWeekly = !_totalSquatsIsWeekly),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kCardGradientStart, kCardGradientEnd],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            label: 'Form Score',
            value: '$formValue',
            suffix: ' %',
            badgeText: formBadge,
            onTap: () => setState(() => _formScoreIsWeekly = !_formScoreIsWeekly),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF3F3F3), Color(0xFFDFF0E8)],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;
  final String badgeText;
  final Gradient gradient;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    this.suffix,
    required this.badgeText,
    required this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(179),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                label,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                    ),
                  ),
                  if (suffix != null)
                    Text(
                      suffix!,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: kTextMuted,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklySection extends StatelessWidget {
  final List<int> data;

  const _WeeklySection({required this.data});

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _dayIndices = [1, 2, 3, 4, 5, 6, 0];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F3F2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFEBE7E7),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/squat-icon.svg',
                    width: 31,
                    height: 31,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF1C1B1B),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This Week',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C1B1B),
                    ),
                  ),
                  Text(
                    'Squats',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF444933),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Builder(
            builder: (context) {
              final maxVal = data.isEmpty
                  ? 0.0
                  : data.reduce(math.max).toDouble();
              final safeMax = maxVal == 0 ? 1.0 : maxVal;

              return Column(
                children: List.generate(7, (i) {
                  final dataIndex = _dayIndices[i];
                  final val = data[dataIndex];
                  final fraction = val / safeMax;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text(
                            _dayNames[i],
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF444933),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  Container(
                                    height: 24,
                                    width: constraints.maxWidth - 40,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFEBE7E7,
                                      ).withAlpha(128), // Light grey track
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 600,
                                        ),
                                        curve: Curves.easeOut,
                                        height: 24,
                                        width:
                                            (constraints.maxWidth - 40) *
                                            fraction,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFCCFF00),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      if (val > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8.0,
                                          ),
                                          child: Text(
                                            '$val',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF1C1B1B),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

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

// Fitness Dashboard - Dark Mode Edition tokens
const kDarkBg = Color(0xFF111710);
const kDarkSurface = Color(0xFF1B2319);
const kDarkContainerHigh = Color(0xFF222B1F);
const kDarkTrack = Color(0xFF141C12);
const kDarkTextMuted = Color(0xFF889684);
const kNeonLime = Color(0xFF82D616);

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
  final List<Map<String, dynamic>> backendNotifications;
  final VoidCallback? onMarkNotificationsRead;
  final VoidCallback? onClearNotifications;
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
    this.backendNotifications = const [],
    this.onMarkNotificationsRead,
    this.onClearNotifications,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? kDarkBg : kBackground;

    return Container(
      color: bg,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                userName: userName,
                greeting: greeting,
                profilePictureUrl: profilePictureUrl,
                weeklySquatsTotal: weeklySquatsTotal,
                weeklyForm: weeklyForm,
                totalSquats: totalSquats,
                backendNotifications: backendNotifications,
                onMarkNotificationsRead: onMarkNotificationsRead,
                onClearNotifications: onClearNotifications,
                onLogout: onLogout,
              ),
              const SizedBox(height: 16),
              _SquatSessionCard(onTap: onOpenCamera),
              const SizedBox(height: 16),
              _StatRow(
                totalSquats: totalSquats,
                weeklySquatsTotal: weeklySquatsTotal,
                weeklyForm: weeklyForm,
                allTimeForm: allTimeForm,
                dateRangeText: dateRangeText,
              ),
              const SizedBox(height: 16),
              _WeeklySection(
                data: weeklySquats,
                titleText: dateRangeText,
                hasPreviousWeek: hasPreviousWeek,
                hasNextWeek: hasNextWeek,
                onPreviousWeek: onPreviousWeek,
                onNextWeek: onNextWeek,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String userName;
  final String greeting;
  final String profilePictureUrl;
  final int weeklySquatsTotal;
  final int weeklyForm;
  final int totalSquats;
  final List<Map<String, dynamic>> backendNotifications;
  final VoidCallback? onMarkNotificationsRead;
  final VoidCallback? onClearNotifications;
  final VoidCallback onLogout;

  const _Header({
    required this.userName,
    required this.greeting,
    this.profilePictureUrl = '',
    required this.weeklySquatsTotal,
    required this.weeklyForm,
    required this.totalSquats,
    this.backendNotifications = const [],
    this.onMarkNotificationsRead,
    this.onClearNotifications,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarBg = isDark ? kDarkContainerHigh : kSurface;
    final avatarIconColor = isDark ? kNeonLime : kOlive;
    final greetingColor = isDark ? kDarkTextMuted : kTextMuted;
    final userNameColor = isDark ? Colors.white : kTextPrimary;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: avatarBg,
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
              ? Icon(Icons.person_outline, color: avatarIconColor, size: 24)
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
                  color: greetingColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                userName,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 22,
                  color: userNameColor,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        _NotificationButton(
          weeklySquatsTotal: weeklySquatsTotal,
          weeklyForm: weeklyForm,
          totalSquats: totalSquats,
          backendNotifications: backendNotifications,
          onMarkNotificationsRead: onMarkNotificationsRead,
          onClearNotifications: onClearNotifications,
        ),
      ],
    );
  }
}

class _NotificationButton extends StatefulWidget {
  final int weeklySquatsTotal;
  final int weeklyForm;
  final int totalSquats;
  final List<Map<String, dynamic>> backendNotifications;
  final VoidCallback? onMarkNotificationsRead;
  final VoidCallback? onClearNotifications;

  const _NotificationButton({
    required this.weeklySquatsTotal,
    required this.weeklyForm,
    required this.totalSquats,
    this.backendNotifications = const [],
    this.onMarkNotificationsRead,
    this.onClearNotifications,
  });

  @override
  State<_NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<_NotificationButton> {
  bool _localReadState = false;
  final MenuController _menuController = MenuController();

  bool get _hasUnread {
    if (_localReadState) return false;
    if (widget.backendNotifications.isEmpty) return false;
    return widget.backendNotifications.any(
      (n) => n['is_read'] == false || n['is_read'] == 0,
    );
  }

  List<Map<String, String>> get _displayNotifications {
    return widget.backendNotifications.map((n) {
      final createdStr = n['created_at']?.toString();
      String timeAgo = 'Just now';
      if (createdStr != null) {
        final dt = DateTime.tryParse(createdStr)?.toLocal();
        if (dt != null) {
          final diff = DateTime.now().difference(dt);
          if (diff.inMinutes < 1) {
            timeAgo = 'Just now';
          } else if (diff.inMinutes < 60) {
            timeAgo = '${diff.inMinutes}m ago';
          } else if (diff.inHours < 24) {
            timeAgo = '${diff.inHours}h ago';
          } else {
            timeAgo = '${diff.inDays}d ago';
          }
        }
      }

      return {
        'title': n['title']?.toString() ?? 'Notification',
        'body': n['body']?.toString() ?? '',
        'time': timeAgo,
        'icon': n['notification_type']?.toString() ?? 'workout',
      };
    }).toList();
  }

  @override
  void didUpdateWidget(covariant _NotificationButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.backendNotifications.length !=
        oldWidget.backendNotifications.length) {
      _localReadState = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final menuBg = isDark ? const Color(0xFF1B2319) : kBackground;
    final menuBorder = isDark
        ? const Color(0xFF222B1F)
        : kSurfaceContainerHighest;
    final titleTextColor = isDark ? Colors.white : kTextPrimary;
    final clearBtnBg = isDark
        ? const Color(0xFF222B1F)
        : kSurfaceContainerHighest;
    final clearBtnText = isDark ? const Color(0xFF889684) : kTextPrimary;
    final emptyTextColor = isDark ? const Color(0xFF889684) : kTextMuted;
    final accentLime = isDark ? const Color(0xFF82D616) : kOlive;

    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(-275, 8),
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(menuBg),
        elevation: WidgetStateProperty.all(8),
        shadowColor: WidgetStateProperty.all(Colors.black.withAlpha(60)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: menuBorder, width: 1),
          ),
        ),
        padding: WidgetStateProperty.all(const EdgeInsets.all(16)),
        maximumSize: WidgetStateProperty.all(const Size(320, 420)),
      ),
      builder: (context, controller, child) {
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            setState(() => _localReadState = true);
            widget.onMarkNotificationsRead?.call();
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: Builder(
            builder: (context) {
              final bellBg = isDark ? kDarkContainerHigh : Colors.transparent;
              final iconColor = isDark ? Colors.white : kTextPrimary;
              final dotColor = isDark ? kNeonLime : kOlive;

              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bellBg,
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  children: [
                    Icon(
                      Icons.notifications_outlined,
                      color: iconColor,
                      size: 24,
                    ),
                    if (_hasUnread)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? kDarkBg : Colors.white,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
      menuChildren: [
        SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Notifications',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: titleTextColor,
                        ),
                      ),
                      if (_hasUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accentLime.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'New',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: accentLime,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      widget.onClearNotifications?.call();
                      _menuController.close();
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: clearBtnBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Clear All',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: clearBtnText,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_displayNotifications.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          color: emptyTextColor,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No new notifications',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: emptyTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._displayNotifications.map((n) {
                  final cardBg = isDark ? const Color(0xFF222B1F) : kSurface;
                  final cardBorder = isDark
                      ? const Color(0xFF2B3627)
                      : kSurfaceContainerHighest;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorder, width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accentLime.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            n['icon'] == 'fitness'
                                ? Icons.fitness_center_rounded
                                : n['icon'] == 'tip'
                                ? Icons.lightbulb_outline_rounded
                                : Icons.local_fire_department_rounded,
                            size: 16,
                            color: accentLime,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      n['title']!,
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: titleTextColor,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    n['time']!,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      color: emptyTextColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                n['body']!,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: emptyTextColor,
                                  height: 1.3,
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
      ],
    );
  }
}

class _SquatSessionCard extends StatelessWidget {
  final VoidCallback onTap;
  const _SquatSessionCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? kNeonLime : kLime;
    final titleColor = isDark ? kDarkBg : kOlive;
    final pillBg = isDark ? kDarkBg : kOlive;
    final watermarkColor = isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(15);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: cardBg.withAlpha(45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              children: [
                Positioned(
                  right: -25,
                  bottom: -25,
                  child: SvgPicture.asset(
                    'assets/squat-icon.svg',
                    width: 230,
                    height: 230,
                    colorFilter: ColorFilter.mode(
                      watermarkColor,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 26.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start your\nSquat Session',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: titleColor.withAlpha(240),
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: pillBg,
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
                            const SizedBox(width: 8),
                            Text(
                              'Improve your form in real-time',
                              style: GoogleFonts.jetBrainsMono(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatefulWidget {
  final int totalSquats;
  final int weeklySquatsTotal;
  final int weeklyForm;
  final int allTimeForm;
  final String dateRangeText;

  const _StatRow({
    required this.totalSquats,
    required this.weeklySquatsTotal,
    required this.weeklyForm,
    required this.allTimeForm,
    this.dateRangeText = 'Last 7 Days',
  });

  @override
  State<_StatRow> createState() => _StatRowState();
}

class _StatRowState extends State<_StatRow> {
  bool _totalSquatsIsWeekly = true; // Default to LAST 7 DAYS / timeframe
  bool _formScoreIsWeekly = true; // Default to LAST 7 DAYS / timeframe

  String _fmt(int n) {
    if (n >= 1000) {
      final s = n.toString();
      return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final timeframeBadge = widget.dateRangeText.toUpperCase();

    final squatsValue = _totalSquatsIsWeekly
        ? widget.weeklySquatsTotal
        : widget.totalSquats;
    final squatsBadge = _totalSquatsIsWeekly ? timeframeBadge : 'ALL TIME';

    final formValue = _formScoreIsWeekly
        ? widget.weeklyForm
        : widget.allTimeForm;
    final formBadge = _formScoreIsWeekly ? timeframeBadge : 'ALL TIME';

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total Squats',
            value: _fmt(squatsValue),
            badgeText: squatsBadge,
            onTap: () =>
                setState(() => _totalSquatsIsWeekly = !_totalSquatsIsWeekly),
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
            onTap: () =>
                setState(() => _formScoreIsWeekly = !_formScoreIsWeekly),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardDecoration = isDark
        ? BoxDecoration(
            color: kDarkSurface,
            borderRadius: BorderRadius.circular(20),
          )
        : BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
          );

    final badgeBg = isDark ? kDarkContainerHigh : Colors.white.withAlpha(179);
    final badgeTextColor = isDark ? kDarkTextMuted : kTextPrimary;
    final labelColor = isDark ? kDarkTextMuted : kTextPrimary;
    final valueColor = isDark ? kNeonLime : kTextPrimary;
    final suffixColor = isDark ? kNeonLime : kTextMuted;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: badgeTextColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
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
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: valueColor,
                    ),
                  ),
                  if (suffix != null)
                    Text(
                      suffix!,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: suffixColor,
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
  final String titleText;
  final bool hasPreviousWeek;
  final bool hasNextWeek;
  final VoidCallback? onPreviousWeek;
  final VoidCallback? onNextWeek;

  const _WeeklySection({
    required this.data,
    this.titleText = 'This Week',
    this.hasPreviousWeek = false,
    this.hasNextWeek = false,
    this.onPreviousWeek,
    this.onNextWeek,
  });

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _dayIndices = [1, 2, 3, 4, 5, 6, 0];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionBg = isDark ? kDarkSurface : const Color(0xFFF6F3F2);
    final circleBg = isDark ? kDarkContainerHigh : const Color(0xFFEBE7E7);
    final iconColor = isDark ? Colors.white : const Color(0xFF1C1B1B);
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1B1B);
    final subtitleColor = isDark ? kDarkTextMuted : const Color(0xFF444933);
    final dayTextColor = isDark ? kDarkTextMuted : const Color(0xFF444933);
    final trackColor = isDark
        ? kDarkTrack
        : const Color(0xFFEBE7E7).withAlpha(128);
    final valTextColor = isDark ? Colors.white : const Color(0xFF1C1B1B);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: sectionBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: circleBg,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/squat-icon.svg',
                        width: 28,
                        height: 28,
                        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      Text(
                        'Squats',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      color: hasPreviousWeek ? titleColor : subtitleColor.withAlpha(80),
                      size: 24,
                    ),
                    onPressed: hasPreviousWeek ? onPreviousWeek : null,
                    tooltip: 'Previous Week',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: hasNextWeek ? titleColor : subtitleColor.withAlpha(80),
                      size: 24,
                    ),
                    onPressed: hasNextWeek ? onNextWeek : null,
                    tooltip: 'Next Week',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final maxVal = data.isEmpty
                  ? 0.0
                  : data.reduce(math.max).toDouble();
              final safeMax = maxVal == 0 ? 1.0 : maxVal;
              const barHeight = 150.0;

              return SizedBox(
                height: 215,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final dataIndex = _dayIndices[i];
                    final val = data[dataIndex];
                    final fraction = (val / safeMax).clamp(0.0, 1.0);
                    final isToday = (titleText == 'This Week') &&
                        (DateTime.now().weekday % 7 == dataIndex);

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          height: 20,
                          child: Text(
                            val > 0 ? '$val' : '',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isToday ? (isDark ? kNeonLime : kOlive) : valTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 22,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: trackColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutCubic,
                                width: 22,
                                height: math.max(val > 0 ? 12.0 : 0.0, barHeight * fraction),
                                decoration: BoxDecoration(
                                  color: isDark ? kNeonLime : kLime,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: isDark && val > 0
                                      ? [
                                          BoxShadow(
                                            color: kNeonLime.withAlpha(80),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _dayNames[i],
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isToday ? titleColor : dayTextColor,
                            fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

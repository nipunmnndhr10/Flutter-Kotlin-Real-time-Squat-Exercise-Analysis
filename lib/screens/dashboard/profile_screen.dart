import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flt_kotlin_pose/core/constants/app_constants.dart';
import 'package:flt_kotlin_pose/main.dart';

// Kinetic Noir Color System (from profile-screen.md)
const kBackground = Color(0xFFFCF8F8);
const kSurface = Color(0xFFF6F3F2);
const kSurfaceContainerHigh = Color(0xFFEBE7E7);
const kSurfaceContainerHighest = Color(0xFFE5E2E1);
const kTextPrimary = Color(0xFF1C1B1B);
const kTextMuted = Color(0xFF696A6D);
const kPrimary = Color(0xFF506600);
const kPrimaryContainer = Color(0xFFCCFF00);
const kSecondary = Color(0xFF006970);
const kError = Color(0xFFD32F2F);

class ProfileScreen extends StatefulWidget {
  final String userName;
  final String greeting;
  final String joinedDate;
  final String profilePictureUrl;
  final VoidCallback onLogout;
  final ValueChanged<String> onProfilePictureUpdated;
  final List<Map<String, dynamic>> workouts;
  final int totalWorkouts;
  final int streakDays;

  const ProfileScreen({
    super.key,
    required this.userName,
    required this.greeting,
    required this.joinedDate,
    required this.profilePictureUrl,
    required this.onLogout,
    required this.onProfilePictureUpdated,
    this.workouts = const [],
    this.totalWorkouts = 142,
    this.streakDays = 12,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;
  String? _localPicUrl;

  @override
  void initState() {
    super.initState();
    _localPicUrl = widget.profilePictureUrl;
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.profilePictureUrl != oldWidget.profilePictureUrl) {
      setState(() {
        _localPicUrl = widget.profilePictureUrl;
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      maxHeight: 1000,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null || token.isEmpty) return;

      final dio = Dio(
        BaseOptions(
          baseUrl: kApiBaseUrl,
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          pickedFile.path,
          filename: pickedFile.name,
        ),
      });

      final response = await dio.post('/auth/profile-picture', data: formData);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final profileData = response.data;
        final relUrl = profileData['profile_picture_url']?.toString() ?? '';
        final fullUrl = relUrl.startsWith('http')
            ? relUrl
            : '$kApiBaseUrl$relUrl';

        await prefs.setString('profile_picture_url', fullUrl);

        setState(() {
          _localPicUrl = fullUrl;
        });

        widget.onProfilePictureUpdated(fullUrl);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
            backgroundColor: kPrimary,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload profile picture: $e'),
          backgroundColor: kError,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showPersonalInfoBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1B2319) : kBackground;
    final handleColor = isDark ? const Color(0xFF222B1F) : kSurfaceContainerHigh;
    final titleColor = isDark ? Colors.white : kTextPrimary;

    final primaryAccent = isDark ? const Color(0xFF82D616) : kPrimary;
    final primaryBtnText = isDark ? const Color(0xFF111710) : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final currentPicUrl = _localPicUrl ?? widget.profilePictureUrl;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: handleColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(
                      'Personal Information',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF222B1F) : kSurface,
                            shape: BoxShape.circle,
                            border: Border.all(color: primaryAccent, width: 2),
                            image: currentPicUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(currentPicUrl),
                                    fit: BoxFit.cover,
                                    onError: (exception, stackTrace) {},
                                  )
                                : null,
                          ),
                          child: currentPicUrl.isEmpty
                              ? Icon(
                                  Icons.person,
                                  color: primaryAccent,
                                  size: 48,
                                )
                              : null,
                        ),
                        if (_isUploading)
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black38,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _isUploading
                          ? null
                          : () async {
                              await _pickAndUploadImage();
                              setSheetState(() {});
                            },
                      icon: Icon(
                        Icons.camera_alt_outlined,
                        color: primaryAccent,
                        size: 18,
                      ),
                      label: Text(
                        'Change Profile Picture',
                        style: GoogleFonts.inter(
                          color: primaryAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      color: isDark ? const Color(0xFF222B1F) : Colors.black12,
                      height: 1,
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(label: 'Full Name', value: widget.userName),
                    const SizedBox(height: 12),
                    _InfoRow(label: 'Joined Date', value: widget.joinedDate),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryAccent,
                          foregroundColor: primaryBtnText,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: Text(
                          'Done',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: primaryBtnText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPicUrl = _localPicUrl ?? widget.profilePictureUrl;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111710) : kBackground;
    final cardBg = isDark ? const Color(0xFF1B2319) : kSurface;
    final cardBorder = isDark ? const Color(0xFF222B1F) : kSurfaceContainerHighest;
    final userNameColor = isDark ? Colors.white : kTextPrimary;
    final joinedColor = isDark ? const Color(0xFF889684) : kTextMuted;

    return SafeArea(
      child: Scaffold(
        backgroundColor: bg,
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // Profile Avatar & User Info Header
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _showPersonalInfoBottomSheet,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: cardBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF82D616), width: 2),
                          image: currentPicUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(currentPicUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: currentPicUrl.isEmpty
                            ? const Icon(
                                Icons.person,
                                color: Color(0xFF82D616),
                                size: 48,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.userName,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: userNameColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Joined ${widget.joinedDate}',
                      style: GoogleFonts.inter(fontSize: 14, color: joinedColor),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Settings & Options Menu Group
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder, width: 1),
                ),
                child: Column(
                  children: [
                    _MenuItemRow(
                      icon: Icons.person_outline_rounded,
                      title: 'Personal Information',
                      onTap: _showPersonalInfoBottomSheet,
                    ),
                    const Divider(height: 1, color: kSurfaceContainerHighest),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeModeNotifier,
                      builder: (context, currentMode, _) {
                        final isDark = currentMode == ThemeMode.dark;
                        return _MenuItemSwitchRow(
                          icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          title: 'Dark Mode',
                          value: isDark,
                          onChanged: (val) async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('is_dark_mode', val);
                            themeModeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                          },
                        );
                      },
                    ),
                    const Divider(height: 1, color: kSurfaceContainerHighest),
                    _MenuItemRow(
                      icon: Icons.lock_outline_rounded,
                      title: 'Privacy & Security',
                      onTap: () {},
                    ),
                    const Divider(height: 1, color: kSurfaceContainerHighest),
                    _MenuItemRow(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & Support',
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: widget.onLogout,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF1B2319) : kBackground,
                    foregroundColor: const Color(0xFFFF5252),
                    side: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 20,
                    color: Color(0xFFFF5252),
                  ),
                  label: Text(
                    'Logout',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFF5252),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuItemRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconBg = isDark ? const Color(0xFF222B1F) : kSurfaceContainerHigh;
    final textColor = isDark ? Colors.white : kTextPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: textColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? const Color(0xFF889684) : kTextMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? const Color(0xFF889684) : kTextMuted;
    final valColor = isDark ? Colors.white : kTextPrimary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 14, color: labelColor)),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valColor,
          ),
        ),
      ],
    );
  }
}

class _MenuItemSwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _MenuItemSwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconBg = isDark ? const Color(0xFF222B1F) : kSurfaceContainerHigh;
    final textColor = isDark ? Colors.white : kTextPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: textColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFF82D616),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

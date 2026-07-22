import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flt_kotlin_pose/core/constants/app_constants.dart';

const kPrimary = Color(0xFF4CAF50);
const kSecondary = Color(0xFF81C784);
const kBackground = Color(0xFFF9F9F9);
const kSurface = Color(0xFFE8F5E9);
const kTextPrimary = Color(0xFF1A1A1A);
const kTextMuted = Color(0xFF757575);

class ProfileScreen extends StatefulWidget {
  final String userName;
  final String greeting;
  final String joinedDate;
  final String profilePictureUrl;
  final VoidCallback onLogout;
  final ValueChanged<String> onProfilePictureUpdated;

  const ProfileScreen({
    super.key,
    required this.userName,
    required this.greeting,
    required this.joinedDate,
    required this.profilePictureUrl,
    required this.onLogout,
    required this.onProfilePictureUpdated,
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
          headers: {
            'Authorization': 'Bearer $token',
          },
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
        final fullUrl = relUrl.startsWith('http') ? relUrl : '$kApiBaseUrl$relUrl';

        await prefs.setString('profile_picture_url', fullUrl);

        setState(() {
          _localPicUrl = fullUrl;
        });

        widget.onProfilePictureUpdated(fullUrl);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload profile picture: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPicUrl = _localPicUrl ?? widget.profilePictureUrl;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            userName: widget.userName,
            greeting: widget.greeting,
            profilePictureUrl: currentPicUrl,
            onLogout: widget.onLogout,
          ),
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: kSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: kPrimary, width: 2),
                        image: currentPicUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(currentPicUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: currentPicUrl.isEmpty
                          ? const Icon(Icons.person, color: kPrimary, size: 54)
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
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _isUploading ? null : _pickAndUploadImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: kPrimary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  widget.userName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: kTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _ProfileDetailRow(
                  icon: Icons.person_outline,
                  label: 'Name',
                  value: widget.userName,
                ),
                const Divider(height: 24, color: Colors.black12),
                _ProfileDetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Joined',
                  value: widget.joinedDate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: widget.onLogout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.logout),
              label: const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
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
    required this.profilePictureUrl,
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
                  )
                : null,
          ),
          child: profilePictureUrl.isEmpty
              ? const Icon(Icons.person_outline, color: kPrimary, size: 24)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(fontSize: 12, color: kTextMuted),
              ),
              Text(
                userName,
                style: const TextStyle(
                  fontSize: 16,
                  color: kTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
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
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onLogout,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.logout_outlined,
              color: Colors.red,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ProfileDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: kPrimary, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: kTextMuted, fontSize: 14)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: kTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flt_kotlin_pose/core/constants/app_constants.dart';
import 'package:flt_kotlin_pose/screens/auth/components/login_components.dart';
import 'package:flt_kotlin_pose/core/utils/validators.dart';
import 'package:flt_kotlin_pose/screens/dashboard/dashboard_screen.dart';
import 'package:google_fonts/google_fonts.dart';

// Design tokens
const _kBg = Color(0xFFFCF8F8);
const _kCard = Color(0xFFF6F3F2);
const _kBorderError = Color(0xFFBA1A1A);
const _kPrimary = Color(0xFF506600);
const _kDark = Color(0xFF1C1B1B);
const _kTextMuted = Color(0xFF444933);
const _kRadius = 12.0;

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  bool _agree = false;
  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // FIX #3: Cache strength score and label as fields updated in onChanged.
  // The getter was re-running passwordStrengthScore() on every build() call.
  int _strengthScore = 0;
  String _strengthLabel = 'WEAK';
  Color _strengthColor = const Color(0xFFE5534B);

  // FIX #5: Cache form validity as a field — never recompute during build().
  bool _formValid = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // FIX #5: Single helper that recomputes _formValid from cached error fields.
  // Called at the end of every onChanged handler — O(1), no regex.
  void _updateFormValid() {
    _formValid =
        _nameError == null &&
        _emailError == null &&
        _passwordError == null &&
        _confirmError == null &&
        _agree &&
        _nameController.text.trim().isNotEmpty;
  }

  // FIX #3 helper: update strength fields from a password string.
  void _updateStrength(String v) {
    _strengthScore = passwordStrengthScore(v);
    _strengthLabel = passwordStrengthLabel(v);
    _strengthColor = _computeStrengthColor(_strengthScore);
  }

  Color _computeStrengthColor(int score) {
    return const Color(0xFFCCFF00);
  }

  void _onNameChanged(String v) {
    setState(() {
      _nameError = v.trim().isEmpty ? 'Full name is required' : null;
      _updateFormValid();
    });
  }

  void _onEmailChanged(String v) {
    setState(() {
      _emailError = validateEmail(v);
      _updateFormValid();
    });
  }

  void _onPasswordChanged(String v) {
    setState(() {
      _passwordError = validateSignupPassword(v);
      // Re-validate confirm if already touched
      if (_confirmController.text.isNotEmpty) {
        _confirmError = _confirmController.text == v
            ? null
            : 'Passwords do not match';
      }
      // FIX #3: Update cached strength fields here, not in build().
      _updateStrength(v);
      _updateFormValid();
    });
  }

  void _onConfirmChanged(String v) {
    setState(() {
      _confirmError = _passwordController.text == v
          ? null
          : 'Passwords do not match';
      _updateFormValid();
    });
  }

  // Save session data to SharedPreferences (same as login)
  Future<void> _saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? {};

    final token = data['access_token']?.toString();
    if (token != null && token.isNotEmpty) {
      await prefs.setString('access_token', token);
    }

    final userId = user['id'];
    if (userId is int) {
      await prefs.setInt('user_id', userId);
    }

    final fullName = user['full_name']?.toString();
    if (fullName != null && fullName.isNotEmpty) {
      await prefs.setString('user_name', fullName);
    }

    final email = user['email']?.toString();
    if (email != null && email.isNotEmpty) {
      await prefs.setString('user_email', email);
    }

    final picUrl = user['profile_picture_url']?.toString();
    if (picUrl != null && picUrl.isNotEmpty) {
      final fullUrl = picUrl.startsWith('http')
          ? picUrl
          : '$kApiBaseUrl$picUrl';
      await prefs.setString('profile_picture_url', fullUrl);
    }
  }

  void _validateAll() {
    setState(() {
      _nameError = _nameController.text.trim().isEmpty
          ? 'Full name is required'
          : null;
      _emailError = validateEmail(_emailController.text);
      _passwordError = validateSignupPassword(_passwordController.text);
      _confirmError = _passwordController.text == _confirmController.text
          ? null
          : 'Passwords do not match';
      _updateStrength(_passwordController.text);
      _updateFormValid();
    });
  }

  Future<void> _handleSignup() async {
    _validateAll();
    if (!_formValid) return;

    setState(() => _isEmailLoading = true);

    try {
      final response = await Dio().post(
        '$kApiBaseUrl/auth/signup',
        data: {
          "email": _emailController.text.trim(),
          "password": _passwordController.text,
          "full_name": _nameController.text.trim(),
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        await _saveSession(Map<String, dynamic>.from(data as Map));

        final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? {};
        final displayName = user['full_name']?.toString() ?? 'User';

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account created successfully!"),
            backgroundColor: Colors.green,
          ),
        );

        // Go to Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardScreen(userName: displayName),
          ),
        );
      }
    } on DioException catch (e) {
      String errorMsg = "Signup failed";

      if (e.response?.data is Map) {
        errorMsg = e.response?.data['detail'] ?? errorMsg;
      } else if (e.message != null) {
        errorMsg = e.message!;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Something went wrong")));
    } finally {
      if (mounted) setState(() => _isEmailLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(
        serverClientId:
            '984161335343-0l7irv2t1nkrft49bo186ahd46unania.apps.googleusercontent.com',
        clientId: kIsWeb
            ? '984161335343-0l7irv2t1nkrft49bo186ahd46unania.apps.googleusercontent.com'
            : null,
      );

      final GoogleSignInAccount googleUser;
      try {
        googleUser = await googleSignIn.authenticate();
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          // User canceled the sign-in
          if (mounted) setState(() => _isGoogleLoading = false);
          return;
        }
        debugPrint('GoogleSignInException: ${e.code} - $e');
        rethrow;
      }

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to get Google ID token"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isGoogleLoading = false);
        return;
      }

      final response = await Dio().post(
        '$kApiBaseUrl/auth/google',
        data: {"id_token": idToken},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        await _saveSession(Map<String, dynamic>.from(data as Map));

        final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? {};
        final displayName = user['full_name']?.toString() ?? 'User';

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Google Signup successful!"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DashboardScreen(userName: displayName),
          ),
        );
      }
    } on DioException catch (e, stackTrace) {
      debugPrint('DioException during Google signup: $e');
      debugPrintStack(stackTrace: stackTrace);
      String errorMsg = "Google Signup failed";
      if (e.response?.data is Map) {
        errorMsg = e.response?.data['detail'] ?? errorMsg;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    } catch (e, stackTrace) {
      debugPrint('Error during Google signup: $e');
      debugPrintStack(stackTrace: stackTrace);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const scaffoldBg = _kBg;
    const backBtnBg = _kCard;
    const backBtnIcon = _kDark;
    const titleColor = _kDark;
    const subtitleColor = _kTextMuted;
    const buttonBg = Color(0xFFCCFF00);
    const buttonText = _kDark;
    const dividerColor = Color(0xFFE5E2E1);
    const googleBg = Colors.white;
    const googleBorder = Color(0xFFE5E2E1);
    const googleText = _kDark;
    const primaryAccent = _kPrimary;

    return Scaffold(
      backgroundColor: scaffoldBg,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacingXl,
                  vertical: 10,
                ),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: backBtnBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: backBtnIcon,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Text(
                          'Create your\naccount',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                            height: 1.1,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Start your journey to better squat form',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: subtitleColor,
                            fontWeight: FontWeight.w400,
                          ),
                        ),

                        const SizedBox(height: 24),

                        _StyledInputField(
                          controller: _nameController,
                          hint: 'Full Name',
                          icon: Icons.person_outline_rounded,
                          errorText: _nameError,
                          onChanged: _onNameChanged,
                        ),

                        const SizedBox(height: 12),

                        // Email
                        _StyledInputField(
                          controller: _emailController,
                          hint: 'Email Address',
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          errorText: _emailError,
                          onChanged: _onEmailChanged,
                        ),

                        const SizedBox(height: 12),

                        // Password
                        _StyledInputField(
                          controller: _passwordController,
                          hint: 'Password',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          errorText: _passwordError,
                          onChanged: _onPasswordChanged,
                          suffixIcon: GestureDetector(
                            onTap: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            child: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.remove_red_eye_outlined,
                              color: subtitleColor,
                              size: 18,
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 2),
                          child: _PasswordStrengthIndicator(
                            score: _strengthScore,
                            label: _strengthLabel,
                            color: _strengthColor,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Confirm Password
                        _StyledInputField(
                          controller: _confirmController,
                          hint: 'Confirm Password',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscureConfirm,
                          errorText: _confirmError,
                          onChanged: _onConfirmChanged,
                          suffixIcon: GestureDetector(
                            onTap: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                            child: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.remove_red_eye_outlined,
                              color: subtitleColor,
                              size: 18,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Terms checkbox
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => setState(() {
                                _agree = !_agree;
                                _updateFormValid();
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: _agree ? primaryAccent : _kCard,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _agree
                                        ? primaryAccent
                                        : const Color(0xFF747A60),
                                    width: 1.5,
                                  ),
                                ),
                                child: _agree
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _agree = !_agree;
                                  _updateFormValid();
                                }),
                                child: RichText(
                                  text: TextSpan(
                                    text: 'I agree to the ',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF1C1B1B),
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Terms of Service',
                                        style: GoogleFonts.inter(
                                          color: primaryAccent,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const TextSpan(text: ' and\n'),
                                      TextSpan(
                                        text: 'Privacy Policy',
                                        style: GoogleFonts.inter(
                                          color: primaryAccent,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // CTA Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed:
                                (_formValid &&
                                    !_isEmailLoading &&
                                    !_isGoogleLoading)
                                ? _handleSignup
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: buttonBg,
                              disabledBackgroundColor: const Color(0xFFDCD9D9),
                              disabledForegroundColor: const Color(0x801C1B1B),
                              foregroundColor: buttonText,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isEmailLoading
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: buttonText,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    'Join SquatMate',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          (_formValid &&
                                              !_isEmailLoading &&
                                              !_isGoogleLoading)
                                          ? buttonText
                                          : const Color(0x801C1B1B),
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // OR divider
                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: dividerColor, thickness: 1),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'OR',
                                style: GoogleFonts.jetBrainsMono(
                                  color: const Color(0xFF5D5E61),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: dividerColor, thickness: 1),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Google button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: (_isEmailLoading || _isGoogleLoading)
                                ? null
                                : _handleGoogleSignIn,
                            icon: _isGoogleLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const GoogleLogo(),
                            label: Text(
                              _isGoogleLoading
                                  ? 'Signing up...'
                                  : 'Continue with Google',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: googleText,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: googleBg,
                              side: BorderSide(color: googleBorder, width: 1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Log in link
                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).maybePop(),
                            child: RichText(
                              text: TextSpan(
                                text: 'Already a member? ',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF444933),
                                  fontSize: 14,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Log in',
                                    style: GoogleFonts.inter(
                                      color: primaryAccent,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),
                      ],
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

// Input field with icon, error message, and optional password toggle/suffix.

class _StyledInputField extends StatelessWidget {
  const _StyledInputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.onChanged,
    this.errorText,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: GoogleFonts.inter(
        fontSize: 15,
        color: _kDark,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          color: const Color(0x801C1B1B),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(icon, size: 20, color: const Color(0x801C1B1B)),
        suffixIcon: suffixIcon != null
            ? Padding(
                padding: const EdgeInsets.only(right: 8),
                child: suffixIcon,
              )
            : null,
        filled: true,
        fillColor: _kCard,
        errorText: errorText,
        errorStyle: GoogleFonts.inter(color: _kBorderError, fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: const BorderSide(color: Color(0xFF747A60), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: const BorderSide(color: _kBorderError, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: const BorderSide(color: _kBorderError, width: 1.5),
        ),
      ),
    );
  }
}

//Password strength indicator bar with label, based on a strength score from 0-4.

class _PasswordStrengthIndicator extends StatelessWidget {
  const _PasswordStrengthIndicator({
    required this.score,
    required this.label,
    required this.color,
  });

  final int score;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactive = isDark ? const Color(0xFF222B1F) : const Color(0xFFEAEDF0);
    final mutedLabel = isDark
        ? const Color(0xFF889684)
        : const Color(0xFFBEC5CF);

    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(4, (i) {
              final active = i < score;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 3 ? 5.0 : 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 4,
                    decoration: BoxDecoration(
                      color: active ? color : inactive,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: score > 0 ? const Color(0xFF1C1B1B) : mutedLabel,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

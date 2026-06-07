import 'package:flutter/material.dart';
import 'app_constants.dart';
import 'login_components.dart';
import 'validators.dart';
import 'pose_screen.dart';

// Design tokens
const _kBg = Color(0xFFF7F8FA);
const _kCard = Colors.white;
const _kBorder = Color(0xFFEAEDF0);
const _kBorderError = Color(0xFFFCA5A5);
const _kPrimary = Color.fromRGBO(46, 204, 113, 1);
const _kDark = Color(0xFF111820);
const _kTextMuted = Color(0xFF8A95A3);
const _kIconColor = Color(0xFFC0C8D2);
const _kRadius = 14.0;

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
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  int get _passwordStrengthScore =>
      passwordStrengthScore(_passwordController.text);

  Color _strengthColor(int score) {
    if (score <= 1) return const Color(0xFFE5534B);
    if (score == 2) return const Color(0xFFF6A623);
    if (score == 3) return const Color(0xFF2ECC71);
    return const Color(0xFF17B26A);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
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
    });
  }

  bool get _isFormValid {
    return _nameError == null &&
        _emailError == null &&
        _passwordError == null &&
        _confirmError == null &&
        _agree &&
        _nameController.text.trim().isNotEmpty;
  }

  Future<void> _handleSignup() async {
    _validateAll();
    if (!_isFormValid) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const PoseScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button row
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: kSpacingXl, vertical: 10),
              child: GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEEF0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: Color(0xFF555D6A)),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: kSpacingXl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Header
                    const Text(
                      'Create your\naccount',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _kDark,
                        height: 1.15,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Join thousands improving their squat form',
                      style: TextStyle(
                        fontSize: 13,
                        color: _kTextMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: kSpacingXxl),

                    // Full Name
                    _StyledInputField(
                      controller: _nameController,
                      hint: 'Full Name',
                      icon: Icons.person_outline_rounded,
                      errorText: _nameError,
                      onChanged: (v) => setState(() {
                        _nameError =
                            v.trim().isEmpty ? 'Full name is required' : null;
                      }),
                    ),

                    const SizedBox(height: kSpacingMd),

                    // Email
                    _StyledInputField(
                      controller: _emailController,
                      hint: 'Email Address',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      errorText: _emailError,
                      onChanged: (v) =>
                          setState(() => _emailError = validateEmail(v)),
                    ),

                    const SizedBox(height: kSpacingMd),

                    // Password
                    _StyledInputField(
                      controller: _passwordController,
                      hint: 'Password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      errorText: _passwordError,
                      onChanged: (v) => setState(() {
                        _passwordError = validateSignupPassword(v);
                        if (_confirmController.text.isNotEmpty) {
                          _confirmError = _confirmController.text == v
                              ? null
                              : 'Passwords do not match';
                        }
                      }),
                      suffixIcon: GestureDetector(
                        onTap: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        child: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.remove_red_eye_outlined,
                          color: _kIconColor,
                          size: 18,
                        ),
                      ),
                    ),

                    // Strength bar — always occupies space to avoid layout jump
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 4),
                      child: _PasswordStrengthIndicator(
                        score: _passwordStrengthScore,
                        label: passwordStrengthLabel(_passwordController.text),
                        color: _strengthColor(_passwordStrengthScore),
                      ),
                    ),

                    const SizedBox(height: kSpacingSm),

                    // Confirm Password
                    _StyledInputField(
                      controller: _confirmController,
                      hint: 'Confirm Password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscureConfirm,
                      errorText: _confirmError,
                      onChanged: (v) => setState(() {
                        _confirmError = _passwordController.text == v
                            ? null
                            : 'Passwords do not match';
                      }),
                      suffixIcon: GestureDetector(
                        onTap: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                        child: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.remove_red_eye_outlined,
                          color: _kIconColor,
                          size: 18,
                        ),
                      ),
                    ),

                    const SizedBox(height: kSpacingLg),

                    // Terms checkbox
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _agree = !_agree),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: _agree ? _kPrimary : _kCard,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: _agree ? _kPrimary : _kBorder,
                                width: 1.8,
                              ),
                            ),
                            child: _agree
                                ? const Icon(Icons.check_rounded,
                                    size: 14, color: Colors.white)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _agree = !_agree),
                            child: RichText(
                              text: TextSpan(
                                text: 'I agree to the ',
                                style: const TextStyle(
                                    color: _kTextMuted,
                                    fontSize: 12.5,
                                    height: 1.5),
                                children: [
                                  TextSpan(
                                    text: 'Terms of Service',
                                    style: const TextStyle(
                                        color: _kPrimary,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: const TextStyle(
                                        color: _kPrimary,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: kSpacingXl),

                    // CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed:
                            (_isLoading || !_isFormValid) ? null : _handleSignup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kDark,
                          disabledBackgroundColor:
                              const Color(0xFFD1D5DB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : const Text(
                                'Join SquatMate',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),

                    const SizedBox(height: kSpacingXl),

                    // OR divider
                    Row(children: [
                      const Expanded(
                          child:
                              Divider(color: Color(0xFFEAEDF0), thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR',
                            style: TextStyle(
                                color: const Color.fromRGBO(138, 149, 163, 1),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6)),
                      ),
                      const Expanded(
                          child:
                              Divider(color: Color(0xFFEAEDF0), thickness: 1)),
                    ]),

                    const SizedBox(height: kSpacingLg),

                    // Google button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _kCard,
                          side: const BorderSide(color: _kBorder, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const GoogleLogo(),
                            const SizedBox(width: 8),
                            const Text(
                              'Continue with Google',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _kDark),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: kSpacingXl),

                    // Log in link
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: RichText(
                          text: const TextSpan(
                            text: 'Already a member? ',
                            style:
                                TextStyle(color: _kTextMuted, fontSize: 13),
                            children: [
                              TextSpan(
                                text: 'Log in',
                                style: TextStyle(
                                    color: _kPrimary,
                                    fontWeight: FontWeight.w700),
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
          ],
        ),
      ),
      ),
    );
  }
}

// ─── Styled Input Field ───────────────────────────────────────────────────────

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
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(_kRadius),
            border: Border.all(
              color: hasError ? _kBorderError : _kBorder,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: _kIconColor),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  onChanged: onChanged,
                  style: const TextStyle(
                      fontSize: 14,
                      color: _kDark,
                      fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(
                        color: Color(0xFFBEC5CF),
                        fontSize: 14,
                        fontWeight: FontWeight.w400),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (suffixIcon != null) ...[
                const SizedBox(width: 8),
                suffixIcon!,
              ],
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              errorText!,
              style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFFE5534B),
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Password Strength Indicator ─────────────────────────────────────────────

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
    const inactive = Color(0xFFEAEDF0);

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
          style: TextStyle(
            color: score > 0 ? color : const Color(0xFFBEC5CF),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
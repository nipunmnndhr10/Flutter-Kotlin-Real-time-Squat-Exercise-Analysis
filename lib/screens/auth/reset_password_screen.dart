import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flt_kotlin_pose/core/constants/app_constants.dart';
import 'package:flt_kotlin_pose/screens/auth/components/login_components.dart';
import 'package:flt_kotlin_pose/core/utils/validators.dart';
import 'package:google_fonts/google_fonts.dart';

const _kBg = Color(0xFFFCF8F8);
const _kDark = Color(0xFF1C1B1B);
const _kTextMuted = Color(0xFF444933);
const _kPrimary = Color(0xFF506600);
const _kLime = Color(0xFFCCFF00);
const _kRadius = 12.0;

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _otpError;
  String? _passwordError;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged(String v) {
    final err = validatePassword(v);
    setState(() {
      _passwordError = err;
    });
  }

  Future<void> _handleResetPassword() async {
    setState(() {
      _otpError = null;
      _passwordError = null;
      _isLoading = true;
    });

    if (_otpController.text.trim().isEmpty) {
      setState(() {
        _otpError = "OTP is required";
        _isLoading = false;
      });
      return;
    }

    if (_passwordController.text.isEmpty) {
      setState(() {
        _passwordError = "New password is required";
        _isLoading = false;
      });
      return;
    }

    if (_passwordError != null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await Dio().post(
        '$kApiBaseUrl/auth/reset-password',
        data: {
          "email": widget.email,
          "otp": _otpController.text.trim(),
          "new_password": _passwordController.text,
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Password reset successfully! You can now log in.", style: TextStyle(color: Colors.black)),
            backgroundColor: Color(0xFFCCFF00),
          ),
        );
        // Pop back to the first screen (LoginScreen)
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on DioException catch (e) {
      String errorMsg = "Failed to reset password";
      if (e.response?.data is Map) {
        errorMsg = e.response?.data['detail'] ?? errorMsg;
      } else if (e.message != null) {
        errorMsg = e.message!;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg, style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Something went wrong", style: GoogleFonts.inter())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const scaffoldBg = _kBg;
    const titleColor = _kDark;
    const subtitleColor = _kTextMuted;
    const buttonBg = _kLime;
    const buttonText = _kDark;
    const backBtnIcon = _kPrimary;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: backBtnIcon, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Reset Password',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please enter the 6-digit code sent to your email and your new password.',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: subtitleColor,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                InputField(
                  controller: _otpController,
                  hint: '6-digit OTP',
                  icon: Icons.numbers_rounded,
                  keyboardType: TextInputType.number,
                  errorText: _otpError,
                ),
                const SizedBox(height: 16),
                InputField(
                  controller: _passwordController,
                  hint: 'New Password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  errorText: _passwordError,
                  onChanged: _onPasswordChanged,
                  suffixIcon: GestureDetector(
                    onTap: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    child: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: subtitleColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleResetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonBg,
                      foregroundColor: buttonText,
                      disabledBackgroundColor: const Color(0xFFDCD9D9),
                      disabledForegroundColor: const Color(0x801C1B1B),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: buttonText,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'Reset Password',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: buttonText,
                            ),
                          ),
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

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flt_kotlin_pose/core/constants/app_constants.dart';
import 'package:flt_kotlin_pose/screens/auth/components/login_components.dart';
import 'package:flt_kotlin_pose/core/utils/validators.dart';

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

  static const Color textDark = Color(0xFF1A2332);
  static const Color textGray = Color(0xFF8A95A3);

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
            content: Text("Password reset successfully! You can now log in."),
            backgroundColor: Colors.green,
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
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF111710) : const Color(0xFFF5F5F5);
    final titleColor = isDark ? Colors.white : textDark;
    final subtitleColor = isDark ? const Color(0xFF889684) : textGray;
    final buttonBg = isDark ? const Color(0xFF82D616) : const Color(0xFF111820);
    final buttonText = isDark ? const Color(0xFF111710) : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: titleColor),
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
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: kSpacingSm),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: subtitleColor,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'Please enter the 6-digit code sent to '),
                      TextSpan(
                        text: widget.email,
                        style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: ' and your new password.'),
                    ],
                  ),
                ),
                const SizedBox(height: kSpacingXxl),
                InputField(
                  controller: _otpController,
                  hint: '6-digit OTP',
                  icon: Icons.numbers_rounded,
                  keyboardType: TextInputType.number,
                  errorText: _otpError,
                ),
                const SizedBox(height: kSpacingMd),
                InputField(
                  controller: _passwordController,
                  hint: 'New Password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  errorText: _passwordError,
                  onChanged: _onPasswordChanged,
                  suffixIcon: GestureDetector(
                    onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                    child: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.remove_red_eye_outlined,
                      color: subtitleColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: kSpacingXxl),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleResetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonBg,
                      foregroundColor: buttonText,
                      disabledBackgroundColor: isDark
                          ? const Color(0xFF222B1F)
                          : const Color.fromRGBO(209, 213, 219, 1),
                      disabledForegroundColor: isDark
                          ? const Color(0xFF889684)
                          : const Color(0xFF9CA3AF),
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
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.35,
                              color: _isLoading
                                  ? buttonText
                                  : (isDark ? const Color(0xFF111710) : Colors.white),
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

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flt_kotlin_pose/core/constants/app_constants.dart';
import 'package:flt_kotlin_pose/screens/auth/components/login_components.dart';
import 'package:flt_kotlin_pose/core/utils/validators.dart';
import 'package:flt_kotlin_pose/screens/auth/reset_password_screen.dart';
import 'package:google_fonts/google_fonts.dart';

const _kBg = Color(0xFFFCF8F8);
const _kDark = Color(0xFF1C1B1B);
const _kTextMuted = Color(0xFF444933);
const _kPrimary = Color(0xFF506600);
const _kLime = Color(0xFFCCFF00);
const _kRadius = 12.0;

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  String? _emailError;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _onEmailChanged(String v) {
    final err = validateEmail(v);
    setState(() {
      _emailError = err;
    });
  }

  Future<void> _handleForgotPassword() async {
    setState(() {
      _emailError = null;
      _isLoading = true;
    });

    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _emailError = "Email is required";
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await Dio().post(
        '$kApiBaseUrl/auth/forgot-password',
        data: {"email": _emailController.text.trim()},
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("OTP sent to your email!", style: TextStyle(color: Colors.black)),
            backgroundColor: Color(0xFFCCFF00),
          ),
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ResetPasswordScreen(email: _emailController.text.trim()),
          ),
        );
      }
    } on DioException catch (e) {
      String errorMsg = "Failed to send OTP";
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Something went wrong", style: GoogleFonts.inter())));
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Forgot Password?',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter the email address associated with your account and we will send you a 6-digit code to reset your password.',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: subtitleColor,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'EMAIL ADDRESS',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5D5E61),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                InputField(
                  controller: _emailController,
                  hint: 'name@example.com',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  errorText: _emailError,
                  onChanged: _onEmailChanged,
                  hintStyle: GoogleFonts.inter(
                    color: _kDark.withValues(alpha: 0.5),
                    fontSize: 16,
                  ),
                  style: GoogleFonts.inter(
                    color: _kDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleForgotPassword,
                    icon: _isLoading
                        ? const SizedBox.shrink()
                        : Icon(
                            Icons.send_outlined,
                            size: 20,
                            color: buttonText,
                          ),
                    label: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: buttonText,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'Send Code',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: buttonText,
                            ),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonBg,
                      foregroundColor: buttonText,
                      disabledBackgroundColor: const Color(0xFFDCD9D9),
                      disabledForegroundColor: const Color(0x801C1B1B),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_kRadius),
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

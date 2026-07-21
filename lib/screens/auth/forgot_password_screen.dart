import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flt_kotlin_pose/core/constants/app_constants.dart';
import 'package:flt_kotlin_pose/screens/auth/components/login_components.dart';
import 'package:flt_kotlin_pose/core/utils/validators.dart';
import 'package:flt_kotlin_pose/screens/auth/reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  String? _emailError;
  bool _isLoading = false;

  static const Color textDark = Color(0xFF1A2332);
  static const Color textGray = Color(0xFF8A95A3);

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
        data: {
          "email": _emailController.text.trim(),
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("OTP sent to your email!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(email: _emailController.text.trim()),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textDark),
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
                const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: kSpacingSm),
                const Text(
                  'Enter the email address associated with your account and we will send you a 6-digit code to reset your password.',
                  style: TextStyle(
                    fontSize: 14,
                    color: textGray,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: kSpacingXxl),
                InputField(
                  controller: _emailController,
                  hint: 'Email Address',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  errorText: _emailError,
                  onChanged: _onEmailChanged,
                ),
                const SizedBox(height: kSpacingXxl),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleForgotPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(17, 24, 32, 1),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color.fromRGBO(209, 213, 219, 1),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Send Code',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.35,
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

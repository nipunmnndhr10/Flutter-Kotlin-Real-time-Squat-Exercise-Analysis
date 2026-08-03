import 'package:dio/dio.dart';
import 'package:flt_kotlin_pose/screens/dashboard/dashboard_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flt_kotlin_pose/core/constants/app_constants.dart';
import 'package:flt_kotlin_pose/core/utils/validators.dart';
import 'package:flt_kotlin_pose/screens/auth/components/login_components.dart';
import 'package:flt_kotlin_pose/screens/auth/signup_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flt_kotlin_pose/screens/auth/forgot_password_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _emailError;
  String? _passwordError;
  bool _obscurePassword = true;
  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;


  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
          ),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onEmailChanged(String v) {
    final err = validateEmail(v);
    setState(() {
      _emailError = err;
    });
  }

  void _onPasswordChanged(String v) {
    final err = validatePassword(v);
    setState(() {
      _passwordError = err;
    });
  }

  // Save session data to SharedPreferences
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

  Future<void> _handleLogin() async {
    // Clear previous errors - resetting UI state
    setState(() {
      _emailError = null;
      _passwordError = null;
      _isEmailLoading = true;
    });

    // Basic input validation
    if (_emailController.text.trim().isEmpty) {
      setState(() => _emailError = "Email is required");
      setState(() => _isEmailLoading = false);
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _passwordError = "Password is required");
      setState(() => _isEmailLoading = false);
      return;
    }

    try {
      final response = await Dio().post(
        '$kApiBaseUrl/auth/login',
        data: {
          "email": _emailController.text.trim(),
          "password": _passwordController.text,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        await _saveSession(Map<String, dynamic>.from(data as Map));

        final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? {};
        final displayName = user['full_name']?.toString() ?? 'User';

        if (!mounted) return;

        // Success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Login successful!", style: TextStyle(color: Colors.black)),
            backgroundColor: Color(0xFFCCFF00),
          ),
        );

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DashboardScreen(userName: displayName),
          ),
        );
      }
      // handling errors
    } on DioException catch (e) {
      String errorMsg = "Login failed";

      if (e.response?.data is Map) {
        errorMsg = e.response?.data['detail'] ?? errorMsg;
      } else if (e.message != null) {
        errorMsg = e.message!;
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg, style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) {
        return; //If this screen is no longer active, stop executing. to make sure user is there
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Something went wrong", style: GoogleFonts.inter())));
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
          SnackBar(
            content: Text("Failed to get Google ID token", style: GoogleFonts.inter()),
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
            content: Text("Google Login successful!", style: TextStyle(color: Colors.black)),
            backgroundColor: Color(0xFFCCFF00),
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DashboardScreen(userName: displayName),
          ),
        );
      }
    } on DioException catch (e, stackTrace) {
      debugPrint('DioException during Google login: $e');
      debugPrintStack(stackTrace: stackTrace);
      String errorMsg = "Google Login failed";
      if (e.response?.data is Map) {
        errorMsg = e.response?.data['detail'] ?? errorMsg;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg, style: GoogleFonts.inter()), backgroundColor: Colors.red),
      );
    } catch (e, stackTrace) {
      debugPrint('Error during Google login: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e", style: GoogleFonts.inter())));
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const scaffoldBg = Color(0xFFFCF8F8);
    const titleColor = Color(0xFF506600);
    const labelColor = Color(0xFF1C1B1B);
    const buttonBg = Color(0xFFCCFF00);
    const buttonText = Color(0xFF1C1B1B);
    const googleBg = Color(0xFFFFFFFF);
    const googleBorder = Color(0xFFE5E2E1);
    const googleText = Color(0xFF1C1B1B);

    return Scaffold(
      backgroundColor: scaffoldBg,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const HeroSection(),
                  const SizedBox(height: 12),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Squat',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w800,
                                      color: titleColor,
                                      letterSpacing: -0.96,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Mate',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w800,
                                      color: titleColor,
                                      letterSpacing: -0.96,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'AI SQUAD COACHING COMPANION',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                color: const Color(0xFF5D5E61),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 40),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Email Address',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: labelColor,
                                      letterSpacing: 0.6,
                                    ),
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
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Password',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: labelColor,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ForgotPasswordScreen(),
                                          ),
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Forgot password?',
                                        style: GoogleFonts.jetBrainsMono(
                                          color: const Color(0xFF006970),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                InputField(
                                  controller: _passwordController,
                                  hint: '••••••••',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  errorText: _passwordError,
                                  onChanged: _onPasswordChanged,
                                  suffixIcon: GestureDetector(
                                    onTap: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    child: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.remove_red_eye_outlined,
                                      color: const Color(0xFF5D5E61),
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _isEmailLoading
                                        ? null
                                        : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: buttonBg,
                                      foregroundColor: buttonText,
                                      disabledBackgroundColor: const Color(
                                        0xFFDCD9D9,
                                      ),
                                      elevation: 0,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isEmailLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: buttonText,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Log In',
                                                style: GoogleFonts.inter(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: buttonText,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(
                                                Icons.arrow_forward,
                                                color: buttonText,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const OrDivider(),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        (_isEmailLoading || _isGoogleLoading)
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
                                          ? 'Signing in...'
                                          : 'Continue with Google',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: googleText,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: googleBg,
                                      side: const BorderSide(
                                        color: googleBorder,
                                        width: 1,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'New here? ',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF444933),
                                    fontSize: 16,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const SignupScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Join SquatMate',
                                    style: GoogleFonts.inter(
                                      color: titleColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

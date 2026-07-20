import 'package:dio/dio.dart';
import 'app_config.dart';
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'validators.dart';
import 'login_components.dart';
import 'signup_screen.dart';

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
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  double _heroHeight = 200.0; // ✅ REDUCED from 280 to 200

  // Brand colors
  static const Color primaryGreen = Color(0xFF2ECC71);
  static const Color textDark = Color(0xFF1A2332);
  static const Color textGray = Color(0xFF8A95A3);
  static const Color cardBg = Color(0xFFFFFFFF);

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    final availableHeight =
        media.size.height -
        media.padding.top -
        media.padding.bottom -
        kToolbarHeight;
    _heroHeight = (availableHeight * 0.30).clamp(140.0, 220.0); // ✅ Reduced
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
  }

  Future<void> _handleLogin() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _isLoading = true;
    });

    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _emailError = "Email is required";
        _isLoading = false;
      });
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() {
        _passwordError = "Password is required";
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await Dio().post(
        '${AppConfig.apiBaseUrl}/auth/login',
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Login successful!"),
            backgroundColor: Colors.green,
          ),
        );

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DashboardScreen(userName: displayName),
          ),
        );
      }
    } on DioException catch (e) {
      String errorMsg = "Login failed";

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        errorMsg = "Cannot connect to server. Please check your connection.";
      } else if (e.response?.data is Map) {
        errorMsg = e.response?.data['detail'] ?? "Invalid credentials";
      } else if (e.message != null) {
        errorMsg = e.message!;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Something went wrong. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Hero Section - Smaller
                      SizedBox(
                        height: _heroHeight,
                        width: double.infinity,
                        child: const RepaintBoundary(child: HeroSection()),
                      ),
                      
                      // Form Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 8),
                                
                                // Title
                                RichText(
                                  text: const TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Squat',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1A2332),
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'Mate',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF2ECC71),
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 2),
                                
                                const Text(
                                  'Your AI squat coaching companion',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8A95A3),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Email Field
                                InputField(
                                  controller: _emailController,
                                  hint: 'Email',
                                  icon: Icons.mail_outline_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  errorText: _emailError,
                                  onChanged: _onEmailChanged,
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Password Field
                                InputField(
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
                                      color: const Color(0xFF8A95A3),
                                      size: 20,
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 4),
                                
                                // Forgot Password
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {},
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 0,
                                        vertical: 2,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Forgot password?',
                                      style: TextStyle(
                                        color: Color(0xFF2ECC71),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Login Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color.fromRGBO(
                                        17,
                                        24,
                                        32,
                                        1,
                                      ),
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          const Color.fromRGBO(
                                            209,
                                            213,
                                            219,
                                            1,
                                          ),
                                      elevation: 0,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          30,
                                        ),
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
                                            'Log In',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.35,
                                            ),
                                          ),
                                  ),
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // OR Divider
                                const OrDivider(),
                                
                                const SizedBox(height: 12),
                                
                                // Google Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: OutlinedButton.icon(
                                    onPressed: () {},
                                    icon: const GoogleLogo(),
                                    label: const Text(
                                      'Continue with Google',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1A2332),
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      side: const BorderSide(
                                        color: Color(0xFFE0E0E0),
                                        width: 1.2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          30,
                                        ),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Sign Up Link - ✅ FIXED NAVIGATION
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'New here? ',
                                      style: TextStyle(
                                        color: Color(0xFF8A95A3),
                                        fontSize: 13,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        print("✅ TAPPED - Navigating to Signup"); // Debug
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => const SignupScreen(),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'Join SquatMate',
                                        style: TextStyle(
                                          color: Color(0xFF2ECC71),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
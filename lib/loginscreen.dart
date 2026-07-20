import 'package:dio/dio.dart';
<<<<<<< HEAD
import 'app_config.dart';
import 'dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
=======
import 'package:flt_kotlin_pose/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_constants.dart';
>>>>>>> main
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

<<<<<<< HEAD
  double _heroHeight = 200.0;
=======
  double _heroHeight = 280.0;

  // Brand colors
  static const Color primaryGreen = Color(0xFF2ECC71);
  static const Color textDark = Color(0xFF1A2332);
  static const Color textGray = Color(0xFF8A95A3);
  static const Color cardBg = Color(0xFFFFFFFF);
>>>>>>> main

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
<<<<<<< HEAD
    _heroHeight = (availableHeight * 0.30).clamp(140.0, 220.0);
=======
    _heroHeight = (availableHeight * 0.36).clamp(180.0, 340.0);
>>>>>>> main
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

<<<<<<< HEAD
=======
  // Save session data to SharedPreferences
>>>>>>> main
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
<<<<<<< HEAD
=======
    // Clear previous errors - resetting UI state
>>>>>>> main
    setState(() {
      _emailError = null;
      _passwordError = null;
      _isLoading = true;
    });

<<<<<<< HEAD
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
=======
    // Basic input validation
    if (_emailController.text.trim().isEmpty) {
      setState(() => _emailError = "Email is required");
      setState(() => _isLoading = false);
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _passwordError = "Password is required");
      setState(() => _isLoading = false);
      return;
    }

    // sending api req to backend
    try {
      final response = await Dio().post(
        'http://192.168.1.3:8000/auth/login',
        // 'http://YOUR_PC_IP:8000/auth/login', // Real Device
>>>>>>> main
        data: {
          "email": _emailController.text.trim(),
          "password": _passwordController.text,
        },
      );

<<<<<<< HEAD
=======
      // handling success response
>>>>>>> main
      if (response.statusCode == 200) {
        final data = response.data;
        await _saveSession(Map<String, dynamic>.from(data as Map));

        final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? {};
        final displayName = user['full_name']?.toString() ?? 'User';

        if (!mounted) return;

<<<<<<< HEAD
=======
        // Success
>>>>>>> main
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
<<<<<<< HEAD
    } on DioException catch (e) {
      String errorMsg = "Login failed";

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        errorMsg = "Cannot connect to server. Please check your connection.";
      } else if (e.response?.data is Map) {
        errorMsg = e.response?.data['detail'] ?? "Invalid credentials";
=======
      // handling errors
    } on DioException catch (e) {
      String errorMsg = "Login failed";

      if (e.response?.data is Map) {
        errorMsg = e.response?.data['detail'] ?? errorMsg;
>>>>>>> main
      } else if (e.message != null) {
        errorMsg = e.message!;
      }

<<<<<<< HEAD
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
=======
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) {
        return; //If this screen is no longer active, stop executing. to make sure user is there
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Something went wrong")));
>>>>>>> main
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
=======
    // FIX #4: Read the cached _heroHeight; no LayoutBuilder or MediaQuery here.
    final availableHeight =
        MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom -
        kToolbarHeight;

>>>>>>> main
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
<<<<<<< HEAD
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
                      // Hero Section
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
=======
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: availableHeight),
              child: Column(
                children: [
                  // FIX #6: RepaintBoundary isolates the hero image from form
                  // repaints. The image layer won't re-rasterize on each keystroke.
                  SizedBox(
                    height: _heroHeight,
                    width: double.infinity,
                    child: const RepaintBoundary(child: HeroSection()),
                  ),

                  SizedBox(
                    height: availableHeight - _heroHeight,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: kSpacingSm),

                              // Title
                              Flexible(
                                flex: 0,
                                child: RichText(
>>>>>>> main
                                  text: const TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Squat',
                                        style: TextStyle(
<<<<<<< HEAD
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1A2332),
=======
                                          fontSize: 30,
                                          fontWeight: FontWeight.w800,
                                          color: textDark,
>>>>>>> main
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'Mate',
                                        style: TextStyle(
<<<<<<< HEAD
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF2ECC71),
=======
                                          fontSize: 30,
                                          fontWeight: FontWeight.w800,
                                          color: primaryGreen,
>>>>>>> main
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
<<<<<<< HEAD
                                
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
                                
                                // Sign Up Link
                                Row(
=======
                              ),

                              const SizedBox(height: kSpacingXs),

                              const Flexible(
                                flex: 0,
                                child: Text(
                                  'Your AI squat coaching companion',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textGray,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ),

                              const SizedBox(height: kSpacingXl),

                              // Form fields
                              Flexible(
                                flex: 0,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    // FIX #1: onChanged now calls _onEmailChanged
                                    // which updates both the error AND _formValid
                                    // in a single setState.
                                    InputField(
                                      controller: _emailController,
                                      hint: 'Email',
                                      icon: Icons.mail_outline_rounded,
                                      keyboardType: TextInputType.emailAddress,
                                      errorText: _emailError,
                                      onChanged: _onEmailChanged,
                                    ),

                                    const SizedBox(height: kSpacingMd),

                                    InputField(
                                      controller: _passwordController,
                                      hint: 'Password',
                                      icon: Icons.lock_outline_rounded,
                                      obscureText: _obscurePassword,
                                      errorText: _passwordError,
                                      onChanged: _onPasswordChanged,
                                      suffixIcon: GestureDetector(
                                        onTap: () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                        child: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.remove_red_eye_outlined,
                                          color: textGray,
                                          size: 20,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: kSpacingSm),

                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () {},
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 0,
                                            vertical: 6,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text(
                                          'Forgot password?',
                                          style: TextStyle(
                                            color: primaryGreen,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: kSpacingMd),

                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _handleLogin,
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
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2.5,
                                                    ),
                                              )
                                            : const Text(
                                                'Log In',
                                                style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.35,
                                                ),
                                              ),
                                      ),
                                    ),

                                    const SizedBox(height: kSpacingLg),

                                    const OrDivider(),

                                    const SizedBox(height: kSpacingMd),

                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: OutlinedButton.icon(
                                        onPressed: () {},
                                        icon: const GoogleLogo(),
                                        label: const Text(
                                          'Continue with Google',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: textDark,
                                            letterSpacing: 0.1,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: cardBg,
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
                                  ],
                                ),
                              ),

                              const SizedBox(height: 15),

                              Flexible(
                                flex: 0,
                                child: Row(
>>>>>>> main
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'New here? ',
                                      style: TextStyle(
<<<<<<< HEAD
                                        color: Color(0xFF8A95A3),
=======
                                        color: textGray,
>>>>>>> main
                                        fontSize: 13,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
<<<<<<< HEAD
                                            builder: (context) => const SignupScreen(),
=======
                                            builder: (_) =>
                                                const SignupScreen(),
>>>>>>> main
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'Join SquatMate',
                                        style: TextStyle(
<<<<<<< HEAD
                                          color: Color(0xFF2ECC71),
                                          fontSize: 14,
=======
                                          color: primaryGreen,
                                          fontSize: 15,
>>>>>>> main
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
<<<<<<< HEAD
                                
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
=======
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
>>>>>>> main
          ),
        ),
      ),
    );
  }
<<<<<<< HEAD
}
=======
}
>>>>>>> main

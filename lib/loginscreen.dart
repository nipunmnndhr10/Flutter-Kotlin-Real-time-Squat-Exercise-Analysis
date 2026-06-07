import 'package:flutter/material.dart';
import 'app_constants.dart';
import 'pose_screen.dart';
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
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final emailErr = validateEmail(_emailController.text);
    final passErr = validatePassword(_passwordController.text);
    setState(() {
      _emailError = emailErr;
      _passwordError = passErr;
    });
    if (emailErr != null || passErr != null) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PoseScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final media = MediaQuery.of(context);
              final availableHeight = media.size.height -
                  media.padding.top -
                  media.padding.bottom -
                  kToolbarHeight;
              final heroHeight =
                  (availableHeight * 0.36).clamp(180.0, 340.0);

              return SingleChildScrollView(
                padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: availableHeight),
                  child: Column(
                    children: [
                      SizedBox(
                        height: heroHeight,
                        width: double.infinity,
                        child: const HeroSection(),
                      ),

                      SizedBox(
                        height: availableHeight - heroHeight,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 8, 24, 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  const SizedBox(height: kSpacingSm),
                                  Flexible(
                                    flex: 0,
                                    child: RichText(
                                      text: const TextSpan(
                                        children: [
                                          TextSpan(
                                            text: 'Squat',
                                            style: TextStyle(
                                              fontSize: 30,
                                              fontWeight: FontWeight.w800,
                                              color: textDark,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                          TextSpan(
                                            text: 'Mate',
                                            style: TextStyle(
                                              fontSize: 30,
                                              fontWeight: FontWeight.w800,
                                              color: primaryGreen,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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

                                  Flexible(
                                    flex: 0,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        InputField(
                                          controller: _emailController,
                                          hint: 'Email',
                                          icon: Icons.mail_outline_rounded,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          errorText: _emailError,
                                          onChanged: (v) => setState(() {
                                            _emailError = validateEmail(v);
                                          }),
                                        ),

                                        const SizedBox(height: kSpacingMd),

                                        InputField(
                                          controller: _passwordController,
                                          hint: 'Password',
                                          icon: Icons.lock_outline_rounded,
                                          obscureText: _obscurePassword,
                                          errorText: _passwordError,
                                          onChanged: (v) => setState(() {
                                            _passwordError =
                                                validatePassword(v);
                                          }),
                                          suffixIcon: GestureDetector(
                                            onTap: () => setState(() =>
                                                _obscurePassword =
                                                    !_obscurePassword),
                                            child: Icon(
                                              _obscurePassword
                                                  ? Icons
                                                      .visibility_off_outlined
                                                  : Icons
                                                      .remove_red_eye_outlined,
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 0,
                                                      vertical: 6),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize
                                                  .shrinkWrap,
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
                                            onPressed: (_isLoading ||
                                                    !isFormValid(
                                                      _emailController.text,
                                                      _passwordController.text,
                                                    ))
                                                ? null
                                                : _handleLogin,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color.fromRGBO(
                                                      17, 24, 32, 1),
                                              foregroundColor: Colors.white,
                                              disabledBackgroundColor:
                                                  const Color.fromRGBO(
                                                      209, 213, 219, 1),
                                              elevation: 0,
                                              shadowColor: Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(30),
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
                                                      fontWeight:
                                                          FontWeight.w800,
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
                                                  width: 1.2),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                              ),
                                              elevation: 0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: kSpacingLg),

                                  Flexible(
                                    flex: 0,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'New here? ',
                                          style: TextStyle(
                                            color: textGray,
                                            fontSize: 13,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const SignupScreen(),
                                              ),
                                            );
                                          },
                                          child: const Text(
                                            'Join SquatMate',
                                            style: TextStyle(
                                              color: primaryGreen,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
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
              );
            },
          ),
        ),
      ),
    );
  }
}
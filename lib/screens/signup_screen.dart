import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

const kPrimary     = Color(0xFF4CAF50);
const kSecondary   = Color(0xFF81C784);
const kBackground  = Color(0xFFF9F9F9);
const kSurface     = Color(0xFFE8F5E9);
const kTextPrimary = Color(0xFF1A1A1A);
const kTextMuted   = Color(0xFF757575);

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  int _currentIndex = 0;
  
  // ========== SIGNUP FORM CONTROLLERS ==========
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  // ========== STATIC DEMO DATA ==========
  final int totalSquats = 1250;
  final int topForm = 98;
  final List<int> weeklySquats = [4, 8, 6, 12, 10, 7, 9];

  // ========== VALIDATION METHODS ==========
  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your name';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!value.contains('@') || !value.contains('.')) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  // ========== 🔐 SIGNUP METHOD WITH NAVIGATION ==========
  Future<void> _handleSignup() async {
    // Validate all fields
    setState(() {
      _nameError = _validateName(_nameController.text);
      _emailError = _validateEmail(_emailController.text);
      _passwordError = _validatePassword(_passwordController.text);
      _confirmPasswordError = _validateConfirmPassword(_confirmPasswordController.text);
    });

    // If any validation fails, stop
    if (_nameError != null ||
        _emailError != null ||
        _passwordError != null ||
        _confirmPasswordError != null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get auth provider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Call real signup API
      final result = await authProvider.signup(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      if (result['success']) {
        // ✅ SUCCESS - Show message and navigate to login
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Please login.'),
            backgroundColor: kPrimary,
            duration: Duration(seconds: 2),
          ),
        );
        
        // ✅ Navigate to login screen with replacement
        //pushReplacement replaces the signup screen with login screen so the user can't go back to signup
        // with the back button.


        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        // ❌ Signup failed - show error
        setState(() {
          _isLoading = false;
          _emailError = result['error'] ?? 'Signup failed. Please try again.';
        });
      }
    } catch (e) {
      // ❌ Error occurred
      if (mounted) {
        setState(() {
          _isLoading = false;
          _emailError = 'Network error. Please check your connection.';
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Account',
          style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ========== SIGNUP FORM ==========
              _buildSignupForm(),
              
              const SizedBox(height: 24),
              
              // ========== SIGNUP BUTTON ==========
              _buildSignupButton(),
              
              const SizedBox(height: 16),
              
              // ========== LOGIN LINK ==========
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(color: kTextMuted, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: kPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // ========== COMMUNITY SECTION ==========
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Join SquatMate Community',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kTextPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Track your squats, improve your form, and achieve your fitness goals with AI-powered coaching.',
                style: TextStyle(fontSize: 13, color: kTextMuted),
              ),
              const SizedBox(height: 16),
              _StatRow(totalSquats: totalSquats, topForm: topForm),
              const SizedBox(height: 16),
              _RecommendedWorkoutSection(onPlay: _startWorkout),
            ],
          ),
        ),
      ),
    );
  }

  // ========== SIGNUP FORM WIDGET ==========
  Widget _buildSignupForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name Field
          const Text(
            'Full Name',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Enter your full name',
              hintStyle: const TextStyle(color: kTextMuted, fontSize: 14),
              prefixIcon: const Icon(Icons.person_outline, color: kTextMuted),
              errorText: _nameError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _nameError = _validateName(value);
              });
            },
          ),
          const SizedBox(height: 16),

          // Email Field
          const Text(
            'Email',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'Enter your email',
              hintStyle: const TextStyle(color: kTextMuted, fontSize: 14),
              prefixIcon: const Icon(Icons.email_outlined, color: kTextMuted),
              errorText: _emailError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _emailError = _validateEmail(value);
              });
            },
          ),
          const SizedBox(height: 16),

          // Password Field
          const Text(
            'Password',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'Enter your password (min 8 characters)',
              hintStyle: const TextStyle(color: kTextMuted, fontSize: 14),
              prefixIcon: const Icon(Icons.lock_outline, color: kTextMuted),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: kTextMuted,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              errorText: _passwordError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _passwordError = _validatePassword(value);
                if (_confirmPasswordController.text.isNotEmpty) {
                  _confirmPasswordError = _validateConfirmPassword(_confirmPasswordController.text);
                }
              });
            },
          ),
          const SizedBox(height: 16),

          // Confirm Password Field
          const Text(
            'Confirm Password',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              hintText: 'Confirm your password',
              hintStyle: const TextStyle(color: kTextMuted, fontSize: 14),
              prefixIcon: const Icon(Icons.lock_outline, color: kTextMuted),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: kTextMuted,
                ),
                onPressed: () {
                  setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                },
              ),
              errorText: _confirmPasswordError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _confirmPasswordError = _validateConfirmPassword(value);
              });
            },
          ),
        ],
      ),
    );
  }

  // ========== SIGNUP BUTTON WIDGET ==========
  Widget _buildSignupButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSignup,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  // ========== HELPER METHODS ==========
  void _startWorkout() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting workout…'),
        backgroundColor: kSecondary,
        duration: Duration(seconds: 1),
      ),
    );
  }
}

// ========== STAT WIDGETS ==========
class _StatRow extends StatelessWidget {
  final int totalSquats;
  final int topForm;
  const _StatRow({required this.totalSquats, required this.topForm});

  String _fmt(int n) {
    if (n >= 1000) {
      final s = n.toString();
      return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'Total Squats', value: _fmt(totalSquats))),
        const SizedBox(width: 14),
        Expanded(child: _StatCard(label: 'Top Form', value: '$topForm%', valueColor: kPrimary)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _StatCard({required this.label, required this.value, this.valueColor = kTextPrimary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: kTextMuted)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: valueColor)),
        ],
      ),
    );
  }
}

class _RecommendedWorkoutSection extends StatelessWidget {
  final VoidCallback onPlay;
  const _RecommendedWorkoutSection({required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recommended Workout',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kTextPrimary)),
        const SizedBox(height: 12),
        _WorkoutCard(title: 'Killer Leg Workout (Squats)', subtitle: '45 Min  •  Advanced', onPlay: onPlay),
      ],
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onPlay;
  const _WorkoutCard({required this.title, required this.subtitle, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: kTextMuted)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onPlay,
            child: Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(color: Color(0x1F4CAF50), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: kPrimary, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
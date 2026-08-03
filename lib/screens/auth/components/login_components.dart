import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Reusable hero illustration
class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/app_logo.png', height: 100, fit: BoxFit.contain);
  }
}

// Reusable input field
class InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextStyle? hintStyle;
  final TextStyle? style;

  static const Color inputBg = Color(0xFFF6F3F2);
  static const Color textDark = Color(0xFF1C1B1B);
  static const Color borderColor = Color(0xFF747A60);

  const InputField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.errorText,
    this.onChanged,
    this.hintStyle,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: style ?? GoogleFonts.inter(
              color: textDark,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: hintStyle ?? GoogleFonts.inter(
                color: textDark.withValues(alpha: 0.5),
                fontSize: 16,
              ),
              prefixIcon: Icon(
                icon,
                color: textDark.withValues(alpha: 0.5),
                size: 24,
              ),
              suffixIcon: suffixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: suffixIcon,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(
              errorText!,
              style: GoogleFonts.inter(
                color: const Color(0xFFBA1A1A),
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

// OR divider
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    const dividerColor = Color(0xFFE5E2E1);
    const mutedColor = Color(0xFF5D5E61);

    return Row(
      children: [
        const Expanded(child: Divider(color: dividerColor, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: GoogleFonts.jetBrainsMono(
              color: mutedColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const Expanded(child: Divider(color: dividerColor, thickness: 1)),
      ],
    );
  }
}

// Google logo
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/google logo.png',
      height: 24,
      width: 24,
      fit: BoxFit.contain,
    );
  }
}

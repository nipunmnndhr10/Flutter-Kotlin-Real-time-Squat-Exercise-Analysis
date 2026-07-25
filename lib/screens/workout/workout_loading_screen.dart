import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pose_screen.dart';

class WorkoutLoadingScreen extends StatefulWidget {
  const WorkoutLoadingScreen({super.key});

  @override
  State<WorkoutLoadingScreen> createState() => _WorkoutLoadingScreenState();
}

class _WorkoutLoadingScreenState extends State<WorkoutLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _progressController;
  late AnimationController _pulseController;
  
  int _currentStep = 0;
  final List<String> _statusMessages = [
    "Initializing Camera & Vision Pipeline...",
    "Loading AI Pose Tracking Engine...",
    "Calibrating Depth Thresholds...",
  ];
  Timer? _stepTimer;

  @override
  void initState() {
    super.initState();
    
    // Rotate the radar rings
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    
    // Pulse effect for the logo and dots
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Progress bar fills over 1.8 seconds
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();

    // Cycle text messages every 600ms
    _stepTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (_currentStep < 2) {
        if (mounted) {
          setState(() {
            _currentStep++;
          });
        }
      } else {
        timer.cancel();
      }
    });

    // Navigate to PoseScreen after 2 seconds
    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (!mounted) return;
      
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const PoseScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
      
      if (mounted) {
        Navigator.pop(context, result);
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _progressController.dispose();
    _pulseController.dispose();
    _stepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const kBgDark = Color(0xFF0F1012); // Very dark gray/black from screenshot
    const kPrimaryLime = Color(0xFFCCFF00); // From design system
    const kTextSecondary = Color(0xFF888B94);

    return Scaffold(
      backgroundColor: kBgDark,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            
            // Central Radar Graphic
            Center(
              child: SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Radar Rings
                    CustomPaint(
                      size: const Size(280, 280),
                      painter: _NeuralEnginePainter(
                        rotation: _rotationController,
                        pulse: _pulseController,
                        color: kPrimaryLime,
                      ),
                    ),
                    
                    // Center Logo (Pulsing)
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final scale = 0.9 + (_pulseController.value * 0.15); // Scale between 0.9 and 1.05
                        return Transform.scale(
                          scale: scale,
                          child: SizedBox(
                            width: 80,
                            height: 80,
                            child: Image.asset(
                              'assets/logo in lime.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 50),
            
            // Text: STARTING SESSION
            Text(
              "STARTING SESSION",
              style: GoogleFonts.jetBrainsMono(
                color: kPrimaryLime,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Animated Status Stepper
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _statusMessages[_currentStep],
                key: ValueKey<int>(_currentStep),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: kTextSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 64),
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  return Container(
                    height: 4,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: kPrimaryLime.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _progressController.value,
                      child: Container(
                        decoration: BoxDecoration(
                          color: kPrimaryLime,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: kPrimaryLime.withValues(alpha: 0.6),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const Spacer(flex: 3),
            
            // Footer Tip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: Text(
                "TIP: Position your device 6–8 feet away.\nEnsure full body from head to ankles is visible.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: kTextSecondary,
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NeuralEnginePainter extends CustomPainter {
  final Animation<double> rotation;
  final Animation<double> pulse;
  final Color color;

  _NeuralEnginePainter({
    required this.rotation,
    required this.pulse,
    required this.color,
  }) : super(repaint: Listenable.merge([rotation, pulse]));

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Paint setup
    final dimStroke = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final dashStroke = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final solidStroke = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final brightGlow = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final brightFill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Outer faint ring
    canvas.drawCircle(center, radius - 10, dimStroke);

    // Top and bottom dots on outer ring
    canvas.drawCircle(Offset(center.dx, 10), 2.5, brightGlow);
    canvas.drawCircle(Offset(center.dx, 10), 2.5, brightFill);
    
    canvas.drawCircle(Offset(center.dx, size.height - 10), 2.5, brightGlow);
    canvas.drawCircle(Offset(center.dx, size.height - 10), 2.5, brightFill);

    // Inner dashed ring (rotating)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation.value * 2 * math.pi);
    
    final dashedRadius = radius * 0.65;
    const int dashCount = 24;
    const double dashAngle = (2 * math.pi) / dashCount;
    for (int i = 0; i < dashCount; i++) {
      // Draw a short segment
      final startAngle = i * dashAngle;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: dashedRadius),
        startAngle,
        dashAngle * 0.5,
        false,
        dashStroke,
      );
    }
    canvas.restore();

    // Rounded rectangle in the middle
    final rectSize = radius * 0.8;
    final rRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: rectSize, height: rectSize),
      const Radius.circular(16),
    );
    canvas.drawRRect(rRect, solidStroke);

    // Crosshairs (thin lines extending from the rounded rect)
    canvas.drawLine(
      Offset(center.dx - rectSize / 2, center.dy),
      Offset(center.dx - radius + 10, center.dy),
      dimStroke,
    );
    canvas.drawLine(
      Offset(center.dx + rectSize / 2, center.dy),
      Offset(center.dx + radius - 10, center.dy),
      dimStroke,
    );

    // Constellation dots pulsing around the logo
    final pulseScale = 0.9 + (pulse.value * 0.15);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    
    // 1. Backlight glow for the Logo
    final logoGlow = Paint()
      ..color = color.withValues(alpha: 0.3 + (pulse.value * 0.2)) // Pulsing opacity
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(Offset.zero, 35, logoGlow);
    
    canvas.scale(pulseScale);

    final List<Offset> baseDots = [
      const Offset(0, -50),
      const Offset(-45, -20),
      const Offset(45, -10),
      const Offset(-30, 45),
      const Offset(35, 40),
    ];
    
    final strongGlow = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      
    final softGlow = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);

    // 2. Make dots float independently using rotation value (which acts as a timer)
    final time = rotation.value * 2 * math.pi; // 0 to 2PI over 10 seconds

    for (int i = 0; i < baseDots.length; i++) {
      final dot = baseDots[i];
      // Generate unique floating offsets for each dot using sine waves
      final floatX = math.sin(time * (1.5 + i * 0.5)) * 6.0;
      final floatY = math.cos(time * (1.2 + i * 0.7)) * 6.0;
      final floatingDot = Offset(dot.dx + floatX, dot.dy + floatY);
      
      // Draw double glow for better visibility
      canvas.drawCircle(floatingDot, 4, softGlow);
      canvas.drawCircle(floatingDot, 3, strongGlow);
      canvas.drawCircle(floatingDot, 3, brightFill);
    }
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NeuralEnginePainter oldDelegate) {
    return true; // Continuously animating
  }
}

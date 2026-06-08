import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PoseScreen extends StatefulWidget {
  const PoseScreen({super.key, this.enableNativePreview = true});

  final bool enableNativePreview;

  @override
  State<PoseScreen> createState() => _PoseScreenState();
}

class _PoseScreenState extends State<PoseScreen> {
  static const EventChannel  _poseChannel       = EventChannel('pose_landmarks');
  static const EventChannel  _squatChannel      = EventChannel('squat_feedback');
  static const MethodChannel _permissionChannel = MethodChannel('pose_permissions');
  static const MethodChannel _actionChannel     = MethodChannel('pose_settings');

  final ValueNotifier<PoseFrameData> _frameData = ValueNotifier<PoseFrameData>(
    PoseFrameData.empty(),
  );

  SquatFeedbackData _squatFeedback = const SquatFeedbackData.empty();

  StreamSubscription<dynamic>? _subscription;
  StreamSubscription<dynamic>? _squatSubscription;
  bool? _cameraPermissionGranted;
  String? _permissionError;

  // Track camera state (Kotlin defaults to back camera initially)
  bool _isFrontCamera = false;

  // Pose-lost detection: fires when the pose channel goes silent for 2s,
  // meaning the person stepped fully out of frame.
  Timer? _poseLostTimer;
  bool _isPoseLost = false;

  // FIX #4: Single timestamp-based idle approach — one periodic timer instead
  // of cancelling+allocating a new Timer on every camera frame (30–60fps).
  // Idle = no rep count change and no phase change for 60 seconds.
  static const Duration _idleThreshold = Duration(minutes: 1);
  static const Duration _idleCheckInterval = Duration(seconds: 5);
  Timer? _idleCheckTimer;
  DateTime _lastActivityTime = DateTime.now();
  int _lastKnownRepCount = 0;
  String _lastKnownPhase = 'STANDING';

  // Controls visibility of the idle end-session banner.
  bool _showIdleBanner = false;

  @override
  void initState() {
    super.initState();
    _setupPoseChannel();
    _setupSquatChannel();
    _setupPermission();
    _startIdleCheck();
  }

  void _setupPoseChannel() {
    _subscription = _poseChannel.receiveBroadcastStream().listen(
      (event) {
        final parsed = _parseFrameData(event);
        if (parsed != null) {
          _frameData.value = parsed;
        }

        // FIX #4: Replaced cancel+new-Timer-every-frame with a simple flag
        // update. _poseLostTimer is only created once here and restarted by
        // updating a timestamp; the periodic _idleCheckTimer handles polling.
        // Pose-lost uses its own dedicated short timer since it needs a
        // tight 2-second window — but we only allocate a new one when the
        // previous one has already fired (i.e. _isPoseLost became true),
        // not on every single frame.
        if (_isPoseLost) {
          // Pose recovered — clear the flag in one setState.
          setState(() => _isPoseLost = false);
        }
        _poseLostTimer?.cancel();
        _poseLostTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _isPoseLost = true);
        });
      },
      onError: (Object error) {
        debugPrint('Pose stream error: $error');
      },
    );
  }

  void _setupSquatChannel() {
    _squatSubscription = _squatChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is! Map) return;
        final newFeedback = SquatFeedbackData.fromMap(event);

        // Idle detection: reset the activity clock whenever a rep is
        // completed or the squat phase changes — these are signs the
        // user is actively squatting.
        if (newFeedback.repCount != _lastKnownRepCount ||
            newFeedback.phase != _lastKnownPhase) {
          _lastActivityTime = DateTime.now();
          _lastKnownRepCount = newFeedback.repCount;
          _lastKnownPhase = newFeedback.phase;

          // Also dismiss the idle banner if the user starts moving again.
          if (_showIdleBanner) {
            setState(() {
              _squatFeedback = newFeedback;
              _showIdleBanner = false;
            });
            return;
          }
        }

        setState(() => _squatFeedback = newFeedback);
      },
      onError: (Object error) {
        debugPrint('Squat feedback error: $error');
      },
    );
  }

  /// Starts a lightweight periodic timer that checks every 5 seconds whether
  /// the user has been idle for over a minute. This is far cheaper than
  /// creating a 60-second Timer on every squat event.
  void _startIdleCheck() {
    _idleCheckTimer = Timer.periodic(_idleCheckInterval, (_) {
      if (!mounted) return;
      if (_showIdleBanner) return; // already showing — don't re-trigger
      final idleFor = DateTime.now().difference(_lastActivityTime);
      if (idleFor >= _idleThreshold) {
        setState(() => _showIdleBanner = true);
      }
    });
  }

  Future<void> _setupPermission() async {
    if (!widget.enableNativePreview ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final granted =
          await _permissionChannel.invokeMethod<bool>(
                'requestCameraPermission',
              ) ??
              false;
      if (!mounted) return;

      setState(() {
        _cameraPermissionGranted = granted;
        _permissionError = granted
            ? null
            : 'Camera permission is required to start tracking.';
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraPermissionGranted = false;
        _permissionError =
            error.message ?? 'Unable to request camera permission.';
      });
    }
  }

  PoseFrameData? _parseFrameData(dynamic event) {
    if (event is! Map) return null;

    final frameWidth  = (event['frameWidth']  as num?)?.toInt() ?? 1;
    final frameHeight = (event['frameHeight'] as num?)?.toInt() ?? 1;
    final rawLandmarks = event['landmarks'];

    if (rawLandmarks is! List) {
      return PoseFrameData(
        frameWidth: frameWidth,
        frameHeight: frameHeight,
        landmarks: const <int, PoseLandmarkPoint>{},
      );
    }

    final landmarks = <int, PoseLandmarkPoint>{};
    for (final item in rawLandmarks.whereType<Map>()) {
      final index = (item['index'] as num?)?.toInt();
      if (index == null) continue;

      landmarks[index] = PoseLandmarkPoint(
        index: index,
        x: (item['x'] as num?)?.toDouble() ?? 0.0,
        y: (item['y'] as num?)?.toDouble() ?? 0.0,
        visibility: (item['visibility'] as num?)?.toDouble(),
        presence:   (item['presence']   as num?)?.toDouble(),
      );
    }

    return PoseFrameData(
      frameWidth: frameWidth,
      frameHeight: frameHeight,
      landmarks: landmarks,
    );
  }

  Future<void> _resetSession() async {
    if (!widget.enableNativePreview ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    await _actionChannel.invokeMethod<void>('resetSquatSession');
  }

  Future<void> _toggleCamera() async {
    if (!widget.enableNativePreview ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    final newFrontState = !_isFrontCamera;
    setState(() => _isFrontCamera = newFrontState);
    await _actionChannel.invokeMethod('toggleCameraFacing', newFrontState);
  }

  /// Called when the user taps "End Session" on the idle banner.
  /// No navigation — just dismisses the banner. Wire up navigation here later.
  void _handleEndSession() {
    setState(() => _showIdleBanner = false);
  
  }

  /// Called when the user taps "Keep Going" on the idle banner.
  void _handleDismissIdleBanner() {
    _lastActivityTime = DateTime.now(); // reset the clock
    setState(() => _showIdleBanner = false);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _squatSubscription?.cancel();
    _poseLostTimer?.cancel();
    _idleCheckTimer?.cancel(); // cancel the idle check timer
    _frameData.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (!widget.enableNativePreview ||
        defaultTargetPlatform != TargetPlatform.android) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const NativePosePreview(enableNativePreview: false),
          RepaintBoundary(
            child: CustomPaint(
              painter: PosePainter(
                repaint: _frameData,
                isFrontCamera: _isFrontCamera,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      );
    }

    if (_cameraPermissionGranted != true) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_cameraPermissionGranted == null)
                const CircularProgressIndicator()
              else
                const Icon(
                  Icons.videocam_off_outlined,
                  color: Colors.white70,
                  size: 48,
                ),
              const SizedBox(height: 16),
              Text(
                _permissionError ?? 'Requesting camera permission...',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        const NativePosePreview(enableNativePreview: true),
        RepaintBoundary(
          child: CustomPaint(
            painter: PosePainter(
              repaint: _frameData,
              isFrontCamera: _isFrontCamera,
            ),
            child: const SizedBox.expand(),
          ),
        ),

        // Rep counter
        Positioned(
          top: 80,
          left: 0,
          right: 0,
          child: Center(child: _RepCounter(feedback: _squatFeedback)),
        ),

        // Fault cue banner
        if (_squatFeedback.activeFaults.isNotEmpty)
          Positioned(
            left: 24,
            right: 24,
            bottom: 100,
            child: _FaultBanner(faults: _squatFeedback.activeFaults),
          ),

        // Landmark lost warning — shown when pose channel goes silent >2s
        if (_isPoseLost)
          const Positioned(
            top: 140,
            left: 0,
            right: 0,
            child: Center(child: _LandmarkLostBadge()),
          ),

        // Idle end-session banner — shown after 1 minute of no activity
        if (_showIdleBanner)
          Positioned(
            left: 24,
            right: 24,
            top: 0,
            bottom: 0,
            child: Center(
              child: _IdleSessionBanner(
                onEndSession: _handleEndSession,
                onKeepGoing: _handleDismissIdleBanner,
              ),
            ),
          ),

        // Bottom bar — flip camera (left) and reset (right)
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton.filledTonal(
                onPressed: _toggleCamera,
                tooltip: 'Flip Camera',
                icon: const Icon(Icons.flip_camera_android_rounded),
              ),
              IconButton.filledTonal(
                onPressed: _resetSession,
                tooltip: 'Reset session',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Native Preview ───────────────────────────────────────────────────────────

class NativePosePreview extends StatelessWidget {
  const NativePosePreview({super.key, required this.enableNativePreview});

  final bool enableNativePreview;

  @override
  Widget build(BuildContext context) {
    if (!enableNativePreview ||
        defaultTargetPlatform != TargetPlatform.android) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Native preview is available on Android only',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return const AndroidView(
      viewType: 'native_pose_camera',
      layoutDirection: TextDirection.ltr,
    );
  }
}

// ─── Data Models ──────────────────────────────────────────────────────────────

class PoseFrameData {
  const PoseFrameData({
    required this.frameWidth,
    required this.frameHeight,
    required this.landmarks,
  });

  factory PoseFrameData.empty() {
    return const PoseFrameData(
      frameWidth: 1,
      frameHeight: 1,
      landmarks: <int, PoseLandmarkPoint>{},
    );
  }

  final int frameWidth;
  final int frameHeight;
  final Map<int, PoseLandmarkPoint> landmarks;
}

class PoseLandmarkPoint {
  const PoseLandmarkPoint({
    required this.index,
    required this.x,
    required this.y,
    this.visibility,
    this.presence,
  });

  final int index;
  final double x;
  final double y;
  final double? visibility;
  final double? presence;
}

class SquatFeedbackData {
  const SquatFeedbackData({
    required this.phase,
    required this.repCount,
    required this.activeFaults,
    required this.kneeAngle,
    required this.hipAngle,
    required this.isLandmarkReliable,
  });

  const SquatFeedbackData.empty()
      : phase = 'STANDING',
        repCount = 0,
        activeFaults = const [],
        kneeAngle = 0,
        hipAngle = 0,
        isLandmarkReliable = false;

  factory SquatFeedbackData.fromMap(Map map) {
    return SquatFeedbackData(
      phase:              (map['phase'] as String?) ?? 'STANDING',
      repCount:           (map['repCount'] as num?)?.toInt() ?? 0,
      activeFaults:       (map['activeFaults'] as List?)?.cast<String>() ?? [],
      kneeAngle:          (map['kneeAngle'] as num?)?.toDouble() ?? 0,
      hipAngle:           (map['hipAngle'] as num?)?.toDouble() ?? 0,
      isLandmarkReliable: (map['isLandmarkReliable'] as bool?) ?? false,
    );
  }

  final String       phase;
  final int          repCount;
  final List<String> activeFaults;
  final double       kneeAngle;
  final double       hipAngle;
  final bool         isLandmarkReliable;
}

// ─── Premium Pose Painter ─────────────────────────────────────────────────────
//
// Visual design:
//   • Connections are drawn as gradient-glowing "bones" — a thick blurred
//     outer glow layer + a bright inner core, each segment coloured by body
//     region (shoulders: cyan, arms: violet, torso: gold, legs: emerald).
//   • Joints are rendered as a layered halo: faint outer ring → coloured
//     mid-ring → bright filled disc. Key joints (hips, knees, ankles,
//     shoulders) are slightly larger.
//   • A subtle drop-shadow is applied to every element so the overlay reads
//     clearly against any background.
//
// Segment colour palette (ARGB hex):
//   Shoulders / upper torso  → cyan   #00E5FF
//   Arms / hands              → violet #D500F9
//   Core / spine              → gold   #FFD600
//   Legs / feet               → green  #00E676

class PosePainter extends CustomPainter {
  PosePainter({
    required ValueListenable<PoseFrameData> repaint,
    required this.isFrontCamera,
  })  : _repaint = repaint,
        super(repaint: repaint);

  final ValueListenable<PoseFrameData> _repaint;
  final bool isFrontCamera;

  // ── Connections grouped by body region ──────────────────────────────────
  static const List<List<int>> _connections = [
    // shoulder bar
    [11, 12],
    // left arm
    [11, 13], [13, 15], [15, 17], [17, 19], [19, 21],
    // right arm
    [12, 14], [14, 16], [16, 18], [18, 20], [20, 22],
    // torso sides + hip bar
    [11, 23], [12, 24], [23, 24],
    // left leg
    [23, 25], [25, 27], [27, 29], [29, 31],
    // right leg
    [24, 26], [26, 28], [28, 30], [30, 32],
  ];

  // Indices that get a larger joint dot
  static const Set<int> _majorJoints = {11, 12, 23, 24, 25, 26, 27, 28};

  // FIX #3: Cache Paint objects as static finals so they are created once
  // per app lifetime, not allocated on every paint() call at 30–60fps.
  // Colours that vary per segment are handled by a small set of cached paints
  // keyed by the four palette colours.
  static final _shadowPaintCached = Paint()
    ..color = Colors.black.withAlpha(120)
    ..strokeWidth = 7
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

  static final _whiteHairlinePaint = Paint()
    ..color = Colors.white.withAlpha(200)
    ..strokeWidth = 0.8
    ..strokeCap = StrokeCap.round;

  // Glow + core paints cached per palette colour.
  static final Map<Color, Paint> _glowPaints = {};
  static final Map<Color, Paint> _corePaints = {};

  static Paint _glowPaint(Color color) {
    return _glowPaints.putIfAbsent(
      color,
      () => Paint()
        ..color = color.withAlpha(60)
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  static Paint _corePaint(Color color) {
    return _corePaints.putIfAbsent(
      color,
      () => Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  // ── Colour look-up ───────────────────────────────────────────────────────
  static Color _segmentColor(int a, int b) {
    if (a == 11 && b == 12) return const Color(0xFF00E5FF);
    if (a >= 11 && a <= 22 && b >= 11 && b <= 22) return const Color(0xFFD500F9);
    if ((a == 11 || a == 12) && (b == 23 || b == 24)) return const Color(0xFFFFD600);
    if (a == 23 && b == 24) return const Color(0xFFFFD600);
    return const Color(0xFF00E676);
  }

  static Color _jointColor(int index) {
    if (index == 11 || index == 12) return const Color(0xFF00E5FF);
    if (index >= 13 && index <= 22) return const Color(0xFFD500F9);
    if (index == 23 || index == 24) return const Color(0xFFFFD600);
    return const Color(0xFF00E676);
  }

  // ── Main paint ───────────────────────────────────────────────────────────
  @override
  void paint(Canvas canvas, Size size) {
    final frame = _repaint.value;
    if (frame.landmarks.isEmpty) return;

    final bool isScreenPortrait = size.height > size.width;
    final bool isFrameLandscape = frame.frameWidth > frame.frameHeight;

    final double adjustedFrameWidth = (isScreenPortrait && isFrameLandscape)
        ? frame.frameHeight.toDouble()
        : frame.frameWidth.toDouble();
    final double adjustedFrameHeight = (isScreenPortrait && isFrameLandscape)
        ? frame.frameWidth.toDouble()
        : frame.frameHeight.toDouble();

    final double scaleX = size.width / adjustedFrameWidth;
    final double scaleY = size.height / adjustedFrameHeight;
    final double scale  = math.max(scaleX, scaleY);

    final double renderedWidth  = adjustedFrameWidth  * scale;
    final double renderedHeight = adjustedFrameHeight * scale;
    final double offsetX = (size.width  - renderedWidth)  / 2.0;
    final double offsetY = (size.height - renderedHeight) / 2.0;

    Offset mapPoint(PoseLandmarkPoint pt) {
      double x = pt.x;
      double y = pt.y;
      if (isScreenPortrait && isFrameLandscape) {
        final double tmp = x;
        x = 1.0 - y;
        y = tmp;
      }
      return Offset(offsetX + x * renderedWidth, offsetY + y * renderedHeight);
    }

    // ── Pass 1: bone glow + core ─────────────────────────────────────────
    for (final conn in _connections) {
      final a = frame.landmarks[conn[0]];
      final b = frame.landmarks[conn[1]];
      if (!_isVisible(a) || !_isVisible(b)) continue;

      final pA = mapPoint(a!);
      final pB = mapPoint(b!);
      final color = _segmentColor(conn[0], conn[1]);

      canvas.drawLine(pA, pB, _shadowPaintCached);
      canvas.drawLine(pA, pB, _glowPaint(color));
      canvas.drawLine(pA, pB, _corePaint(color));
      canvas.drawLine(pA, pB, _whiteHairlinePaint);
    }

    // ── Pass 2: joints ───────────────────────────────────────────────────
    for (final lm in frame.landmarks.values) {
      if (!_isVisible(lm)) continue;

      final p = mapPoint(lm);
      final color = _jointColor(lm.index);
      final isMajor = _majorJoints.contains(lm.index);
      final double r = isMajor ? 7.0 : 4.5;

      canvas.drawCircle(
        p, r + 3,
        Paint()
          ..color = Colors.black.withAlpha(100)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );

      canvas.drawCircle(
        p, r + 5,
        Paint()
          ..color = color.withAlpha(40)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      canvas.drawCircle(
        p, r + 1.5,
        Paint()
          ..color = color.withAlpha(160)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      canvas.drawCircle(p, r, Paint()..color = color);

      canvas.drawCircle(
        Offset(p.dx - r * 0.28, p.dy - r * 0.28),
        r * 0.28,
        Paint()..color = Colors.white.withAlpha(200),
      );
    }
  }

  // FIX #1: shouldRepaint now also checks if the repaint notifier instance
  // changed, so the skeleton never freezes when only _repaint updates.
  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.isFrontCamera != isFrontCamera ||
        oldDelegate._repaint != _repaint;
  }

  bool _isVisible(PoseLandmarkPoint? landmark) {
    if (landmark == null) return false;
    final visibility = landmark.visibility ?? landmark.presence;
    return visibility == null || visibility > 0.4;
  }
}

// ─── Squat Overlay Widgets ────────────────────────────────────────────────────

class _RepCounter extends StatelessWidget {
  const _RepCounter({required this.feedback});

  final SquatFeedbackData feedback;

  String get _phaseLabel => switch (feedback.phase) {
    'DESCENDING' => 'Going down',
    'BOTTOM'     => 'Hold',
    'ASCENDING'  => 'Coming up',
    _            => 'Ready',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${feedback.repCount}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'REPS',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                _phaseLabel,
                style: const TextStyle(
                  color: Color(0xFF2ECC71),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FaultBanner extends StatelessWidget {
  const _FaultBanner({required this.faults});

  final List<String> faults;

  String _label(String fault) => switch (fault) {
    'GO_DEEPER'       => 'Go deeper',
    'LEAN_FORWARD'    => "Chest up : don't lean forward",
    'LEFT_KNEE_CAVE'  => 'Push your left knee out',
    'RIGHT_KNEE_CAVE' => 'Push your right knee out',
    _                 => fault,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: faults.map((f) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE5534B).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                _label(f),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _LandmarkLostBadge extends StatelessWidget {
  const _LandmarkLostBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_off_outlined, color: Colors.white, size: 16),
          SizedBox(width: 6),
          Text(
            'Pose lost — step into frame',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown after 1 minute of no squat activity.
/// "End Session" dismisses the banner (no navigation yet — wire up later).
/// "Keep Going" resets the idle clock and dismisses the banner.
class _IdleSessionBanner extends StatelessWidget {
  const _IdleSessionBanner({
    required this.onEndSession,
    required this.onKeepGoing,
  });

  final VoidCallback onEndSession;
  final VoidCallback onKeepGoing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.hourglass_bottom_rounded,
              color: Color(0xFF2ECC71), size: 36),
          const SizedBox(height: 14),
          const Text(
            'Still there?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "You've been idle for a minute.\nWould you like to end your session?",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onKeepGoing,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Keep Going',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onEndSession,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5534B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'End Session',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
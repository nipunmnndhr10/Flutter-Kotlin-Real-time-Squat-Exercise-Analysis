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

  // Pose-lost detection: Kotlin emits nothing when landmarks are unreliable,
  // so we track silence on the squat channel with a timer.
  Timer? _poseLostTimer;
  bool _isPoseLost = false;

  @override
  void initState() {
    super.initState();
    _setupPoseChannel();
    _setupSquatChannel();
    _setupPermission();
  }

  void _setupPoseChannel() {
    _subscription = _poseChannel.receiveBroadcastStream().listen(
      (event) {
        final parsed = _parseFrameData(event);
        if (parsed != null) {
          _frameData.value = parsed;
        }
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
        _poseLostTimer?.cancel();
        _poseLostTimer = Timer(const Duration(seconds: 1), () {
          if (mounted) setState(() => _isPoseLost = true);
        });
        setState(() {
          _squatFeedback = SquatFeedbackData.fromMap(event);
          _isPoseLost = false;
        });
      },
      onError: (Object error) {
        debugPrint('Squat feedback error: $error');
      },
    );
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

  @override
  void dispose() {
    _subscription?.cancel();
    _squatSubscription?.cancel();
    _poseLostTimer?.cancel();
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
        // Landmark lost warning — shown when squat channel goes silent >1s
        if (_isPoseLost)
          const Positioned(
            top: 140,
            left: 0,
            right: 0,
            child: Center(child: _LandmarkLostBadge()),
          ),
        // Bottom bar — single row with flip camera (left) and reset (right)
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

// Native preview widget: Displays the camera feed using platform view on Android, or a placeholder on unsupported platforms.

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

// Data Models for pose frame and squat feedback

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

// Pose Painter: Draws pose landmarks and connections on canvas

class PosePainter extends CustomPainter {
  PosePainter({
    required ValueListenable<PoseFrameData> repaint,
    required this.isFrontCamera,
  })  : _repaint = repaint,
        super(repaint: repaint);

  final ValueListenable<PoseFrameData> _repaint;
  final bool isFrontCamera;

  static const List<List<int>> _connections = [
    [11, 12], [11, 13], [13, 15], [15, 17], [17, 19], [19, 21],
    [12, 14], [14, 16], [16, 18], [18, 20], [20, 22],
    [11, 23], [12, 24], [23, 24],
    [23, 25], [25, 27], [27, 29], [29, 31],
    [24, 26], [26, 28], [28, 30], [30, 32],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final frame = _repaint.value;
    if (frame.landmarks.isEmpty) return;

    // Detect if native frame orientation (typically landscape from sensor) mismatch with screen
    final bool isScreenPortrait = size.height > size.width;
    final bool isFrameLandscape = frame.frameWidth > frame.frameHeight;

    // Swap aspect calculations if coordinates arrive side-oriented
    final double adjustedFrameWidth = (isScreenPortrait && isFrameLandscape)
        ? frame.frameHeight.toDouble()
        : frame.frameWidth.toDouble();
    final double adjustedFrameHeight = (isScreenPortrait && isFrameLandscape)
        ? frame.frameWidth.toDouble()
        : frame.frameHeight.toDouble();

    final scaleX = size.width / adjustedFrameWidth;
    final scaleY = size.height / adjustedFrameHeight;
    final scale = math.max(scaleX, scaleY); // Fill Center boundary map

    final renderedWidth  = adjustedFrameWidth  * scale;
    final renderedHeight = adjustedFrameHeight * scale;
    final offsetX = (size.width  - renderedWidth)  / 2.0;
    final offsetY = (size.height - renderedHeight) / 2.0;

    Offset mapPoint(PoseLandmarkPoint point) {
      double x = point.x;
      double y = point.y;

      // Translate 90 degrees clockwise if framework raw frame buffer orientation differs
      if (isScreenPortrait && isFrameLandscape) {
        final double temp = x;
        x = 1.0 - y;
        y = temp;
      }

      // Front-Facing Camera Mirror Fix: Flips horizontal positioning accurately
      if (isFrontCamera) {
        x = 1.0 - x;
      }

      return Offset(
        offsetX + x * renderedWidth,
        offsetY + y * renderedHeight,
      );
    }

    final pointPaint = Paint()
      ..color = const Color(0xFFFF5D5D)
      ..strokeWidth = 5
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = const Color(0xFF7FF0B0)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (final connection in _connections) {
      final first  = frame.landmarks[connection[0]];
      final second = frame.landmarks[connection[1]];
      if (_isVisible(first) && _isVisible(second)) {
        canvas.drawLine(mapPoint(first!), mapPoint(second!), linePaint);
      }
    }

    for (final landmark in frame.landmarks.values) {
      if (_isVisible(landmark)) {
        canvas.drawCircle(mapPoint(landmark), 4, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.isFrontCamera != isFrontCamera;
  }

  bool _isVisible(PoseLandmarkPoint? landmark) {
    if (landmark == null) return false;
    final visibility = landmark.visibility ?? landmark.presence;
    return visibility == null || visibility > 0.4;
  }
}

/// Squat overlay widgets

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
    'LEAN_FORWARD'    => "Chest up — don't lean forward",
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
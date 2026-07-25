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
  static const EventChannel _poseChannel = EventChannel('pose_landmarks');
  static const EventChannel _squatChannel = EventChannel('squat_feedback');
  static const MethodChannel _permissionChannel = MethodChannel(
    'pose_permissions',
  );
  static const MethodChannel _actionChannel = MethodChannel('pose_settings');
  static const String _workoutType = 'squat';

  final ValueNotifier<PoseFrameData> _frameData = ValueNotifier<PoseFrameData>(
    PoseFrameData.empty(),
  );

  final ValueNotifier<SquatFeedbackData> _squatFeedback =
      ValueNotifier<SquatFeedbackData>(const SquatFeedbackData.empty());

  StreamSubscription<dynamic>? _subscription;
  StreamSubscription<dynamic>? _squatSubscription;
  bool? _cameraPermissionGranted;
  String? _permissionError;

  // Track camera state (Kotlin defaults to back camera initially)
  bool _isFrontCamera = false;

  // Pose-lost detection: fires when the pose channel goes silent for 2s
  Timer? _poseLostTimer;
  final ValueNotifier<bool> _isPoseLost = ValueNotifier<bool>(false);

  // Idle detection — tracks actual landmark movement, not just rep/phase changes.
  // When zero movement is detected for 1 minute, show the "Are you there?" banner.
  // If the user doesn't respond within another 1 minute, auto-end the session.
  static const Duration _idleThreshold = Duration(minutes: 1);
  static const Duration _autoEndTimeout = Duration(minutes: 1);
  static const Duration _idleCheckInterval = Duration(seconds: 5);
  Timer? _idleCheckTimer;
  Timer? _autoEndTimer;
  DateTime _lastMovementTime = DateTime.now();
  int _lastKnownRepCount = 0;
  String _lastKnownPhase = 'STANDING';
  bool _showIdleBanner = false;

  // Landmark movement tracking — compare hip position across frames.
  // A movement threshold of 0.005 (0.5% of normalised frame) filters out
  // MediaPipe jitter while still detecting any real body motion.
  double? _prevHipX;
  double? _prevHipY;
  static const double _movementThreshold = 0.005;

  // Workout summary payload assembled during the session.
  final Map<String, int> _faultSummaryCounts = <String, int>{};
  final Set<String> _faultsThisRep = <String>{};
  int _currentRepForFaults = 0;
  bool _isWorkoutPaused = false;
  late final DateTime _workoutStartedAt;

  @override
  void initState() {
    super.initState();
    _workoutStartedAt = DateTime.now().toUtc();
    _setupPoseChannel();
    _setupSquatChannel();
    _setupPermission();
    _resetNativeSessionState();
    _startIdleCheck();
  }

  Future<void> _resetNativeSessionState() async {
    if (!widget.enableNativePreview ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    await _actionChannel.invokeMethod<void>('resetSquatSession');
  }

  // Channel setup

  void _setupPoseChannel() {
    _subscription = _poseChannel.receiveBroadcastStream().listen((event) {
      if (_isWorkoutPaused) return;
      final parsed = _parseFrameData(event);
      if (parsed == null) return;

      _frameData.value = parsed;
      final hasLandmarks = parsed.landmarks.isNotEmpty;

      if (!hasLandmarks) {
        _poseLostTimer?.cancel();
        if (!_isPoseLost.value && mounted) {
          _isPoseLost.value = true;
        }
        return;
      }

      if (_isPoseLost.value && mounted) {
        _isPoseLost.value = false;
      }
      _poseLostTimer?.cancel();
      _poseLostTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) _isPoseLost.value = true;
      });

      // Track actual landmark movement for idle detection.
      // Use the hip landmark (index 23 or 24) as a proxy for body movement.
      // Any displacement above the threshold resets the idle timer.
      _checkLandmarkMovement(parsed);
    }, onError: (Object error) => debugPrint('Pose stream error: $error'));
  }

  /// Checks if the user's body has actually moved by comparing the current
  /// hip position to the previous frame. Resets the idle timer on movement.
  void _checkLandmarkMovement(PoseFrameData frame) {
    // Try left hip (23), fall back to right hip (24)
    final hip = frame.landmarks[23] ?? frame.landmarks[24];
    if (hip == null) return;

    final prevX = _prevHipX;
    final prevY = _prevHipY;
    _prevHipX = hip.x;
    _prevHipY = hip.y;

    if (prevX == null || prevY == null) return;

    final dx = (hip.x - prevX).abs();
    final dy = (hip.y - prevY).abs();

    if (dx > _movementThreshold || dy > _movementThreshold) {
      _lastMovementTime = DateTime.now();
    }
  }

  void _setupSquatChannel() {
    _squatSubscription = _squatChannel.receiveBroadcastStream().listen((event) {
      if (_isWorkoutPaused) return;
      if (event is! Map) return;
      final newFeedback = SquatFeedbackData.fromMap(event);

      _recordFaultSummary(newFeedback.repCount, newFeedback.activeFaults);

      if (newFeedback.repCount != _lastKnownRepCount ||
          newFeedback.phase != _lastKnownPhase) {
        // Rep or phase change counts as movement too
        _lastMovementTime = DateTime.now();
        _lastKnownRepCount = newFeedback.repCount;
        _lastKnownPhase = newFeedback.phase;

        if (_showIdleBanner) {
          _cancelAutoEndTimer();
          _squatFeedback.value = newFeedback;
          setState(() => _showIdleBanner = false);
          return;
        }
      }

      // No setState() — only the ValueListenableBuilder widgets rebuild.
      _squatFeedback.value = newFeedback;
    }, onError: (Object error) => debugPrint('Squat feedback error: $error'));
  }

  void _recordFaultSummary(int repCount, List<String> faults) {
    if (repCount != _currentRepForFaults) {
      _currentRepForFaults = repCount;
      _faultsThisRep.clear();
    }
    for (final fault in faults) {
      if (_faultsThisRep.add(fault)) {
        _faultSummaryCounts[fault] = (_faultSummaryCounts[fault] ?? 0) + 1;
      }
    }
  }

  void _pauseWorkoutSessionTracking() {
    if (_isWorkoutPaused) return;
    _isWorkoutPaused = true;
    _poseLostTimer?.cancel();
    _idleCheckTimer?.cancel();
    _cancelAutoEndTimer();
    _subscription?.pause();
    _squatSubscription?.pause();
    if (widget.enableNativePreview &&
        defaultTargetPlatform == TargetPlatform.android) {
      _actionChannel.invokeMethod<void>('pauseSquatSession');
    }
  }

  void _resumeWorkoutSessionTracking() {
    if (!_isWorkoutPaused) return;
    _isWorkoutPaused = false;
    _startIdleCheck();
    _subscription?.resume();
    _squatSubscription?.resume();
    if (widget.enableNativePreview &&
        defaultTargetPlatform == TargetPlatform.android) {
      _actionChannel.invokeMethod<void>('resumeSquatSession');
    }
  }

  void _startIdleCheck() {
    _idleCheckTimer?.cancel();
    _idleCheckTimer = Timer.periodic(_idleCheckInterval, (_) {
      if (!mounted || _showIdleBanner) return;
      if (DateTime.now().difference(_lastMovementTime) >= _idleThreshold) {
        setState(() => _showIdleBanner = true);
        _startAutoEndTimer();
      }
    });
  }

  /// Starts a 1-minute countdown. If the user doesn't respond to the idle
  /// banner within this time, the session ends automatically.
  void _startAutoEndTimer() {
    _cancelAutoEndTimer();
    _autoEndTimer = Timer(_autoEndTimeout, () {
      if (!mounted) return;
      _autoEndSession();
    });
  }

  void _cancelAutoEndTimer() {
    _autoEndTimer?.cancel();
    _autoEndTimer = null;
  }

  /// Auto-ends the session when the user fails to respond to the idle banner.
  /// Bypasses the confirmation dialog — the banner itself served as the warning.
  Future<void> _autoEndSession() async {
    if (!mounted) return;
    _cancelAutoEndTimer();
    _idleCheckTimer?.cancel();

    Map<Object?, Object?>? summaryMap;
    if (widget.enableNativePreview &&
        defaultTargetPlatform == TargetPlatform.android) {
      summaryMap = await _actionChannel.invokeMapMethod<String, dynamic>(
        'endWorkoutSession',
      );
      await _actionChannel.invokeMethod<void>('resetSquatSession');
    }
    if (!mounted) return;

    final mergedSummary = _buildWorkoutSummary(summaryMap);
    Navigator.of(context).pop(mergedSummary);
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

  // Actions

  Future<void> _resetSession() async {
    if (!widget.enableNativePreview ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    await _actionChannel.invokeMethod<void>('resetSquatSession');
    if (!mounted) return;
    _squatFeedback.value = const SquatFeedbackData.empty();
    _faultSummaryCounts.clear();
    _faultsThisRep.clear();
    _currentRepForFaults = 0;
    _lastKnownRepCount = 0;
    _lastKnownPhase = 'STANDING';
    _lastMovementTime = DateTime.now();
    _cancelAutoEndTimer();
    setState(() => _showIdleBanner = false);
  }

  Future<void> _promptEndWorkoutSession() async {
    _pauseWorkoutSessionTracking();

    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit workout?'),
        content: const Text(
          'Are you sure you want to end this workout session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Yes, exit'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (shouldExit != true) {
      _resumeWorkoutSessionTracking();
      return;
    }

    Map<Object?, Object?>? summaryMap;
    if (widget.enableNativePreview &&
        defaultTargetPlatform == TargetPlatform.android) {
      summaryMap = await _actionChannel.invokeMapMethod<String, dynamic>(
        'endWorkoutSession',
      );
      await _actionChannel.invokeMethod<void>('resetSquatSession');
    }
    if (!mounted) return;

    final mergedSummary = _buildWorkoutSummary(summaryMap);

    Navigator.of(context).pop(mergedSummary);
  }

  Map<String, dynamic> _buildWorkoutSummary(Map<Object?, Object?>? summaryMap) {
    final workoutEndedAt = DateTime.now().toUtc();
    return <String, dynamic>{
      if (summaryMap != null)
        ...summaryMap.map((key, value) => MapEntry(key.toString(), value)),
      'id': null,
      'workoutType': _workoutType,
      'startedAt': _workoutStartedAt.toIso8601String(),
      'endedAt': workoutEndedAt.toIso8601String(),
      'targetAngleThreshold': _squatFeedback.value.angleThreshold,
      'camera': _isFrontCamera ? 'front' : 'back',
      'faultSummaryJson': Map<String, int>.from(_faultSummaryCounts),
    };
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

  /// User chose "End Session" from the idle banner — end immediately.
  void _handleEndSession() {
    _cancelAutoEndTimer();
    setState(() => _showIdleBanner = false);
    _autoEndSession();
  }

  /// User chose "Keep Going" — dismiss the banner, reset idle timer.
  void _handleDismissIdleBanner() {
    _cancelAutoEndTimer();
    _lastMovementTime = DateTime.now();
    setState(() => _showIdleBanner = false);
  }

  // Frame parsing

  PoseFrameData? _parseFrameData(dynamic event) {
    if (event is! Map) return null;

    final frameWidth = (event['frameWidth'] as num?)?.toInt() ?? 1;
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
        presence: (item['presence'] as num?)?.toDouble(),
      );
    }

    return PoseFrameData(
      frameWidth: frameWidth,
      frameHeight: frameHeight,
      landmarks: landmarks,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _squatSubscription?.cancel();
    _poseLostTimer?.cancel();
    _idleCheckTimer?.cancel();
    _autoEndTimer?.cancel();
    _frameData.dispose();
    _squatFeedback.dispose();
    _isPoseLost.dispose();
    super.dispose();
  }

  // Build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _promptEndWorkoutSession();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    // Non-Android / preview-disabled path
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
          _buildOverlay(),
        ],
      );
    }

    // Permission pending / denied
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

    // Full live view
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
        _buildOverlay(),
      ],
    );
  }

  /// All HUD elements layered on top of the camera — extracted so both
  /// the preview path and the live path share identical overlays.
  Widget _buildOverlay() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Rep counter — rebuilds only when squat feedback changes
        Positioned(
          top: 80,
          left: 0,
          right: 0,
          child: Center(
            child: ValueListenableBuilder<SquatFeedbackData>(
              valueListenable: _squatFeedback,
              builder: (_, feedback, _) => _RepCounter(feedback: feedback),
            ),
          ),
        ),

        // Fault cue banner — rebuilds only when squat feedback changes
        Positioned(
          left: 24,
          right: 24,
          bottom: 140,
          child: ValueListenableBuilder<SquatFeedbackData>(
            valueListenable: _squatFeedback,
            builder: (_, feedback, _) {
              if (feedback.activeFaults.isEmpty) return const SizedBox.shrink();
              return _FaultBanner(faults: feedback.activeFaults);
            },
          ),
        ),

        // Landmark lost warning — rebuilds only when pose-lost flag changes
        Positioned(
          top: 140,
          left: 0,
          right: 0,
          child: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: _isPoseLost,
              builder: (_, lost, _) {
                if (!lost) return const SizedBox.shrink();
                return const _LandmarkLostBadge();
              },
            ),
          ),
        ),

        // Idle end-session banner
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
                autoEndTimeout: _autoEndTimeout,
              ),
            ),
          ),

        // Bottom controls: preset dropdown + flip/reset buttons
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _TargetDepthBadge(),
              const SizedBox(height: 10),
              Row(
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
                  IconButton.filledTonal(
                    onPressed: _promptEndWorkoutSession,
                    tooltip: 'End workout',
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Native Preview

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
    // TextureAndroidView uses Texture Layer compositing instead of Virtual
    // Display, significantly reducing latency for real-time camera feeds.
    return const AndroidView(
      viewType: 'native_pose_camera',
      layoutDirection: TextDirection.ltr,
      creationParamsCodec: StandardMessageCodec(),
    );
  }
}

// Data Models

class PoseFrameData {
  const PoseFrameData({
    required this.frameWidth,
    required this.frameHeight,
    required this.landmarks,
  });

  factory PoseFrameData.empty() => const PoseFrameData(
    frameWidth: 1,
    frameHeight: 1,
    landmarks: <int, PoseLandmarkPoint>{},
  );

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
    this.activePreset = 'FULL_SQUAT',
    this.angleThreshold = 90.0,
    this.presetLabel = 'Full Strength (Full Squat)',
  });

  const SquatFeedbackData.empty()
    : phase = 'STANDING',
      repCount = 0,
      activeFaults = const [],
      kneeAngle = 0,
      hipAngle = 0,
      isLandmarkReliable = false,
      activePreset = 'FULL_SQUAT',
      angleThreshold = 90.0,
      presetLabel = 'Full Strength (Full Squat)';

  factory SquatFeedbackData.fromMap(Map map) => SquatFeedbackData(
    phase: (map['phase'] as String?) ?? 'STANDING',
    repCount: (map['repCount'] as num?)?.toInt() ?? 0,
    activeFaults: (map['activeFaults'] as List?)?.cast<String>() ?? [],
    kneeAngle: (map['kneeAngle'] as num?)?.toDouble() ?? 0,
    hipAngle: (map['hipAngle'] as num?)?.toDouble() ?? 0,
    isLandmarkReliable: (map['isLandmarkReliable'] as bool?) ?? false,
    activePreset: (map['activePreset'] as String?) ?? 'FULL_SQUAT',
    angleThreshold: (map['angleThreshold'] as num?)?.toDouble() ?? 90.0,
    presetLabel:
        (map['presetLabel'] as String?) ?? 'Full Strength (Full Squat)',
  );

  final String phase;
  final int repCount;
  final List<String> activeFaults;
  final double kneeAngle;
  final double hipAngle;
  final bool isLandmarkReliable;
  final String activePreset;
  final double angleThreshold;
  final String presetLabel;
}

// Pose Painter

class PosePainter extends CustomPainter {
  PosePainter({
    required ValueListenable<PoseFrameData> repaint,
    required this.isFrontCamera,
  }) : _repaint = repaint,
       super(repaint: repaint);

  final ValueListenable<PoseFrameData> _repaint;
  final bool isFrontCamera;

  static const List<List<int>> _connections = [
    [11, 12],
    [11, 13],
    [13, 15],
    [15, 17],
    [17, 19],
    [19, 21],
    [12, 14],
    [14, 16],
    [16, 18],
    [18, 20],
    [20, 22],
    [11, 23],
    [12, 24],
    [23, 24],
    [23, 25],
    [25, 27],
    [27, 29],
    [29, 31],
    [24, 26],
    [26, 28],
    [28, 30],
    [30, 32],
  ];

  static const Set<int> _majorJoints = {11, 12, 23, 24, 25, 26, 27, 28};

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

  static final Map<Color, Paint> _glowPaints = {};
  static final Map<Color, Paint> _corePaints = {};

  static Paint _glowPaint(Color color) => _glowPaints.putIfAbsent(
    color,
    () => Paint()
      ..color = color.withAlpha(60)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
  );

  static Paint _corePaint(Color color) => _corePaints.putIfAbsent(
    color,
    () => Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke,
  );

  // Cached Paint objects for joint rendering — eliminates ~150 allocations/frame
  static final _jointShadowPaint = Paint()
    ..color = Colors.black.withAlpha(100)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

  static final Map<Color, Paint> _jointGlowPaints = {};
  static Paint _jointGlowPaint(Color color) => _jointGlowPaints.putIfAbsent(
    color,
    () => Paint()
      ..color = color.withAlpha(40)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );

  static final Map<Color, Paint> _jointRingPaints = {};
  static Paint _jointRingPaint(Color color) => _jointRingPaints.putIfAbsent(
    color,
    () => Paint()
      ..color = color.withAlpha(160)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );

  static final Map<Color, Paint> _jointFillPaints = {};
  static Paint _jointFillPaint(Color color) =>
      _jointFillPaints.putIfAbsent(color, () => Paint()..color = color);

  static final _jointHighlightPaint = Paint()
    ..color = Colors.white.withAlpha(200);

  static Color _segmentColor(int a, int b) {
    if (a == 11 && b == 12) return const Color(0xFF00E5FF);
    if (a >= 11 && a <= 22 && b >= 11 && b <= 22) {
      return const Color(0xFFD500F9);
    }
    if ((a == 11 || a == 12) && (b == 23 || b == 24)) {
      return const Color(0xFFFFD600);
    }
    if (a == 23 && b == 24) return const Color(0xFFFFD600);
    return const Color(0xFF00E676);
  }

  static Color _jointColor(int index) {
    if (index == 11 || index == 12) return const Color(0xFF00E5FF);
    if (index >= 13 && index <= 22) return const Color(0xFFD500F9);
    if (index == 23 || index == 24) return const Color(0xFFFFD600);
    return const Color(0xFF00E676);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final frame = _repaint.value;
    if (frame.landmarks.isEmpty) return;

    final bool isScreenPortrait = size.height > size.width;
    final bool isFrameLandscape = frame.frameWidth > frame.frameHeight;

    final double adjW = (isScreenPortrait && isFrameLandscape)
        ? frame.frameHeight.toDouble()
        : frame.frameWidth.toDouble();
    final double adjH = (isScreenPortrait && isFrameLandscape)
        ? frame.frameWidth.toDouble()
        : frame.frameHeight.toDouble();

    final double scale = math.max(size.width / adjW, size.height / adjH);
    final double rendW = adjW * scale;
    final double rendH = adjH * scale;
    final double offsetX = (size.width - rendW) / 2.0;
    final double offsetY = (size.height - rendH) / 2.0;

    Offset mapPoint(PoseLandmarkPoint pt) {
      double x = pt.x, y = pt.y;
      if (isScreenPortrait && isFrameLandscape) {
        final tmp = x;
        x = 1.0 - y;
        y = tmp;
      }
      return Offset(offsetX + x * rendW, offsetY + y * rendH);
    }

    // Pass 1: bones
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

    // Pass 2: joints — all Paint objects are cached statics
    for (final lm in frame.landmarks.values) {
      if (!_isVisible(lm)) continue;
      final p = mapPoint(lm);
      final color = _jointColor(lm.index);
      final double r = _majorJoints.contains(lm.index) ? 5.0 : 3.0;

      canvas.drawCircle(p, r + 2, _jointShadowPaint);
      canvas.drawCircle(p, r + 3, _jointGlowPaint(color));
      canvas.drawCircle(p, r + 1, _jointRingPaint(color));
      canvas.drawCircle(p, r, _jointFillPaint(color));
      canvas.drawCircle(
        Offset(p.dx - r * 0.28, p.dy - r * 0.28),
        r * 0.28,
        _jointHighlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) =>
      oldDelegate.isFrontCamera != isFrontCamera ||
      oldDelegate._repaint != _repaint;

  bool _isVisible(PoseLandmarkPoint? lm) {
    if (lm == null) return false;
    final v = lm.visibility ?? lm.presence;
    return v == null || v > 0.4;
  }
}

// Squat Overlay Widgets

class _RepCounter extends StatelessWidget {
  const _RepCounter({required this.feedback});
  final SquatFeedbackData feedback;

  String get _phaseLabel => switch (feedback.phase) {
    'DESCENDING' => 'Going down',
    'BOTTOM' => 'Hold',
    'ASCENDING' => 'Coming up',
    _ => 'Ready',
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
    'GO_DEEPER' => 'Go deeper',
    'LEAN_FORWARD' => "Chest up : don't lean forward",
    'LEFT_KNEE_CAVE' => 'Push your left knee out',
    'RIGHT_KNEE_CAVE' => 'Push your right knee out',
    'TOO_LOW' => 'Too low — ease up',
    _ => fault,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: faults
          .map(
            (f) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE5534B).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
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
            ),
          )
          .toList(),
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

class _IdleSessionBanner extends StatefulWidget {
  const _IdleSessionBanner({
    required this.onEndSession,
    required this.onKeepGoing,
    required this.autoEndTimeout,
  });
  final VoidCallback onEndSession;
  final VoidCallback onKeepGoing;
  final Duration autoEndTimeout;

  @override
  State<_IdleSessionBanner> createState() => _IdleSessionBannerState();
}

class _IdleSessionBannerState extends State<_IdleSessionBanner> {
  late int _secondsRemaining;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.autoEndTimeout.inSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _secondsRemaining = (_secondsRemaining - 1).clamp(0, 999);
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String get _countdownText {
    final m = _secondsRemaining ~/ 60;
    final s = _secondsRemaining % 60;
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

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
          const Icon(
            Icons.hourglass_bottom_rounded,
            color: Color(0xFF2ECC71),
            size: 36,
          ),
          const SizedBox(height: 14),
          const Text(
            'Are you there?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "No movement detected for a minute.\nThe session will end automatically if you don't respond.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 12),
          // Countdown badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE5534B).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFE5534B).withValues(alpha: 0.6),
                width: 0.8,
              ),
            ),
            child: Text(
              'Auto-ending in $_countdownText',
              style: const TextStyle(
                color: Color(0xFFE5534B),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onKeepGoing,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    "I'm here!",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onEndSession,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5534B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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

// Target Depth Badge (Standard Parallel 90°)

class _TargetDepthBadge extends StatelessWidget {
  const _TargetDepthBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.fitness_center_rounded,
            color: Color(0xFF2ECC71),
            size: 16,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Target Depth: Standard Parallel (90°)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF2ECC71).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF2ECC71).withValues(alpha: 0.5),
              ),
            ),
            child: const Text(
              '90° Target',
              style: TextStyle(
                color: Color(0xFF2ECC71),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.enableNativePreview = true});

  final bool enableNativePreview;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Live Pose Tracking',
      theme: ThemeData.dark(useMaterial3: true),
      home: PoseScreen(enableNativePreview: enableNativePreview),
    );
  }
}

class PoseScreen extends StatefulWidget {
  const PoseScreen({super.key, this.enableNativePreview = true});

  final bool enableNativePreview;

  @override
  State<PoseScreen> createState() => _PoseScreenState();
}

class _PoseScreenState extends State<PoseScreen> {
  static const EventChannel _poseChannel = EventChannel('pose_landmarks');
  static const MethodChannel _permissionChannel = MethodChannel(
    'pose_permissions',
  );
  final ValueNotifier<List<PoseLandmarkPoint>> _landmarks =
      ValueNotifier<List<PoseLandmarkPoint>>(<PoseLandmarkPoint>[]);
  StreamSubscription<dynamic>? _subscription;
  bool? _cameraPermissionGranted;
  String? _permissionError;

  @override
  void initState() {
    super.initState();
    _setupPoseChannel();
    _setupPermission();
  }

  void _setupPoseChannel() {
    _subscription = _poseChannel.receiveBroadcastStream().listen(
      (event) {
        final parsed = _parsePoseLandmarks(event);
        if (parsed != null) {
          _landmarks.value = parsed;
        }
      },
      onError: (Object error) {
        debugPrint('Pose stream error: $error');
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
      if (!mounted) {
        return;
      }

      setState(() {
        _cameraPermissionGranted = granted;
        _permissionError = granted
            ? null
            : 'Camera permission is required to start tracking.';
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _cameraPermissionGranted = false;
        _permissionError =
            error.message ?? 'Unable to request camera permission.';
      });
    }
  }

  List<PoseLandmarkPoint>? _parsePoseLandmarks(dynamic event) {
    if (event is! List) {
      return null;
    }

    return event
        .whereType<Map>()
        .map(
          (map) => PoseLandmarkPoint(
            x: (map['x'] as num?)?.toDouble() ?? 0.0,
            y: (map['y'] as num?)?.toDouble() ?? 0.0,
            visibility: (map['visibility'] as num?)?.toDouble(),
            presence: (map['presence'] as num?)?.toDouble(),
          ),
        )
        .toList(growable: false);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _landmarks.dispose();
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
          NativePosePreview(enableNativePreview: false),
          RepaintBoundary(
            child: CustomPaint(
              painter: PosePainter(repaint: _landmarks),
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
            painter: PosePainter(repaint: _landmarks),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'Native CameraX + MediaPipe',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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

class PoseLandmarkPoint {
  const PoseLandmarkPoint({
    required this.x,
    required this.y,
    this.visibility,
    this.presence,
  });

  final double x;
  final double y;
  final double? visibility;
  final double? presence;
}

class PosePainter extends CustomPainter {
  PosePainter({required ValueListenable<List<PoseLandmarkPoint>> repaint})
    : _repaint = repaint,
      super(repaint: repaint);

  final ValueListenable<List<PoseLandmarkPoint>> _repaint;

  static const List<List<int>> _connections = [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 7],
    [0, 4],
    [4, 5],
    [5, 6],
    [6, 8],
    [11, 13],
    [13, 15],
    [12, 14],
    [14, 16],
    [5, 11],
    [6, 12],
    [11, 12],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final landmarks = _repaint.value;
    if (landmarks.isEmpty) {
      return;
    }

    final pointPaint = Paint()
      ..color = const Color(0xFFFF4D4D)
      ..strokeWidth = 6
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = const Color(0xFF77E0A3)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (final connection in _connections) {
      final first = landmarks.elementAtOrNull(connection[0]);
      final second = landmarks.elementAtOrNull(connection[1]);

      if (_isVisible(first) && _isVisible(second)) {
        canvas.drawLine(
          Offset(first!.x * size.width, first.y * size.height),
          Offset(second!.x * size.width, second.y * size.height),
          linePaint,
        );
      }
    }

    for (final landmark in landmarks) {
      if (_isVisible(landmark)) {
        canvas.drawCircle(
          Offset(landmark.x * size.width, landmark.y * size.height),
          4,
          pointPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) => false;

  bool _isVisible(PoseLandmarkPoint? landmark) {
    if (landmark == null) {
      return false;
    }

    final visibility = landmark.visibility ?? landmark.presence;
    return visibility == null || visibility > 0.5;
  }
}

extension ListExt<T> on List<T> {
  T? elementAtOrNull(int index) =>
      index >= 0 && index < length ? this[index] : null;
}

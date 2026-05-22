import 'dart:async';
import 'dart:math' as math;

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
  static const MethodChannel _settingsChannel = MethodChannel('pose_settings');

  final ValueNotifier<PoseFrameData> _frameData = ValueNotifier<PoseFrameData>(
    PoseFrameData.empty(),
  );
  StreamSubscription<dynamic>? _subscription;
  bool? _cameraPermissionGranted;
  String? _permissionError;
  PoseSettings _settings = const PoseSettings();

  @override
  void initState() {
    super.initState();
    _setupPoseChannel();
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

      if (granted) {
        await _pushSettingsToNative(_settings);
      }
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

  PoseFrameData? _parseFrameData(dynamic event) {
    if (event is! Map) {
      return null;
    }

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
      if (index == null) {
        continue;
      }

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

  Future<void> _pushSettingsToNative(PoseSettings settings) async {
    if (!widget.enableNativePreview ||
        defaultTargetPlatform != TargetPlatform.android ||
        _cameraPermissionGranted != true) {
      return;
    }

    await _settingsChannel.invokeMethod<void>(
      'updatePoseConfig',
      settings.toNativePayload(),
    );
  }

  Future<void> _openSettingsSheet() async {
    if (!widget.enableNativePreview ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final updated = await showModalBottomSheet<PoseSettings>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121417),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        var draft = _settings;

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Pose settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _ThresholdSlider(
                      label: 'Detection threshold',
                      value: draft.detectionThreshold,
                      onChanged: (value) {
                        setSheetState(() {
                          draft = draft.copyWith(detectionThreshold: value);
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _ThresholdSlider(
                      label: 'Tracking threshold',
                      value: draft.trackingThreshold,
                      onChanged: (value) {
                        setSheetState(() {
                          draft = draft.copyWith(trackingThreshold: value);
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _ThresholdSlider(
                      label: 'Presence threshold',
                      value: draft.presenceThreshold,
                      onChanged: (value) {
                        setSheetState(() {
                          draft = draft.copyWith(presenceThreshold: value);
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(draft),
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (updated == null) {
      return;
    }

    setState(() {
      _settings = updated;
    });
    await _pushSettingsToNative(updated);
  }

  @override
  void dispose() {
    _subscription?.cancel();
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
              painter: PosePainter(repaint: _frameData),
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
            painter: PosePainter(repaint: _frameData),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Row(
            children: [
              Expanded(
                child: _InfoPill(title: 'Model', value: 'Lite only'),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: _openSettingsSheet,
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          child: _InfoPill(
            title: 'Thresholds',
            value:
                'D ${_settings.detectionThreshold.toStringAsFixed(2)}  '
                'T ${_settings.trackingThreshold.toStringAsFixed(2)}  '
                'P ${_settings.presenceThreshold.toStringAsFixed(2)}',
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThresholdSlider extends StatelessWidget {
  const _ThresholdSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${value.toStringAsFixed(2)}',
          style: const TextStyle(color: Colors.white70),
        ),
        Slider(
          value: value,
          min: 0,
          max: 1,
          divisions: 20,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class PoseSettings {
  const PoseSettings({
    this.detectionThreshold = 0.5,
    this.trackingThreshold = 0.5,
    this.presenceThreshold = 0.5,
  });

  final double detectionThreshold;
  final double trackingThreshold;
  final double presenceThreshold;

  PoseSettings copyWith({
    double? detectionThreshold,
    double? trackingThreshold,
    double? presenceThreshold,
  }) {
    return PoseSettings(
      detectionThreshold: detectionThreshold ?? this.detectionThreshold,
      trackingThreshold: trackingThreshold ?? this.trackingThreshold,
      presenceThreshold: presenceThreshold ?? this.presenceThreshold,
    );
  }

  Map<String, Object> toNativePayload() {
    return <String, Object>{
      'detectionThreshold': detectionThreshold,
      'trackingThreshold': trackingThreshold,
      'presenceThreshold': presenceThreshold,
    };
  }
}

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

class PosePainter extends CustomPainter {
  PosePainter({required ValueListenable<PoseFrameData> repaint})
    : _repaint = repaint,
      super(repaint: repaint);

  final ValueListenable<PoseFrameData> _repaint;

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

  @override
  void paint(Canvas canvas, Size size) {
    final frame = _repaint.value;
    if (frame.landmarks.isEmpty) {
      return;
    }

    final scaleX = size.width / frame.frameWidth;
    final scaleY = size.height / frame.frameHeight;
    final scale = math.max(scaleX, scaleY);
    final renderedWidth = frame.frameWidth * scale;
    final renderedHeight = frame.frameHeight * scale;
    final offsetX = (size.width - renderedWidth) / 2.0;
    final offsetY = (size.height - renderedHeight) / 2.0;

    Offset mapPoint(PoseLandmarkPoint point) {
      return Offset(
        offsetX + point.x * renderedWidth,
        offsetY + point.y * renderedHeight,
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
      final first = frame.landmarks[connection[0]];
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
  bool shouldRepaint(covariant PosePainter oldDelegate) => false;

  bool _isVisible(PoseLandmarkPoint? landmark) {
    if (landmark == null) {
      return false;
    }

    final visibility = landmark.visibility ?? landmark.presence;
    return visibility == null || visibility > 0.4;
  }
}

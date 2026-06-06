package com.example.flt_kotlin_pose

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val poseChannelName       = "pose_landmarks"
    private val squatChannelName      = "squat_feedback"   // streams squat feedback to Flutter
    private val permissionChannelName = "pose_permissions"
    private val settingsChannelName   = "pose_settings"
    private val cameraViewType        = "native_pose_camera"
    private val cameraPermissionRequestCode = 1001

    private var pendingPermissionResult: MethodChannel.Result? = null

    // Activity-scoped instances
    private lateinit var audioController: SquatAudioController
    private lateinit var squatEngine: SquatHeuristicEngine

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        audioController = SquatAudioController(this)
        squatEngine     = SquatHeuristicEngine(audioController)

        // 1. Pose landmark stream
        // Also hooks the heuristic engine into every emitted frame
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, poseChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    PoseLandmarkEventBus.eventSink = events

                    // Engine subscribes here (camera thread)
                    PoseLandmarkEventBus.onFrame = { frame ->
                        val feedback = squatEngine.analyze(frame) ?: return@onFrame
                        SquatFeedbackEventBus.emit(feedback)
                        // Audio triggered in SquatHeuristicEngine
                    }
                }

                override fun onCancel(arguments: Any?) {
                    PoseLandmarkEventBus.eventSink = null
                    PoseLandmarkEventBus.onFrame   = null
                }
            })

        // 2. Squat feedback stream to Flutter UI
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, squatChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    SquatFeedbackEventBus.eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    SquatFeedbackEventBus.eventSink = null
                }
            })

        // 3. Permission channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, permissionChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasCameraPermission"     -> result.success(hasCameraPermission())
                    "requestCameraPermission" -> {
                        if (hasCameraPermission()) {
                            result.success(true)
                        } else {
                            pendingPermissionResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.CAMERA),
                                cameraPermissionRequestCode,
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // 4. Settings and session control channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, settingsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updatePoseConfig" -> {
                        val args = call.arguments as? Map<*, *>
                        if (args == null) {
                            result.error("BAD_ARGS", "Pose settings payload is missing", null)
                            return@setMethodCallHandler
                        }
                        val config = PoseDetectorConfig(
                            detectionThreshold = (args["detectionThreshold"] as? Number)?.toFloat() ?: 0.5f,
                            trackingThreshold  = (args["trackingThreshold"]  as? Number)?.toFloat() ?: 0.5f,
                            presenceThreshold  = (args["presenceThreshold"]  as? Number)?.toFloat() ?: 0.5f,
                        )
                        PoseCameraRegistry.updateConfig(this, config)
                        result.success(null)
                    }
                    // Allows Flutter to reset rep counter
                    "resetSquatSession" -> {
                        squatEngine.reset()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // 5. Platform view factory
        flutterEngine.platformViewsController.registry.registerViewFactory(
            cameraViewType,
            PoseCameraViewFactory(this),
        )
    }

    override fun onDestroy() {
        PoseLandmarkEventBus.eventSink  = null
        PoseLandmarkEventBus.onFrame    = null
        SquatFeedbackEventBus.eventSink = null
        audioController.release()       // release audio resources
        pendingPermissionResult         = null
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == cameraPermissionRequestCode) {
            val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    private fun hasCameraPermission() =
        ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
}
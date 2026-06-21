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
    private val squatChannelName      = "squat_feedback"
    private val permissionChannelName = "pose_permissions"
    private val resetChannelName      = "pose_settings"
    private val cameraViewType        = "native_pose_camera"
    private val cameraPermissionRequestCode = 1001

    private var pendingPermissionResult: MethodChannel.Result? = null

    private lateinit var audioController: SquatAudioController
    private lateinit var squatEngine: SquatHeuristicEngine

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        audioController = SquatAudioController(this)
        squatEngine     = SquatHeuristicEngine(audioController)

        // 1. Pose landmarks → Flutter + heuristic engine
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, poseChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    PoseLandmarkEventBus.eventSink = events
                    PoseLandmarkEventBus.onFrame = { frame ->
                        val feedback = squatEngine.analyze(frame)
                        if (feedback != null) {
                            SquatFeedbackEventBus.emit(feedback)
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    PoseLandmarkEventBus.eventSink = null
                    PoseLandmarkEventBus.onFrame   = null
                }
            })

        // 2. Squat feedback → Flutter UI
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, squatChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    SquatFeedbackEventBus.eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    SquatFeedbackEventBus.eventSink = null
                }
            })

        // 3. Camera permission
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

        // 4. Session control
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, resetChannelName)
        .setMethodCallHandler { call, result ->
            when (call.method) {
                "resetSquatSession" -> {
                    squatEngine.reset()
                    result.success(null)
                }
                "toggleCameraFacing" -> {
                    val useFront = call.arguments as? Boolean ?: false
                    PoseCameraRegistry.toggleCamera(this, useFront)
                    result.success(null)
                }
                "setDepthThreshold" -> {
                    val angle = (call.arguments as? Double)?.toFloat() ?: 90f
                    squatEngine.setDepthThreshold(angle)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
    }


        // 5. Native camera view
        flutterEngine.platformViewsController.registry.registerViewFactory(
            cameraViewType,
            PoseCameraViewFactory(this),
        )
    }

    override fun onDestroy() {
        PoseLandmarkEventBus.eventSink  = null
        PoseLandmarkEventBus.onFrame    = null
        SquatFeedbackEventBus.eventSink = null
        audioController.release()
        pendingPermissionResult = null
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
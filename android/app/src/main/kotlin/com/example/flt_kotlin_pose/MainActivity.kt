package com.example.flt_kotlin_pose

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity : FlutterActivity() {

    private val poseChannelName       = "pose_landmarks"
    private val squatChannelName      = "squat_feedback"
    private val permissionChannelName = "pose_permissions"
    private val resetChannelName      = "pose_settings"
    private val workoutChannelName    = "com.squatapp.squat_channel"
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
                    Log.d("PoseChannel", "✅ Flutter is listening to pose_landmarks")
                    PoseLandmarkEventBus.eventSink = events
                    PoseLandmarkEventBus.onFrame = { frame ->
                        val feedback = squatEngine.analyze(frame)
                        if (feedback != null) {
                            SquatFeedbackEventBus.emit(feedback)
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    Log.d("PoseChannel", "❌ Flutter stopped listening")
                    PoseLandmarkEventBus.eventSink = null
                    PoseLandmarkEventBus.onFrame   = null
                }
            })

        // 2. Squat feedback → Flutter UI
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, squatChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    Log.d("SquatChannel", "✅ Flutter is listening to squat_feedback")
                    SquatFeedbackEventBus.eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    Log.d("SquatChannel", "❌ Flutter stopped listening")
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

        // 5. Workout data channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, workoutChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startSquatDetection" -> {
                        Log.d("WorkoutChannel", "🔵 startSquatDetection called")
                        try {
                            squatEngine.start()
                            result.success(mapOf("status" to "started"))
                        } catch (e: Exception) {
                            Log.e("WorkoutChannel", "❌ Error: ${e.message}")
                            result.error("START_ERROR", e.message, null)
                        }
                    }
                    
                    // In MainActivity.kt - the stopSquatDetection handler

                    "stopSquatDetection" -> {
                        Log.d("WorkoutChannel", "🔵 stopSquatDetection called")
                        try {
                            // Get summary from engine
                            val summary = squatEngine.endWorkoutSummary()
                            Log.d("WorkoutChannel", "🔵 Summary: $summary")
                            
                            // Get workout data
                            val workoutData = getCurrentWorkoutData()
                            Log.d("WorkoutChannel", "🔵 Workout data: $workoutData")
                            
                            // Combine into one response
                            val response = mutableMapOf<String, Any>()
                            response.putAll(workoutData)
                            
                            if (summary != null) {
                                response["durationSeconds"] = summary.durationSeconds
                                response["avgKneeAngle"] = summary.avgKneeAngle
                                response["avgHipAngle"] = summary.avgHipAngle
                                response["minKneeAngle"] = summary.minKneeAngle
                                response["minHipAngle"] = summary.minHipAngle
                            }
                            
                            // Reset the engine
                            squatEngine.reset()
                            Log.d("WorkoutChannel", "✅ Engine reset")
                            
                            Log.d("WorkoutChannel", "📤 Full workout data: $response")
                            result.success(response)
                        } catch (e: Exception) {
                            Log.e("WorkoutChannel", "❌ Error: ${e.message}")
                            result.error("STOP_ERROR", e.message, null)
                        }
                    }
                    
                    "getWorkoutData" -> {
                        Log.d("WorkoutChannel", "🔵 getWorkoutData called")
                        try {
                            val data = getCurrentWorkoutData()
                            result.success(data)
                        } catch (e: Exception) {
                            Log.e("WorkoutChannel", "❌ Error: ${e.message}")
                            result.error("DATA_ERROR", e.message, null)
                        }
                    }
                    
                    "resetSquatEngine" -> {
                        Log.d("WorkoutChannel", "🔵 resetSquatEngine called")
                        try {
                            squatEngine.reset()
                            result.success(mapOf("status" to "reset"))
                        } catch (e: Exception) {
                            Log.e("WorkoutChannel", "❌ Error: ${e.message}")
                            result.error("RESET_ERROR", e.message, null)
                        }
                    }
                    
                    "setSquatType" -> {
                        val type = call.arguments as? String ?: "STANDARD"
                        Log.d("WorkoutChannel", "🔵 setSquatType: $type")
                        squatEngine.setSquatType(type)
                        result.success(null)
                    }
                    
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // 6. Native camera view
        flutterEngine.platformViewsController.registry.registerViewFactory(
            cameraViewType,
            PoseCameraViewFactory(this),
        )
    }

    // Get current workout data
    private fun getCurrentWorkoutData(): Map<String, Any> {
        return mapOf(
            "squatType" to squatEngine.getSquatType(),
            "totalReps" to squatEngine.getRepCount(),
            "formScore" to squatEngine.getFormScore(),
            "repScores" to squatEngine.getRepScores(),
            "faults" to squatEngine.getFaultSummary(),
            "timestamp" to System.currentTimeMillis()
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
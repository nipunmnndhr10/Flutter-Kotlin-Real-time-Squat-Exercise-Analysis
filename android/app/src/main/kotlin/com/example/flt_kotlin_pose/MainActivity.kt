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

   private val poseChannelName = "pose_landmarks"
   private val cameraViewType = "native_pose_camera"
   private val permissionChannelName = "pose_permissions"
   private val cameraPermissionRequestCode = 1001
   private var pendingPermissionResult: MethodChannel.Result? = null

   override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
      super.configureFlutterEngine(flutterEngine)

      EventChannel(flutterEngine.dartExecutor.binaryMessenger, poseChannelName)
              .setStreamHandler(
                      object : EventChannel.StreamHandler {
                         override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                            PoseLandmarkEventBus.eventSink = events
                         }

                         override fun onCancel(arguments: Any?) {
                            PoseLandmarkEventBus.eventSink = null
                         }
                      }
              )

      MethodChannel(flutterEngine.dartExecutor.binaryMessenger, permissionChannelName)
              .setMethodCallHandler { call, result ->
                 when (call.method) {
                    "hasCameraPermission" -> {
                       result.success(hasCameraPermission())
                    }
                    "requestCameraPermission" -> {
                       if (hasCameraPermission()) {
                          result.success(true)
                       } else {
                          pendingPermissionResult = result
                          ActivityCompat.requestPermissions(
                                  this,
                                  arrayOf(Manifest.permission.CAMERA),
                                  cameraPermissionRequestCode
                          )
                       }
                    }
                    else -> result.notImplemented()
                 }
              }

      flutterEngine.platformViewsController.registry.registerViewFactory(
              cameraViewType,
              PoseCameraViewFactory(this)
      )
   }

   override fun onDestroy() {
      PoseLandmarkEventBus.eventSink = null
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

   private fun hasCameraPermission(): Boolean {
      return ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
   }
}

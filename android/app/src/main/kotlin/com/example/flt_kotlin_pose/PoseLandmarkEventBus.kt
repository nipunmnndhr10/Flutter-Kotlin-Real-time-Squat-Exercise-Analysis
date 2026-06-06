package com.example.flt_kotlin_pose

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

internal object PoseLandmarkEventBus {
   private val mainHandler = Handler(Looper.getMainLooper())

   @Volatile
   var eventSink: EventChannel.EventSink? = null

   fun emit(framePayload: PoseFramePayload) {
      mainHandler.post {
         eventSink?.success(
                 mapOf(
                         "frameWidth" to framePayload.frameWidth,
                         "frameHeight" to framePayload.frameHeight,
                         "landmarks" to framePayload.landmarks.map {
                            mapOf(
                                    "index" to it.index,
                                    "x" to it.x,
                                    "y" to it.y,
                                    "visibility" to it.visibility,
                                    "presence" to it.presence,
                            )
                         },
                 )
         )
      }
   }

   fun error(message: String) {
      mainHandler.post {
         eventSink?.error("POSE_ERROR", message, null)
      }
   }
}

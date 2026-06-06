package com.example.flt_kotlin_pose

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

internal object PoseLandmarkEventBus {
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    var eventSink: EventChannel.EventSink? = null

    // Heuristic engine subscribes here — called on the background camera thread,
    // so SquatHeuristicEngine must be thread-safe (it is, since it's called
    // sequentially from the single camera executor thread).
    @Volatile
    var onFrame: ((PoseFramePayload) -> Unit)? = null

    fun emit(framePayload: PoseFramePayload) {
        // Notify heuristic engine first — stays on camera thread, no UI overhead
        onFrame?.invoke(framePayload)

        // Then forward landmarks to Flutter on main thread
        mainHandler.post {
            eventSink?.success(
                mapOf(
                    "frameWidth"  to framePayload.frameWidth,
                    "frameHeight" to framePayload.frameHeight,
                    "landmarks"   to framePayload.landmarks.map {
                        mapOf(
                            "index"      to it.index,
                            "x"          to it.x,
                            "y"          to it.y,
                            "visibility" to it.visibility,
                            "presence"   to it.presence,
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
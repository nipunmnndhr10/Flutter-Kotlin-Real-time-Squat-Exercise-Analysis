package com.example.flt_kotlin_pose

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

internal object SquatFeedbackEventBus {
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    var eventSink: EventChannel.EventSink? = null

    fun emit(feedback: SquatFeedback) {
        mainHandler.post {
            eventSink?.success(
                mapOf(
                    "phase"              to feedback.phase.name,
                    "repCount"           to feedback.repCount,
                    "activeFaults"       to feedback.activeFaults.map { it.name },
                    "kneeAngle"          to feedback.kneeAngle,
                    "hipAngle"           to feedback.hipAngle,
                    "isLandmarkReliable" to feedback.isLandmarkReliable,
                )
            )
        }
    }
}
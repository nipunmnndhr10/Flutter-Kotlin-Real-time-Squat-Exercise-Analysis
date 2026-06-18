package com.example.flt_kotlin_pose

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

internal object SquatFeedbackEventBus {
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    var eventSink: EventChannel.EventSink? = null

    // Deduplication cache — only emit when UI-visible state changes
    private var lastPhase: SquatPhase? = null
    private var lastRepCount: Int = -1
    private var lastFaults: List<SquatFault> = emptyList()

    fun emit(feedback: SquatFeedback) {
        // Skip if phase, repCount, and activeFaults are unchanged.
        // This prevents 30fps setState() spam on the Flutter UI thread.
        if (feedback.phase == lastPhase &&
            feedback.repCount == lastRepCount &&
            feedback.activeFaults == lastFaults
        ) {
            return
        }

        lastPhase = feedback.phase
        lastRepCount = feedback.repCount
        lastFaults = feedback.activeFaults

        mainHandler.post {
            eventSink?.success(
                mapOf(
                    "phase"              to feedback.phase.name,
                    "repCount"           to feedback.repCount,
                    "activeFaults"       to feedback.activeFaults.map { it.name },
                    "kneeAngle"          to feedback.kneeAngle,
                    "hipAngle"           to feedback.hipAngle,
                    "isLandmarkReliable" to feedback.isLandmarkReliable,
                    "activePreset"       to feedback.activePreset.name,
                    "angleThreshold"     to feedback.activePreset.angleThreshold,
                    "presetLabel"        to feedback.activePreset.label,
                )
            )
        }
    }
}

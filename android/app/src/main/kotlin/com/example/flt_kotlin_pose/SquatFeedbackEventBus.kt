package com.example.flt_kotlin_pose

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import kotlin.math.abs

internal object SquatFeedbackEventBus {
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    var eventSink: EventChannel.EventSink? = null

    // Deduplication cache — only emit when UI-visible state changes
    private var lastPhase: SquatPhase? = null
    private var lastRepCount: Int = -1
    private var lastFaults: List<SquatFault> = emptyList()
    private var lastKneeAngle: Float? = null
    private var lastHipAngle: Float? = null
    private var lastEmitTime: Long = 0L

    fun emit(feedback: SquatFeedback) {
        val now = System.currentTimeMillis()
        val timeSinceLastEmit = now - lastEmitTime
        val stateChanged = feedback.phase != lastPhase ||
                feedback.repCount != lastRepCount ||
                feedback.activeFaults != lastFaults

        val angleChanged = lastKneeAngle == null || lastHipAngle == null ||
                abs(feedback.kneeAngle - lastKneeAngle!!) > 0.5f ||
                abs(feedback.hipAngle - lastHipAngle!!) > 0.5f

        // Only skip emission if no state has changed, AND either angles haven't changed much
        // OR we are throttling angle updates (less than 100ms since last update).
        if (!stateChanged && (!angleChanged || timeSinceLastEmit < 100L)) {
            return
        }

        lastPhase = feedback.phase
        lastRepCount = feedback.repCount
        lastFaults = feedback.activeFaults
        lastKneeAngle = feedback.kneeAngle
        lastHipAngle = feedback.hipAngle
        lastEmitTime = now

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

    fun reset() {
        lastPhase = null
        lastRepCount = -1
        lastFaults = emptyList()
        lastKneeAngle = null
        lastHipAngle = null
        lastEmitTime = 0L
    }
}

package com.example.flt_kotlin_pose

import kotlin.math.abs
import kotlin.math.atan2

class SquatHeuristicEngine(private val audioController: SquatAudioController) {

    private var currentPhase = SquatPhase.STANDING
    private var repCount = 0
    private var wasAtBottom = false

    // Smoothing — avoid phase flicker from single noisy frames
    private val kneeAngleBuffer = FloatArray(5)
    private var bufferIndex = 0

    // Debouncing — prevent audio spam during a single rep
    private val faultsAnnouncedThisRep = mutableSetOf<SquatFault>()

    fun analyze(frame: PoseFramePayload): SquatFeedback? {
        val lm = frame.landmarks.associateBy { it.index }

        // Need these 7 landmarks minimum — bail if any are missing or low-confidence.
        // RIGHT_HIP (24) is not used in angle calculations so it is intentionally
        // excluded from the required set; all other used landmarks are listed here.
        val required = listOf(
            LM.LEFT_HIP, LM.LEFT_KNEE, LM.LEFT_ANKLE,
            LM.LEFT_SHOULDER, LM.RIGHT_SHOULDER,
            LM.RIGHT_KNEE, LM.RIGHT_ANKLE,
        )

        val reliable = required.all { idx ->
            val l = lm[idx]
            l != null && (l.visibility ?: 0f) > 0.5f && (l.presence ?: 0f) > 0.5f
        }

        if (!reliable) return null  // skip frame, don't corrupt state

        val leftHip       = lm[LM.LEFT_HIP]!!
        val leftKnee      = lm[LM.LEFT_KNEE]!!
        val leftAnkle     = lm[LM.LEFT_ANKLE]!!
        val leftShoulder  = lm[LM.LEFT_SHOULDER]!!
        val rightShoulder = lm[LM.RIGHT_SHOULDER]!!
        val rightKnee     = lm[LM.RIGHT_KNEE]!!
        val rightAnkle    = lm[LM.RIGHT_ANKLE]!!

        val w = frame.frameWidth
        val h = frame.frameHeight

        // Calculate aspect-ratio-corrected angles
        val rawKneeAngle = calculateAngle(leftHip, leftKnee, leftAnkle, w, h)
        val hipAngle     = calculateAngle(leftShoulder, leftHip, leftKnee, w, h)

        // FIX: Write into the circular buffer first, then average only the
        // slots that have actually been filled. On early frames (bufferIndex < 5)
        // the unfilled slots still hold 0f, which would pull the average down
        // and could falsely trigger a BOTTOM phase on the very first frames.
        val slot = bufferIndex % kneeAngleBuffer.size
        kneeAngleBuffer[slot] = rawKneeAngle
        bufferIndex++
        val filledSlots = minOf(bufferIndex, kneeAngleBuffer.size)
        val kneeAngle = kneeAngleBuffer.take(filledSlots).average().toFloat()

        updatePhaseAndReps(kneeAngle)

        val faults = detectFaults(
            kneeAngle, hipAngle,
            leftShoulder, rightShoulder,
            leftKnee, leftAnkle, rightKnee, rightAnkle,
        )

        // Trigger audio for new faults only (debounced per rep)
        triggerAudioFeedback(faults)

        return SquatFeedback(
            phase              = currentPhase,
            repCount           = repCount,
            activeFaults       = faults,
            kneeAngle          = kneeAngle,
            hipAngle           = hipAngle,
            isLandmarkReliable = true,
        )
    }

    private fun updatePhaseAndReps(kneeAngle: Float) {
        val newPhase = when {
            kneeAngle > 155f -> SquatPhase.STANDING
            kneeAngle < 100f -> SquatPhase.BOTTOM
            kneeAngle < 140f -> if (wasAtBottom) SquatPhase.ASCENDING else SquatPhase.DESCENDING
            else             -> currentPhase  // hold current phase in ambiguous range
        }

        if (currentPhase == SquatPhase.BOTTOM) wasAtBottom = true

        // Rep counted on transition: ASCENDING → STANDING
        if (currentPhase == SquatPhase.ASCENDING && newPhase == SquatPhase.STANDING) {
            if (wasAtBottom) repCount++

            // Reset rep-scoped state for the next squat
            wasAtBottom = false
            faultsAnnouncedThisRep.clear()
        }

        currentPhase = newPhase
    }

    private fun detectFaults(
        kneeAngle: Float,
        hipAngle: Float,
        leftShoulder:  PoseLandmarkPayload,
        rightShoulder: PoseLandmarkPayload,
        leftKnee:  PoseLandmarkPayload,
        leftAnkle: PoseLandmarkPayload,
        rightKnee:  PoseLandmarkPayload,
        rightAnkle: PoseLandmarkPayload,
    ): List<SquatFault> {
        val faults = mutableListOf<SquatFault>()

        // Only check faults at bottom of squat — avoids false positives mid-descent
        if (currentPhase == SquatPhase.BOTTOM) {
            if (kneeAngle > 115f) faults.add(SquatFault.GO_DEEPER)
            if (hipAngle < 40f)   faults.add(SquatFault.LEAN_FORWARD)

            // Dynamic ruler: knee-cave threshold scales with the user's own
            // shoulder width in normalized space, so it's camera-distance-agnostic.
            val shoulderWidth  = abs(leftShoulder.x - rightShoulder.x)
            val caveThreshold  = shoulderWidth * 0.15f

            if (leftKnee.x  > leftAnkle.x  + caveThreshold) faults.add(SquatFault.LEFT_KNEE_CAVE)
            if (rightKnee.x < rightAnkle.x - caveThreshold) faults.add(SquatFault.RIGHT_KNEE_CAVE)
        }

        return faults
    }

    private fun triggerAudioFeedback(currentFaults: List<SquatFault>) {
        for (fault in currentFaults) {
            if (faultsAnnouncedThisRep.add(fault)) {   // add() returns false if already present
                audioController.playCue(fault.cueName)
            }
        }
    }

    fun reset() {
        currentPhase = SquatPhase.STANDING
        repCount     = 0
        wasAtBottom  = false
        bufferIndex  = 0
        kneeAngleBuffer.fill(0f)
        faultsAnnouncedThisRep.clear()
    }

    // 2D angle at vertex b, using pixel coordinates for aspect-ratio correctness
    private fun calculateAngle(
        a: PoseLandmarkPayload,
        b: PoseLandmarkPayload,  // vertex
        c: PoseLandmarkPayload,
        width: Int,
        height: Int,
    ): Float {
        val ax = a.x * width;  val ay = a.y * height
        val bx = b.x * width;  val by = b.y * height
        val cx = c.x * width;  val cy = c.y * height

        val radians = atan2((cy - by).toDouble(), (cx - bx).toDouble()) -
                      atan2((ay - by).toDouble(), (ax - bx).toDouble())

        var angle = abs(Math.toDegrees(radians)).toFloat()
        if (angle > 180f) angle = 360f - angle
        return angle
    }
}
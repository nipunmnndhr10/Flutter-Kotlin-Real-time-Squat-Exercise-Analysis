package com.example.flt_kotlin_pose

import kotlin.math.abs
import kotlin.math.atan2

class SquatHeuristicEngine(private val audioController: SquatAudioController) {

    private var currentPhase = SquatPhase.STANDING
    private var repCount = 0
    private var minKneeAngleThisRep = 180f
    private var isInsideRep = false

    // Smoothing — avoid phase flicker from single noisy frames
    private val kneeAngleBuffer = FloatArray(5)
    private var bufferIndex = 0

    // Debouncing — prevent audio spam during a single rep
    private val faultsAnnouncedThisRep = mutableSetOf<SquatFault>()

    fun analyze(frame: PoseFramePayload): SquatFeedback? {
        val lm = frame.landmarks.associateBy { it.index }

        // 1. Verify tracking viability independently for Left and Right profiles
        val leftProfileValid = listOf(LM.LEFT_SHOULDER, LM.LEFT_HIP, LM.LEFT_KNEE, LM.LEFT_ANKLE).all { idx ->
            val l = lm[idx]
            l != null && (l.visibility ?: 0f) > 0.45f && (l.presence ?: 0f) > 0.45f
        }

        val rightProfileValid = listOf(LM.RIGHT_SHOULDER, LM.RIGHT_HIP, LM.RIGHT_KNEE, LM.RIGHT_ANKLE).all { idx ->
            val l = lm[idx]
            l != null && (l.visibility ?: 0f) > 0.45f && (l.presence ?: 0f) > 0.45f
        }

        if (!leftProfileValid && !rightProfileValid) return null

        // 2. Auto-select the optimal side for profile plane angle tracking
        val useLeftSide = when {
            leftProfileValid && !rightProfileValid -> true
            !leftProfileValid && rightProfileValid -> false
            else -> {
                val leftScore = listOf(LM.LEFT_SHOULDER, LM.LEFT_HIP, LM.LEFT_KNEE, LM.LEFT_ANKLE).map { lm[it]?.visibility ?: 0f }.sum()
                val rightScore = listOf(LM.RIGHT_SHOULDER, LM.RIGHT_HIP, LM.RIGHT_KNEE, LM.RIGHT_ANKLE).map { lm[it]?.visibility ?: 0f }.sum()
                leftScore >= rightScore
            }
        }

        val hip      = if (useLeftSide) lm[LM.LEFT_HIP]!!      else lm[LM.RIGHT_HIP]!!
        val knee     = if (useLeftSide) lm[LM.LEFT_KNEE]!!     else lm[LM.RIGHT_KNEE]!!
        val ankle    = if (useLeftSide) lm[LM.LEFT_ANKLE]!!    else lm[LM.RIGHT_ANKLE]!!
        val shoulder = if (useLeftSide) lm[LM.LEFT_SHOULDER]!! else lm[LM.RIGHT_SHOULDER]!!

        val w = frame.frameWidth
        val h = frame.frameHeight

        // 3. Calculate aspect-ratio corrected angles
        val rawKneeAngle = calculateAngle(hip, knee, ankle, w, h)
        val hipAngle     = calculateAngle(shoulder, hip, knee, w, h)

        // Rolling average to smooth knee angle pathing
        kneeAngleBuffer[bufferIndex % kneeAngleBuffer.size] = rawKneeAngle
        bufferIndex++
        val kneeAngle = kneeAngleBuffer.take(
            minOf(bufferIndex, kneeAngleBuffer.size)
        ).average().toFloat()

        // 4. Run State Machine Update
        updatePhaseAndReps(kneeAngle)

        val isFrontView = leftProfileValid && rightProfileValid
        val faults = detectFaults(kneeAngle, hipAngle, lm, isFrontView, w, h)

        // Trigger safe debounced audio feedback
        triggerAudioFeedback(faults)

        return SquatFeedback(
            phase = currentPhase,
            repCount = repCount,
            activeFaults = faults,
            kneeAngle = kneeAngle,
            hipAngle = hipAngle,
            isLandmarkReliable = true,
        )
    }

    private fun updatePhaseAndReps(kneeAngle: Float) {
        // Open the rep window when starting descent
        if (kneeAngle < 140f) {
            if (!isInsideRep) {
                isInsideRep = true
                minKneeAngleThisRep = 180f
            }
            if (kneeAngle < minKneeAngleThisRep) {
                minKneeAngleThisRep = kneeAngle
            }
        }

        // Determine phase mapping for the UI state
        val newPhase = when {
            kneeAngle > 145f -> SquatPhase.STANDING
            kneeAngle < 105f -> SquatPhase.BOTTOM
            else -> {
                // Ascending if driving upward from lowest recorded depth
                if (isInsideRep && kneeAngle > minKneeAngleThisRep + 5f) {
                    SquatPhase.ASCENDING
                } else {
                    SquatPhase.DESCENDING
                }
            }
        }

        // Handle full standing completion cleanly
        if (isInsideRep && kneeAngle > 145f) {
            if (minKneeAngleThisRep <= 105f) {
                repCount++ // Validated rep depth met
            }
            isInsideRep = false
            minKneeAngleThisRep = 180f
            faultsAnnouncedThisRep.clear() // Ready for next rep
        }

        currentPhase = newPhase
    }

    private fun detectFaults(
        kneeAngle: Float,
        hipAngle: Float,
        lm: Map<Int, PoseLandmarkPayload>,
        isFrontView: Boolean,
        w: Int,
        h: Int
    ): List<SquatFault> {
        val faults = mutableListOf<SquatFault>()

        // Analyze form continuously throughout the movement window
        if (currentPhase != SquatPhase.STANDING) {

            // 1. Depth Fault: Catch shallow depth dynamically as soon as the user starts driving upward early
            if (currentPhase == SquatPhase.ASCENDING && minKneeAngleThisRep > 105f) {
                faults.add(SquatFault.GO_DEEPER)
            }

            // 2. Posture Lean Fault ("Chest Up!") — Evaluated under load (below 130 deg)
            if (kneeAngle < 130f) {
                if (isFrontView) {
                    val leftShoulder  = lm[LM.LEFT_SHOULDER]!!
                    val rightShoulder = lm[LM.RIGHT_SHOULDER]!!
                    val leftHip       = lm[LM.LEFT_HIP]!!
                    val rightHip      = lm[LM.RIGHT_HIP]!!

                    // Convert calculations to TRUE PIXEL SPACE to neutralize device aspect ratios
                    val shoulderWidthPx = abs((leftShoulder.x * w) - (rightShoulder.x * w))
                    val avgTorsoHeightPx = (abs((leftShoulder.y * h) - (leftHip.y * h)) + abs((rightShoulder.y * h) - (rightHip.y * h))) / 2f

                    if (avgTorsoHeightPx < shoulderWidthPx * 0.78f) {
                        faults.add(SquatFault.LEAN_FORWARD)
                    }
                } else {
                    if (hipAngle < 55f) {
                        faults.add(SquatFault.LEAN_FORWARD)
                    }
                }
            }

            // 3. Knee Alignment Faults ("Knees Out!") — Tracked in pixel space during active range
            if (isFrontView && kneeAngle < 125f) {
                val leftShoulder  = lm[LM.LEFT_SHOULDER]!!
                val rightShoulder = lm[LM.RIGHT_SHOULDER]!!
                val leftKnee      = lm[LM.LEFT_KNEE]!!
                val leftAnkle     = lm[LM.LEFT_ANKLE]!!
                val rightKnee     = lm[LM.RIGHT_KNEE]!!
                val rightAnkle    = lm[LM.RIGHT_ANKLE]!!

                val shoulderWidthPx = abs((leftShoulder.x * w) - (rightShoulder.x * w))
                val caveThresholdPx = shoulderWidthPx * 0.15f 
                val ankleMidpointXPx = ((leftAnkle.x * w) + (rightAnkle.x * w)) / 2f
                
                val leftAnkleDistPx = abs((leftAnkle.x * w) - ankleMidpointXPx)
                val leftKneeDistPx  = abs((leftKnee.x * w) - ankleMidpointXPx)
                
                val rightAnkleDistPx = abs((rightAnkle.x * w) - ankleMidpointXPx)
                val rightKneeDistPx  = abs((rightKnee.x * w) - ankleMidpointXPx)

                if (leftKneeDistPx < leftAnkleDistPx - caveThresholdPx) {
                    faults.add(SquatFault.LEFT_KNEE_CAVE)
                }
                    
                if (rightKneeDistPx < rightAnkleDistPx - caveThresholdPx) {
                    faults.add(SquatFault.RIGHT_KNEE_CAVE)
                }
            }
        }

        return faults
    }

    private fun triggerAudioFeedback(currentFaults: List<SquatFault>) {
        for (fault in currentFaults) {
            if (!faultsAnnouncedThisRep.contains(fault)) {
                faultsAnnouncedThisRep.add(fault)
                audioController.playCue(fault.cueName)
            }
        }
    }

    fun reset() {
        currentPhase = SquatPhase.STANDING
        repCount = 0
        minKneeAngleThisRep = 180f
        isInsideRep = false
        bufferIndex = 0
        kneeAngleBuffer.fill(0f)
        faultsAnnouncedThisRep.clear()
    }

    private fun calculateAngle(
        a: PoseLandmarkPayload,
        b: PoseLandmarkPayload,
        c: PoseLandmarkPayload,
        width: Int,
        height: Int
    ): Float {
        val ax = a.x * width
        val ay = a.y * height
        val bx = b.x * width
        val by = b.y * height
        val cx = c.x * width
        val cy = c.y * height

        val radians = atan2((cy - by).toDouble(), (cx - bx).toDouble()) -
                      atan2((ay - by).toDouble(), (ax - bx).toDouble())
                      
        var angle = abs(Math.toDegrees(radians)).toFloat()
        if (angle > 180f) angle = 360f - angle
        return angle
    }
}
package com.example.flt_kotlin_pose

import kotlin.math.abs
import kotlin.math.atan2

class SquatHeuristicEngine(private val audioController: SquatAudioController) {

    // ---------------- STATE ----------------
    private var currentPhase = SquatPhase.STANDING
    private var repCount = 0

    private var isInsideRep = false
    private var reachedBottom = false
    private var violatedDepth = false

    private var minKneeAngleThisRep = 180f

    // ---------------- DEPTH PROFILE ----------------
    data class DepthProfile(
        val minAllowed: Float,   // required depth (bottom target)
        val maxAllowed: Float    // upper bound for mode validity
    )

    private var depthProfile = DepthProfile(90f, 180f)

    fun setDepthThreshold(angle: Float) {
        depthProfile = when (angle) {

            // 1/4 squat → shallow only
            135f -> DepthProfile(
                minAllowed = 120f,
                maxAllowed = 170f
            )

            // 1/2 squat → medium
            110f -> DepthProfile(
                minAllowed = 100f,
                maxAllowed = 140f
            )

            // full squat → deep allowed
            90f -> DepthProfile(
                minAllowed = 70f,
                maxAllowed = 180f
            )

            else -> DepthProfile(70f, 180f)
        }
    }

    // ---------------- SMOOTHING ----------------
    private val kneeAngleBuffer = FloatArray(5)
    private var bufferIndex = 0

    private val faultsAnnouncedThisRep = mutableSetOf<SquatFault>()

    // ---------------- MAIN ENTRY ----------------
    fun analyze(frame: PoseFramePayload): SquatFeedback? {

        val lm = frame.landmarks.associateBy { it.index }

        val leftProfileValid = listOf(
            LM.LEFT_SHOULDER, LM.LEFT_HIP, LM.LEFT_KNEE, LM.LEFT_ANKLE
        ).all {
            val l = lm[it]
            l != null && (l.visibility ?: 0f) > 0.45f && (l.presence ?: 0f) > 0.45f
        }

        val rightProfileValid = listOf(
            LM.RIGHT_SHOULDER, LM.RIGHT_HIP, LM.RIGHT_KNEE, LM.RIGHT_ANKLE
        ).all {
            val l = lm[it]
            l != null && (l.visibility ?: 0f) > 0.45f && (l.presence ?: 0f) > 0.45f
        }

        if (!leftProfileValid && !rightProfileValid) return null

        val useLeftSide = when {
            leftProfileValid && !rightProfileValid -> true
            !leftProfileValid && rightProfileValid -> false
            else -> {
                val leftScore = listOf(
                    LM.LEFT_SHOULDER, LM.LEFT_HIP, LM.LEFT_KNEE, LM.LEFT_ANKLE
                ).sumOf { lm[it]?.visibility ?: 0f }

                val rightScore = listOf(
                    LM.RIGHT_SHOULDER, LM.RIGHT_HIP, LM.RIGHT_KNEE, LM.RIGHT_ANKLE
                ).sumOf { lm[it]?.visibility ?: 0f }

                leftScore >= rightScore
            }
        }

        val hip = if (useLeftSide) lm[LM.LEFT_HIP]!! else lm[LM.RIGHT_HIP]!!
        val knee = if (useLeftSide) lm[LM.LEFT_KNEE]!! else lm[LM.RIGHT_KNEE]!!
        val ankle = if (useLeftSide) lm[LM.LEFT_ANKLE]!! else lm[LM.RIGHT_ANKLE]!!
        val shoulder = if (useLeftSide) lm[LM.LEFT_SHOULDER]!! else lm[LM.RIGHT_SHOULDER]!!

        val w = frame.frameWidth
        val h = frame.frameHeight

        val rawKneeAngle = calculateAngle(hip, knee, ankle, w, h)
        val hipAngle = calculateAngle(shoulder, hip, knee, w, h)

        // smoothing
        kneeAngleBuffer[bufferIndex % kneeAngleBuffer.size] = rawKneeAngle
        bufferIndex++

        val kneeAngle = kneeAngleBuffer
            .take(minOf(bufferIndex, kneeAngleBuffer.size))
            .average()
            .toFloat()

        updatePhaseAndReps(kneeAngle)

        val faults = detectFaults(kneeAngle, hipAngle, lm, true, w, h)
        triggerAudioFeedback(faults)

        return SquatFeedback(
            phase = currentPhase,
            repCount = repCount,
            activeFaults = faults,
            kneeAngle = kneeAngle,
            hipAngle = hipAngle,
            isLandmarkReliable = true
        )
    }

    // ---------------- CORE STATE MACHINE ----------------
    private fun updatePhaseAndReps(kneeAngle: Float) {

        val min = depthProfile.minAllowed
        val max = depthProfile.maxAllowed

        // HARD VIOLATION (too deep for selected mode)
        if (kneeAngle < min - 10f) {
            violatedDepth = true
            audioController.playCue("too_low")
        }

        // START REP
        if (kneeAngle < max) {
            if (!isInsideRep) {
                isInsideRep = true
                reachedBottom = false
                violatedDepth = false
                minKneeAngleThisRep = 180f
            }

            if (kneeAngle < minKneeAngleThisRep) {
                minKneeAngleThisRep = kneeAngle
            }
        }

        // BOTTOM CONFIRMATION
        if (kneeAngle <= min) {
            reachedBottom = true
        }

        // END REP (standing again)
        val isStanding = kneeAngle > max - 5f

        if (isInsideRep && isStanding) {

            val validRep =
                reachedBottom &&
                !violatedDepth &&
                minKneeAngleThisRep <= max

            if (validRep) {
                repCount++
            }

            // reset cycle
            isInsideRep = false
            reachedBottom = false
            violatedDepth = false
            minKneeAngleThisRep = 180f
            faultsAnnouncedThisRep.clear()
        }

        currentPhase = when {
            !isInsideRep -> SquatPhase.STANDING
            kneeAngle <= min -> SquatPhase.BOTTOM
            kneeAngle < max -> SquatPhase.DESCENDING
            else -> SquatPhase.ASCENDING
        }
    }

    // ---------------- FAULT DETECTION ----------------
    private fun detectFaults(
        kneeAngle: Float,
        hipAngle: Float,
        lm: Map<Int, PoseLandmarkPayload>,
        isFrontView: Boolean,
        w: Int,
        h: Int
    ): List<SquatFault> {

        val faults = mutableListOf<SquatFault>()

        if (currentPhase != SquatPhase.STANDING) {

            if (currentPhase == SquatPhase.ASCENDING &&
                minKneeAngleThisRep > depthProfile.minAllowed + 15f
            ) {
                faults.add(SquatFault.GO_DEEPER)
            }

            if (kneeAngle < 130f) {

                if (isFrontView) {
                    val leftShoulder = lm[LM.LEFT_SHOULDER]!!
                    val rightShoulder = lm[LM.RIGHT_SHOULDER]!!
                    val leftHip = lm[LM.LEFT_HIP]!!
                    val rightHip = lm[LM.RIGHT_HIP]!!

                    val shoulderWidthPx =
                        abs((leftShoulder.x * w) - (rightShoulder.x * w))

                    val avgTorsoHeightPx =
                        (abs((leftShoulder.y * h) - (leftHip.y * h)) +
                                abs((rightShoulder.y * h) - (rightHip.y * h))) / 2f

                    if (avgTorsoHeightPx < shoulderWidthPx * 0.78f) {
                        faults.add(SquatFault.LEAN_FORWARD)
                    }
                } else {
                    if (hipAngle < 55f) {
                        faults.add(SquatFault.LEAN_FORWARD)
                    }
                }
            }

            if (isFrontView && kneeAngle < 125f) {

                val leftKnee = lm[LM.LEFT_KNEE]!!
                val rightKnee = lm[LM.RIGHT_KNEE]!!
                val leftAnkle = lm[LM.LEFT_ANKLE]!!
                val rightAnkle = lm[LM.RIGHT_ANKLE]!!

                val ankleMidX =
                    ((leftAnkle.x * w) + (rightAnkle.x * w)) / 2f

                val caveThreshold = abs((lm[LM.LEFT_SHOULDER]!!.x * w) -
                        (lm[LM.RIGHT_SHOULDER]!!.x * w)) * 0.15f

                val leftKneeDist = abs((leftKnee.x * w) - ankleMidX)
                val rightKneeDist = abs((rightKnee.x * w) - ankleMidX)

                val leftAnkleDist = abs((leftAnkle.x * w) - ankleMidX)
                val rightAnkleDist = abs((rightAnkle.x * w) - ankleMidX)

                if (leftKneeDist < leftAnkleDist - caveThreshold) {
                    faults.add(SquatFault.LEFT_KNEE_CAVE)
                }

                if (rightKneeDist < rightAnkleDist - caveThreshold) {
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
        isInsideRep = false
        reachedBottom = false
        violatedDepth = false
        minKneeAngleThisRep = 180f
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
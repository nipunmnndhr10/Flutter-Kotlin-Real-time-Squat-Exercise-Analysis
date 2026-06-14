package com.example.flt_kotlin_pose

import kotlin.math.abs
import kotlin.math.atan2

class SquatHeuristicEngine(private val audioController: SquatAudioController) {

    // ---------------- STATE ----------------
    private var currentPhase = SquatPhase.STANDING
    private var repCount = 0

    private var isInsideRep = false
    private var violatedDepth = false

    private var minKneeAngleThisRep = 180f
    private var maxDepthReachedThisRep = 180f

    // ---------------- DEPTH PROFILE ----------------
    data class DepthProfile(
        val targetBottom: Float,   // ideal bottom
        val maxAllowed: Float      // standing cutoff
    )

    private var depthProfile = DepthProfile(90f, 180f)

    fun setDepthThreshold(angle: Float) {
        depthProfile = when (angle) {

            140f -> DepthProfile(130f, 175f) // 1/4 squat
            120f -> DepthProfile(105f, 150f) // 1/2 squat
            90f  -> DepthProfile(70f, 180f)  // full squat

            else -> DepthProfile(70f, 180f)
        }
    }

    // ---------------- SMOOTHING ----------------
    private val kneeAngleBuffer = FloatArray(5)
    private var bufferIndex = 0

    private val faultsAnnouncedThisRep = mutableSetOf<SquatFault>()

    // ---------------- COOLDOWN ----------------
    private val faultCooldowns = HashMap<SquatFault, Long>()
    private val faultCooldownTime = 900L

    // ---------------- MAIN ----------------
    fun analyze(frame: PoseFramePayload): SquatFeedback? {

        val lm = frame.landmarks.associateBy { it.index }

        val leftValid = listOf(
            LM.LEFT_SHOULDER, LM.LEFT_HIP, LM.LEFT_KNEE, LM.LEFT_ANKLE
        ).all { lm[it]?.visibility ?: 0f > 0.45f }

        val rightValid = listOf(
            LM.RIGHT_SHOULDER, LM.RIGHT_HIP, LM.RIGHT_KNEE, LM.RIGHT_ANKLE
        ).all { lm[it]?.visibility ?: 0f > 0.45f }

        if (!leftValid && !rightValid) return null

        val useLeft = when {
            leftValid && !rightValid -> true
            !leftValid && rightValid -> false
            else -> {
                val l = listOf(LM.LEFT_SHOULDER, LM.LEFT_HIP, LM.LEFT_KNEE, LM.LEFT_ANKLE)
                    .sumOf { (lm[it]?.visibility ?: 0f).toDouble() }

                val r = listOf(LM.RIGHT_SHOULDER, LM.RIGHT_HIP, LM.RIGHT_KNEE, LM.RIGHT_ANKLE)
                    .sumOf { (lm[it]?.visibility ?: 0f).toDouble() }

                l >= r
            }
        }

        val hip = if (useLeft) lm[LM.LEFT_HIP]!! else lm[LM.RIGHT_HIP]!!
        val knee = if (useLeft) lm[LM.LEFT_KNEE]!! else lm[LM.RIGHT_KNEE]!!
        val ankle = if (useLeft) lm[LM.LEFT_ANKLE]!! else lm[LM.RIGHT_ANKLE]!!
        val shoulder = if (useLeft) lm[LM.LEFT_SHOULDER]!! else lm[LM.RIGHT_SHOULDER]!!

        val w = frame.frameWidth
        val h = frame.frameHeight

        val rawAngle = calculateAngle(hip, knee, ankle, w, h)
        val hipAngle = calculateAngle(shoulder, hip, knee, w, h)

        // ---------------- SMOOTHING ----------------
        kneeAngleBuffer[bufferIndex % kneeAngleBuffer.size] = rawAngle
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

    // ---------------- FIXED CORE LOGIC ----------------
    private fun updatePhaseAndReps(kneeAngle: Float) {

        val bottom = depthProfile.targetBottom
        val top = depthProfile.maxAllowed

        // track deepest point in rep
        if (kneeAngle < maxDepthReachedThisRep) {
            maxDepthReachedThisRep = kneeAngle
        }

        // start rep
        if (kneeAngle < top) {
            if (!isInsideRep) {
                isInsideRep = true
                violatedDepth = false
                minKneeAngleThisRep = 180f
                maxDepthReachedThisRep = 180f
            }

            if (kneeAngle < minKneeAngleThisRep) {
                minKneeAngleThisRep = kneeAngle
            }
        }

        // ❗ IMPROVED TOO_LOW LOGIC (FIXED FOR ALL MODES)
        val tooLowThreshold = bottom - when {
            bottom >= 125f -> 8f   // shallow squat
            bottom >= 100f -> 10f  // mid squat
            else -> 12f            // deep squat
        }

        if (kneeAngle < tooLowThreshold) {
            violatedDepth = true
            audioController.playCue("too_low")
        }

        // end rep condition (standing)
        val isStanding = kneeAngle > top - 6f

        if (isInsideRep && isStanding) {

            val depthAchieved =
                maxDepthReachedThisRep <= (bottom + 15f)

            val validRep = depthAchieved && !violatedDepth

            if (validRep) {
                repCount++
            }

            // reset
            isInsideRep = false
            violatedDepth = false
            minKneeAngleThisRep = 180f
            maxDepthReachedThisRep = 180f
            faultsAnnouncedThisRep.clear()
        }

        currentPhase = when {
            !isInsideRep -> SquatPhase.STANDING
            kneeAngle <= bottom -> SquatPhase.BOTTOM
            kneeAngle < top -> SquatPhase.DESCENDING
            else -> SquatPhase.ASCENDING
        }
    }

    // ---------------- FAULTS ----------------
    private fun detectFaults(
        kneeAngle: Float,
        hipAngle: Float,
        lm: Map<Int, PoseLandmarkPayload>,
        isFrontView: Boolean,
        w: Int,
        h: Int
    ): List<SquatFault> {

        val faults = mutableListOf<SquatFault>()
        val now = System.currentTimeMillis()

        fun addFault(f: SquatFault) {
            val last = faultCooldowns[f] ?: 0L
            if (now - last > faultCooldownTime) {
                faultCooldowns[f] = now
                faults.add(f)
            }
        }

        if (currentPhase == SquatPhase.STANDING) return faults

        if (kneeAngle < 130f) {

            if (isFrontView) {
                val lS = lm[LM.LEFT_SHOULDER]!!
                val rS = lm[LM.RIGHT_SHOULDER]!!
                val lH = lm[LM.LEFT_HIP]!!
                val rH = lm[LM.RIGHT_HIP]!!

                val shoulderWidth = abs((lS.x * w) - (rS.x * w))
                val torsoHeight =
                    (abs((lS.y * h) - (lH.y * h)) +
                     abs((rS.y * h) - (rH.y * h))) / 2f

                if (torsoHeight < shoulderWidth * 0.78f) {
                    addFault(SquatFault.LEAN_FORWARD)
                }
            } else {
                if (hipAngle < 55f) addFault(SquatFault.LEAN_FORWARD)
            }
        }

        return faults
    }

    private fun triggerAudioFeedback(faults: List<SquatFault>) {
        for (f in faults) {
            if (!faultsAnnouncedThisRep.contains(f)) {
                faultsAnnouncedThisRep.add(f)
                audioController.playCue(f.cueName)
            }
        }
    }

    fun reset() {
        currentPhase = SquatPhase.STANDING
        repCount = 0
        isInsideRep = false
        violatedDepth = false
        minKneeAngleThisRep = 180f
        maxDepthReachedThisRep = 180f
        bufferIndex = 0
        kneeAngleBuffer.fill(0f)
        faultsAnnouncedThisRep.clear()
        faultCooldowns.clear()
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
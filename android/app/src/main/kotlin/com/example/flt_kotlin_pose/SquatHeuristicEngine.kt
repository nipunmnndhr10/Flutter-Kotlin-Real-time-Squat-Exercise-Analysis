package com.example.flt_kotlin_pose

import kotlin.math.abs
import kotlin.math.atan2

class SquatHeuristicEngine(private val audioController: SquatAudioController) {

    // ---------------- STATE ----------------
    private var currentPhase = SquatPhase.STANDING
    private var repCount = 0

    private var isInsideRep = false
    private var violatedDepth = false
    private var maxDepthReachedThisRep = 180f

    // For correct descending/ascending phase detection
    private var prevKneeAngle = 180f

    // ---------------- DEPTH PROFILE ----------------
    data class DepthProfile(
        val targetBottom: Float,
        val maxAllowed: Float,
    )

    private var depthProfile = DepthProfile(90f, 180f)

    fun setDepthThreshold(angle: Float) {
        depthProfile = when (angle) {
            140f -> DepthProfile(130f, 175f) // 1/4 squat
            120f -> DepthProfile(105f, 150f) // 1/2 squat
            90f  -> DepthProfile(70f, 180f)   // full squat
            else -> DepthProfile(70f, 180f)
        }
    }

    // ---------------- SMOOTHING (zero-allocation rolling average) ----------------
    private val kneeAngleBuffer = FloatArray(5)
    private var bufferIndex = 0
    private var bufferCount = 0
    private var rollingSum = 0f

    // ---------------- FAULT TRACKING ----------------
    private val faultsAnnouncedThisRep = mutableSetOf<SquatFault>()

    // Fixed-size cooldown array indexed by enum ordinal — no HashMap churn
    private val faultCooldowns = LongArray(SquatFault.entries.size) { 0L }
    private val faultCooldownTime = 900L

    // Pre-allocated landmark lookup — zero-allocation per frame
    private val landmarkArray = Array<PoseLandmarkPayload?>(33) { null }

    // ---------------- MAIN ----------------
    fun analyze(frame: PoseFramePayload): SquatFeedback? {
        // Zero-fill and populate lookup array
        landmarkArray.fill(null)
        for (lm in frame.landmarks) {
            if (lm.index in 0..32) landmarkArray[lm.index] = lm
        }

        val leftValid = listOf(
            LM.LEFT_SHOULDER, LM.LEFT_HIP, LM.LEFT_KNEE, LM.LEFT_ANKLE,
        ).all { landmarkArray[it]?.visibility ?: 0f > 0.45f }

        val rightValid = listOf(
            LM.RIGHT_SHOULDER, LM.RIGHT_HIP, LM.RIGHT_KNEE, LM.RIGHT_ANKLE,
        ).all { landmarkArray[it]?.visibility ?: 0f > 0.45f }

        if (!leftValid && !rightValid) return null

        val useLeft = when {
            leftValid && !rightValid -> true
            !leftValid && rightValid -> false
            else -> {
                val l = listOf(LM.LEFT_SHOULDER, LM.LEFT_HIP, LM.LEFT_KNEE, LM.LEFT_ANKLE)
                    .sumOf { (landmarkArray[it]?.visibility ?: 0f).toDouble() }
                val r = listOf(LM.RIGHT_SHOULDER, LM.RIGHT_HIP, LM.RIGHT_KNEE, LM.RIGHT_ANKLE)
                    .sumOf { (landmarkArray[it]?.visibility ?: 0f).toDouble() }
                l >= r
            }
        }

        val hip = if (useLeft) landmarkArray[LM.LEFT_HIP] ?: return null else landmarkArray[LM.RIGHT_HIP] ?: return null
        val knee = if (useLeft) landmarkArray[LM.LEFT_KNEE] ?: return null else landmarkArray[LM.RIGHT_KNEE] ?: return null
        val ankle = if (useLeft) landmarkArray[LM.LEFT_ANKLE] ?: return null else landmarkArray[LM.RIGHT_ANKLE] ?: return null
        val shoulder = if (useLeft) landmarkArray[LM.LEFT_SHOULDER] ?: return null else landmarkArray[LM.RIGHT_SHOULDER] ?: return null

        val w = frame.frameWidth
        val h = frame.frameHeight

        // Compute BOTH knee angles so we track the most-bent side.
        // This ensures a caved knee is detected even if useLeft picked the straight side.
        val leftKneeAngle = if (leftValid) {
            val lH = landmarkArray[LM.LEFT_HIP]!!
            val lK = landmarkArray[LM.LEFT_KNEE]!!
            val lA = landmarkArray[LM.LEFT_ANKLE]!!
            calculateAngle(lH, lK, lA, w, h)
        } else 180f

        val rightKneeAngle = if (rightValid) {
            val rH = landmarkArray[LM.RIGHT_HIP]!!
            val rK = landmarkArray[LM.RIGHT_KNEE]!!
            val rA = landmarkArray[LM.RIGHT_ANKLE]!!
            calculateAngle(rH, rK, rA, w, h)
        } else 180f

        val rawAngle = minOf(leftKneeAngle, rightKneeAngle)
        val hipAngle = calculateAngle(shoulder, hip, knee, w, h)

        // Rolling-sum smoothing — zero allocation
        val slot = bufferIndex % kneeAngleBuffer.size
        rollingSum += rawAngle - kneeAngleBuffer[slot]
        kneeAngleBuffer[slot] = rawAngle
        bufferIndex++
        if (bufferCount < kneeAngleBuffer.size) bufferCount++
        val kneeAngle = rollingSum / bufferCount

        // Auto-detect front vs side view from shoulder spread
        val isFrontView = run {
            val lS = landmarkArray[LM.LEFT_SHOULDER]
            val rS = landmarkArray[LM.RIGHT_SHOULDER]
            if (lS == null || rS == null) return@run false
            val shoulderWidth = abs((lS.x * w) - (rS.x * w))
            shoulderWidth > w * 0.08f  // at least 8% of frame width
        }

        val tooLowFault = updatePhaseAndReps(kneeAngle)
        val faults = detectFaults(kneeAngle, hipAngle, landmarkArray, isFrontView, w, h)
        val allFaults = if (tooLowFault != null) faults + tooLowFault else faults
        triggerAudioFeedback(allFaults)

        return SquatFeedback(
            phase = currentPhase,
            repCount = repCount,
            activeFaults = allFaults,
            kneeAngle = kneeAngle,
            hipAngle = hipAngle,
            isLandmarkReliable = true,
        )
    }

    // ---------------- CORE LOGIC ----------------
    private fun updatePhaseAndReps(kneeAngle: Float): SquatFault? {
        val bottom = depthProfile.targetBottom
        val top = depthProfile.maxAllowed
        var tooLowFault: SquatFault? = null

        // Track deepest point in rep
        if (kneeAngle < maxDepthReachedThisRep) {
            maxDepthReachedThisRep = kneeAngle
        }

        // Start rep
        if (kneeAngle < top) {
            if (!isInsideRep) {
                isInsideRep = true
                violatedDepth = false
                maxDepthReachedThisRep = 180f
                prevKneeAngle = kneeAngle
            }
        }

        // Too-low detection (unified as a SquatFault)
        val tooLowThreshold = bottom - when {
            bottom >= 125f -> 8f   // shallow squat
            bottom >= 100f -> 10f  // mid squat
            else -> 12f            // deep squat
        }

        if (kneeAngle < tooLowThreshold) {
            violatedDepth = true
            tooLowFault = SquatFault.TOO_LOW
        }

        // End rep condition (standing)
        val isStanding = kneeAngle > top - 6f

        if (isInsideRep && isStanding) {
            val depthAchieved = maxDepthReachedThisRep <= (bottom + 15f)
            val validRep = depthAchieved && !violatedDepth

            if (validRep) {
                repCount++
            }

            // Reset
            isInsideRep = false
            violatedDepth = false
            maxDepthReachedThisRep = 180f
            prevKneeAngle = 180f
            faultsAnnouncedThisRep.clear()
        }

        // FIX: Distinguish descending vs ascending using angle trend.
        // Without this, any angle between bottom and top is incorrectly
        // labelled DESCENDING even when the user is coming up.
        val isDescending = kneeAngle < prevKneeAngle - 1.5f
        prevKneeAngle = kneeAngle

        currentPhase = when {
            !isInsideRep -> SquatPhase.STANDING
            kneeAngle <= bottom -> SquatPhase.BOTTOM
            isDescending -> SquatPhase.DESCENDING
            else -> SquatPhase.ASCENDING
        }

        return tooLowFault
    }

    // ---------------- FAULTS (all 5 now initialized) ----------------
    private fun detectFaults(
        kneeAngle: Float,
        hipAngle: Float,
        lm: Array<PoseLandmarkPayload?>,
        isFrontView: Boolean,
        w: Int,
        h: Int,
    ): List<SquatFault> {
        val bottom = depthProfile.targetBottom
        val top = depthProfile.maxAllowed
        val faults = mutableListOf<SquatFault>()
        val now = System.currentTimeMillis()

        fun addFault(f: SquatFault) {
            val last = faultCooldowns[f.ordinal]
            if (now - last > faultCooldownTime) {
                faultCooldowns[f.ordinal] = now
                faults.add(f)
            }
        }

        if (currentPhase == SquatPhase.STANDING) return faults

        // 1) GO_DEEPER — descending but not deep enough yet
        if (currentPhase == SquatPhase.DESCENDING &&
            kneeAngle > depthProfile.targetBottom + 15f &&
            kneeAngle < depthProfile.maxAllowed - 10f
        ) {
            addFault(SquatFault.GO_DEEPER)
        }

        // 2) LEAN_FORWARD — front view via torso ratio, side view via hip angle
        if (kneeAngle < 130f) {
            if (isFrontView) {
                val lS = lm[LM.LEFT_SHOULDER]
                val rS = lm[LM.RIGHT_SHOULDER]
                val lH = lm[LM.LEFT_HIP]
                val rH = lm[LM.RIGHT_HIP]

                if (lS == null || rS == null || lH == null || rH == null) return faults

                val shoulderWidth = abs((lS.x * w) - (rS.x * w))
                val torsoHeight =
                    (abs((lS.y * h) - (lH.y * h)) + abs((rS.y * h) - (rH.y * h))) / 2f

                if (torsoHeight < shoulderWidth * 0.78f) {
                    addFault(SquatFault.LEAN_FORWARD)
                }
            } else {
                if (hipAngle < 55f) addFault(SquatFault.LEAN_FORWARD)
            }
        }

        // 3) KNEE CAVE — front view only; use the MINIMUM of both knee angles
        // so a caved side is detected even if the other side is straight.
        if (isFrontView) {
            val lH = lm[LM.LEFT_HIP]
            val lK = lm[LM.LEFT_KNEE]
            val lA = lm[LM.LEFT_ANKLE]
            val leftKneeAngle = if (lH != null && lK != null && lA != null)
                calculateAngle(lH, lK, lA, w, h) else 180f

            val rH = lm[LM.RIGHT_HIP]
            val rK = lm[LM.RIGHT_KNEE]
            val rA = lm[LM.RIGHT_ANKLE]
            val rightKneeAngle = if (rH != null && rK != null && rA != null)
                calculateAngle(rH, rK, rA, w, h) else 180f

            val minKneeAngle = minOf(leftKneeAngle, rightKneeAngle)
            if (minKneeAngle < 150f) {
                if (lK != null && lA != null) {
                    // Left knee caves inward → x increases toward the center
                    if (lK.x > lA.x + 0.03f) {
                        addFault(SquatFault.LEFT_KNEE_CAVE)
                    }
                }
                if (rK != null && rA != null) {
                    // Right knee caves inward → x decreases toward the center
                    if (rK.x < rA.x - 0.03f) {
                        addFault(SquatFault.RIGHT_KNEE_CAVE)
                    }
                }
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
        maxDepthReachedThisRep = 180f
        prevKneeAngle = 180f
        bufferIndex = 0
        bufferCount = 0
        rollingSum = 0f
        kneeAngleBuffer.fill(0f)
        faultsAnnouncedThisRep.clear()
        faultCooldowns.fill(0L)
    }

    private fun calculateAngle(
        a: PoseLandmarkPayload,
        b: PoseLandmarkPayload,
        c: PoseLandmarkPayload,
        width: Int,
        height: Int,
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

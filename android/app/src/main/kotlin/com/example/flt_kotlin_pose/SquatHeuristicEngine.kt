package com.example.flt_kotlin_pose

import kotlin.math.abs
import kotlin.math.atan2

class SquatHeuristicEngine(private val audioController: SquatAudioController) {

    // ---------------- STATE ----------------
    private var currentPhase = SquatPhase.STANDING
    private var repCount = 0

    private var isInsideRep = false
    private var maxDepthReachedThisRep = 180f
    private var standingHipYBaseline: Float? = null
    private var maxHipDropThisRep = 0f
    private var hasLeftStandingThisRep = false
    private var tooLowFrameStreak = 0

    // For correct descending/ascending phase detection
    private var prevKneeAngle = 180f

    // ---------------- DEPTH PROFILE ----------------
    data class DepthProfile(
        val targetBottom: Float,
        val repStart: Float,
        val standing: Float,
        val hipDropTarget: Float,
    )

    private var activePreset = SquatDepthPreset.DEFAULT
    // Default to Full Squat but with a more forgiving target (100° instead of 90°)
    private var depthProfile = DepthProfile(100f, 155f, 165f, 0.11f)

    fun setDepthThreshold(angle: Float) {
        activePreset = SquatDepthPreset.fromAngle(angle)
        depthProfile = when (activePreset) {
            // Camera perspective often makes angles appear 5-10° wider than reality.
            // We pad the target bottoms to make the app feel accurate to the user.
            SquatDepthPreset.QUARTER_SQUAT -> DepthProfile(145f, 163f, 170f, 0.045f)
            SquatDepthPreset.HALF_SQUAT -> DepthProfile(125f, 158f, 166f, 0.085f)
            SquatDepthPreset.FULL_SQUAT -> DepthProfile(100f, 155f, 165f, 0.11f)
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

    // ---------------- SUMMARY STATISTICS ----------------
    private var sessionFrameCount = 0
    private var sessionSumKneeAngle = 0f
    private var sessionSumHipAngle = 0f
    private var sessionMinKneeAngle = 180f
    private var sessionMinHipAngle = 180f
    private var sessionStartTime = 0L
    private var sessionPausedAt = 0L
    private var sessionPausedMillis = 0L
    @Volatile private var isPaused = false

    data class WorkoutSummary(
        val avgKneeAngle: Float,
        val avgHipAngle: Float,
        val minKneeAngle: Float,
        val minHipAngle: Float,
        val durationSeconds: Long,
        val totalReps: Int
    )

    fun endWorkoutSummary(): WorkoutSummary? {
        if (sessionFrameCount == 0 || sessionStartTime == 0L) return null

        val now = System.currentTimeMillis()
        val pausedMillis = sessionPausedMillis + if (sessionPausedAt != 0L) now - sessionPausedAt else 0L
        val durationSeconds = ((now - sessionStartTime - pausedMillis).coerceAtLeast(0L)) / 1000L
        val avgKneeAngle = sessionSumKneeAngle / sessionFrameCount
        val avgHipAngle = sessionSumHipAngle / sessionFrameCount

        return WorkoutSummary(
            avgKneeAngle = avgKneeAngle,
            avgHipAngle = avgHipAngle,
            minKneeAngle = sessionMinKneeAngle,
            minHipAngle = sessionMinHipAngle,
            durationSeconds = durationSeconds,
            totalReps = repCount
        )
    }

    fun pauseWorkoutTimer() {
        if (sessionPausedAt == 0L) {
            sessionPausedAt = System.currentTimeMillis()
        }
    }

    fun resumeWorkoutTimer() {
        if (sessionPausedAt != 0L) {
            sessionPausedMillis += System.currentTimeMillis() - sessionPausedAt
            sessionPausedAt = 0L
        }
    }

    fun pauseAnalysis() {
        isPaused = true
    }

    fun resumeAnalysis() {
        isPaused = false
    }

    // ---------------- MAIN ----------------
    fun analyze(frame: PoseFramePayload): SquatFeedback? {
        if (isPaused) return null

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

        // Auto-detect front vs side view from shoulder spread
        val isFrontView = run {
            val lS = landmarkArray[LM.LEFT_SHOULDER]
            val rS = landmarkArray[LM.RIGHT_SHOULDER]
            if (lS == null || rS == null) return@run false
            val shoulderWidthNorm = abs(lS.x - rS.x)
            shoulderWidthNorm > 0.08f  // at least 8% of normalized frame width
        }

        // Compute both knee angles. Use bilateral averaging only in front view;
        // in side view we rely on the single most reliable visible side.
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

        val rawAngle = when {
            isFrontView && leftValid && rightValid -> (leftKneeAngle + rightKneeAngle) / 2f
            leftValid -> leftKneeAngle
            rightValid -> rightKneeAngle
            else -> 180f
        }
        val hipAngle = calculateAngle(shoulder, hip, knee, w, h)
        val hipY = if (leftValid && rightValid) {
            ((landmarkArray[LM.LEFT_HIP]?.y ?: hip.y) + (landmarkArray[LM.RIGHT_HIP]?.y ?: hip.y)) / 2f
        } else {
            hip.y
        }

        // Rolling-sum smoothing — zero allocation
        val slot = bufferIndex % kneeAngleBuffer.size
        rollingSum += rawAngle - kneeAngleBuffer[slot]
        kneeAngleBuffer[slot] = rawAngle
        bufferIndex++
        if (bufferCount < kneeAngleBuffer.size) bufferCount++
        val kneeAngle = rollingSum / bufferCount

        val tooLowFault = updatePhaseAndReps(kneeAngle, hipY)
        val faults = detectFaults(kneeAngle, hipAngle, landmarkArray, isFrontView, w, h)
        val allFaults = if (tooLowFault != null) faults + tooLowFault else faults

        if (isPaused) return null

        triggerAudioFeedback(allFaults)

        // Update session summary statistics
        if (isPaused) return null

        if (sessionStartTime == 0L) {
            sessionStartTime = System.currentTimeMillis()
        }
        sessionFrameCount++
        sessionSumKneeAngle += kneeAngle
        sessionSumHipAngle += hipAngle
        if (kneeAngle < sessionMinKneeAngle) sessionMinKneeAngle = kneeAngle
        if (hipAngle < sessionMinHipAngle) sessionMinHipAngle = hipAngle

        return SquatFeedback(
            phase = currentPhase,
            repCount = repCount,
            activeFaults = allFaults,
            kneeAngle = kneeAngle,
            hipAngle = hipAngle,
            isLandmarkReliable = true,
            activePreset = activePreset,
        )
    }

    // ---------------- CORE LOGIC ----------------
    private fun updatePhaseAndReps(kneeAngle: Float, hipY: Float): SquatFault? {
        val bottom = depthProfile.targetBottom
        val repStart = depthProfile.repStart
        val standing = depthProfile.standing
        var tooLowFault: SquatFault? = null

        val hipBaseline = standingHipYBaseline
        val hipDrop = hipBaseline?.let { hipY - it } ?: 0f

        // Track deepest point in rep
        if (kneeAngle < maxDepthReachedThisRep) {
            maxDepthReachedThisRep = kneeAngle
        }
        if (hipDrop > maxHipDropThisRep) {
            maxHipDropThisRep = hipDrop
        }

        // Start rep
        if (kneeAngle < repStart || hipDrop >= depthProfile.hipDropTarget * 0.6f) {
            if (!isInsideRep) {
                isInsideRep = true
                maxDepthReachedThisRep = kneeAngle
                maxHipDropThisRep = maxOf(0f, hipDrop)
                hasLeftStandingThisRep = false
            }
        }

        // hasLeftStandingThisRep is necessary to prevent immediate rep termination
        // when a rep is triggered by hip drop while the knee angle is still above standing.
        if (isInsideRep && kneeAngle <= standing) {
            hasLeftStandingThisRep = true
        }

        // Too-low detection (unified as a SquatFault)
        // Made buffers wider so we don't accidentally fire "too low" for good full squats.
        val tooLowThreshold = bottom - when {
            bottom >= 140f -> 15f  // quarter squat
            bottom >= 120f -> 20f  // half squat
            else -> 25f            // full squat (e.g., target 100, fires if < 75)
        }

        if (isInsideRep && kneeAngle < tooLowThreshold) {
            tooLowFrameStreak++
        } else {
            tooLowFrameStreak = 0
        }

        // Require a short sustained violation to avoid one-frame jitter false positives.
        if (tooLowFrameStreak >= 3) {
            tooLowFault = SquatFault.TOO_LOW
        }

        // End rep condition (standing)
        val isStanding = kneeAngle > standing

        if (isInsideRep && isStanding && hasLeftStandingThisRep) {
            val kneeDepthAchieved = maxDepthReachedThisRep <= (bottom + 15f)
            val hipDepthAchieved = maxHipDropThisRep >= depthProfile.hipDropTarget
            val validRep = kneeDepthAchieved || hipDepthAchieved

            if (validRep) {
                repCount++
            }

            // Reset
            isInsideRep = false
            maxDepthReachedThisRep = 180f
            maxHipDropThisRep = 0f
            hasLeftStandingThisRep = false
            tooLowFrameStreak = 0
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

        if (currentPhase == SquatPhase.STANDING) {
            standingHipYBaseline = standingHipYBaseline
                ?.let { (it * 0.9f) + (hipY * 0.1f) }
                ?: hipY
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
        val formCheckGate = when (activePreset) {
            SquatDepthPreset.QUARTER_SQUAT -> 148f
            SquatDepthPreset.HALF_SQUAT -> 132f
            SquatDepthPreset.FULL_SQUAT -> 130f
        }
        val kneeCaveAngleGate = when (activePreset) {
            SquatDepthPreset.QUARTER_SQUAT -> 152f
            SquatDepthPreset.HALF_SQUAT -> 144f
            SquatDepthPreset.FULL_SQUAT -> 145f
        }
        // Increased from ~0.045 to 0.06 to allow natural wobble without triggering a fault.
        val kneeCaveOffsetGate = when (activePreset) {
            SquatDepthPreset.QUARTER_SQUAT -> 0.065f
            SquatDepthPreset.HALF_SQUAT -> 0.06f
            SquatDepthPreset.FULL_SQUAT -> 0.06f
        }
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

        // 1) GO_DEEPER — only when the user starts ascending without reaching target depth.
        // This avoids repeatedly cueing "go deeper" while the user is still descending.
        if (currentPhase == SquatPhase.ASCENDING &&
            maxDepthReachedThisRep > depthProfile.targetBottom + 12f &&
            kneeAngle < depthProfile.repStart
        ) {
            addFault(SquatFault.GO_DEEPER)
        }

        // 2) LEAN_FORWARD — front view via torso ratio, side view via hip angle
        if (kneeAngle < formCheckGate) {
            if (isFrontView) {
                val lS = lm[LM.LEFT_SHOULDER]
                val rS = lm[LM.RIGHT_SHOULDER]
                val lH = lm[LM.LEFT_HIP]
                val rH = lm[LM.RIGHT_HIP]

                if (lS != null && rS != null && lH != null && rH != null) {
                    val shoulderWidth = abs((lS.x * w) - (rS.x * w))
                    val torsoHeight =
                        (abs((lS.y * h) - (lH.y * h)) + abs((rS.y * h) - (rH.y * h))) / 2f

                    // Relaxed from 0.68f to 0.62f to allow more natural lean for longer femurs.
                    if (torsoHeight < shoulderWidth * 0.62f) {
                        addFault(SquatFault.LEAN_FORWARD)
                    }
                }
            } else {
                // Relaxed from 50f to 45f. A hip angle < 45 means very extreme forward lean.
                if (hipAngle < 45f) addFault(SquatFault.LEAN_FORWARD)
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
            if (minKneeAngle < kneeCaveAngleGate) {
                if (lK != null && lA != null) {
                    // Left knee caves inward → x decreases toward the center
                    if (lK.x < lA.x - kneeCaveOffsetGate) {
                        addFault(SquatFault.LEFT_KNEE_CAVE)
                    }
                }
                if (rK != null && rA != null) {
                    // Right knee caves inward → x increases toward the center
                    if (rK.x > rA.x + kneeCaveOffsetGate) {
                        addFault(SquatFault.RIGHT_KNEE_CAVE)
                    }
                }
            }
        }

        return faults
    }

    private fun triggerAudioFeedback(faults: List<SquatFault>) {
        val nextFault = faults.firstOrNull { it !in faultsAnnouncedThisRep } ?: return
        faultsAnnouncedThisRep.add(nextFault)
        audioController.playCue(nextFault.cueName)
    }

    fun reset() {
        currentPhase = SquatPhase.STANDING
        repCount = 0
        isInsideRep = false
        maxDepthReachedThisRep = 180f
        standingHipYBaseline = null
        maxHipDropThisRep = 0f
        hasLeftStandingThisRep = false
        tooLowFrameStreak = 0
        prevKneeAngle = 180f
        bufferIndex = 0
        bufferCount = 0
        rollingSum = 0f
        kneeAngleBuffer.fill(0f)
        faultsAnnouncedThisRep.clear()
        faultCooldowns.fill(0L)

        // Reset summary statistics
        sessionFrameCount = 0
        sessionSumKneeAngle = 0f
        sessionSumHipAngle = 0f
        sessionMinKneeAngle = 180f
        sessionMinHipAngle = 180f
        sessionStartTime = 0L
        sessionPausedAt = 0L
        sessionPausedMillis = 0L
        isPaused = false
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

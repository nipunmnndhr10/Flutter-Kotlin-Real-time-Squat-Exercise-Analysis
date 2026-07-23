package com.example.flt_kotlin_pose

import android.os.SystemClock
import kotlin.math.abs

class SquatHeuristicEngine(private val audioController: SquatAudioController) {

    // State variables
    private var currentPhase = SquatPhase.STANDING
    private var repCount = 0

    private var isInsideRep = false
    private var maxDepthReachedThisRep = 180f
    private var standingHipYBaseline: Float? = null
    private var maxHipDropThisRep = 0f
    private var hasLeftStandingThisRep = false
    private var tooLowFrameStreak = 0

    // Debounce / hysteresis counters — prevents jitter at phase boundaries.
    // repStartFrameStreak: how many consecutive frames the "wants to start" condition
    //   has held. A rep only begins after 4 consecutive frames (~130ms at 30fps) to
    //   eliminate micro-bend false starts from postural shifts and camera wobble.
    // standingFrameStreak: how many consecutive frames the user has been above 'standing'.
    //   A rep only ends after 4 consecutive frames to prevent double-counting when the
    //   user briefly straightens then re-descends at the top.
    private var repStartFrameStreak = 0
    private var standingFrameStreak = 0

    // Phase-hold hysteresis: once a phase is entered, the opposite direction must sustain
    // for ≥3 consecutive frames before the phase actually flips. This prevents single-frame
    // and brief multi-frame noise from flickering the UI phase display.
    private var phaseHoldCounter = 0
    private var pendingPhase = SquatPhase.STANDING

    // Lean-forward (chest-up) detection: require 3 consecutive frames of the hip angle
    // being below the lean threshold before firing the fault. This prevents single-frame
    // jitter from triggering false chest-up warnings.
    private var leanForwardFrameStreak = 0

    // Raw (unsmoothed) angle ring buffer — used exclusively for velocity-based phase
    // direction. Comparing the current raw angle to the raw angle 6 frames ago gives a
    // lag-free descending/ascending signal that does not suffer from the rolling-average delay
    // that caused the smoothed angle to linger, flipping ASCENDING↔DESCENDING at transitions.
    // Expanded from 4→6 to match the wider 7-frame smoothing buffer and provide a more
    // stable velocity signal.
    private val rawAngleHistory = FloatArray(6) { 180f }
    private var rawHistIndex = 0

    // Depth profile configuration
    data class DepthProfile(
        val targetBottom: Float,
        val maxValidAngle: Float,
        val repStart: Float,
        val standing: Float,
    )

    private var activePreset = SquatDepthPreset.DEFAULT
    private var depthProfile = DepthProfile(
        targetBottom = 95f,
        maxValidAngle = 105f,
        repStart = 148f,
        standing = 162f,
    )

    fun setDepthThreshold(angle: Float) {
        activePreset = SquatDepthPreset.fromAngle(angle)
        depthProfile = when (activePreset) {
            SquatDepthPreset.QUARTER_SQUAT -> DepthProfile(140f, 148f, 155f, 165f)
            SquatDepthPreset.HALF_SQUAT    -> DepthProfile(120f, 130f, 150f, 162f)
            SquatDepthPreset.FULL_SQUAT    -> DepthProfile(95f, 105f, 148f, 162f)
        }
    }



    // STAGE 1 & 2: 3D Spatial Landmark Spike Guard + 3D Spatial 1€ Trajectory Filters
    private val lastLandmarkCoords = Array<PoseLandmarkPayload?>(33) { null }
    private val landmarkFilters = Array(33) { OneEuroFilter3D(minCutoffXY = 3.0f, betaXY = 0.5f, minCutoffZ = 1.5f, betaZ = 0.1f) }

    private var lastFilteredTorsoLength: Float? = null

    private fun getDynamicSpikeThreshold(): Float {
        val torso = lastFilteredTorsoLength ?: 0.35f
        return (1.5f * torso).coerceIn(0.25f, 0.60f)
    }

    private fun clampSpatialSpike(lm: PoseLandmarkPayload): PoseLandmarkPayload {
        val prev = lastLandmarkCoords[lm.index] ?: run {
            lastLandmarkCoords[lm.index] = lm
            return lm
        }
        val maxDelta = getDynamicSpikeThreshold()
        val cx = lm.x.coerceIn(prev.x - maxDelta, prev.x + maxDelta)
        val cy = lm.y.coerceIn(prev.y - maxDelta, prev.y + maxDelta)
        val cz = lm.z.coerceIn(prev.z - maxDelta, prev.z + maxDelta)
        val clamped = lm.copy(x = cx, y = cy, z = cz)
        lastLandmarkCoords[lm.index] = clamped
        return clamped
    }

    // Adaptive smoothing filters
    private val kneeAngleFilter = OneEuroFilter(minCutoff = 1.0f, beta = 0.015f, dCutoff = 1.0f)
    private val hipAngleFilter  = OneEuroFilter(minCutoff = 1.0f, beta = 0.015f, dCutoff = 1.0f)

    // Outlier Spike Guard tracking (clamps camera occlusion & lighting glare noise spikes before filtering)
    private var lastRawKneeAngle: Float? = null
    private var lastRawHipAngle: Float? = null

    private fun clampSpike(current: Float, last: Float?, maxDelta: Float = 45f): Float {
        if (last == null) return current
        val diff = current - last
        return when {
            diff > maxDelta  -> last + maxDelta
            diff < -maxDelta -> last - maxDelta
            else             -> current
        }
    }

    // Fault tracking
    private val faultsAnnouncedThisRep = mutableSetOf<SquatFault>()

    // Fixed-size cooldown array indexed by enum ordinal — no HashMap churn
    private val faultCooldowns = LongArray(SquatFault.entries.size) { 0L }
    private val faultCooldownTime = 900L

    // Pre-allocated landmark lookup — zero-allocation per frame
    private val landmarkArray = Array<PoseLandmarkPayload?>(33) { null }

    // Summary statistics
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

    // Analysis engine entry point
    fun analyze(frame: PoseFramePayload): SquatFeedback? {
        if (isPaused) return null

        // STAGE 1 & 2: 3D Spatial Landmark Spike Guard + 3D Spatial 1€ Trajectory Filtering
        landmarkArray.fill(null)
        val timestampMs = frame.timestampMs
        for (lm in frame.landmarks) {
            if (lm.index in 0..32) {
                val isVisible = (lm.visibility ?: 0f) >= 0.50f
                val clampedLm = clampSpatialSpike(lm)
                landmarkArray[lm.index] = landmarkFilters[lm.index].filter(lm, timestampMs, isVisible, clampedLm)
            }
        }

        // Raised visibility threshold from 0.45 → 0.50 for more reliable landmark selection.
        val leftValid = listOf(
            LM.LEFT_SHOULDER, LM.LEFT_HIP, LM.LEFT_KNEE, LM.LEFT_ANKLE,
        ).all { landmarkArray[it]?.visibility ?: 0f > 0.50f }

        val rightValid = listOf(
            LM.RIGHT_SHOULDER, LM.RIGHT_HIP, LM.RIGHT_KNEE, LM.RIGHT_ANKLE,
        ).all { landmarkArray[it]?.visibility ?: 0f > 0.50f }

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

        val hip      = if (useLeft) landmarkArray[LM.LEFT_HIP]      ?: return null else landmarkArray[LM.RIGHT_HIP]      ?: return null
        val knee     = if (useLeft) landmarkArray[LM.LEFT_KNEE]     ?: return null else landmarkArray[LM.RIGHT_KNEE]     ?: return null
        val ankle    = if (useLeft) landmarkArray[LM.LEFT_ANKLE]    ?: return null else landmarkArray[LM.RIGHT_ANKLE]    ?: return null
        val shoulder = if (useLeft) landmarkArray[LM.LEFT_SHOULDER] ?: return null else landmarkArray[LM.RIGHT_SHOULDER] ?: return null

        val w = frame.frameWidth
        val h = frame.frameHeight

        // Auto-detect front vs side view from shoulder spread.
        // Threshold raised from 0.08 → 0.15: shoulders must span ≥15% of normalised frame
        // width for the view to be classified as frontal. This suppresses knee-cave detection
        // in side and 3/4-angle views where mediolateral landmark tracking is unreliable.
        // Side view is the recommended and primary use-case for this app.
        val isFrontView = run {
            val lS = landmarkArray[LM.LEFT_SHOULDER]
            val rS = landmarkArray[LM.RIGHT_SHOULDER]
            if (lS == null || rS == null) return@run false
            val shoulderWidthNorm = abs(lS.x - rS.x)
            shoulderWidthNorm > 0.15f
        }

        // Compute both knee angles. Use bilateral averaging only in front view;
        // in side view rely on the single most-visible side.
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
            useLeft    -> leftKneeAngle
            else       -> rightKneeAngle
        }
        val hipAngle = calculateAngle(shoulder, hip, knee, w, h)
        val hipY = if (leftValid && rightValid) {
            ((landmarkArray[LM.LEFT_HIP]?.y ?: hip.y) + (landmarkArray[LM.RIGHT_HIP]?.y ?: hip.y)) / 2f
        } else {
            hip.y
        }

        // Outlier Spike Guard: clamp unphysical camera glare / occlusion angle jumps (> 45°) BEFORE 1€ filtering
        val clampedKneeAngle = clampSpike(rawAngle, lastRawKneeAngle, maxDelta = 45f)
        val clampedHipAngle  = clampSpike(hipAngle, lastRawHipAngle, maxDelta = 45f)
        lastRawKneeAngle = clampedKneeAngle
        lastRawHipAngle  = clampedHipAngle

        // Store raw angle in ring buffer BEFORE smoothing so the velocity signal is
        // not contaminated by the rolling-average lag.
        rawHistIndex = (rawHistIndex + 1) % rawAngleHistory.size
        rawAngleHistory[rawHistIndex] = clampedKneeAngle

        val kneeAngle = clampedKneeAngle
        val smoothedHipAngle = clampedHipAngle

        val tooLowFault = updatePhaseAndReps(kneeAngle, hipY)
        val faults = detectFaults(kneeAngle, smoothedHipAngle, landmarkArray, isFrontView, w, h)
        val allFaults = if (tooLowFault != null) faults + tooLowFault else faults

        if (isPaused) return null

        triggerAudioFeedback(allFaults)

        if (isPaused) return null

        if (sessionStartTime == 0L) {
            sessionStartTime = System.currentTimeMillis()
        }
        sessionFrameCount++
        sessionSumKneeAngle += kneeAngle
        sessionSumHipAngle += hipAngle
        if (kneeAngle < sessionMinKneeAngle) sessionMinKneeAngle = kneeAngle
        if (hipAngle < sessionMinHipAngle) sessionMinHipAngle = hipAngle

        val lS = landmarkArray[LM.LEFT_SHOULDER]
        val lH = landmarkArray[LM.LEFT_HIP]
        if (lS != null && lH != null) {
            val dx = lS.x - lH.x
            val dy = lS.y - lH.y
            val dz = lS.z - lH.z
            lastFilteredTorsoLength = kotlin.math.sqrt((dx * dx + dy * dy + dz * dz).toDouble()).toFloat()
        }

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

    // Core rep and phase logic
    private fun updatePhaseAndReps(kneeAngle: Float, hipY: Float): SquatFault? {
        val bottom        = depthProfile.targetBottom
        val maxValidAngle = depthProfile.maxValidAngle
        val repStart      = depthProfile.repStart
        val standing      = depthProfile.standing
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

        // Rep-start condition.
        val wantsToStart = kneeAngle < repStart

        if (wantsToStart) {
            repStartFrameStreak++
        } else {
            repStartFrameStreak = 0
        }

        if (!isInsideRep && repStartFrameStreak >= 3) {
            isInsideRep = true
            maxDepthReachedThisRep = kneeAngle
            maxHipDropThisRep = maxOf(0f, hipDrop)
            hasLeftStandingThisRep = false
            repStartFrameStreak = 0
        }

        if (isInsideRep && kneeAngle <= standing) {
            hasLeftStandingThisRep = true
        }

        // Too-low detection (unified as a SquatFault).
        val tooLowThreshold = bottom - when {
            bottom >= 140f -> 15f  // quarter squat
            bottom >= 120f -> 20f  // half squat
            else           -> 25f  // full squat
        }

        if (isInsideRep && kneeAngle < tooLowThreshold) {
            tooLowFrameStreak++
        } else {
            tooLowFrameStreak = 0
        }

        if (tooLowFrameStreak >= 3) {
            tooLowFault = SquatFault.TOO_LOW
        }

        // Rep-end condition (standing hysteresis).
        if (isInsideRep && hasLeftStandingThisRep && kneeAngle > standing) {
            standingFrameStreak++
        } else {
            standingFrameStreak = 0
        }

        if (standingFrameStreak >= 3) {
            // Validate rep depth using maxValidAngle defined in depthProfile.
            val validRep = maxDepthReachedThisRep <= maxValidAngle

            if (validRep) {
                repCount++
            }

            // Reset all per-rep state
            isInsideRep = false
            maxDepthReachedThisRep = 180f
            maxHipDropThisRep = 0f
            hasLeftStandingThisRep = false
            tooLowFrameStreak = 0
            standingFrameStreak = 0
            repStartFrameStreak = 0
            faultsAnnouncedThisRep.clear()
            leanForwardFrameStreak = 0
        }

        // Phase direction via raw angle velocity.
        val oldRaw     = rawAngleHistory[(rawHistIndex + 1) % rawAngleHistory.size]
        val currentRaw = rawAngleHistory[rawHistIndex]
        val rawDelta   = currentRaw - oldRaw

        val isDescending = rawDelta < -2.5f
        val isAscending  = rawDelta >  2.5f

        // Determine candidate phase
        val candidatePhase = when {
            kneeAngle <= bottom                   -> SquatPhase.BOTTOM
            isDescending                          -> SquatPhase.DESCENDING
            isAscending && isInsideRep            -> SquatPhase.ASCENDING
            isInsideRep && currentPhase == SquatPhase.ASCENDING -> SquatPhase.ASCENDING
            kneeAngle >= standing && !isInsideRep -> SquatPhase.STANDING
            else -> currentPhase
        }

        // Phase-hold hysteresis
        if (candidatePhase != currentPhase) {
            if (candidatePhase == pendingPhase) {
                phaseHoldCounter++
            } else {
                pendingPhase = candidatePhase
                phaseHoldCounter = 1
            }
            val holdThreshold = when (candidatePhase) {
                SquatPhase.STANDING, SquatPhase.BOTTOM, SquatPhase.ASCENDING -> 1
                else -> 2
            }
            if (phaseHoldCounter >= holdThreshold) {
                currentPhase = candidatePhase
                phaseHoldCounter = 0
            }
        } else {
            phaseHoldCounter = 0
        }

        if (currentPhase == SquatPhase.STANDING) {
            standingHipYBaseline = standingHipYBaseline
                ?.let { (it * 0.9f) + (hipY * 0.1f) }
                ?: hipY
        }

        return tooLowFault
    }

    // Fault detection logic
    private fun detectFaults(
        kneeAngle: Float,
        hipAngle: Float,
        lm: Array<PoseLandmarkPayload?>,
        isFrontView: Boolean,
        w: Int,
        h: Int,
    ): List<SquatFault> {
        val formCheckGate = depthProfile.repStart
        val kneeCaveAngleGate = depthProfile.repStart
        val kneeCaveOffsetGate = when (activePreset) {
            SquatDepthPreset.QUARTER_SQUAT -> 0.065f
            SquatDepthPreset.HALF_SQUAT    -> 0.06f
            SquatDepthPreset.FULL_SQUAT    -> 0.06f
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

        if (currentPhase == SquatPhase.STANDING && !isInsideRep) return faults

        // 1) GO_DEEPER — only when the user starts ascending without reaching maxValidAngle.
        val oldRaw     = rawAngleHistory[(rawHistIndex + 1) % rawAngleHistory.size]
        val currentRaw = rawAngleHistory[rawHistIndex]
        val rawDelta   = currentRaw - oldRaw
        val isAscending = rawDelta > 2.5f

        if ((isInsideRep || hasLeftStandingThisRep) &&
            (currentPhase == SquatPhase.ASCENDING || isAscending) &&
            maxDepthReachedThisRep > depthProfile.maxValidAngle
        ) {
            addFault(SquatFault.GO_DEEPER)
        }

        // 2) LEAN_FORWARD ("chest up") — detects excessive forward lean.
        if (kneeAngle < formCheckGate || isInsideRep) {
            if (isFrontView) {
                val lS = lm[LM.LEFT_SHOULDER]
                val rS = lm[LM.RIGHT_SHOULDER]
                val lH = lm[LM.LEFT_HIP]
                val rH = lm[LM.RIGHT_HIP]

                if (lS != null && rS != null && lH != null && rH != null) {
                    val shoulderWidth = abs((lS.x * w) - (rS.x * w))
                    val torsoHeight =
                        (abs((lS.y * h) - (lH.y * h)) + abs((rS.y * h) - (rH.y * h))) / 2f

                    if (torsoHeight < shoulderWidth * 0.62f) {
                        addFault(SquatFault.LEAN_FORWARD)
                    }
                }
            } else {
                if (hipAngle < 55f) {
                    leanForwardFrameStreak++
                } else {
                    leanForwardFrameStreak = 0
                }
                if (leanForwardFrameStreak >= 2) {
                    addFault(SquatFault.LEAN_FORWARD)
                }
            }
        } else {
            leanForwardFrameStreak = 0
        }

        // 3) KNEE CAVE — front view ONLY.
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
            if (minKneeAngle < kneeCaveAngleGate || kneeAngle < kneeCaveAngleGate || isInsideRep) {
                if (lK != null && lA != null) {
                    if (lK.x < lA.x - kneeCaveOffsetGate) {
                        addFault(SquatFault.LEFT_KNEE_CAVE)
                    }
                }
                if (rK != null && rA != null) {
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
        repStartFrameStreak = 0
        standingFrameStreak = 0
        phaseHoldCounter = 0
        pendingPhase = SquatPhase.STANDING
        leanForwardFrameStreak = 0
        rawAngleHistory.fill(180f)
        rawHistIndex = 0
        lastRawKneeAngle = null
        lastRawHipAngle = null
        lastLandmarkCoords.fill(null)
        kneeAngleFilter.reset()
        hipAngleFilter.reset()
        landmarkFilters.forEach { it.reset() }
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
        val ux = (a.x - b.x) * width
        val uy = (a.y - b.y) * height
        val uz = (a.z - b.z) * width

        val vx = (c.x - b.x) * width
        val vy = (c.y - b.y) * height
        val vz = (c.z - b.z) * width

        val dot = ux * vx + uy * vy + uz * vz

        // Cross product u x v
        val cx = uy * vz - uz * vy
        val cy = uz * vx - ux * vz
        val cz = ux * vy - uy * vx
        val crossNorm = kotlin.math.sqrt((cx * cx + cy * cy + cz * cz).toDouble())

        if (crossNorm == 0.0 && dot == 0f) return 180f

        val angleRad = kotlin.math.atan2(crossNorm, dot.toDouble())
        return Math.toDegrees(angleRad).toFloat()
    }
}

/**
 * One Euro (1€) Adaptive Filter for real-time kinematic signal smoothing.
 * Dynamically adjusts cutoff frequency based on movement speed:
 * - High movement velocity (explosive motion) -> Low smoothing, Zero lag.
 * - Low movement velocity (static holds) -> High smoothing, Zero micro-jitter.
 */
class OneEuroFilter(
    private var minCutoff: Float = 1.0f,
    private var beta: Float = 0.005f,
    private var dCutoff: Float = 1.0f
) {
    private var isInitialized = false
    private var xPrev: Float = 0.0f
    private var dxPrev: Float = 0.0f
    private var tPrev: Long = 0L

    fun filter(x: Float, timestampMs: Long = System.currentTimeMillis()): Float {
        if (!isInitialized) {
            xPrev = x
            tPrev = timestampMs
            dxPrev = 0.0f
            isInitialized = true
            return x
        }

        val dtRaw = (timestampMs - tPrev) / 1000.0f
        // Monotonic dt clamping: use measured dt if >1ms, else fallback to 0.033s (30fps) for test loops
        val dt = if (dtRaw > 0.001f) dtRaw.coerceAtMost(0.200f) else 0.033f

        // Derivative (velocity)
        val dx = (x - xPrev) / dt
        val alphaDx = alpha(dt, dCutoff)
        val edx = alphaDx * dx + (1.0f - alphaDx) * dxPrev

        // Dynamic cutoff frequency scaling with velocity magnitude
        val cutoff = minCutoff + beta * abs(edx)
        val alphaX = alpha(dt, cutoff)
        val result = alphaX * x + (1.0f - alphaX) * xPrev

        xPrev = result
        dxPrev = edx
        tPrev = timestampMs
        return result
    }

    private fun alpha(dt: Float, cutoff: Float): Float {
        val tau = 1.0f / (2.0f * Math.PI.toFloat() * cutoff)
        return 1.0f / (1.0f + tau / dt)
    }

    fun reset(seedValue: Float = 0.0f, timestampMs: Long = 0L) {
        if (timestampMs > 0L) {
            xPrev = seedValue
            dxPrev = 0.0f
            tPrev = timestampMs
            isInitialized = true
        } else {
            isInitialized = false
            xPrev = 0.0f
            dxPrev = 0.0f
            tPrev = 0L
        }
    }
}

/**
 * Anisotropic 3D Spatial Landmark Coordinate One Euro (1€) Filter.
 * Applies dedicated parameters for 2D image plane (X, Y) vs 3D depth (Z).
 * Supports visibility-gated state freezing and seeded re-acquisition recovery.
 */
class OneEuroFilter3D(
    minCutoffXY: Float = 3.0f,
    betaXY: Float = 0.5f,
    minCutoffZ: Float = 1.5f,
    betaZ: Float = 0.1f,
    dCutoff: Float = 1.0f
) {
    private val filterX = OneEuroFilter(minCutoffXY, betaXY, dCutoff)
    private val filterY = OneEuroFilter(minCutoffXY, betaXY, dCutoff)
    private val filterZ = OneEuroFilter(minCutoffZ, betaZ, dCutoff)
    private var isOccluded = false

    fun filter(
        lm: PoseLandmarkPayload,
        timestampMs: Long,
        isVisible: Boolean,
        clampedLm: PoseLandmarkPayload
    ): PoseLandmarkPayload {
        if (!isVisible) {
            isOccluded = true
            return clampedLm
        }

        if (isOccluded) {
            filterX.reset(clampedLm.x, timestampMs)
            filterY.reset(clampedLm.y, timestampMs)
            filterZ.reset(clampedLm.z, timestampMs)
            isOccluded = false
            return clampedLm
        }

        val fx = filterX.filter(clampedLm.x, timestampMs)
        val fy = filterY.filter(clampedLm.y, timestampMs)
        val fz = filterZ.filter(clampedLm.z, timestampMs)
        return clampedLm.copy(x = fx, y = fy, z = fz)
    }

    fun reset() {
        filterX.reset()
        filterY.reset()
        filterZ.reset()
        isOccluded = false
    }
}

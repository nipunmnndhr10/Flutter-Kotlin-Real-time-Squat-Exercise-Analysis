package com.example.flt_kotlin_pose

import kotlin.math.abs
import kotlin.math.atan2

// Data class for workout summary
data class WorkoutSummary(
    val avgKneeAngle: Float,
    val avgHipAngle: Float,
    val minKneeAngle: Float,
    val minHipAngle: Float,
    val durationSeconds: Long,
    val totalReps: Int
)

class SquatHeuristicEngine(private val audioController: SquatAudioController) {

    // ---------------- STATE ----------------
    private var currentPhase = SquatPhase.STANDING
    private var repCount = 0

    private var isInsideRep = false
    private var violatedDepth = false

    private var minKneeAngleThisRep = 180f
    private var maxDepthReachedThisRep = 180f

    // ---------------- SCORING ----------------
    private var totalRepScore: Int = 0
    private var scoredRepCount: Int = 0
    private var currentRepScore: Int = 100
    
    private val faultsDetectedThisRep = mutableSetOf<SquatFault>()

    private val repScores = mutableListOf<Double>()
    private val faultSummary = mutableMapOf<String, Int>()
    private var squatType: String = "STANDARD"

    // ---------------- SUMMARY STATISTICS ----------------
    private var sessionFrameCount = 0
    private var sessionSumKneeAngle = 0f
    private var sessionSumHipAngle = 0f
    private var sessionMinKneeAngle = 180f
    private var sessionMinHipAngle = 180f
    private var sessionStartTime = 0L

    // ---------------- DEPTH PROFILE ----------------
    data class DepthProfile(
        val targetBottom: Float,
        val maxAllowed: Float
    )

    private var depthProfile = DepthProfile(90f, 180f)

    fun setDepthThreshold(angle: Float) {
        depthProfile = when (angle) {
            140f -> DepthProfile(130f, 175f)
            120f -> DepthProfile(105f, 150f)
            90f  -> DepthProfile(70f, 180f)
            else -> DepthProfile(70f, 180f)
        }
    }

    // ---------------- SMOOTHING ----------------
    private val kneeAngleBuffer = FloatArray(5)
    private var bufferIndex = 0

    private val faultsAnnouncedThisRep = mutableSetOf<SquatFault>()

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

        kneeAngleBuffer[bufferIndex % kneeAngleBuffer.size] = rawAngle
        bufferIndex++

        val kneeAngle = kneeAngleBuffer
            .take(minOf(bufferIndex, kneeAngleBuffer.size))
            .average()
            .toFloat()

        updatePhaseAndReps(kneeAngle)

        val faults = detectFaults(kneeAngle, hipAngle, lm, true, w, h)
        triggerAudioFeedback(faults)

        // Update session summary statistics
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
            activeFaults = faults,
            kneeAngle = kneeAngle,
            hipAngle = hipAngle,
            isLandmarkReliable = true
        )
    }

    // ---------------- CORE LOGIC ----------------
    private fun updatePhaseAndReps(kneeAngle: Float) {

        val bottom = depthProfile.targetBottom
        val top = depthProfile.maxAllowed

        if (kneeAngle < maxDepthReachedThisRep) {
            maxDepthReachedThisRep = kneeAngle
        }

        if (kneeAngle < top) {
            if (!isInsideRep) {
                isInsideRep = true
                violatedDepth = false
                minKneeAngleThisRep = 180f
                maxDepthReachedThisRep = 180f
                currentRepScore = 100
                faultsDetectedThisRep.clear()
            }

            if (kneeAngle < minKneeAngleThisRep) {
                minKneeAngleThisRep = kneeAngle
            }
        }

        val tooLowThreshold = bottom - when {
            bottom >= 125f -> 8f
            bottom >= 100f -> 10f
            else -> 12f
        }

        if (kneeAngle < tooLowThreshold) {
            violatedDepth = true
            audioController.playCue("too_low")
        }

        val isStanding = kneeAngle > top - 6f

        if (isInsideRep && isStanding) {

            val depthAchieved = maxDepthReachedThisRep <= (bottom + 15f)
            val validRep = depthAchieved && !violatedDepth

            if (validRep) {
                repCount++
                
                applyPenaltiesForDetectedFaults()
                repScores.add(currentRepScore.toDouble())
                totalRepScore += currentRepScore
                scoredRepCount++
            }

            isInsideRep = false
            violatedDepth = false
            minKneeAngleThisRep = 180f
            maxDepthReachedThisRep = 180f
            faultsAnnouncedThisRep.clear()
            faultsDetectedThisRep.clear()
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
                faultsDetectedThisRep.add(f)
                faultSummary[f.name] = faultSummary.getOrDefault(f.name, 0) + 1
            }
        }

        if (currentPhase == SquatPhase.STANDING) return faults

        // LEAN_FORWARD
        if (kneeAngle < 130f) {
            if (isFrontView) {
                val lS = lm[LM.LEFT_SHOULDER]!!
                val rS = lm[LM.RIGHT_SHOULDER]!!
                val lH = lm[LM.LEFT_HIP]!!
                val rH = lm[LM.RIGHT_HIP]!!

                val shoulderWidth = abs((lS.x * w) - (rS.x * w))
                val torsoHeight = (abs((lS.y * h) - (lH.y * h)) + abs((rS.y * h) - (rH.y * h))) / 2f

                if (torsoHeight < shoulderWidth * 0.78f) {
                    addFault(SquatFault.LEAN_FORWARD)
                }
            } else {
                if (hipAngle < 55f) addFault(SquatFault.LEAN_FORWARD)
            }
        }

        // NOT_DEEP_ENOUGH
        val bottom = depthProfile.targetBottom
        if (isInsideRep && kneeAngle > bottom + 15f && kneeAngle < depthProfile.maxAllowed) {
            addFault(SquatFault.NOT_DEEP_ENOUGH)
        }

        // KNEES_TOO_FAR_OUT
        if (isInsideRep && kneeAngle < 100f) {
            addFault(SquatFault.KNEES_TOO_FAR_OUT)
        }

        // TOO_LOW
        if (violatedDepth) {
            addFault(SquatFault.TOO_LOW)
        }

        return faults
    }

    private fun applyPenaltiesForDetectedFaults() {
        for (fault in faultsDetectedThisRep) {
            val penalty = when (fault) {
                SquatFault.LEAN_FORWARD -> 10
                SquatFault.KNEE_CAVE -> 15
                SquatFault.KNEES_TOO_FAR_OUT -> 10
                SquatFault.TOO_LOW -> 8
                SquatFault.NOT_DEEP_ENOUGH -> 12
                else -> 0
            }
            currentRepScore = maxOf(0, currentRepScore - penalty)
        }
    }

    private fun triggerAudioFeedback(faults: List<SquatFault>) {
        for (f in faults) {
            if (!faultsAnnouncedThisRep.contains(f)) {
                faultsAnnouncedThisRep.add(f)
                
                val cueName = when (f) {
                    SquatFault.LEAN_FORWARD -> "chest_up"
                    SquatFault.NOT_DEEP_ENOUGH -> "go_deeper"
                    SquatFault.KNEES_TOO_FAR_OUT -> "knees_out"
                    SquatFault.TOO_LOW -> "too_low"
                    else -> f.cueName
                }
                audioController.playCue(cueName)
            }
        }
    }

    // ==================== WORKOUT DATA GETTERS ====================

    fun start() {
        // Called from Flutter to start detection
    }

    fun stop() {
        // Called from Flutter to stop detection
    }

    fun setSquatType(type: String) {
        squatType = type
    }

    fun getSquatType(): String = squatType

    fun getRepCount(): Int = scoredRepCount

    fun getFormScore(): Double {
        return if (scoredRepCount > 0) {
            totalRepScore.toDouble() / scoredRepCount
        } else 0.0
    }

    fun getRepScores(): List<Double> = repScores.toList()

    fun getFaultSummary(): Map<String, Int> = faultSummary.toMap()

    fun endWorkoutSummary(): WorkoutSummary? {
        if (sessionFrameCount == 0 || sessionStartTime == 0L) return null

        val durationSeconds = (System.currentTimeMillis() - sessionStartTime) / 1000L
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
        faultsDetectedThisRep.clear()
        
        totalRepScore = 0
        scoredRepCount = 0
        currentRepScore = 100
        
        repScores.clear()
        faultSummary.clear()
        squatType = "STANDARD"

        // Reset summary statistics
        sessionFrameCount = 0
        sessionSumKneeAngle = 0f
        sessionSumHipAngle = 0f
        sessionMinKneeAngle = 180f
        sessionMinHipAngle = 180f
        sessionStartTime = 0L
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
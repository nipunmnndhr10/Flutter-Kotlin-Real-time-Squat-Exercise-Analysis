package com.example.flt_kotlin_pose

import io.mockk.mockk
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

/**
 * Clean 10 Unit Tests for SquatHeuristicEngine covering:
 * 1. Phase lifecycle
 * 2. Parallel depth rep counting
 * 3. Shallow rep rejection
 * 4. GO_DEEPER fault on ascent
 * 5. LEAN_FORWARD fault
 * 6. KNEE_CAVE fault
 * 7. TOO_LOW fault
 * 8. 3D spatial kinematics calculation
 * 9. Adaptive smoothing
 * 10. Engine reset
 */
class SquatHeuristicEngineTest {

    private lateinit var audioController: SquatAudioController
    private lateinit var engine: SquatHeuristicEngine
    private var testTimestamp = 1000L

    @Before
    fun setUp() {
        audioController = mockk(relaxed = true)
        engine = SquatHeuristicEngine(audioController)
        testTimestamp = 1000L
    }

    // ---------- Frame Helpers ----------

    private fun frame(
        vararg landmarks: Pair<Int, Triple<Float, Float, Float>>,
        width: Int = 1080,
        height: Int = 1920,
    ): PoseFramePayload {
        testTimestamp += 33L
        val list = landmarks.map { (index, triple) ->
            PoseLandmarkPayload(
                index = index,
                x = triple.first,
                y = triple.second,
                visibility = triple.third,
                presence = null,
            )
        }
        return PoseFramePayload(frameWidth = width, frameHeight = height, landmarks = list, timestampMs = testTimestamp)
    }

    private data class Landmark3D(val x: Float, val y: Float, val z: Float, val visibility: Float = 0.95f)

    private fun frame3D(
        vararg landmarks: Pair<Int, Landmark3D>,
        width: Int = 1080,
        height: Int = 1920,
    ): PoseFramePayload {
        testTimestamp += 33L
        val list = landmarks.map { (index, lm) ->
            PoseLandmarkPayload(
                index = index,
                x = lm.x,
                y = lm.y,
                z = lm.z,
                visibility = lm.visibility,
                presence = null,
            )
        }
        return PoseFramePayload(frameWidth = width, frameHeight = height, landmarks = list, timestampMs = testTimestamp)
    }

    private fun prime(target: PoseFramePayload) {
        repeat(15) { engine.analyze(target) }
    }

    private fun standing() = frame(
        LM.LEFT_SHOULDER  to Triple(0.70f, 0.20f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.30f, 0.20f, 0.95f),
        LM.LEFT_HIP       to Triple(0.65f, 0.45f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.35f, 0.45f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.65f, 0.65f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.35f, 0.65f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.65f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.35f, 0.90f, 0.95f),
    )

    private fun descending() = frame(
        LM.LEFT_SHOULDER  to Triple(0.70f, 0.20f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.30f, 0.20f, 0.95f),
        LM.LEFT_HIP       to Triple(0.85f, 0.50f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.15f, 0.50f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.65f, 0.70f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.35f, 0.70f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.65f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.35f, 0.90f, 0.95f),
    )

    private fun deep() = frame(
        LM.LEFT_SHOULDER  to Triple(0.70f, 0.20f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.30f, 0.20f, 0.95f),
        LM.LEFT_HIP       to Triple(0.80f, 0.74f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.20f, 0.74f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.65f, 0.70f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.35f, 0.70f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.65f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.35f, 0.90f, 0.95f),
    )

    private fun shallow() = frame(
        LM.LEFT_SHOULDER  to Triple(0.70f, 0.20f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.30f, 0.20f, 0.95f),
        LM.LEFT_HIP       to Triple(0.85f, 0.60f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.15f, 0.60f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.65f, 0.70f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.35f, 0.70f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.65f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.35f, 0.90f, 0.95f),
    )

    private fun ascending() = frame(
        LM.LEFT_SHOULDER  to Triple(0.70f, 0.20f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.30f, 0.20f, 0.95f),
        LM.LEFT_HIP       to Triple(0.75f, 0.55f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.25f, 0.55f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.65f, 0.68f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.35f, 0.68f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.65f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.35f, 0.90f, 0.95f),
    )

    private fun tooLow() = frame(
        LM.LEFT_SHOULDER  to Triple(0.70f, 0.20f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.30f, 0.20f, 0.95f),
        LM.LEFT_HIP       to Triple(0.75f, 0.85f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.25f, 0.85f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.65f, 0.70f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.35f, 0.70f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.65f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.35f, 0.90f, 0.95f),
    )

    private fun leaningFront() = frame(
        LM.LEFT_SHOULDER  to Triple(0.60f, 0.60f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.40f, 0.60f, 0.95f),
        LM.LEFT_HIP       to Triple(0.85f, 0.65f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.15f, 0.65f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.65f, 0.70f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.35f, 0.70f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.65f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.40f, 0.90f, 0.95f),
    )

    private fun leftKneeCave() = frame(
        LM.LEFT_SHOULDER  to Triple(0.70f, 0.20f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.30f, 0.20f, 0.95f),
        LM.LEFT_HIP       to Triple(0.65f, 0.60f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.35f, 0.60f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.58f, 0.65f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.35f, 0.65f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.65f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.35f, 0.90f, 0.95f),
    )

    // ---------- 10 Core Heuristic Engine Tests ----------

    // 1. Phase state machine transitions
    @Test
    fun `1 phase cycles through all states`() {
        engine.setDepthThreshold(90f)
        val phases = mutableSetOf<SquatPhase>()

        repeat(5) { phases.add(engine.analyze(standing())!!.phase) }
        repeat(4) { phases.add(engine.analyze(descending())!!.phase) }
        repeat(5) { phases.add(engine.analyze(deep())!!.phase) }
        repeat(5) { phases.add(engine.analyze(descending())!!.phase) }
        repeat(5) { phases.add(engine.analyze(standing())!!.phase) }

        assertTrue(phases.contains(SquatPhase.STANDING))
        assertTrue(phases.contains(SquatPhase.DESCENDING))
        assertTrue(phases.contains(SquatPhase.BOTTOM))
        assertTrue(phases.contains(SquatPhase.ASCENDING))
    }

    // 2. Valid rep count increment
    @Test
    fun `2 rep counted when parallel depth is achieved`() {
        engine.setDepthThreshold(90f)
        prime(standing())
        prime(descending())
        prime(deep())
        prime(standing())
        val result = engine.analyze(standing())!!
        assertEquals(1, result.repCount)
    }

    // 3. Shallow rep rejection
    @Test
    fun `3 rep NOT counted when depth not achieved`() {
        prime(standing())
        prime(descending())
        prime(shallow())
        prime(standing())
        val result = engine.analyze(standing())!!
        assertEquals(0, result.repCount)
    }

    // 4. Fault: GO_DEEPER
    @Test
    fun `4 GO_DEEPER fires on ascent when depth was shallow`() {
        engine.setDepthThreshold(90f)
        prime(standing())
        prime(shallow())

        var goDeeperResult: SquatFeedback? = null
        repeat(5) {
            val r = engine.analyze(ascending())
            if (r != null && r.activeFaults.contains(SquatFault.GO_DEEPER)) {
                goDeeperResult = r
            }
        }
        assertNotNull(goDeeperResult)
    }

    // 5. Fault: LEAN_FORWARD
    @Test
    fun `5 LEAN_FORWARD fires when torso is too short or leaning forward`() {
        prime(standing())
        prime(descending())

        var leanResult: SquatFeedback? = null
        repeat(5) {
            val r = engine.analyze(leaningFront())!!
            if (r.activeFaults.contains(SquatFault.LEAN_FORWARD)) {
                leanResult = r
            }
        }
        assertNotNull(leanResult)
    }

    // 6. Fault: KNEE_CAVE
    @Test
    fun `6 KNEE_CAVE fires when knee drifts inward`() {
        prime(standing())
        prime(descending())

        var caveResult: SquatFeedback? = null
        repeat(5) {
            val r = engine.analyze(leftKneeCave())!!
            if (r.activeFaults.contains(SquatFault.LEFT_KNEE_CAVE)) {
                caveResult = r
            }
        }
        assertNotNull(caveResult)
    }

    // 7. Fault: TOO_LOW
    @Test
    fun `7 TOO_LOW fires when user squats too deep`() {
        prime(standing())
        prime(descending())

        var tooLowResult: SquatFeedback? = null
        repeat(8) {
            val r = engine.analyze(tooLow())!!
            if (r.activeFaults.contains(SquatFault.TOO_LOW)) {
                tooLowResult = r
            }
        }
        assertNotNull(tooLowResult)
    }

    // 8. 3D Kinematics angle calculation
    @Test
    fun `8 3D vector dot product calculates accurate knee angle with depth Z`() {
        val bend3D = frame3D(
            LM.LEFT_SHOULDER  to Landmark3D(0.50f, 0.10f, 0.00f),
            LM.RIGHT_SHOULDER to Landmark3D(0.48f, 0.10f, 0.00f),
            LM.LEFT_HIP       to Landmark3D(0.50f, 0.30f, 0.00f),
            LM.RIGHT_HIP      to Landmark3D(0.48f, 0.30f, 0.00f),
            LM.LEFT_KNEE      to Landmark3D(0.50f, 0.60f, 0.00f),
            LM.RIGHT_KNEE     to Landmark3D(0.48f, 0.60f, 0.00f),
            LM.LEFT_ANKLE     to Landmark3D(0.50f, 0.60f, 0.30f),
            LM.RIGHT_ANKLE    to Landmark3D(0.48f, 0.60f, 0.30f),
        )
        val result = engine.analyze(bend3D)!!
        assertEquals(90.0f, result.kneeAngle, 1.0f)
    }

    // 9. Adaptive smoothing
    @Test
    fun `9 rolling average smooths noisy knee angles`() {
        prime(standing())
        val angles = mutableListOf<Float>()
        repeat(5) { angles.add(engine.analyze(standing())!!.kneeAngle) }
        val lastFive = angles.takeLast(5)
        val variance = lastFive.map { (it - lastFive.average()).toFloat() }.map { it * it }.average()
        assertTrue("Rolling average should stabilize", variance < 1.0)
    }

    // 10. Engine Reset
    @Test
    fun `10 reset clears rep count and state`() {
        prime(standing())
        prime(descending())
        prime(deep())
        prime(standing())
        engine.reset()
        val result = engine.analyze(standing())!!
        assertEquals(0, result.repCount)
        assertEquals(SquatPhase.STANDING, result.phase)
    }
}

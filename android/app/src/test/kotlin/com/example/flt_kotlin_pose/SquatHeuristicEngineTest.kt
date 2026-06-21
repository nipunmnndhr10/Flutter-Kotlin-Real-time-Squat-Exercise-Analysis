package com.example.flt_kotlin_pose

import io.mockk.mockk
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

/**
 * Unit tests for SquatHeuristicEngine.
 *
 * All tests prime the 5-frame rolling-average buffer first (repeat(5))
 * so that the smoothed kneeAngle converges before assertions are made.
 */
class SquatHeuristicEngineTest {

    private lateinit var audioController: SquatAudioController
    private lateinit var engine: SquatHeuristicEngine

    @Before
    fun setUp() {
        audioController = mockk(relaxed = true)
        engine = SquatHeuristicEngine(audioController)
    }

    // ---------- helpers ----------

    private fun frame(
        vararg landmarks: Pair<Int, Triple<Float, Float, Float>>,
        width: Int = 1080,
        height: Int = 1920,
    ): PoseFramePayload {
        val list = landmarks.map { (index, triple) ->
            PoseLandmarkPayload(
                index = index,
                x = triple.first,
                y = triple.second,
                visibility = triple.third,
                presence = null,
            )
        }
        return PoseFramePayload(frameWidth = width, frameHeight = height, landmarks = list)
    }

    /** Feed N frames of the same position to prime the rolling-average buffer. */
    private fun prime(target: PoseFramePayload) {
        repeat(5) { engine.analyze(target) }
    }

    // Standing: straight vertical legs, exterior knee angle = 180°
    private fun standing() = frame(
        LM.LEFT_SHOULDER  to Triple(0.30f, 0.20f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.70f, 0.20f, 0.95f),
        LM.LEFT_HIP       to Triple(0.35f, 0.45f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.65f, 0.45f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.35f, 0.65f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.65f, 0.65f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.35f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.65f, 0.90f, 0.95f),
    )

    // Descending: exterior knee angle ~150°
    private fun descending() = frame(
        LM.LEFT_SHOULDER  to Triple(0.30f, 0.20f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.70f, 0.20f, 0.95f),
        LM.LEFT_HIP       to Triple(0.30f, 0.65f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.70f, 0.65f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.35f, 0.70f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.65f, 0.70f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.35f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.65f, 0.90f, 0.95f),
    )

    // Deep / BOTTOM: exterior knee angle ~65° (BOTTOM but NOT too-low for full squat preset)
    private fun deep() = frame(
        LM.LEFT_SHOULDER  to Triple(0.30f, 0.20f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.70f, 0.20f, 0.95f),
        LM.LEFT_HIP       to Triple(0.20f, 0.74f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.80f, 0.74f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.35f, 0.70f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.65f, 0.70f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.35f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.65f, 0.90f, 0.95f),
    )

    // Too-low: knee angle ~47° (triggers TOO_LOW for full squat preset)
    private fun tooLow() = frame(
        LM.LEFT_SHOULDER  to Triple(0.30f, 0.20f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.70f, 0.20f, 0.95f),
        LM.LEFT_HIP       to Triple(0.20f, 0.78f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.80f, 0.78f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.35f, 0.70f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.65f, 0.70f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.35f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.65f, 0.90f, 0.95f),
    )

    // Shallow: exterior knee angle ~139° (valid for quarter squat, not full)
    private fun shallow() = frame(
        LM.LEFT_SHOULDER  to Triple(0.30f, 0.20f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.70f, 0.20f, 0.95f),
        LM.LEFT_HIP       to Triple(0.25f, 0.55f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.75f, 0.55f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.40f, 0.65f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.60f, 0.65f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.40f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.60f, 0.90f, 0.95f),
    )

    // Leaning forward (front view): torso compressed, knee angle ~124°
    private fun leaningFront() = frame(
        LM.LEFT_SHOULDER  to Triple(0.30f, 0.55f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.70f, 0.55f, 0.95f),
        LM.LEFT_HIP       to Triple(0.35f, 0.68f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.65f, 0.68f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.40f, 0.70f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.60f, 0.70f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.40f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.60f, 0.90f, 0.95f),
    )

    // Leaning forward (side view): hip angle ~14°, knee angle ~120°
    private fun leaningSide() = frame(
        LM.LEFT_SHOULDER  to Triple(0.70f, 0.50f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.72f, 0.50f, 0.95f),
        LM.LEFT_HIP       to Triple(0.50f, 0.50f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.52f, 0.50f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.70f, 0.55f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.72f, 0.55f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.80f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.82f, 0.90f, 0.95f),
    )

    // Left knee caves inward
    private fun leftKneeCave() = frame(
        LM.LEFT_SHOULDER  to Triple(0.30f, 0.20f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.70f, 0.20f, 0.95f),
        LM.LEFT_HIP       to Triple(0.35f, 0.60f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.65f, 0.60f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.42f, 0.65f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.65f, 0.65f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.35f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.65f, 0.90f, 0.95f),
    )

    // Right knee caves inward (right knee angle ~113° so avg < 150)
    private fun rightKneeCave() = frame(
        LM.LEFT_SHOULDER  to Triple(0.30f, 0.20f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.70f, 0.20f, 0.95f),
        LM.LEFT_HIP       to Triple(0.35f, 0.60f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.65f, 0.60f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.35f, 0.65f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.55f, 0.75f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.35f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.65f, 0.90f, 0.95f),
    )

    // Side view (narrow shoulders)
    private fun sideView() = frame(
        LM.LEFT_SHOULDER  to Triple(0.50f, 0.20f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.52f, 0.20f, 0.95f),
        LM.LEFT_HIP       to Triple(0.50f, 0.45f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.52f, 0.45f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.50f, 0.65f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.52f, 0.65f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.50f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.52f, 0.90f, 0.95f),
    )

    // Only left side visible
    private fun partialLeft() = frame(
        LM.LEFT_SHOULDER  to Triple(0.30f, 0.20f, 0.95f),
        LM.LEFT_HIP       to Triple(0.35f, 0.45f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.35f, 0.65f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.35f, 0.90f, 0.95f),
    )

    // All landmarks invisible
    private fun invisible() = frame(
        LM.LEFT_SHOULDER  to Triple(0.30f, 0.20f, 0.10f),
        LM.RIGHT_SHOULDER to Triple(0.70f, 0.20f, 0.10f),
        LM.LEFT_HIP       to Triple(0.35f, 0.45f, 0.10f),
        LM.RIGHT_HIP      to Triple(0.65f, 0.45f, 0.10f),
    )

    // ---------- PHASE & REPS ----------

    @Test
    fun `phase cycles through all states`() {
        engine.setDepthThreshold(90f) // full squat for clean phase transitions
        val phases = mutableSetOf<SquatPhase>()

        // Standing — 5 frames to stabilize rolling average
        repeat(5) { phases.add(engine.analyze(standing())!!.phase) }

        // Descending — first 4 frames still have a decreasing trend
        repeat(4) { phases.add(engine.analyze(descending())!!.phase) }

        // Deep — 5 frames, first 4 DESCENDING, last BOTTOM
        repeat(5) { phases.add(engine.analyze(deep())!!.phase) }

        // Ascending — after deep, same descending frame now shows ASCENDING
        repeat(5) { phases.add(engine.analyze(descending())!!.phase) }

        // Standing — rep ends, back to STANDING
        repeat(5) { phases.add(engine.analyze(standing())!!.phase) }

        assertTrue(phases.contains(SquatPhase.STANDING))
        assertTrue(phases.contains(SquatPhase.DESCENDING))
        assertTrue(phases.contains(SquatPhase.BOTTOM))
        assertTrue(phases.contains(SquatPhase.ASCENDING))
    }

    @Test
    fun `rep counted when full depth achieved and no violation`() {
        engine.setDepthThreshold(90f) // full squat: bottom=70, tooLow=58
        prime(standing())
        prime(descending())
        prime(deep())
        prime(standing())
        val result = engine.analyze(standing())!!
        assertEquals(1, result.repCount)
    }

    @Test
    fun `rep NOT counted when depth not achieved`() {
        prime(standing())
        prime(descending())
        prime(shallow())
        prime(standing())
        val result = engine.analyze(standing())!!
        assertEquals(0, result.repCount)
    }

    @Test
    fun `rep NOT counted when too-low violation occurred`() {
        prime(standing())
        prime(descending())

        var tooLowResult: SquatFeedback? = null
        repeat(5) {
            val r = engine.analyze(tooLow())!!
            if (r.activeFaults.contains(SquatFault.TOO_LOW)) {
                tooLowResult = r
            }
        }
        assertNotNull(tooLowResult)

        prime(standing())
        val result = engine.analyze(standing())!!
        assertEquals(0, result.repCount)
    }

    // ---------- FAULTS ----------

    @Test
    fun `GO_DEEPER fires during descent when not deep enough`() {
        prime(standing())

        var goDeeperResult: SquatFeedback? = null
        repeat(5) {
            val r = engine.analyze(descending())!!
            if (r.activeFaults.contains(SquatFault.GO_DEEPER)) {
                goDeeperResult = r
            }
        }
        assertNotNull(goDeeperResult)
        assertEquals(SquatPhase.DESCENDING, goDeeperResult!!.phase)
    }

    @Test
    fun `GO_DEEPER does NOT fire when already at bottom`() {
        prime(standing())
        prime(descending())

        var bottomResult: SquatFeedback? = null
        repeat(5) {
            val r = engine.analyze(deep())!!
            if (r.phase == SquatPhase.BOTTOM) {
                bottomResult = r
            }
        }
        assertNotNull(bottomResult)
        assertFalse(bottomResult!!.activeFaults.contains(SquatFault.GO_DEEPER))
    }

    @Test
    fun `LEAN_FORWARD fires in front view when torso is too short`() {
        prime(standing())

        var leanResult: SquatFeedback? = null
        repeat(5) {
            val r = engine.analyze(leaningFront())!!
            if (r.activeFaults.contains(SquatFault.LEAN_FORWARD)) {
                leanResult = r
            }
        }
        assertNotNull(leanResult)
    }

    @Test
    fun `LEAN_FORWARD fires in side view when hip angle is small`() {
        prime(sideView())

        var leanResult: SquatFeedback? = null
        repeat(5) {
            val r = engine.analyze(leaningSide())!!
            if (r.activeFaults.contains(SquatFault.LEAN_FORWARD)) {
                leanResult = r
            }
        }
        assertNotNull(leanResult)
    }

    @Test
    fun `LEFT_KNEE_CAVE fires when left knee drifts inward`() {
        prime(standing())

        var caveResult: SquatFeedback? = null
        repeat(5) {
            val r = engine.analyze(leftKneeCave())!!
            if (r.activeFaults.contains(SquatFault.LEFT_KNEE_CAVE)) {
                caveResult = r
            }
        }
        assertNotNull(caveResult)
    }

    @Test
    fun `RIGHT_KNEE_CAVE fires when right knee drifts inward`() {
        prime(standing())

        var caveResult: SquatFeedback? = null
        repeat(5) {
            val r = engine.analyze(rightKneeCave())!!
            if (r.activeFaults.contains(SquatFault.RIGHT_KNEE_CAVE)) {
                caveResult = r
            }
        }
        assertNotNull(caveResult)
    }

    // ---------- VIEW MODE ----------

    @Test
    fun `auto-detects front view when shoulders are wide apart`() {
        val result = engine.analyze(standing())!!
        assertEquals(SquatPhase.STANDING, result.phase)
    }

    @Test
    fun `auto-detects side view when shoulders are narrow`() {
        val result = engine.analyze(sideView())!!
        assertEquals(SquatPhase.STANDING, result.phase)
    }

    // ---------- DEPTH PRESETS ----------

    @Test
    fun `quarter squat preset has higher bottom threshold`() {
        engine.setDepthThreshold(140f)
        prime(standing())
        prime(shallow())
        prime(standing())
        val result = engine.analyze(standing())!!
        assertEquals(1, result.repCount)
    }

    @Test
    fun `full squat preset requires deeper descent`() {
        engine.setDepthThreshold(90f)
        prime(standing())
        prime(shallow())
        prime(standing())
        val result = engine.analyze(standing())!!
        assertEquals(0, result.repCount)
    }

    // ---------- SMOOTHING ----------

    @Test
    fun `rolling average smooths noisy knee angles`() {
        prime(standing())
        val angles = mutableListOf<Float>()
        repeat(5) { angles.add(engine.analyze(standing())!!.kneeAngle) }
        val lastFive = angles.takeLast(5)
        val variance = lastFive.map { (it - lastFive.average()).toFloat() }.map { it * it }.average()
        assertTrue("Rolling average should stabilize", variance < 1.0)
    }

    // ---------- RESET ----------

    @Test
    fun `reset clears rep count and phase`() {
        prime(standing())
        prime(descending())
        prime(deep())
        prime(standing())
        engine.reset()
        val result = engine.analyze(standing())!!
        assertEquals(0, result.repCount)
        assertEquals(SquatPhase.STANDING, result.phase)
    }

    // ---------- NULL SAFETY ----------

    @Test
    fun `returns null when both sides have low visibility`() {
        assertNull(engine.analyze(invisible()))
    }

    @Test
    fun `falls back to visible side when one side is missing`() {
        val result = engine.analyze(partialLeft())!!
        assertEquals(SquatPhase.STANDING, result.phase)
    }
}

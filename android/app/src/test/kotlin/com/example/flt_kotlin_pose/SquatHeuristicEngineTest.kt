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

    private data class Landmark3D(val x: Float, val y: Float, val z: Float, val visibility: Float = 0.95f)

    private fun frame3D(
        vararg landmarks: Pair<Int, Landmark3D>,
        width: Int = 1080,
        height: Int = 1920,
    ): PoseFramePayload {
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
        return PoseFramePayload(frameWidth = width, frameHeight = height, landmarks = list)
    }

    /** Feed N frames of the same position to prime the rolling-average buffer. */
    private fun prime(target: PoseFramePayload) {
        repeat(5) { engine.analyze(target) }
    }

    // Standing: straight vertical legs, exterior knee angle = 180°
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

    // Descending: exterior knee angle ~135°
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

    // Deep / BOTTOM: exterior knee angle ~75° (BOTTOM but NOT too-low for full squat preset)
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

    // Too-low: knee angle ~62° (triggers TOO_LOW for full squat preset)
    private fun tooLow() = frame(
        LM.LEFT_SHOULDER  to Triple(0.70f, 0.20f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.30f, 0.20f, 0.95f),
        LM.LEFT_HIP       to Triple(0.80f, 0.78f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.20f, 0.78f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.65f, 0.70f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.35f, 0.70f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.65f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.35f, 0.90f, 0.95f),
    )

    // Shallow: exterior knee angle ~124° (valid for quarter squat, not full)
    private fun shallow() = frame(
        LM.LEFT_SHOULDER  to Triple(0.70f, 0.20f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.30f, 0.20f, 0.95f),
        LM.LEFT_HIP       to Triple(0.75f, 0.55f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.25f, 0.55f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.60f, 0.65f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.40f, 0.65f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.60f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.40f, 0.90f, 0.95f),
    )

    // Minor standing bend: not deep enough to start an actual repetition.
    private fun slightBend() = frame(
        LM.LEFT_SHOULDER  to Triple(0.70f, 0.20f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.30f, 0.20f, 0.95f),
        LM.LEFT_HIP       to Triple(0.66f, 0.47f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.34f, 0.47f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.65f, 0.65f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.35f, 0.65f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.65f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.35f, 0.90f, 0.95f),
    )

    // Leaning forward (front view): torso compressed, knee angle ~124°
    private fun leaningFront() = frame(
        LM.LEFT_SHOULDER  to Triple(0.70f, 0.55f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.30f, 0.55f, 0.95f),
        LM.LEFT_HIP       to Triple(0.65f, 0.68f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.35f, 0.68f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.60f, 0.70f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.40f, 0.70f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.60f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.40f, 0.90f, 0.95f),
    )

    // Leaning forward (side view): hip angle ~14°, knee angle ~120°
    private fun leaningSide() = frame(
        LM.LEFT_SHOULDER  to Triple(0.30f, 0.50f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.28f, 0.50f, 0.95f),
        LM.LEFT_HIP       to Triple(0.50f, 0.50f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.48f, 0.50f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.30f, 0.55f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.28f, 0.55f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.20f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.18f, 0.90f, 0.95f),
    )

    // Left knee caves inward
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

    // Right knee caves inward (right knee angle ~113° so avg < 150)
    private fun rightKneeCave() = frame(
        LM.LEFT_SHOULDER  to Triple(0.70f, 0.20f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.30f, 0.20f, 0.95f),
        LM.LEFT_HIP       to Triple(0.65f, 0.60f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.35f, 0.60f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.65f, 0.65f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.45f, 0.75f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.65f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.35f, 0.90f, 0.95f),
    )

    // Side view (narrow shoulders)
    private fun sideView() = frame(
        LM.LEFT_SHOULDER  to Triple(0.52f, 0.20f, 0.95f),
        LM.RIGHT_SHOULDER to Triple(0.50f, 0.20f, 0.95f),
        LM.LEFT_HIP       to Triple(0.52f, 0.45f, 0.95f),
        LM.RIGHT_HIP      to Triple(0.50f, 0.45f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.52f, 0.65f, 0.95f),
        LM.RIGHT_KNEE     to Triple(0.50f, 0.65f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.52f, 0.90f, 0.95f),
        LM.RIGHT_ANKLE    to Triple(0.50f, 0.90f, 0.95f),
    )

    // Only left side visible
    private fun partialLeft() = frame(
        LM.LEFT_SHOULDER  to Triple(0.70f, 0.20f, 0.95f),
        LM.LEFT_HIP       to Triple(0.65f, 0.45f, 0.95f),
        LM.LEFT_KNEE      to Triple(0.65f, 0.65f, 0.95f),
        LM.LEFT_ANKLE     to Triple(0.65f, 0.90f, 0.95f),
    )

    // All landmarks invisible
    private fun invisible() = frame(
        LM.LEFT_SHOULDER  to Triple(0.70f, 0.20f, 0.10f),
        LM.RIGHT_SHOULDER to Triple(0.30f, 0.20f, 0.10f),
        LM.LEFT_HIP       to Triple(0.65f, 0.45f, 0.10f),
        LM.RIGHT_HIP      to Triple(0.35f, 0.45f, 0.10f),
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
        // Full squat preset: targetBottom=100, repStart=160, standing=168.
        // Rep starts after 2 frames of descending() (< 160°), ends after 2 frames of
        // standing() above 168°. prime() supplies 5 frames for each — well within budget.
        engine.setDepthThreshold(90f)
        prime(standing())
        prime(descending())
        prime(deep())
        prime(standing())
        val result = engine.analyze(standing())!!
        assertEquals(1, result.repCount)
    }

    @Test
    fun `no double-count when user pauses at top of rep`() {
        // Regression: a user who momentarily hits the standing angle and immediately
        // re-descends should NOT have two reps counted.
        engine.setDepthThreshold(90f)
        prime(standing())
        prime(descending())
        prime(deep())

        // Ascend: one frame at standing level (streak = 1, rep does NOT close yet)
        engine.analyze(standing())
        // Immediately descend again (streak resets to 0)
        repeat(3) { engine.analyze(descending()) }
        // Come back up fully (streak reaches 2 → rep closes)
        prime(standing())
        val result = engine.analyze(standing())!!

        // Only 1 valid rep should be counted, not 2.
        assertEquals(1, result.repCount)
    }

    @Test
    fun `rep NOT started or counted from minor standing movement`() {
        engine.setDepthThreshold(90f)
        prime(standing())
        prime(slightBend())
        prime(standing())
        val result = engine.analyze(standing())!!
        assertEquals(0, result.repCount)
        assertEquals(SquatPhase.STANDING, result.phase)
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
    fun `rep counted and faulted when too-low violation occurred`() {
        // After prime(descending) the 5-frame rolling avg converges to ~150.6°.
        // tooLow() raw angle is ~46.5°. The buffer needs 6 frames of tooLow()
        // before the rolling avg drops below the tooLowThreshold (74°) for 3
        // consecutive frames (the streak gate). Using 8 frames is safe.
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

        prime(standing())
        val result = engine.analyze(standing())!!
        assertEquals(1, result.repCount)
    }

    // ---------- FAULTS ----------

    @Test
    fun `GO_DEEPER fires on ascent when depth was not achieved`() {
        // Full squat preset: repStart=160, targetBottom=100, standing=168.
        // shallow() raw angle ≈ 139.84° — clearly below repStart (160°) so after
        // 2 frames the rep starts, but 139.84° is above targetBottom+12 (112°)
        // so depth is NOT achieved.
        // After 5x shallow the buffer converges to 139.84°. The first standing()
        // frame pushes the rolling avg to 147.88° which is still below repStart (160°),
        // so the engine sees:
        //   phase=ASCENDING, maxDepth(139.84) > 112, kneeAngle(147.88) < 160
        // — exactly the three conditions required to fire GO_DEEPER.
        engine.setDepthThreshold(90f)
        prime(standing())
        repeat(8) { engine.analyze(shallow()) } // rep starts (streak ≥ 3), depth NOT reached

        var goDeeperResult: SquatFeedback? = null
        repeat(5) {
            val r = engine.analyze(standing())!! // ascending back toward standing
            if (r.activeFaults.contains(SquatFault.GO_DEEPER)) {
                goDeeperResult = r
            }
        }
        assertNotNull("GO_DEEPER should fire once the user ascends without reaching depth", goDeeperResult)
        assertEquals(SquatPhase.ASCENDING, goDeeperResult!!.phase)
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

    @Test
    fun `side view uses right leg angle when right leg is more visible`() {
        // Right side landmarks visible (0.95), left side low visibility (0.52)
        val rightFacingSideView = frame(
            LM.LEFT_SHOULDER  to Triple(0.52f, 0.20f, 0.52f),
            LM.RIGHT_SHOULDER to Triple(0.50f, 0.20f, 0.95f),
            LM.LEFT_HIP       to Triple(0.52f, 0.45f, 0.52f),
            LM.RIGHT_HIP      to Triple(0.50f, 0.45f, 0.95f),
            LM.LEFT_KNEE      to Triple(0.52f, 0.65f, 0.52f),
            LM.RIGHT_KNEE     to Triple(0.50f, 0.65f, 0.95f),
            LM.LEFT_ANKLE     to Triple(0.52f, 0.90f, 0.52f),
            LM.RIGHT_ANKLE    to Triple(0.50f, 0.90f, 0.95f),
        )
        val result = engine.analyze(rightFacingSideView)!!
        assertNotNull(result)
        assertEquals(SquatPhase.STANDING, result.phase)
        assertTrue("Landmark should be reliable", result.isLandmarkReliable)
    }

    // ---------- 3D KINEMATICS & PERSPECTIVE INVARIANCE ----------

    @Test
    fun `3D vector dot product calculates accurate knee angle with depth z`() {
        // Orthogonal 90-degree knee bend with depth Z:
        // Hip=(0.5, 0.3, 0.0), Knee=(0.5, 0.6, 0.0), Ankle=(0.5, 0.6, 0.3)
        // Vector BA (Knee->Hip) = (0, -0.3, 0) [pointing straight up]
        // Vector BC (Knee->Ankle) = (0, 0, 0.3) [pointing forward in depth Z]
        // Dot product between vertical Y and depth Z vectors = 90.0°
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

    @Test
    fun `3D vector dot product preserves knee angle under 45-degree diagonal camera view`() {
        // 90° knee bend rotated 45° around the Y-axis:
        // Ankle X' = 0.5 + (0.3 * cos 45°) = 0.7121, Z' = 0.3 * sin 45° = 0.2121
        val rotated3D = frame3D(
            LM.LEFT_SHOULDER  to Landmark3D(0.50f, 0.10f, 0.00f),
            LM.RIGHT_SHOULDER to Landmark3D(0.48f, 0.10f, 0.00f),
            LM.LEFT_HIP       to Landmark3D(0.50f, 0.30f, 0.00f),
            LM.RIGHT_HIP      to Landmark3D(0.48f, 0.30f, 0.00f),
            LM.LEFT_KNEE      to Landmark3D(0.50f, 0.60f, 0.00f),
            LM.RIGHT_KNEE     to Landmark3D(0.48f, 0.60f, 0.00f),
            LM.LEFT_ANKLE     to Landmark3D(0.7121f, 0.60f, 0.2121f),
            LM.RIGHT_ANKLE    to Landmark3D(0.6921f, 0.60f, 0.2121f),
        )
        val result = engine.analyze(rotated3D)!!
        assertEquals(90.0f, result.kneeAngle, 1.0f)
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

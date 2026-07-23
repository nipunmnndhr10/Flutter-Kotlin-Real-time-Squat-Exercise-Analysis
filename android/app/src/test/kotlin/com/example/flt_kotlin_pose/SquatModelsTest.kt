package com.example.flt_kotlin_pose

import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for data classes, enums, and constants in the SquatModels file.
 */
class SquatModelsTest {

    // SquatDepthPreset Tests

    @Test
    fun `default depth preset is FULL_SQUAT`() {
        assertEquals(SquatDepthPreset.FULL_SQUAT, SquatDepthPreset.DEFAULT)
    }

    @Test
    fun `fromAngle defaults to FULL_SQUAT`() {
        assertEquals(SquatDepthPreset.FULL_SQUAT, SquatDepthPreset.fromAngle(90f))
        assertEquals(SquatDepthPreset.DEFAULT, SquatDepthPreset.fromAngle(45f))
        assertEquals(SquatDepthPreset.DEFAULT, SquatDepthPreset.fromAngle(200f))
    }

    // SquatPhase Tests

    @Test
    fun `phase enum has four states`() {
        val phases = SquatPhase.entries
        assertEquals(4, phases.size)
        assertTrue(phases.contains(SquatPhase.STANDING))
        assertTrue(phases.contains(SquatPhase.DESCENDING))
        assertTrue(phases.contains(SquatPhase.BOTTOM))
        assertTrue(phases.contains(SquatPhase.ASCENDING))
    }

    // SquatFault Tests

    @Test
    fun `fault enum has five entries`() {
        assertEquals(5, SquatFault.entries.size)
    }

    @Test
    fun `fault cue names are correct`() {
        assertEquals("go_deeper", SquatFault.GO_DEEPER.cueName)
        assertEquals("chest_up", SquatFault.LEAN_FORWARD.cueName)
        assertEquals("knees_out", SquatFault.LEFT_KNEE_CAVE.cueName)
        assertEquals("knees_out", SquatFault.RIGHT_KNEE_CAVE.cueName)
        assertEquals("too_low", SquatFault.TOO_LOW.cueName)
    }

    // LM Constants Tests

    @Test
    fun `landmark indices match MediaPipe spec`() {
        assertEquals(11, LM.LEFT_SHOULDER)
        assertEquals(12, LM.RIGHT_SHOULDER)
        assertEquals(23, LM.LEFT_HIP)
        assertEquals(24, LM.RIGHT_HIP)
        assertEquals(25, LM.LEFT_KNEE)
        assertEquals(26, LM.RIGHT_KNEE)
        assertEquals(27, LM.LEFT_ANKLE)
        assertEquals(28, LM.RIGHT_ANKLE)
    }

    // SquatFeedback Data Class Tests

    @Test
    fun `feedback default preset is full squat`() {
        val feedback = SquatFeedback(
            phase = SquatPhase.STANDING,
            repCount = 0,
            activeFaults = emptyList(),
            kneeAngle = 180f,
            hipAngle = 180f,
            isLandmarkReliable = true,
        )
        assertEquals(SquatDepthPreset.FULL_SQUAT, feedback.activePreset)
    }

    @Test
    fun `feedback equality works`() {
        val a = SquatFeedback(
            phase = SquatPhase.BOTTOM,
            repCount = 3,
            activeFaults = listOf(SquatFault.GO_DEEPER),
            kneeAngle = 85f,
            hipAngle = 60f,
            isLandmarkReliable = true,
        )
        val b = SquatFeedback(
            phase = SquatPhase.BOTTOM,
            repCount = 3,
            activeFaults = listOf(SquatFault.GO_DEEPER),
            kneeAngle = 85f,
            hipAngle = 60f,
            isLandmarkReliable = true,
        )
        assertEquals(a, b)
    }

    @Test
    fun `feedback inequality when phase differs`() {
        val a = SquatFeedback(
            phase = SquatPhase.DESCENDING,
            repCount = 1,
            activeFaults = emptyList(),
            kneeAngle = 120f,
            hipAngle = 90f,
            isLandmarkReliable = true,
        )
        val b = a.copy(phase = SquatPhase.ASCENDING)
        assertNotEquals(a, b)
    }
}

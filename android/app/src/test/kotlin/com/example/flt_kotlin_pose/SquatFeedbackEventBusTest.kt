package com.example.flt_kotlin_pose

import io.flutter.plugin.common.EventChannel
import io.mockk.mockk
import io.mockk.verify
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Unit tests for SquatFeedbackEventBus deduplication logic.
 *
 * Uses Robolectric to provide a fake Android runtime (Handler + Looper).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])

class SquatFeedbackEventBusTest {

    @Before
    fun setUp() {
        // Reset the singleton state before each test
        SquatFeedbackEventBus.reset()
        SquatFeedbackEventBus.eventSink = null
    }

    private fun feedback(
        phase: SquatPhase = SquatPhase.STANDING,
        repCount: Int = 0,
        activeFaults: List<SquatFault> = emptyList(),
    ): SquatFeedback = SquatFeedback(
        phase = phase,
        repCount = repCount,
        activeFaults = activeFaults,
        kneeAngle = 180f,
        hipAngle = 180f,
        isLandmarkReliable = true,
    )

    @Test
    fun `emits event when state changes`() {
        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        SquatFeedbackEventBus.eventSink = sink

        SquatFeedbackEventBus.emit(feedback(phase = SquatPhase.DESCENDING, repCount = 0))

        // Allow the Handler to process the posted Runnable
        org.robolectric.shadows.ShadowLooper.runUiThreadTasksIncludingDelayedTasks()

        verify(exactly = 1) { sink.success(any()) }
    }

    @Test
    fun `skips duplicate emission when phase repCount and faults are unchanged`() {
        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        SquatFeedbackEventBus.eventSink = sink

        val same = feedback(phase = SquatPhase.STANDING, repCount = 0)
        SquatFeedbackEventBus.emit(same)
        SquatFeedbackEventBus.emit(same)
        SquatFeedbackEventBus.emit(same)

        org.robolectric.shadows.ShadowLooper.runUiThreadTasksIncludingDelayedTasks()

        // Despite 3 calls, only 1 actual success() should fire
        verify(exactly = 1) { sink.success(any()) }
    }

    @Test
    fun `emits again when phase changes`() {
        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        SquatFeedbackEventBus.eventSink = sink

        SquatFeedbackEventBus.emit(feedback(phase = SquatPhase.STANDING, repCount = 0))
        SquatFeedbackEventBus.emit(feedback(phase = SquatPhase.DESCENDING, repCount = 0))

        org.robolectric.shadows.ShadowLooper.runUiThreadTasksIncludingDelayedTasks()

        verify(exactly = 2) { sink.success(any()) }
    }

    @Test
    fun `emits again when repCount changes`() {
        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        SquatFeedbackEventBus.eventSink = sink

        SquatFeedbackEventBus.emit(feedback(phase = SquatPhase.BOTTOM, repCount = 0))
        SquatFeedbackEventBus.emit(feedback(phase = SquatPhase.BOTTOM, repCount = 1))

        org.robolectric.shadows.ShadowLooper.runUiThreadTasksIncludingDelayedTasks()

        verify(exactly = 2) { sink.success(any()) }
    }

    @Test
    fun `emits again when activeFaults change`() {
        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        SquatFeedbackEventBus.eventSink = sink

        SquatFeedbackEventBus.emit(feedback(phase = SquatPhase.DESCENDING, repCount = 0, activeFaults = emptyList()))
        SquatFeedbackEventBus.emit(
            feedback(
                phase = SquatPhase.DESCENDING,
                repCount = 0,
                activeFaults = listOf(SquatFault.GO_DEEPER),
            ),
        )

        org.robolectric.shadows.ShadowLooper.runUiThreadTasksIncludingDelayedTasks()

        verify(exactly = 2) { sink.success(any()) }
    }

    @Test
    fun `does not emit when eventSink is null`() {
        SquatFeedbackEventBus.eventSink = null
        // Should not crash
        SquatFeedbackEventBus.emit(feedback(phase = SquatPhase.STANDING, repCount = 0))

        org.robolectric.shadows.ShadowLooper.runUiThreadTasksIncludingDelayedTasks()

        // Nothing to verify — the fact it didn't crash is the assertion
        assertTrue(true)
    }

    @Test
    fun `emits with correct map keys`() {
        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        SquatFeedbackEventBus.eventSink = sink

        val fb = SquatFeedback(
            phase = SquatPhase.BOTTOM,
            repCount = 5,
            activeFaults = listOf(SquatFault.LEAN_FORWARD),
            kneeAngle = 85f,
            hipAngle = 60f,
            isLandmarkReliable = true,
            activePreset = SquatDepthPreset.HALF_SQUAT,
        )
        SquatFeedbackEventBus.emit(fb)

        org.robolectric.shadows.ShadowLooper.runUiThreadTasksIncludingDelayedTasks()

        val slot = io.mockk.slot<Any>()
        verify(exactly = 1) { sink.success(capture(slot)) }

        val map = slot.captured as Map<*, *>
        assertEquals("BOTTOM", map["phase"])
        assertEquals(5, map["repCount"])
        assertEquals(listOf("LEAN_FORWARD"), map["activeFaults"])
        assertEquals(85f, map["kneeAngle"])
        assertEquals(60f, map["hipAngle"])
        assertEquals(true, map["isLandmarkReliable"])
        assertEquals("HALF_SQUAT", map["activePreset"])
        assertEquals(120f, map["angleThreshold"])
        assertEquals("Athletic Strength (½ Squat)", map["presetLabel"])
    }
}

package com.example.flt_kotlin_pose

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import android.util.Log
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

private const val TAG = "SquatAudioController"

class SquatAudioController(private val context: Context) {

    private var soundPool: SoundPool? = null
    private val soundMap = HashMap<String, Int>()
    private val loadedSoundIds = ConcurrentHashMap.newKeySet<Int>()

    private val totalSounds = 4
    private val loadedCount = AtomicInteger(0)

    // Per-cue cooldowns prevent the same cue from repeating too fast.
    // The global 1-second block that was here previously was removed because it
    // silently dropped the *second* cue whenever two different faults fired
    // in rapid succession (e.g. GO_DEEPER followed immediately by LEAN_FORWARD).
    private val lastPlayedTime = HashMap<String, Long>()

    private val cooldownMs = mapOf(
        "go_deeper" to 1000L,
        "chest_up"  to 800L,
        "knees_out" to 800L,
        "too_low"   to 1000L
    )

    private var activeStreamId = 0

    init {
        val audioAttributes = AudioAttributes.Builder()
            // USAGE_MEDIA routes cues through the media audio stream (same as music/videos).
            // USAGE_ASSISTANCE_SONIFICATION was wrong — it uses the notification/ring stream
            // which is silenced by Do Not Disturb, Focus Mode, and vibrate-only profiles.
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()

        soundPool = SoundPool.Builder()
            .setMaxStreams(2)
            .setAudioAttributes(audioAttributes)
            .build()

        soundPool?.setOnLoadCompleteListener { _, sampleId, status ->
            if (status == 0) {
                loadedSoundIds.add(sampleId)
                val count = loadedCount.incrementAndGet()
                if (count >= totalSounds) {
                    Log.d(TAG, "All audio ready for real-time coaching")
                }
            } else {
                Log.e(TAG, "Failed to load sample: $sampleId, status: $status")
            }
        }

        soundPool?.let { pool ->
            loadSound(pool, "go_deeper", R.raw.go_deeper)
            loadSound(pool, "chest_up", R.raw.chest_up)
            loadSound(pool, "knees_out", R.raw.knees_out)
            loadSound(pool, "too_low", R.raw.too_low)
        }
    }

    private fun loadSound(pool: SoundPool, key: String, resId: Int) {
        try {
            val soundId = pool.load(context, resId, 1)
            soundMap[key] = soundId
        } catch (e: Exception) {
            Log.e(TAG, "Failed loading cue: $key", e)
        }
    }

    fun playCue(cueName: String) {
        val soundId = soundMap[cueName] ?: return
        if (!loadedSoundIds.contains(soundId)) return

        val now = System.currentTimeMillis()
        val last = lastPlayedTime[cueName] ?: 0L
        val cooldown = cooldownMs[cueName] ?: 1000L
        if (now - last < cooldown) return

        lastPlayedTime[cueName] = now

        // Stop the currently active stream to ensure no overlapping audio
        if (activeStreamId != 0) {
            soundPool?.stop(activeStreamId)
        }

        activeStreamId = soundPool?.play(soundId, 1f, 1f, 1, 0, 1f) ?: 0

        Log.d(TAG, "Cue: $cueName, StreamId: $activeStreamId")
    }

    fun release() {
        soundPool?.release()
        soundPool = null
        soundMap.clear()
        loadedSoundIds.clear()
        lastPlayedTime.clear()
        activeStreamId = 0
        loadedCount.set(0)
    }
}
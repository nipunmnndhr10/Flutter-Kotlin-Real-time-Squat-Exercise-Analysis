package com.example.flt_kotlin_pose

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import android.util.Log
import java.util.concurrent.atomic.AtomicInteger

private const val TAG = "SquatAudioController"

class SquatAudioController(private val context: Context) {

    private var soundPool: SoundPool? = null
    private val soundMap = HashMap<String, Int>()

    private val totalSounds = 4
    private val loadedCount = AtomicInteger(0)
    private val isReady get() = loadedCount.get() >= totalSounds

    // ---------------- FASTER COOLDOWNS (REDUCED PAUSE TIME) ----------------
    private val lastPlayedTime = HashMap<String, Long>()

    private val cooldownMs = mapOf(
        "go_deeper" to 700L,
        "chest_up" to 900L,
        "knees_out" to 900L,
        "too_low" to 1200L
    )

    init {
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        soundPool = SoundPool.Builder()
            .setMaxStreams(4)
            .setAudioAttributes(audioAttributes)
            .build()

        soundPool?.setOnLoadCompleteListener { _, _, status ->
            if (status == 0) {
                val count = loadedCount.incrementAndGet()
                if (count >= totalSounds) {
                    Log.d(TAG, "Audio ready for real-time coaching")
                }
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
        if (!isReady) return

        val soundId = soundMap[cueName] ?: return

        val now = System.currentTimeMillis()
        val last = lastPlayedTime[cueName] ?: 0L
        val cooldown = cooldownMs[cueName] ?: 800L

        // ---------------- LOWER LATENCY FEEDBACK ----------------
        if (now - last < cooldown) return

        lastPlayedTime[cueName] = now

        soundPool?.play(soundId, 1f, 1f, 1, 0, 1f)

        Log.d(TAG, "Cue: $cueName")
    }

    fun release() {
        soundPool?.release()
        soundPool = null
        soundMap.clear()
        lastPlayedTime.clear()
        loadedCount.set(0)
    }
}
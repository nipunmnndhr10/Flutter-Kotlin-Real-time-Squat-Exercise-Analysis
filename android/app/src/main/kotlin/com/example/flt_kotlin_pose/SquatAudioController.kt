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

    // Count how many sounds have finished loading — only play once ALL are ready
    private val totalSounds = 3
    private val loadedCount = AtomicInteger(0)
    private val isReady get() = loadedCount.get() >= totalSounds

    init {
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        soundPool = SoundPool.Builder()
            .setMaxStreams(3)
            .setAudioAttributes(audioAttributes)
            .build()

        soundPool?.setOnLoadCompleteListener { _, _, status ->
            if (status == 0) {
                val count = loadedCount.incrementAndGet()
                if (count >= totalSounds) {
                    Log.d(TAG, "All $totalSounds audio assets loaded — ready to play.")
                }
            } else {
                Log.e(TAG, "A sound asset failed to load (status=$status).")
            }
        }

        soundPool?.let { pool ->
            loadSound(pool, "go_deeper", R.raw.go_deeper)
            loadSound(pool, "chest_up",  R.raw.chest_up)
            loadSound(pool, "knees_out", R.raw.knees_out)
        }
    }

    private fun loadSound(pool: SoundPool, key: String, resId: Int) {
        try {
            val soundId = pool.load(context, resId, 1)
            soundMap[key] = soundId
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load audio resource for cue: $key", e)
        }
    }

    fun playCue(cueName: String) {
        if (!isReady) {
            Log.w(TAG, "Cue '$cueName' skipped — SoundPool still loading.")
            return
        }
        val soundId = soundMap[cueName]
        if (soundId == null) {
            Log.w(TAG, "Cue '$cueName' not found in soundMap.")
            return
        }
        soundPool?.play(soundId, 1.0f, 1.0f, 1, 0, 1.0f)
        Log.d(TAG, "Playing cue: $cueName")
    }

    fun release() {
        soundPool?.release()
        soundPool = null
        soundMap.clear()
        loadedCount.set(0)
        Log.d(TAG, "SoundPool released.")
    }
}
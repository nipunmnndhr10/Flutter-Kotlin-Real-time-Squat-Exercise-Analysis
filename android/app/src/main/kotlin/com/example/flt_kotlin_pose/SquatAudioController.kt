package com.example.flt_kotlin_pose

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import android.util.Log

class SquatAudioController(private val context: Context) {

    private var soundPool: SoundPool? = null
    private val soundMap = HashMap<String, Int>()
    private var isLoaded = false

    init {
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        soundPool = SoundPool.Builder()
            .setMaxStreams(3)
            .setAudioAttributes(audioAttributes)
            .build()

        soundPool?.let { pool ->
            loadSound(pool, "go_deeper", R.raw.go_deeper)
            loadSound(pool, "chest_up", R.raw.chest_up)
            loadSound(pool, "knees_out", R.raw.knees_out)
            
            pool.setOnLoadCompleteListener { _, _, status ->
                if (status == 0) {
                    isLoaded = true
                    Log.d("SquatAudio", "Low-latency audio assets loaded successfully.")
                }
            }
        }
    }

    private fun loadSound(pool: SoundPool, key: String, resId: Int) {
        try {
            val soundId = pool.load(context, resId, 1)
            soundMap[key] = soundId
        } catch (e: Exception) {
            Log.e("SquatAudio", "Failed to load audio resource for cue: $key", e)
        }
    }

    fun playCue(cueName: String) {
        val soundId = soundMap[cueName]
        if (soundPool != null && soundId != null && isLoaded) {
            soundPool?.play(soundId, 1.0f, 1.0f, 1, 0, 1.0f)
            Log.d("SquatAudio", "Playing cue: $cueName")
        } else {
            Log.w("SquatAudio", "Audio cue '$cueName' skipped: SoundPool unready.")
        }
    }

    fun release() {
        soundPool?.release()
        soundPool = null
        soundMap.clear()
        isLoaded = false
        Log.d("SquatAudio", "SoundPool hardware resources destroyed clean.")
    }
}
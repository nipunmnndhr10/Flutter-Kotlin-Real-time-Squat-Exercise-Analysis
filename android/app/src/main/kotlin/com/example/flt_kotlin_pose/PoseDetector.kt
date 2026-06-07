package com.example.flt_kotlin_pose

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.SystemClock
import android.util.Log
import androidx.camera.core.ImageProxy
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import java.util.concurrent.atomic.AtomicBoolean

private const val TAG = "PoseLandmarkerProcessor"

private val TRACKED_LANDMARK_INDICES = setOf(
    11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22,
    23, 24, 25, 26, 27, 28, 29, 30, 31, 32,
)

// Hardcoded — tuned for squat analysis
private val SQUAT_CONFIG = PoseDetectorConfig(
    detectionThreshold = 0.5f,
    trackingThreshold  = 0.6f,
    presenceThreshold  = 0.5f,
)

data class PoseDetectorConfig(
    val detectionThreshold: Float = 0.5f,
    val trackingThreshold:  Float = 0.6f,
    val presenceThreshold:  Float = 0.5f,
)

data class PoseLandmarkPayload(
    val index:      Int,
    val x:          Float,
    val y:          Float,
    val visibility: Float?,
    val presence:   Float?,
)

data class PoseFramePayload(
    val frameWidth:  Int,
    val frameHeight: Int,
    val landmarks:   List<PoseLandmarkPayload>,
)

class PoseLandmarkerProcessor(
    context: Context,
    // FIX: mirrorLandmarks is now a @Volatile var so it can be toggled
    // at runtime when the user switches between front and back camera.
    @Volatile var mirrorLandmarks: Boolean = false,
) {
    private val lock = Any()
    private val isProcessingFrame = AtomicBoolean(false)
    private var poseLandmarker: PoseLandmarker = createPoseLandmarker(context)
    private var pendingBitmap: Bitmap? = null

    fun detectLiveStream(imageProxy: ImageProxy) {
        if (!isProcessingFrame.compareAndSet(false, true)) {
            imageProxy.close()
            return
        }

        try {
            val rotationDegrees = imageProxy.imageInfo.rotationDegrees
            val bitmapBuffer = Bitmap.createBitmap(
                imageProxy.width, imageProxy.height, Bitmap.Config.ARGB_8888
            )
            bitmapBuffer.copyPixelsFromBuffer(imageProxy.planes[0].buffer)

            // FIX: Read mirrorLandmarks once per frame so it's consistent
            // across the matrix operations even if toggled mid-frame.
            val shouldMirror = mirrorLandmarks

            val matrix = Matrix().apply {
                postRotate(rotationDegrees.toFloat())
                if (shouldMirror) {
                    postScale(-1f, 1f, bitmapBuffer.width / 2f, bitmapBuffer.height / 2f)
                }
            }

            val rotatedBitmap = Bitmap.createBitmap(
                bitmapBuffer, 0, 0,
                bitmapBuffer.width, bitmapBuffer.height,
                matrix, true,
            )

            bitmapBuffer.recycle()
            imageProxy.close()

            val mpImage: MPImage = BitmapImageBuilder(rotatedBitmap).build()

            synchronized(lock) {
                pendingBitmap?.recycle()
                pendingBitmap = rotatedBitmap
            }

            synchronized(lock) { poseLandmarker }.detectAsync(mpImage, SystemClock.uptimeMillis())

        } catch (error: Throwable) {
            imageProxy.close()
            synchronized(lock) {
                pendingBitmap?.recycle()
                pendingBitmap = null
            }
            isProcessingFrame.set(false)
            Log.e(TAG, "Failed to process frame", error)
        }
    }

    fun close() {
        synchronized(lock) { poseLandmarker.close() }
        isProcessingFrame.set(false)
    }

    private fun createPoseLandmarker(context: Context): PoseLandmarker {
        val baseOptions = BaseOptions.builder()
            .setModelAssetPath("pose_landmarker_lite.task")
            .setDelegate(Delegate.CPU)
            .build()

        val options = PoseLandmarker.PoseLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setRunningMode(RunningMode.LIVE_STREAM)
            .setMinPoseDetectionConfidence(SQUAT_CONFIG.detectionThreshold)
            .setMinTrackingConfidence(SQUAT_CONFIG.trackingThreshold)
            .setMinPosePresenceConfidence(SQUAT_CONFIG.presenceThreshold)
            .setResultListener(this::onResult)
            .setErrorListener(this::onError)
            .build()

        return PoseLandmarker.createFromOptions(context, options)
    }

    private fun onResult(result: PoseLandmarkerResult, input: MPImage) {
        val allLandmarks = result.landmarks().firstOrNull().orEmpty()
        val filteredLandmarks = allLandmarks.mapIndexedNotNull { index, landmark ->
            if (index !in TRACKED_LANDMARK_INDICES) null
            else PoseLandmarkPayload(
                index      = index,
                x          = landmark.x().coerceIn(0f, 1f),
                y          = landmark.y().coerceIn(0f, 1f),
                visibility = landmark.visibility().takeIf { it.isPresent }?.get(),
                presence   = landmark.presence().takeIf { it.isPresent }?.get(),
            )
        }

        PoseLandmarkEventBus.emit(
            PoseFramePayload(
                frameWidth  = input.width,
                frameHeight = input.height,
                landmarks   = filteredLandmarks,
            )
        )

        synchronized(lock) {
            pendingBitmap?.recycle()
            pendingBitmap = null
        }
        isProcessingFrame.set(false)
        Log.v(TAG, "Landmarks emitted: ${input.width}x${input.height}")
    }

    private fun onError(error: RuntimeException) {
        PoseLandmarkEventBus.error(error.message ?: "Pose landmarker error")
        synchronized(lock) {
            pendingBitmap?.recycle()
            pendingBitmap = null
        }
        isProcessingFrame.set(false)
        Log.e(TAG, error.message ?: "Pose landmarker error")
    }
}
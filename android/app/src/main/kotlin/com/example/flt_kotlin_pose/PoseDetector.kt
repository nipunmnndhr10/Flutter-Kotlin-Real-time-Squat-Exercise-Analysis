package com.example.flt_kotlin_pose

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.PorterDuff
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
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean

private const val TAG = "PoseLandmarkerProcessor"

private val TRACKED_LANDMARK_INDICES = setOf(
    11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22,
    23, 24, 25, 26, 27, 28, 29, 30, 31, 32,
)

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
    val z:          Float = 0f,
    val visibility: Float?,
    val presence:   Float?,
)

data class PoseFramePayload(
    val frameWidth:  Int,
    val frameHeight: Int,
    val landmarks:   List<PoseLandmarkPayload>,
    val timestampMs: Long = System.currentTimeMillis(),
)

class PoseLandmarkerProcessor(
    context: Context,
    @Volatile var mirrorLandmarks: Boolean = false,
) {
    private val lock = Any()
    private val isProcessingFrame = AtomicBoolean(false)
    @Volatile private var lastFrameProcessingTime = 0L
    @Volatile var isPaused: Boolean = false
    private var poseLandmarker: PoseLandmarker = createPoseLandmarker(context)

    // PERFORMANCE METRICS 

    // Inference timing
    private var inferenceStartTime = 0L
    private var totalInferenceTime = 0.0
    private var processedFrames = 0

    // FPS calculation
    private var fpsFrameCount = 0
    private var fpsStartTime = System.currentTimeMillis()

    // Session timing
    private val sessionStartTime = System.currentTimeMillis()

    // Reusable bitmaps — double-buffered to prevent Mali GPU gralloc buffer locking collisions
    private var bufferBitmap: Bitmap? = null
    private val rotatedBitmaps = arrayOfNulls<Bitmap>(2)
    private val rotationCanvases = arrayOfNulls<Canvas>(2)
    private var frameBufferCounter = 0
    private var pixelArray: IntArray? = null

    fun detectLiveStream(imageProxy: ImageProxy) {
        if (isPaused) {
            imageProxy.close()
            return
        }

        val now = SystemClock.uptimeMillis()
        val processingTime = now - lastFrameProcessingTime
        if (isProcessingFrame.get() && processingTime > 1000L) {
            Log.w(TAG, "Watchdog triggered: PoseLandmarker took too long ($processingTime ms), resetting isProcessingFrame")
            isProcessingFrame.set(false)
        }

        if (!isProcessingFrame.compareAndSet(false, true)) {
            imageProxy.close()
            return
        }
        lastFrameProcessingTime = SystemClock.uptimeMillis()

        try {
            val rotationDegrees = imageProxy.imageInfo.rotationDegrees
            val shouldMirror = mirrorLandmarks

            val srcW = imageProxy.width
            val srcH = imageProxy.height
            val isRotated90 = rotationDegrees % 180 != 0
            val dstW = if (isRotated90) srcH else srcW
            val dstH = if (isRotated90) srcW else srcH

            val bufIndex = frameBufferCounter % 2
            frameBufferCounter++

            // Ensure reusable bitmaps match current dimensions
            val buf = getOrResizeBitmap(bufferBitmap, srcW, srcH).also { bufferBitmap = it }
            val rot = getOrResizeBitmap(rotatedBitmaps[bufIndex], dstW, dstH).also { rotatedBitmaps[bufIndex] = it }

            // Stride-safe buffer copy (handles CameraX padding)
            val plane = imageProxy.planes[0]
            copyPixelsWithStride(plane.buffer, plane.rowStride, srcW, srcH, buf)

            imageProxy.close()

            val canvas = getOrCreateCanvas(rot, bufIndex)
            // Clear reused bitmap before drawing transformed pixels.
            canvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR)

            // Rotate into destination bounds, then optionally mirror for front camera.
            val matrix = buildTransformMatrix(rotationDegrees, srcW, srcH, dstW, dstH, shouldMirror)
            canvas.drawBitmap(buf, matrix, null)

            val mpImage: MPImage = BitmapImageBuilder(rot).build()

            // Start inference timer
            inferenceStartTime = System.nanoTime()

            synchronized(lock) { poseLandmarker }.detectAsync(mpImage, SystemClock.uptimeMillis())

        } catch (error: Throwable) {
            imageProxy.close()
            isProcessingFrame.set(false)
            Log.e(TAG, "Failed to process frame", error)
        }
    }

    fun close() {
        synchronized(lock) { poseLandmarker.close() }
        isProcessingFrame.set(false)
        bufferBitmap?.recycle(); bufferBitmap = null
        rotatedBitmaps[0]?.recycle(); rotatedBitmaps[0] = null
        rotatedBitmaps[1]?.recycle(); rotatedBitmaps[1] = null
        pixelArray = null
        rotationCanvases[0] = null
        rotationCanvases[1] = null
    }

    private fun createPoseLandmarker(context: Context): PoseLandmarker {
        val baseOptionsBuilder = BaseOptions.builder()
            .setModelAssetPath("pose_landmarker_lite.task")

        try {
            baseOptionsBuilder.setDelegate(Delegate.GPU)
        } catch (e: Exception) {
            Log.w(TAG, "GPU Delegate unavailable, falling back to CPU", e)
            baseOptionsBuilder.setDelegate(Delegate.CPU)
        }

        val optionsBuilder = PoseLandmarker.PoseLandmarkerOptions.builder()
            .setBaseOptions(baseOptionsBuilder.build())
            .setRunningMode(RunningMode.LIVE_STREAM)
            .setMinPoseDetectionConfidence(SQUAT_CONFIG.detectionThreshold)
            .setMinTrackingConfidence(SQUAT_CONFIG.trackingThreshold)
            .setMinPosePresenceConfidence(SQUAT_CONFIG.presenceThreshold)
            .setResultListener(this::onResult)
            .setErrorListener(this::onError)

        return try {
            PoseLandmarker.createFromOptions(context, optionsBuilder.build())
        } catch (gpuError: Exception) {
            Log.w(TAG, "Failed to create PoseLandmarker with GPU delegate, falling back to CPU", gpuError)
            val fallbackBaseOptions = BaseOptions.builder()
                .setModelAssetPath("pose_landmarker_lite.task")
                .setDelegate(Delegate.CPU)
                .build()
            val fallbackOptions = PoseLandmarker.PoseLandmarkerOptions.builder()
                .setBaseOptions(fallbackBaseOptions)
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setMinPoseDetectionConfidence(SQUAT_CONFIG.detectionThreshold)
                .setMinTrackingConfidence(SQUAT_CONFIG.trackingThreshold)
                .setMinPosePresenceConfidence(SQUAT_CONFIG.presenceThreshold)
                .setResultListener(this::onResult)
                .setErrorListener(this::onError)
                .build()
            PoseLandmarker.createFromOptions(context, fallbackOptions)
        }
    }

    private fun onResult(result: PoseLandmarkerResult, input: MPImage) {
        val inferenceTime = (System.nanoTime() - inferenceStartTime) / 1_000_000.0

        processedFrames++
        totalInferenceTime += inferenceTime
        fpsFrameCount++

        val elapsed = System.currentTimeMillis() - fpsStartTime

        if (processedFrames == 1) {
            val devMsg = "Device: ${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL} | Android: ${android.os.Build.VERSION.RELEASE}"
            Log.i(TAG, devMsg)
            Log.i("Performance", devMsg)
        }

        if (elapsed >= 1000) {
            val currentFps = fpsFrameCount * 1000f / elapsed
            val averageInference = totalInferenceTime / processedFrames

            val singleLinePerf = "PERFORMANCE | Inference: %.2f ms | AverageInference: %.2f ms | FPS: %.1f | Frames: %d".format(
                inferenceTime,
                averageInference,
                currentFps,
                processedFrames
            )

            // Log single-line summary to both TAG ("PoseLandmarkerProcessor") and "Performance"
            Log.i(TAG, singleLinePerf)
            Log.i("Performance", singleLinePerf)

            // Log formatted multi-line summary
            val multiLinePerf = """
                ================ PERFORMANCE =================
                Inference        : %.2f ms
                AverageInference : %.2f ms
                FPS              : %.1f
                Frames           : %d
                =============================================
                """.trimIndent().format(
                inferenceTime,
                averageInference,
                currentFps,
                processedFrames
            )

            Log.i(TAG, multiLinePerf)
            Log.i("Performance", multiLinePerf)

            fpsFrameCount = 0
            fpsStartTime = System.currentTimeMillis()
        }

        if (isPaused) {
            isProcessingFrame.set(false)
            return
        }

        val allLandmarks = result.landmarks().firstOrNull().orEmpty()

        // Verify genuine human pose presence: if key joints (shoulders, hips, knees, ankles)
        // do not meet 0.55 average visibility, reject false-positive hallucinations on fans/furniture.
        val isHumanDetected = run {
            if (allLandmarks.size < 29) false
            else {
                val keyIndices = listOf(11, 12, 23, 24, 25, 26, 27, 28)
                val avgVis = keyIndices.map { idx ->
                    allLandmarks[idx].visibility().takeIf { it.isPresent }?.get() ?: 0f
                }.average()
                avgVis >= 0.55
            }
        }

        val filteredLandmarks = if (!isHumanDetected) emptyList() else allLandmarks.mapIndexedNotNull { index, landmark ->
            if (index !in TRACKED_LANDMARK_INDICES) null
            else PoseLandmarkPayload(
                index      = index,
                x          = landmark.x().coerceIn(0f, 1f),
                y          = landmark.y().coerceIn(0f, 1f),
                z          = landmark.z(),
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

        isProcessingFrame.set(false)
    }

    private fun onError(error: RuntimeException) {
        if (isPaused) {
            isProcessingFrame.set(false)
            return
        }

        PoseLandmarkEventBus.error(error.message ?: "Pose landmarker error")
        isProcessingFrame.set(false)
        Log.e(TAG, error.message ?: "Pose landmarker error")
    }

    // ---------- Reusable helpers ----------

    private fun getOrResizeBitmap(existing: Bitmap?, width: Int, height: Int): Bitmap {
        if (existing != null && existing.width == width && existing.height == height) {
            return existing
        }
        existing?.recycle()
        return Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    }

    private fun getOrCreateCanvas(bitmap: Bitmap, bufIndex: Int): Canvas {
        val existing = rotationCanvases[bufIndex]
        if (existing != null) {
            existing.setBitmap(bitmap)
            return existing
        }
        return Canvas(bitmap).also { rotationCanvases[bufIndex] = it }
    }

    /** Copies a CameraX ImageProxy buffer into a Bitmap, handling row-stride padding. */
    private fun copyPixelsWithStride(
        buffer: ByteBuffer,
        rowStride: Int,
        width: Int,
        height: Int,
        bitmap: Bitmap,
    ) {
        // Fast path: tightly packed buffer — no padding
        if (rowStride == width * 4) {
            buffer.rewind()
            bitmap.copyPixelsFromBuffer(buffer)
            return
        }

        // Safe path: row-by-row respecting stride
        val pixels = getOrResizePixelArray(width * height)
        buffer.rewind()

        for (y in 0 until height) {
            val rowBase = y * rowStride
            val pixelRow = y * width
            for (x in 0 until width) {
                val pos = rowBase + x * 4
                val r = buffer.get(pos).toInt() and 0xFF
                val g = buffer.get(pos + 1).toInt() and 0xFF
                val b = buffer.get(pos + 2).toInt() and 0xFF
                val a = buffer.get(pos + 3).toInt() and 0xFF
                pixels[pixelRow + x] = (a shl 24) or (r shl 16) or (g shl 8) or b
            }
        }
        bitmap.setPixels(pixels, 0, width, 0, 0, width, height)
    }

    private fun getOrResizePixelArray(size: Int): IntArray {
        val existing = pixelArray
        if (existing != null && existing.size >= size) {
            return existing
        }
        return IntArray(size).also { pixelArray = it }
    }

    private fun buildTransformMatrix(
        rotationDegrees: Int,
        srcWidth: Int,
        srcHeight: Int,
        dstWidth: Int,
        dstHeight: Int,
        mirror: Boolean,
    ): Matrix {
        val matrix = Matrix()

        when ((rotationDegrees % 360 + 360) % 360) {
            0 -> Unit
            90 -> {
                matrix.postRotate(90f)
                matrix.postTranslate(dstWidth.toFloat(), 0f)
            }
            180 -> {
                matrix.postRotate(180f)
                matrix.postTranslate(dstWidth.toFloat(), dstHeight.toFloat())
            }
            270 -> {
                matrix.postRotate(270f)
                matrix.postTranslate(0f, dstHeight.toFloat())
            }
            else -> {
                matrix.postRotate(rotationDegrees.toFloat(), srcWidth / 2f, srcHeight / 2f)
                matrix.postTranslate((dstWidth - srcWidth) / 2f, (dstHeight - srcHeight) / 2f)
            }
        }

        if (mirror) {
            matrix.postScale(-1f, 1f, dstWidth / 2f, dstHeight / 2f)
        }

        return matrix
    }
}

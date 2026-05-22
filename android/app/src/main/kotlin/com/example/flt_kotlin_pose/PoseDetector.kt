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

 data class PoseLandmarkPayload(
        val x: Float,
        val y: Float,
        val visibility: Float?,
        val presence: Float?,
)

class PoseLandmarkerProcessor(
        context: Context,
        private val mirrorLandmarks: Boolean = false,
) {

   private val poseLandmarker: PoseLandmarker

   init {
      val baseOptions =
              BaseOptions.builder()
                      .setModelAssetPath("pose_landmarker_lite.task")
                      .setDelegate(Delegate.CPU)
                      .build()

      val options =
              PoseLandmarker.PoseLandmarkerOptions.builder()
                      .setBaseOptions(baseOptions)
                      .setRunningMode(RunningMode.LIVE_STREAM)
                      .setMinPoseDetectionConfidence(0.5f)
                      .setMinTrackingConfidence(0.5f)
                      .setMinPosePresenceConfidence(0.5f)
                      .setResultListener(this::onResult)
                      .setErrorListener(this::onError)
                      .build()

      poseLandmarker = PoseLandmarker.createFromOptions(context, options)
   }

   fun detectLiveStream(imageProxy: ImageProxy) {
      val frameTime = SystemClock.uptimeMillis()
      val rotationDegrees = imageProxy.imageInfo.rotationDegrees.toFloat()

      val bitmapBuffer =
              Bitmap.createBitmap(imageProxy.width, imageProxy.height, Bitmap.Config.ARGB_8888)
      bitmapBuffer.copyPixelsFromBuffer(imageProxy.planes[0].buffer)

      val matrix =
              Matrix().apply {
                 postRotate(rotationDegrees)
                 if (mirrorLandmarks) {
                    postScale(-1f, 1f, bitmapBuffer.width / 2f, bitmapBuffer.height / 2f)
                 }
              }

      val rotatedBitmap =
              Bitmap.createBitmap(
                      bitmapBuffer,
                      0,
                      0,
                      bitmapBuffer.width,
                      bitmapBuffer.height,
                      matrix,
                      true
              )

      imageProxy.close()
      bitmapBuffer.recycle()

      val mpImage: MPImage = BitmapImageBuilder(rotatedBitmap).build()
      poseLandmarker.detectAsync(mpImage, frameTime)
   }

   fun close() {
      poseLandmarker.close()
   }

   private fun onResult(
           result: com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult,
           input: MPImage,
   ) {
      val landmarks = result.landmarks().firstOrNull().orEmpty()
      val payload =
              landmarks.map { landmark ->
                 PoseLandmarkPayload(
                         x = landmark.x().coerceIn(0f, 1f),
                         y = landmark.y().coerceIn(0f, 1f),
                         visibility = landmark.visibility().orElse(null),
                         presence = landmark.presence().orElse(null),
                 )
              }

      PoseLandmarkEventBus.emit(payload)
      Log.v(TAG, "Pose landmarks emitted for ${input.width}x${input.height}")
   }

   private fun onError(error: RuntimeException) {
      PoseLandmarkEventBus.error(error.message ?: "Pose landmarker error")
      Log.e(TAG, error.message ?: "Pose landmarker error")
   }

   companion object {
      private const val TAG = "PoseLandmarkerProcessor"
   }
}

package com.example.flt_kotlin_pose

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

internal object PoseLandmarkEventBus {
   private val mainHandler = Handler(Looper.getMainLooper())

   @Volatile
   var eventSink: EventChannel.EventSink? = null

   fun emit(framePayload: PoseFramePayload) {
      mainHandler.post {
         eventSink?.success(
                 mapOf(
                         "frameWidth" to framePayload.frameWidth,
                         "frameHeight" to framePayload.frameHeight,
                         "landmarks" to framePayload.landmarks.map {
                            mapOf(
                                    "index" to it.index,
                                    "x" to it.x,
                                    "y" to it.y,
                                    "visibility" to it.visibility,
                                    "presence" to it.presence,
                            )
                         },
                 )
         )
      }
   }

   fun error(message: String) {
      mainHandler.post {
         eventSink?.error("POSE_ERROR", message, null)
      }
   }
}

internal object PoseCameraRegistry {
   @Volatile
   var processor: PoseLandmarkerProcessor? = null

   fun updateConfig(context: Context, config: PoseDetectorConfig) {
      processor?.updateConfig(context, config)
   }

   fun clear(processor: PoseLandmarkerProcessor) {
      if (this.processor === processor) {
         this.processor = null
      }
   }
}

class PoseCameraViewFactory(
        private val lifecycleOwner: LifecycleOwner,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
   override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
      return PoseCameraView(context, lifecycleOwner)
   }
}

private class PoseCameraView(
        context: Context,
        private val lifecycleOwner: LifecycleOwner,
) : FrameLayout(context), PlatformView {

   private val previewView =
           PreviewView(context).apply {
              implementationMode = PreviewView.ImplementationMode.COMPATIBLE
              scaleType = PreviewView.ScaleType.FILL_CENTER
              layoutParams =
                      LayoutParams(
                              ViewGroup.LayoutParams.MATCH_PARENT,
                              ViewGroup.LayoutParams.MATCH_PARENT,
                      )
           }
   private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
   private val poseLandmarkerProcessor = PoseLandmarkerProcessor(context)
   private var cameraProvider: ProcessCameraProvider? = null

   init {
      PoseCameraRegistry.processor = poseLandmarkerProcessor
      addView(previewView)
      startCamera(context)
   }

   private fun startCamera(context: Context) {
      val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
      cameraProviderFuture.addListener(
              {
                 val provider = cameraProviderFuture.get()
                 cameraProvider = provider
                 bindCamera(provider)
              },
              ContextCompat.getMainExecutor(context)
      )
   }

   private fun bindCamera(cameraProvider: ProcessCameraProvider) {
      val preview =
              Preview.Builder().build().also {
                 it.setSurfaceProvider(previewView.surfaceProvider)
              }

      val imageAnalysis =
              ImageAnalysis.Builder()
                      .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                      .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                      .build()

      imageAnalysis.setAnalyzer(cameraExecutor) { imageProxy ->
         poseLandmarkerProcessor.detectLiveStream(imageProxy)
      }

      cameraProvider.unbindAll()
      cameraProvider.bindToLifecycle(
              lifecycleOwner,
              CameraSelector.DEFAULT_BACK_CAMERA,
              preview,
              imageAnalysis,
      )
   }

   override fun getView() = this

   override fun dispose() {
      cameraProvider?.unbindAll()
      cameraExecutor.shutdownNow()
      PoseCameraRegistry.clear(poseLandmarkerProcessor)
      poseLandmarkerProcessor.close()
   }
}

package com.example.flt_kotlin_pose

import android.content.Context
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

internal object PoseCameraRegistry {
    @Volatile var processor: PoseLandmarkerProcessor? = null

    // Active view reference so toggleCamera can rebind the camera
    @Volatile private var activeView: PoseCameraView? = null

    fun register(view: PoseCameraView) { activeView = view }
    fun unregister(view: PoseCameraView) { if (activeView === view) activeView = null }

    fun toggleCamera(context: Context, useFront: Boolean) {
        activeView?.switchCamera(useFront)
    }

    fun clear(processor: PoseLandmarkerProcessor) {
        if (this.processor === processor) this.processor = null
    }
}

class PoseCameraViewFactory(
    private val lifecycleOwner: LifecycleOwner,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return PoseCameraView(context, lifecycleOwner)
    }
}

internal class PoseCameraView(
    context: Context,
    private val lifecycleOwner: LifecycleOwner,
) : FrameLayout(context), PlatformView {

    private val previewView = PreviewView(context).apply {
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        scaleType = PreviewView.ScaleType.FILL_CENTER
        layoutParams = LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
    }

    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val poseLandmarkerProcessor = PoseLandmarkerProcessor(context)
    private var cameraProvider: ProcessCameraProvider? = null
    private var useFrontCamera = false

    // FIX: Build ImageAnalysis once and reuse it across camera rebinds.
    // Recreating it on every bindCamera() call leaks the old analyzer
    // reference and creates unnecessary object churn.
    private val imageAnalysis = ImageAnalysis.Builder()
        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
        .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
        .build()
        .also { analysis ->
            analysis.setAnalyzer(cameraExecutor) { imageProxy ->
                poseLandmarkerProcessor.detectLiveStream(imageProxy)
            }
        }

    init {
        PoseCameraRegistry.processor = poseLandmarkerProcessor
        PoseCameraRegistry.register(this)
        addView(previewView)
        startCamera(context)
    }

    private fun startCamera(context: Context) {
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener(
            {
                val provider = future.get()
                cameraProvider = provider
                bindCamera(provider)
            },
            ContextCompat.getMainExecutor(context),
        )
    }

    private fun bindCamera(cameraProvider: ProcessCameraProvider) {
        val preview = Preview.Builder().build().also {
            it.setSurfaceProvider(previewView.surfaceProvider)
        }

        val selector = if (useFrontCamera)
            CameraSelector.DEFAULT_FRONT_CAMERA
        else
            CameraSelector.DEFAULT_BACK_CAMERA

        cameraProvider.unbindAll()
        cameraProvider.bindToLifecycle(lifecycleOwner, selector, preview, imageAnalysis)
    }

    // FIX: When switching to the front camera, mirror landmark X coordinates
    // in the processor so that left/right faults are not reported inverted.
    // The front camera sensor outputs a horizontally flipped image; mirroring
    // the landmarks corrects for this before the heuristic engine sees them.
    fun switchCamera(front: Boolean) {
        useFrontCamera = front
        poseLandmarkerProcessor.mirrorLandmarks = front
        cameraProvider?.let { bindCamera(it) }
    }

    override fun getView() = this

    override fun dispose() {
        cameraProvider?.unbindAll()
        cameraExecutor.shutdownNow()
        PoseCameraRegistry.unregister(this)
        PoseCameraRegistry.clear(poseLandmarkerProcessor)
        poseLandmarkerProcessor.close()
    }
}
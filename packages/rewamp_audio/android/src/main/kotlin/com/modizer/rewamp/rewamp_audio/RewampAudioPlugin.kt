package com.modizer.rewamp.rewamp_audio

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.view.TextureRegistry
import java.util.concurrent.CountDownLatch

class RewampAudioPlugin : FlutterPlugin {

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        sAppContext = binding.applicationContext
        sTextureRegistry = binding.textureRegistry
        // Visualizer PlatformView: a SurfaceView the native GL renders into
        // directly — SurfaceFlinger composites it as its own layer, bypassing
        // Flutter's Texture/ImageReader import pipeline entirely (which judders:
        // consumer runs on the busy main thread + uncontrolled latch phase).
        binding.platformViewRegistry.registerViewFactory(
            "rewamp_viz_surface", RewampVizViewFactory())
        nativeOnAttach()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Stop the native render thread FIRST: if it keeps swapping frames while
        // the engine detaches, ImageReaderSurfaceProducer.onImage → scheduleFrame
        // throws "FlutterJNI is not attached to native" (fatal on app exit).
        nativeVizShutdown()
        sTextureRegistry = null
    }

    companion object {
        init {
            System.loadLibrary("rewamp_audio")
        }

        private var sAppContext: Context? = null
        private var sTextureRegistry: TextureRegistry? = null
        private val sProducers = HashMap<Long, TextureRegistry.SurfaceProducer>()

        // Called from C++ JNI when playback starts/stops. INTENTIONAL NO-OPS:
        // the Flutter `audio_service` plugin already runs the mediaPlayback
        // foreground service that keeps this process alive in the background AND
        // posts the rich media notification (title/artist/artwork + transport
        // controls). Running a SECOND mediaPlayback foreground service here
        // occupied the slot with a plain "Rewamp / Playing" notification and
        // shadowed audio_service's media notification (no controls, no artwork).
        // Left as no-ops (rather than removing the JNI symbols) so the native
        // engine's calls stay valid; RewampAudioService is now never started.
        @JvmStatic
        fun startAudioService() { /* audio_service owns the foreground service */ }

        @JvmStatic
        fun stopAudioService() { /* audio_service owns the foreground service */ }

        // Uses TextureRegistry.createSurfaceProducer() (Flutter's current external-
        // texture API — works under BOTH Skia and Impeller). The legacy
        // createSurfaceTexture() compat path silently displayed nothing on some
        // devices (MIUI tablet: producer swapped frames fine, consumer never
        // showed them). The registry is main-thread-only and this is invoked from
        // C++ (Dart FFI thread) → hop to the main Looper and block on a latch
        // (<1ms; caller is never the main thread, so no deadlock — and if it ever
        // is, the direct branch runs instead).
        @JvmStatic
        fun jniCreateTexture(width: Int, height: Int): LongArray {
            val reg = sTextureRegistry ?: return longArrayOf(-1L, 0L)
            if (Looper.myLooper() == Looper.getMainLooper()) {
                return createTextureOnMain(reg, width, height)
            }
            var result = longArrayOf(-1L, 0L)
            val latch = CountDownLatch(1)
            Handler(Looper.getMainLooper()).post {
                try {
                    result = createTextureOnMain(reg, width, height)
                } finally {
                    latch.countDown()
                }
            }
            latch.await()
            return result
        }

        private fun createTextureOnMain(
            reg: TextureRegistry, width: Int, height: Int): LongArray {
            val producer = reg.createSurfaceProducer()
            producer.setSize(width, height)
            val surface = producer.surface
            // Pin the frame rate: adaptive-refresh panels (MIUI) treat a texture
            // stream as video-like content and flap the display rate, which
            // reads as periodic judder on the scrolling visualizers.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                try {
                    surface.setFrameRate(120f, Surface.FRAME_RATE_COMPATIBILITY_FIXED_SOURCE)
                } catch (_: Exception) {}
            }
            val nativeWindow = nativeWindowFromSurface(surface)
            sProducers[producer.id()] = producer
            return longArrayOf(producer.id(), nativeWindow)
        }

        @JvmStatic
        fun jniDestroyTexture(textureId: Long) {
            // Release on the main thread too (registry affinity), fire-and-forget.
            Handler(Looper.getMainLooper()).post {
                sProducers.remove(textureId)?.release()
            }
        }

        @JvmStatic
        external fun nativeWindowFromSurface(surface: Surface): Long

        @JvmStatic
        external fun nativeOnAttach()

        @JvmStatic
        external fun nativeVizShutdown()

        // ── PlatformView (SurfaceView) native hooks ─────────────────────────
        @JvmStatic
        external fun nativeVizSurfaceChanged(surface: Surface, mode: Int, width: Int, height: Int, viewId: Long)

        @JvmStatic
        external fun nativeVizSurfaceDestroyed(viewId: Long)
    }
}

// ── Visualizer PlatformView: plain SurfaceView, GL-rendered by native code ──
class RewampVizViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val params = args as? Map<String, Any?>
        val mode = (params?.get("mode") as? Int) ?: 0
        return RewampVizView(context, mode)
    }
}

class RewampVizView(context: Context, private val mode: Int) :
    PlatformView, SurfaceHolder.Callback {

    // Unique per instance: on an effect switch the outgoing view's dispose() can
    // land AFTER the incoming view's surfaceChanged, and both drive the ONE
    // global native surface/thread. Native ignores a destroy whose id no longer
    // owns the surface, so a stale view can't tear down the live one.
    private val viewId = nextViewId.getAndIncrement()

    companion object {
        private val nextViewId = java.util.concurrent.atomic.AtomicLong(0)
    }

    private val surfaceView = SurfaceView(context)

    // Dedupe redundant surfaceChanged callbacks. Android fires surfaceChanged on
    // any structural change (relayout, MIUI compositor churn), often with the SAME
    // Surface and the SAME size. Each call tore down the native EGL surface + the
    // render thread and restarted them — a brief no-producer gap that showed as an
    // intermittent black-frame flicker (cleared by toggling the viz off/on, which
    // recreates the view once, cleanly). Only rebind when the surface instance or
    // its size actually changes.
    private var lastSurface: Surface? = null
    private var lastW = 0
    private var lastH = 0

    init {
        surfaceView.holder.addCallback(this)
    }

    override fun getView() = surfaceView

    override fun dispose() {
        lastSurface = null; lastW = 0; lastH = 0
        RewampAudioPlugin.nativeVizSurfaceDestroyed(viewId)
    }

    override fun surfaceCreated(holder: SurfaceHolder) { /* wait for size */ }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, w: Int, h: Int) {
        val surf = holder.surface
        if (surf === lastSurface && w == lastW && h == lastH) return  // redundant → skip restart
        lastSurface = surf; lastW = w; lastH = h
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                surf.setFrameRate(120f, Surface.FRAME_RATE_COMPATIBILITY_FIXED_SOURCE)
            } catch (_: Exception) {}
        }
        RewampAudioPlugin.nativeVizSurfaceChanged(surf, mode, w, h, viewId)
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        lastSurface = null; lastW = 0; lastH = 0
        RewampAudioPlugin.nativeVizSurfaceDestroyed(viewId)
    }
}

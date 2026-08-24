// Android GPU oscilloscope: JNI bridge to Flutter TextureRegistry + EGL GL context.
// Defines rewamp_viz_register / rewamp_scope_register / rewamp_viz_unregister etc.
// for Android, parallel to src/apple/rewamp_viz_plugin.mm on iOS/macOS.

#include <jni.h>
#include <android/native_window_jni.h>
#include <android/log.h>
#include <GLES3/gl3.h>
#include "../rewamp_audio.h"

#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "rewamp_viz", __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  "rewamp_viz", __VA_ARGS__)

// Defined in rewamp_gl_android.cpp
int rewamp_gl_android_set_window(ANativeWindow* window, int width, int height);
extern "C" void rewamp_gl_release_current(void);

#include <time.h>
#include <pthread.h>
#include <unistd.h>
#include <atomic>
#include <mutex>
#include <android/choreographer.h>
#include <android/looper.h>

// Serializes every viz lifecycle transition (surfaceChanged / surfaceDestroyed /
// unregister / shutdown). They arrive from TWO threads — the platform/UI thread
// (SurfaceHolder callbacks) and the Dart thread (vizUnregister FFI) — and each
// mutates the ONE global EGL context + render thread. Unserialized they raced:
// vizUnregister's eglMakeCurrent on the Dart thread while the render thread still
// owned the context → EGL_BAD_ACCESS, then a context/surface destroyed under a
// live BufferQueue (dead-producer / Adreno DequeueBuffer failed). The render
// thread (sv_thread_main) never takes this lock, so sv_thread_stop()'s join
// under it can't deadlock.
static std::mutex g_sv_lock;
// Each RewampVizView gets a unique id. On an effect switch the OLD child's
// platform view disposes while the NEW child's is already live — both drive this
// one global surface/thread. A destroy from a stale view must NOT tear down the
// surface the live view just installed: surfaceChanged records the owning id and
// surfaceDestroyed only tears down when it still matches.
static jlong g_current_view_id = -1;

// ── GLSL preamble (GLES 3.0) ────────────────────────────────────────────────
#define REWAMP_GL_GLES 1
// Include the shared renderers (they use k_gl_preamble + GLES3 symbols)
#include "../rewamp_viz_render.cpp"
#include "../rewamp_scope_render.cpp"
// notes renderer reuses compile_shader/link_program/k_gl_preamble from
// rewamp_viz_render.cpp, so it must be included after it (same TU). All its
// file-scope symbols are nv_-prefixed → no clash with viz/scope.
#include "../rewamp_notes_render.cpp"
// pattern renderer (mode 4): same deal, pv_-prefixed.
#include "../rewamp_pattern_render.cpp"
// spectrum renderer (mode 5): same deal, sp_-prefixed.
#include "../rewamp_spectrum_render.cpp"

// projectM (viz mode 3) lives in its OWN TU (src/rewamp_projectm_render.cpp):
// unity-including it here would drag projectM's private, generic-named headers
// into this TU. Declare its entry points instead.
#ifdef REWAMP_WITH_PROJECTM
extern "C" int  rewamp_projectm_init(int width, int height);
extern "C" void rewamp_projectm_render(void);
extern "C" void rewamp_projectm_uninit(void);
#endif

// ── JVM state (set once from nativeOnAttach, called from Kotlin JVM context) ─
static JavaVM* g_jvm        = nullptr;
static jclass  g_plugin_cls = nullptr;  // global ref — valid from any thread

static jlong g_current_texture_id = -1;
static int   g_thread_mode = 0;   /* active viz mode (0 stereo, 1 voices, 2 notes) */

// ── JNI: nativeOnAttach — called by Kotlin onAttachedToEngine ───────────────
// This is invoked from the JVM thread so JNIEnv + class loader are correct.
// We store the JavaVM and a global ref to the plugin class for later callbacks.
extern "C" JNIEXPORT void JNICALL
Java_com_modizer_rewamp_rewamp_1audio_RewampAudioPlugin_nativeOnAttach(
        JNIEnv* env, jclass cls) {
    env->GetJavaVM(&g_jvm);
    if (g_plugin_cls) { env->DeleteGlobalRef(g_plugin_cls); }
    g_plugin_cls = (jclass)env->NewGlobalRef(cls);
}

// ── SurfaceView render thread (PlatformView path) ───────────────────────────
// The SurfaceView is composited by SurfaceFlinger directly (one latch per
// vsync) — no Flutter consumer in the pipeline — so a dedicated
// AChoreographer-paced render thread gives native-app smoothness here.
static pthread_t        g_sv_thread;
static std::atomic<int> g_sv_run{0};
static int  g_sv_mode = 0, g_sv_w = 0, g_sv_h = 0;
static std::atomic<int> g_sv_ok{0};

static void sv_frame_cb(long, void* data) {
    ((std::atomic<int>*)data)->store(1, std::memory_order_release);
}

static void* sv_thread_main(void*) {
    rewamp_gl_make_current();
    int err;
    switch (g_sv_mode) {
        case 1:  err = rewamp_scope_init(g_sv_w, g_sv_h);   break;
        case 2:  err = rewamp_noteviz_init(g_sv_w, g_sv_h); break;
#ifdef REWAMP_WITH_PROJECTM
        case 3:  err = rewamp_projectm_init(g_sv_w, g_sv_h); break;
#endif
        case 4:  err = rewamp_patternviz_init(g_sv_w, g_sv_h); break;
        case 5:  err = rewamp_spectrum_init(g_sv_w, g_sv_h);   break;
        default: err = rewamp_viz_init(g_sv_w, g_sv_h);     break;
    }
    g_sv_ok.store(err == 0 ? 1 : -1);
    if (err != 0) { LOGE("sv shader init failed: %d", err); rewamp_gl_release_current(); return nullptr; }
    ALooper_prepare(0);
    AChoreographer* chor = AChoreographer_getInstance();
    std::atomic<int> vsync{0};
    LOGI("surfaceview render thread up (mode=%d %dx%d, %s)",
         g_sv_mode, g_sv_w, g_sv_h, chor ? "vsync" : "usleep");
    while (g_sv_run.load(std::memory_order_relaxed)) {
        if (chor) {
            vsync.store(0, std::memory_order_relaxed);
            AChoreographer_postFrameCallback(chor, sv_frame_cb, &vsync);
            while (!vsync.load(std::memory_order_acquire) &&
                   g_sv_run.load(std::memory_order_relaxed))
                ALooper_pollOnce(50, nullptr, nullptr, nullptr);
            if (!g_sv_run.load(std::memory_order_relaxed)) break;
        }
        // Each render fn does its OWN single rewamp_gl_flush (eglSwapBuffers) and,
        // on Android, forces the framebuffer opaque (alpha=1) right before that swap
        // (rewamp_gl_force_opaque). Do NOT flush again here: the old code rendered +
        // swapped, THEN alpha-cleared + swapped a SECOND time — the alpha-clear hit
        // an already-rotated buffer and the extra swap presented a STALE frame, so
        // the actually-shown frames stayed translucent and SurfaceFlinger blended
        // them over a frozen backing buffer (a static ghost showing through the live
        // viz). One render = one opaque swap.
        switch (g_sv_mode) {
            case 1:  rewamp_scope_render();   break;
            case 2:  rewamp_noteviz_render(); break;
#ifdef REWAMP_WITH_PROJECTM
            case 3:  rewamp_projectm_render(); break;
#endif
            case 4:  rewamp_patternviz_render(); break;
            case 5:  rewamp_spectrum_render();   break;
            default: rewamp_viz_render();     break;
        }
        if (!chor) usleep(8300);
    }
    switch (g_sv_mode) {
        case 1:  rewamp_scope_uninit();   break;
        case 2:  rewamp_noteviz_uninit(); break;
#ifdef REWAMP_WITH_PROJECTM
        case 3:  rewamp_projectm_uninit(); break;
#endif
        case 4:  rewamp_patternviz_uninit(); break;
        case 5:  rewamp_spectrum_uninit();   break;
        default: rewamp_viz_uninit();     break;
    }
    // The artwork background's GL objects (texture/program) die with this
    // context; art_cleanup() drops them AND re-flags the cached pixels dirty so
    // the NEXT context re-uploads. Only the stereo mode's uninit does this by
    // itself — without this call, leaving voices/notes left stale handles and a
    // clean dirty flag → artwork gone until a new set_artwork. (art_cleanup is
    // file-scope in rewamp_viz_render.cpp — same unity TU on Android.)
    art_cleanup();
    rewamp_gl_release_current();
    return nullptr;
}

static void sv_thread_stop(void) {
    if (!g_sv_run.load()) return;
    g_sv_run.store(0);
    pthread_join(g_sv_thread, nullptr);
}

static int sv_thread_start(int mode, int w, int h) {
    g_sv_mode = mode; g_sv_w = w; g_sv_h = h;
    g_sv_ok.store(0);
    g_sv_run.store(1);
    if (pthread_create(&g_sv_thread, nullptr, sv_thread_main, nullptr) != 0) {
        g_sv_run.store(0); return -1;
    }
    while (g_sv_ok.load() == 0) usleep(1000);
    if (g_sv_ok.load() < 0) { g_sv_run.store(0); pthread_join(g_sv_thread, nullptr); return -2; }
    return 0;
}

// ── JNI: PlatformView surface lifecycle ─────────────────────────────────────
extern "C" JNIEXPORT void JNICALL
Java_com_modizer_rewamp_rewamp_1audio_RewampAudioPlugin_nativeVizSurfaceChanged(
        JNIEnv* env, jclass, jobject surface, jint mode, jint width, jint height, jlong viewId) {
    std::lock_guard<std::mutex> lk(g_sv_lock);
    sv_thread_stop();
    ANativeWindow* win = ANativeWindow_fromSurface(env, surface);
    if (!win) { LOGE("sv: ANativeWindow_fromSurface failed"); return; }
    int err = rewamp_gl_android_set_window(win, width, height);
    if (err != 0) { LOGE("sv: set_window failed %d", err); return; }
    g_current_view_id = viewId;           // this view now owns the surface/thread
    rewamp_gl_release_current();          // hand the context to the thread
    err = sv_thread_start(mode, width, height);
    if (err != 0) LOGE("sv: thread start failed %d", err);
}

extern "C" JNIEXPORT void JNICALL
Java_com_modizer_rewamp_rewamp_1audio_RewampAudioPlugin_nativeVizSurfaceDestroyed(
        JNIEnv*, jclass, jlong viewId) {
    std::lock_guard<std::mutex> lk(g_sv_lock);
    // Stale view mid-switch: the live view already installed this surface/thread.
    // Its destroy is not ours to honour — ignore, or we'd kill the live context.
    if (viewId != g_current_view_id) return;
    sv_thread_stop();
    rewamp_gl_uninit();
    g_current_view_id = -1;
}

// ── JNI: nativeVizShutdown — called by Kotlin onDetachedFromEngine ──────────
// Stops the render thread so no frame reaches a detaching engine (fatal
// "FlutterJNI is not attached" in ImageReaderSurfaceProducer.onImage otherwise).
extern "C" JNIEXPORT void JNICALL
Java_com_modizer_rewamp_rewamp_1audio_RewampAudioPlugin_nativeVizShutdown(
        JNIEnv* /*env*/, jclass /*cls*/);

// ── JNI: nativeWindowFromSurface — called by Kotlin inside jniCreateTexture ─
extern "C" JNIEXPORT jlong JNICALL
Java_com_modizer_rewamp_rewamp_1audio_RewampAudioPlugin_nativeWindowFromSurface(
        JNIEnv* env, jclass /*cls*/, jobject surface) {
    ANativeWindow* win = ANativeWindow_fromSurface(env, surface);
    return (jlong)(intptr_t)win;
}

// ── Utility: attach/detach JNI env ──────────────────────────────────────────
static JNIEnv* jni_env(bool* attached) {
    *attached = false;
    if (!g_jvm) return nullptr;
    JNIEnv* env = nullptr;
    jint st = g_jvm->GetEnv((void**)&env, JNI_VERSION_1_6);
    if (st == JNI_EDETACHED) {
        g_jvm->AttachCurrentThread(&env, nullptr);
        *attached = true;
    }
    return env;
}

static void jni_detach_if(bool attached) {
    if (attached && g_jvm) g_jvm->DetachCurrentThread();
}

// ── Create Flutter SurfaceTexture via JNI ───────────────────────────────────
static void android_destroy_texture(void);

static int64_t android_create_texture(int width, int height, int mode) {
    LOGI("create_texture %dx%d mode=%d", width, height, mode);
    if (!g_jvm || !g_plugin_cls) {
        LOGE("JVM or plugin class not initialized (nativeOnAttach not called yet)");
        return -1;
    }
    // Single global EGL surface: a re-register (mode switch / widget re-init)
    // must stop the render thread and release the previous Flutter texture
    // entry, or the stale entry leaks and two BufferQueues fight over the one
    // producer (flicker/stale frames).
    android_destroy_texture();

    bool detach;
    JNIEnv* env = jni_env(&detach);
    if (!env) { LOGE("Failed to get JNIEnv"); return -1; }

    jmethodID mid = env->GetStaticMethodID(g_plugin_cls, "jniCreateTexture", "(II)[J");
    if (!mid) {
        LOGE("jniCreateTexture method not found");
        if (env->ExceptionCheck()) env->ExceptionClear();
        jni_detach_if(detach);
        return -3;
    }

    jlongArray arr = (jlongArray)env->CallStaticObjectMethod(g_plugin_cls, mid, width, height);
    if (!arr || env->ExceptionCheck()) {
        LOGE("jniCreateTexture threw exception");
        if (env->ExceptionCheck()) env->ExceptionClear();
        jni_detach_if(detach);
        return -4;
    }

    jlong* vals = env->GetLongArrayElements(arr, nullptr);
    int64_t textureId = vals[0];
    jlong   nativeWin = vals[1];
    env->ReleaseLongArrayElements(arr, vals, JNI_ABORT);
    env->DeleteLocalRef(arr);
    jni_detach_if(detach);

    if (textureId < 0 || nativeWin == 0) {
        LOGE("jniCreateTexture returned invalid id=%lld win=%lld", (long long)textureId, (long long)nativeWin);
        return -5;
    }

    ANativeWindow* window = (ANativeWindow*)(intptr_t)nativeWin;
    int err = rewamp_gl_android_set_window(window, width, height);
    if (err != 0) { LOGE("rewamp_gl_android_set_window failed: %d", err); return err; }

    // Phase-locked rendering: frames are rendered SYNCHRONOUSLY inside the
    // Dart Ticker's per-frame FFI call (rewamp_*_render_and_notify), exactly
    // like the Apple plugin. A free-running vsync-locked render thread produced
    // frames at the right CADENCE but with an uncontrolled PHASE vs Flutter's
    // raster — the displayed content timestamp jittered ±1 frame several times
    // per second (beat between two same-rate loops), which read as constant
    // micro-judder on scrolling content. The Ticker fires at Flutter frame
    // start; rendering inline (~4 ms) queues the image before the same frame's
    // raster samples it → deterministic 1-frame pipeline, no beat.
    // set_window left the context current on THIS thread (the Dart UI thread,
    // where the ticker FFI calls also run); shader init happens here too.
    err = (mode == 1) ? rewamp_scope_init(width, height)
        : (mode == 2) ? rewamp_noteviz_init(width, height)
        : (mode == 4) ? rewamp_patternviz_init(width, height)
        : (mode == 5) ? rewamp_spectrum_init(width, height)
                      : rewamp_viz_init(width, height);
    if (err != 0) { LOGE("shader init failed: %d", err); return err; }
    g_thread_mode = mode;   /* mode dispatch for render_and_notify */

    g_current_texture_id = textureId;
    LOGI("create_texture OK id=%lld", (long long)textureId);
    return textureId;
}

// ── Dedicated render thread ─────────────────────────────────────────────────



static void android_destroy_texture(void) {
    if (g_current_texture_id < 0 || !g_jvm || !g_plugin_cls) return;
    bool detach;
    JNIEnv* env = jni_env(&detach);
    if (env) {
        jmethodID mid = env->GetStaticMethodID(g_plugin_cls, "jniDestroyTexture", "(J)V");
        if (mid) env->CallStaticVoidMethod(g_plugin_cls, mid, (jlong)g_current_texture_id);
        if (env->ExceptionCheck()) env->ExceptionClear();
        jni_detach_if(detach);
    }
    g_current_texture_id = -1;
}

// ── Android foreground service control ──────────────────────────────────────
static void call_static_void(const char* method) {
    if (!g_jvm || !g_plugin_cls) return;
    bool detach;
    JNIEnv* env = jni_env(&detach);
    if (!env) return;
    jmethodID mid = env->GetStaticMethodID(g_plugin_cls, method, "()V");
    if (mid) env->CallStaticVoidMethod(g_plugin_cls, mid);
    if (env->ExceptionCheck()) env->ExceptionClear();
    jni_detach_if(detach);
}

extern "C" void rewamp_android_start_service(void) { call_static_void("startAudioService"); }
extern "C" void rewamp_android_stop_service(void)  { call_static_void("stopAudioService");  }

// ── Public API (mirrors src/apple/rewamp_viz_plugin.mm) ─────────────────────
REWAMP_EXPORT int64_t rewamp_viz_register(int width, int height) {
    return android_create_texture(width, height, 0);
}

REWAMP_EXPORT int64_t rewamp_scope_register(int width, int height) {
    return android_create_texture(width, height, 1);
}

REWAMP_EXPORT int rewamp_viz_resize_register(int width, int height) {
    return rewamp_gl_resize(width, height);   // leaves the context current here
}

// Synchronous per-frame render, called from the Dart Ticker (phase-locked to
// Flutter's frame — see the note in android_create_texture). makeCurrent every
// call: cheap when already current, and defends against anything on this
// thread unbinding the context (MIUI vendor hooks).
// NB: each render fn already makes-current, forces opaque (Android) and does its
// own single rewamp_gl_flush — do NOT flush again here (that was a double swap).
REWAMP_EXPORT void rewamp_viz_render_and_notify(void) {
    rewamp_viz_render();
}
REWAMP_EXPORT void rewamp_scope_render_and_notify(void) {
    rewamp_scope_render();
}

REWAMP_EXPORT int64_t rewamp_noteviz_register(int width, int height) {
    return android_create_texture(width, height, 2);
}

REWAMP_EXPORT void rewamp_noteviz_render_and_notify(void) {
    rewamp_noteviz_render();
}

REWAMP_EXPORT int64_t rewamp_patternviz_register(int width, int height) {
    return android_create_texture(width, height, 4);
}

REWAMP_EXPORT void rewamp_patternviz_render_and_notify(void) {
    rewamp_patternviz_render();
}

REWAMP_EXPORT int64_t rewamp_spectrum_register(int width, int height) {
    return android_create_texture(width, height, 5);
}

REWAMP_EXPORT void rewamp_spectrum_render_and_notify(void) {
    rewamp_spectrum_render();
}

REWAMP_EXPORT void rewamp_viz_unregister(void) {
    std::lock_guard<std::mutex> lk(g_sv_lock);
    // Called from the Dart thread on selector close. On the SurfaceView path the
    // render thread owns the EGL context on ITS thread — stop it FIRST or the
    // make_current/uninit below race it (EGL_BAD_ACCESS) and destroy a context
    // still driving a live BufferQueue. No-op on the Texture path (no thread).
    sv_thread_stop();
    g_current_view_id = -1;
    rewamp_gl_make_current();  // GL uninits need the context on this thread
    rewamp_viz_uninit();
    rewamp_scope_uninit();
    rewamp_noteviz_uninit();
    rewamp_patternviz_uninit();
    rewamp_spectrum_uninit();
    rewamp_gl_uninit();
    android_destroy_texture();
}

extern "C" JNIEXPORT void JNICALL
Java_com_modizer_rewamp_rewamp_1audio_RewampAudioPlugin_nativeVizShutdown(
        JNIEnv* /*env*/, jclass /*cls*/) {
    std::lock_guard<std::mutex> lk(g_sv_lock);
    sv_thread_stop();
    rewamp_gl_uninit();
    g_current_texture_id = -1;   // entries die with the engine — don't JNI back
    g_current_view_id    = -1;
}

// Android EGL + GLES3 GL context for oscilloscope rendering.
// Renders directly to an ANativeWindow (backed by a Flutter SurfaceTexture).
// FBO 0 = the window surface — no off-screen copy needed.
#include "../rewamp_audio.h"
#include "../rewamp_gl.h"
#include <EGL/egl.h>
#include <GLES3/gl3.h>
#include <android/native_window.h>
#include <android/log.h>
#include <stdlib.h>

#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "rewamp_gl", __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  "rewamp_gl", __VA_ARGS__)

static EGLDisplay g_display = EGL_NO_DISPLAY;
static EGLContext g_context = EGL_NO_CONTEXT;
static EGLConfig  g_config  = nullptr;
static EGLSurface g_surface = EGL_NO_SURFACE;
static ANativeWindow* g_window = nullptr;
static int g_width  = 0;
static int g_height = 0;

static int egl_create_context(void) {
    g_display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (g_display == EGL_NO_DISPLAY) { LOGE("eglGetDisplay failed"); return -1; }
    if (!eglInitialize(g_display, nullptr, nullptr)) { LOGE("eglInitialize failed"); return -2; }

    // WINDOW **| PBUFFER**: le préchargement de presets projectM ouvre un
    // second contexte du même share group sur un pbuffer 1×1
    // (rewamp_gl_preload_context_create). Un pbuffer ne peut être créé qu'avec
    // une config qui annonce EGL_PBUFFER_BIT, et `eglMakeCurrent` exige des
    // configs COMPATIBLES entre contexte et surface — donc la config du
    // contexte de rendu doit porter les deux bits, on ne peut pas en choisir
    // une autre pour le worker. La plupart des pilotes rendent des configs
    // WINDOW|PBUFFER et ça passait par chance; là où le pilote sert une config
    // window-only, `eglCreatePbufferSurface` échoue en EGL_BAD_MATCH, le
    // préchargement se désactive EN SILENCE et chaque changement de preset
    // repart en compilation synchrone sur le thread de rendu (~950 ms) — ce
    // qui se voit exactement comme « les transitions ne sont pas fluides ».
    const EGLint attribs[] = {
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL_SURFACE_TYPE,    EGL_WINDOW_BIT | EGL_PBUFFER_BIT,
        EGL_RED_SIZE,   8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE,  8,
        EGL_ALPHA_SIZE, 8,
        EGL_NONE
    };
    EGLint n = 0;
    if (!eglChooseConfig(g_display, attribs, &g_config, 1, &n) || n == 0) {
        // Repli: sans pbuffer on perd le préchargement, pas l'affichage.
        LOGE("eglChooseConfig WINDOW|PBUFFER failed — repli window-only "
             "(le prechargement des presets sera desactive)");
        const EGLint winOnly[] = {
            EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
            EGL_SURFACE_TYPE,    EGL_WINDOW_BIT,
            EGL_RED_SIZE,   8,
            EGL_GREEN_SIZE, 8,
            EGL_BLUE_SIZE,  8,
            EGL_ALPHA_SIZE, 8,
            EGL_NONE
        };
        if (!eglChooseConfig(g_display, winOnly, &g_config, 1, &n) || n == 0) {
            LOGE("eglChooseConfig failed"); return -3;
        }
    }

    const EGLint ctx_attribs[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
    g_context = eglCreateContext(g_display, g_config, EGL_NO_CONTEXT, ctx_attribs);
    if (g_context == EGL_NO_CONTEXT) { LOGE("eglCreateContext failed %x", eglGetError()); return -4; }
    return 0;
}

static int egl_create_surface(void) {
    if (!g_window || g_display == EGL_NO_DISPLAY) return -1;
    ANativeWindow_setBuffersGeometry(g_window, g_width, g_height, 0);
    g_surface = eglCreateWindowSurface(g_display, g_config, g_window, nullptr);
    if (g_surface == EGL_NO_SURFACE) { LOGE("eglCreateWindowSurface failed %x", eglGetError()); return -2; }
    if (!eglMakeCurrent(g_display, g_surface, g_surface, g_context)) {
        LOGE("eglMakeCurrent failed %x", eglGetError()); return -3;
    }
    LOGI("surface created %dx%d + context current", g_width, g_height);
    return 0;
}

// Called from rewamp_viz_android.cpp after getting ANativeWindow from Kotlin JNI.
int rewamp_gl_android_set_window(ANativeWindow* window, int width, int height) {
    // Tear down previous surface if any
    if (g_surface != EGL_NO_SURFACE) {
        eglMakeCurrent(g_display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        eglDestroySurface(g_display, g_surface);
        g_surface = EGL_NO_SURFACE;
    }
    if (g_window) { ANativeWindow_release(g_window); g_window = nullptr; }

    g_window  = window;  // ownership transferred
    g_width   = width;
    g_height  = height;

    if (g_context == EGL_NO_CONTEXT) {
        int err = egl_create_context();
        if (err) return err;
    }
    return egl_create_surface();
}

REWAMP_EXPORT int rewamp_gl_init(int width, int height) {
    // Android: init deferred until window is set via rewamp_gl_android_set_window.
    g_width  = width;
    g_height = height;
    return 0;
}

REWAMP_EXPORT int rewamp_gl_resize(int width, int height) {
    g_width  = width;
    g_height = height;
    if (g_window) ANativeWindow_setBuffersGeometry(g_window, width, height, 0);
    // Recreate the surface at the new size
    if (g_surface != EGL_NO_SURFACE) {
        eglMakeCurrent(g_display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        eglDestroySurface(g_display, g_surface);
        g_surface = EGL_NO_SURFACE;
    }
    return egl_create_surface();
}

REWAMP_EXPORT void rewamp_gl_make_current(void) {
    if (g_display != EGL_NO_DISPLAY && g_surface != EGL_NO_SURFACE)
        eglMakeCurrent(g_display, g_surface, g_surface, g_context);
}

// ── Context liveness ────────────────────────────────────────────────────────
// See rewamp_gl_ensure() in rewamp_gl.h for why this exists.
static unsigned g_gl_generation = 0;

REWAMP_EXPORT unsigned rewamp_gl_generation(void) { return g_gl_generation; }

REWAMP_EXPORT int rewamp_gl_ensure(int width, int height) {
    if (g_width != 0 && g_context != EGL_NO_CONTEXT) {
        // eglMakeCurrent's return value used to be thrown away, so a context the
        // OS destroyed under us went unnoticed and the visualizer just drew into
        // the void. Catch it and rebuild.
        if (eglMakeCurrent(g_display, g_surface, g_surface, g_context) == EGL_TRUE) {
            return 0;                       // alive — same generation, caches valid
        }
        rewamp_gl_uninit();                 // lost: drop the corpse, rebuild below
    }
    int err = rewamp_gl_init(width, height);
    if (err != 0) return err;
    g_gl_generation++;                      // caches built on the old one are stale
    return 0;
}

// Release the context from the CALLING thread (EGL contexts are thread-affine:
// current on one thread at a time). Needed to hand the context from the thread
// that created the surface (Dart FFI / platform thread) to the render thread.
extern "C" REWAMP_EXPORT void rewamp_gl_release_current(void) {
    if (g_display != EGL_NO_DISPLAY)
        eglMakeCurrent(g_display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
}


// ── Preload context (background shader compilation — see rewamp_gl.h) ────────
// Same share group as the render context; 1x1 pbuffer because some EGL
// implementations reject EGL_NO_SURFACE without EGL_KHR_surfaceless_context.
static EGLContext g_preload_ctx  = EGL_NO_CONTEXT;
static EGLSurface g_preload_surf = EGL_NO_SURFACE;

REWAMP_EXPORT int rewamp_gl_preload_context_create(void) {
    if (g_preload_ctx != EGL_NO_CONTEXT) return 0;               /* idempotent */
    if (g_display == EGL_NO_DISPLAY || g_context == EGL_NO_CONTEXT) return -1;
    const EGLint ctxAttrs[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
    g_preload_ctx = eglCreateContext(g_display, g_config, g_context /* SHARED */, ctxAttrs);
    if (g_preload_ctx == EGL_NO_CONTEXT) {
        LOGE("preload eglCreateContext failed %x", eglGetError());
        return -2;
    }
    const EGLint pbAttrs[] = { EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE };
    g_preload_surf = eglCreatePbufferSurface(g_display, g_config, pbAttrs);
    if (g_preload_surf == EGL_NO_SURFACE) {
        // BRUYANT exprès: sans cette surface, projectM recompile chaque preset
        // sur le thread de rendu et les transitions saccadent — un échec muet
        // ici ressemble à « c'est lent sur cet appareil », pas à un défaut.
        LOGE("preload eglCreatePbufferSurface failed %x — prechargement des "
             "presets DESACTIVE (chargement synchrone, transitions saccadees)",
             eglGetError());
        eglDestroyContext(g_display, g_preload_ctx);
        g_preload_ctx = EGL_NO_CONTEXT;
        return -3;
    }
    return 0;
}

REWAMP_EXPORT int rewamp_gl_preload_make_current(void) {
    if (g_preload_ctx == EGL_NO_CONTEXT) return -1;
    return eglMakeCurrent(g_display, g_preload_surf, g_preload_surf, g_preload_ctx)
               ? 0 : -2;
}

REWAMP_EXPORT void rewamp_gl_preload_release(void) {
    if (g_display != EGL_NO_DISPLAY)
        eglMakeCurrent(g_display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
}

REWAMP_EXPORT void rewamp_gl_flush(void) {
    static int logged = 0;
    if (g_display != EGL_NO_DISPLAY && g_surface != EGL_NO_SURFACE) {
        EGLBoolean ok = eglSwapBuffers(g_display, g_surface);
        if (!ok) { LOGE("eglSwapBuffers failed 0x%x", eglGetError()); }
        else if (logged < 3) { LOGI("swap ok (%d)", logged); logged++; }
    } else if (logged < 3) {
        LOGE("flush with no surface (display=%p surface=%p)", (void*)g_display, (void*)g_surface);
        logged++;
    }
}

REWAMP_EXPORT void rewamp_gl_uninit(void) {
    if (g_display != EGL_NO_DISPLAY) {
        eglMakeCurrent(g_display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        if (g_surface != EGL_NO_SURFACE) { eglDestroySurface(g_display, g_surface); g_surface = EGL_NO_SURFACE; }
        if (g_context != EGL_NO_CONTEXT) { eglDestroyContext(g_display, g_context); g_context = EGL_NO_CONTEXT; }
        eglTerminate(g_display);
        g_display = EGL_NO_DISPLAY;
        g_config  = nullptr;
    }
    if (g_window) { ANativeWindow_release(g_window); g_window = nullptr; }
    g_width = 0; g_height = 0;
}

// On Android we render to FBO 0 (the window surface directly).
REWAMP_EXPORT unsigned int rewamp_gl_get_fbo(void)     { return 0; }
REWAMP_EXPORT unsigned int rewamp_gl_get_texture(void) { return 0; }
REWAMP_EXPORT int  rewamp_gl_width(void)  { return g_width;  }
REWAMP_EXPORT int  rewamp_gl_height(void) { return g_height; }
REWAMP_EXPORT void* rewamp_gl_get_front_pixel_buffer(void) { return nullptr; } // unused on Android

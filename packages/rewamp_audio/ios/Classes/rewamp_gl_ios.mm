// iOS OpenGL ES 3.0 offscreen context via ANGLE (Metal backend), linked
// statically from Libs/angle/ANGLE.xcframework — the same upstream ANGLE the
// macOS side uses (see scripts/build_angle_ios.sh).
//
// Presentation: the renderers draw into an offscreen RGBA scene FBO, and each
// frame is handed to Flutter with ONE GPU blit into an IOSurface-backed
// CVPixelBuffer (EGL_ANGLE_iosurface_client_buffer), exactly the surfaces
// rewamp_gl_macos.mm renders into. The blit reverses Y (GL's origin is
// bottom-left, the iOS Flutter texture reads the buffer top-down) and converts
// RGBA→BGRA on the way, which is what the old path did on the CPU: a full
// glFinish + glReadPixels of the whole surface + a per-pixel loop swapping R↔B
// and flipping rows — ~2.8 MB read back and 700k iterations per frame at 2× on
// a full-screen visualizer, sixty times a second.
//
// macOS renders STRAIGHT into the IOSurface with no scene FBO because its
// Flutter texture keeps GL's bottom-left origin; iOS does not, hence the extra
// blit rather than a straight copy of that file. See the ART_UV_Y switch in
// rewamp_viz_render.cpp for the other half of that difference.
#ifdef REWAMP_WITH_ANGLE

#include "../../src/rewamp_audio.h"
#include "../../src/rewamp_gl.h"

#import <EGL/egl.h>
#import <EGL/eglext.h>
#import <GLES3/gl3.h>
#import <GLES2/gl2ext.h>   // GL_BGRA_EXT
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdatomic.h>
#include <pthread.h>


static EGLDisplay g_display = EGL_NO_DISPLAY;
static EGLConfig  g_config  = NULL;
static EGLContext g_context = EGL_NO_CONTEXT;
static EGLSurface g_surface = EGL_NO_SURFACE;

static int g_width  = 0;
static int g_height = 0;

// What every renderer draws into. Kept separate from the two present buffers so
// a frame is never half-visible to Flutter, and so the Y flip has somewhere to
// happen (a blit needs a source and a destination).
static GLuint g_sceneTex = 0, g_sceneFbo = 0, g_sceneDepth = 0;

typedef struct {
    CVPixelBufferRef pixelBuf;
    IOSurfaceRef     ioSurf;
    EGLSurface       eglSurf;   // pbuffer wrapping the IOSurface
    GLuint colorTex, fbo;       // no depth: this one is a blit target only
} VizBuffer;

// THREE buffers, not two: one read by Flutter (front), one holding the frame we
// just drew whose GPU work is still in flight (pending), one being drawn into.
// That is what lets the wait be DEFERRED - see rewamp_gl_flush.
static VizBuffer  g_buf[3];
static atomic_int g_front = 0;
static int        g_draw    = 1;     // buffer being blitted into
static int        g_pending = -1;    // blitted last frame, fence in flight
static GLsync     g_pendingFence = 0;
static pthread_mutex_t g_swap_mutex = PTHREAD_MUTEX_INITIALIZER;
static inline int back_idx(void) { return g_draw; }

// The buffer that is neither displayed nor waiting on its fence.
static int spare_idx(void) {
    const int f = atomic_load(&g_front);
    for (int i = 0; i < 3; i++) {
        if (i != f && i != g_pending && i != g_draw) return i;
    }
    return (f + 1) % 3;
}

static void _destroy_scene(void) {
    if (g_sceneFbo)   { glDeleteFramebuffers(1,  &g_sceneFbo);   g_sceneFbo = 0; }
    if (g_sceneDepth) { glDeleteRenderbuffers(1, &g_sceneDepth); g_sceneDepth = 0; }
    if (g_sceneTex)   { glDeleteTextures(1,      &g_sceneTex);   g_sceneTex = 0; }
}

static int _create_scene(int w, int h) {
    glGenTextures(1, &g_sceneTex);
    glBindTexture(GL_TEXTURE_2D, g_sceneTex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);

    glGenRenderbuffers(1, &g_sceneDepth);
    glBindRenderbuffer(GL_RENDERBUFFER, g_sceneDepth);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, w, h);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);

    glGenFramebuffers(1, &g_sceneFbo);
    glBindFramebuffer(GL_FRAMEBUFFER, g_sceneFbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, g_sceneTex, 0);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, g_sceneDepth);
    GLenum st = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    if (st != GL_FRAMEBUFFER_COMPLETE) { _destroy_scene(); return -20; }
    return 0;
}

static void _destroy_buf(VizBuffer* b) {
    if (b->fbo)      { glDeleteFramebuffers(1, &b->fbo); b->fbo = 0; }
    if (b->colorTex) {
        glBindTexture(GL_TEXTURE_2D, b->colorTex);
        if (b->eglSurf != EGL_NO_SURFACE) eglReleaseTexImage(g_display, b->eglSurf, EGL_BACK_BUFFER);
        glBindTexture(GL_TEXTURE_2D, 0);
        glDeleteTextures(1, &b->colorTex); b->colorTex = 0;
    }
    if (b->eglSurf != EGL_NO_SURFACE) { eglDestroySurface(g_display, b->eglSurf); b->eglSurf = EGL_NO_SURFACE; }
    if (b->ioSurf)   { CFRelease(b->ioSurf); b->ioSurf = NULL; }
    if (b->pixelBuf) { CVPixelBufferRelease(b->pixelBuf); b->pixelBuf = NULL; }
}

static int _create_buf(VizBuffer* b, int w, int h) {
    NSDictionary* opts = @{
        (NSString*)kCVPixelBufferIOSurfacePropertiesKey: @{},
        (NSString*)kCVPixelBufferMetalCompatibilityKey: @YES,
    };
    if (CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA,
        (__bridge CFDictionaryRef)opts, &b->pixelBuf) != kCVReturnSuccess) return -10;
    b->ioSurf = CVPixelBufferGetIOSurface(b->pixelBuf);
    if (!b->ioSurf) { _destroy_buf(b); return -11; }
    CFRetain(b->ioSurf);

    // Wrap the IOSurface as an EGL pbuffer we can render into (zero-copy).
    const EGLint surfAttrs[] = {
        EGL_WIDTH,                         w,
        EGL_HEIGHT,                        h,
        EGL_IOSURFACE_PLANE_ANGLE,         0,
        EGL_TEXTURE_TARGET,                EGL_TEXTURE_2D,
        EGL_TEXTURE_INTERNAL_FORMAT_ANGLE, GL_BGRA_EXT,
        EGL_TEXTURE_FORMAT,                EGL_TEXTURE_RGBA,
        EGL_TEXTURE_TYPE_ANGLE,            GL_UNSIGNED_BYTE,
        EGL_IOSURFACE_USAGE_HINT_ANGLE,    EGL_IOSURFACE_READ_HINT_ANGLE | EGL_IOSURFACE_WRITE_HINT_ANGLE,
        EGL_NONE
    };
    b->eglSurf = eglCreatePbufferFromClientBuffer(g_display, EGL_IOSURFACE_ANGLE,
                     (EGLClientBuffer)b->ioSurf, g_config, surfAttrs);
    if (b->eglSurf == EGL_NO_SURFACE) { _destroy_buf(b); return -12; }

    glGenTextures(1, &b->colorTex);
    glBindTexture(GL_TEXTURE_2D, b->colorTex);
    if (!eglBindTexImage(g_display, b->eglSurf, EGL_BACK_BUFFER)) { _destroy_buf(b); return -13; }
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glGenFramebuffers(1, &b->fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, b->fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, b->colorTex, 0);
    GLenum st = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
    if (st != GL_FRAMEBUFFER_COMPLETE) { _destroy_buf(b); return -14; }
    return 0;
}

REWAMP_EXPORT int rewamp_gl_init(int width, int height) {
    g_width = width; g_height = height;

    g_display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (g_display == EGL_NO_DISPLAY) return -2;
    if (!eglInitialize(g_display, NULL, NULL)) return -3;
    eglBindAPI(EGL_OPENGL_ES_API);

    const EGLint cfgAttrs[] = {
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL_SURFACE_TYPE,    EGL_PBUFFER_BIT,
        EGL_RED_SIZE,   8, EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE,  8, EGL_ALPHA_SIZE, 8,
        EGL_DEPTH_SIZE, 24,
        EGL_NONE
    };
    EGLint numCfg = 0;
    if (!eglChooseConfig(g_display, cfgAttrs, &g_config, 1, &numCfg) || numCfg == 0) return -4;

    // 1×1 pbuffer — rendering targets FBOs, but ANGLE requires a current surface.
    const EGLint pbufAttrs[] = { EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE };
    g_surface = eglCreatePbufferSurface(g_display, g_config, pbufAttrs);
    if (g_surface == EGL_NO_SURFACE) return -5;

    const EGLint ctxAttrs[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
    g_context = eglCreateContext(g_display, g_config, EGL_NO_CONTEXT, ctxAttrs);
    if (g_context == EGL_NO_CONTEXT) return -6;

    if (!eglMakeCurrent(g_display, g_surface, g_surface, g_context)) return -7;

    // One line per context: which GL we actually got, and whether the two
    // extensions this port hangs on are there —
    //   GL_EXT_shader_framebuffer_fetch      → projectM's CUSTOMSHAPE_FAST_RENDER
    //   EGL_ANGLE_iosurface_client_buffer    → the zero-copy present path below
    // (MetalANGLE advertised neither; the patched upstream build advertises both.)
    {
        const char* eglExt = eglQueryString(g_display, EGL_EXTENSIONS);
        const char* glExt  = (const char*)glGetString(GL_EXTENSIONS);
        fprintf(stderr, "[rewamp_gl] %s | %s | fb_fetch=%d iosurface=%d\n",
                (const char*)glGetString(GL_VERSION),
                (const char*)glGetString(GL_RENDERER),
                (glExt  && strstr(glExt,  "GL_EXT_shader_framebuffer_fetch"))   ? 1 : 0,
                (eglExt && strstr(eglExt, "EGL_ANGLE_iosurface_client_buffer")) ? 1 : 0);
    }

    int err = _create_scene(width, height);
    if (err) return err;
    for (int i = 0; i < 3; i++) {
        err = _create_buf(&g_buf[i], width, height);
        if (err) return err;
    }
    atomic_store(&g_front, 0);
    g_draw = 1; g_pending = -1;
    if (g_pendingFence) { glDeleteSync(g_pendingFence); g_pendingFence = 0; }
    return 0;
}

REWAMP_EXPORT void rewamp_gl_make_current(void) {
    if (g_context != EGL_NO_CONTEXT)
        eglMakeCurrent(g_display, g_surface, g_surface, g_context);
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
        fprintf(stderr, "[rewamp_gl] preload eglCreateContext failed 0x%x\n", eglGetError());
        return -2;
    }
    const EGLint pbAttrs[] = { EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE };
    g_preload_surf = eglCreatePbufferSurface(g_display, g_config, pbAttrs);
    if (g_preload_surf == EGL_NO_SURFACE) {
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
    const int bi = g_draw;
    if (!g_sceneFbo || !g_buf[bi].fbo) return;

    // Scene → IOSurface, flipped in Y (dst rows counted from the top) and
    // converted RGBA→BGRA by the blit itself.
    glBindFramebuffer(GL_READ_FRAMEBUFFER, g_sceneFbo);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, g_buf[bi].fbo);
    glBlitFramebuffer(0, 0,        g_width, g_height,
                      0, g_height, g_width, 0,
                      GL_COLOR_BUFFER_BIT, GL_NEAREST);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    // Deferred barrier. Flutter samples the IOSurface from another thread as soon
    // as we publish it, so a frame must never go out before its blit has landed -
    // but glFinish paid for that by BLOCKING this thread, the one driving the
    // Flutter frame. Measured on an A18 Pro: 1.6 ms on average, up to 6.5 ms, out
    // of an 8.3 ms budget at 120 Hz, with about one frame in eight being dropped.
    //
    // So: fence this frame and let the GPU run, then publish the frame blitted
    // LAST time, whose fence has had a whole frame to signal - normally an
    // instant check. It costs one more frame of latency, constant and therefore
    // invisible; what the eye catches is jitter, not delay.
    GLsync fence = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0);
    glFlush();                       // make sure the fence is actually submitted

    int nextDraw;
    if (g_pending >= 0 && g_pendingFence) {
        // A wait this long means the GPU is in real trouble; a late frame still
        // beats blocking the UI thread for ever.
        glClientWaitSync(g_pendingFence, GL_SYNC_FLUSH_COMMANDS_BIT, 50ull * 1000ull * 1000ull);
        glDeleteSync(g_pendingFence);
        pthread_mutex_lock(&g_swap_mutex);
        const int prevFront = atomic_load(&g_front);
        atomic_store(&g_front, g_pending);
        pthread_mutex_unlock(&g_swap_mutex);
        nextDraw = prevFront;        // Flutter has moved on from that one
    } else {
        nextDraw = spare_idx();
    }
    g_pending      = bi;
    g_pendingFence = fence;
    g_draw         = nextDraw;
}

REWAMP_EXPORT void rewamp_gl_uninit(void) {
    if (g_display == EGL_NO_DISPLAY) return;
    eglMakeCurrent(g_display, g_surface, g_surface, g_context);
    if (g_pendingFence) { glDeleteSync(g_pendingFence); g_pendingFence = 0; }
    g_pending = -1; g_draw = 1;
    for (int i = 0; i < 3; i++) _destroy_buf(&g_buf[i]);
    _destroy_scene();
    eglMakeCurrent(g_display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    if (g_surface != EGL_NO_SURFACE) { eglDestroySurface(g_display, g_surface); g_surface = EGL_NO_SURFACE; }
    if (g_context != EGL_NO_CONTEXT) { eglDestroyContext(g_display, g_context); g_context = EGL_NO_CONTEXT; }
    eglTerminate(g_display); g_display = EGL_NO_DISPLAY;
    g_config = NULL;
    g_width = 0; g_height = 0;
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

REWAMP_EXPORT int rewamp_gl_resize(int width, int height) {
    if (width == g_width && height == g_height) return 0;
    eglMakeCurrent(g_display, g_surface, g_surface, g_context);
    g_width = width; g_height = height;
    pthread_mutex_lock(&g_swap_mutex);
    _destroy_scene();
    int err = _create_scene(width, height);
    if (err) { pthread_mutex_unlock(&g_swap_mutex); return err; }
    for (int i = 0; i < 3; i++) {
        _destroy_buf(&g_buf[i]);
        err = _create_buf(&g_buf[i], width, height);
        if (err) { pthread_mutex_unlock(&g_swap_mutex); return err; }
    }
    atomic_store(&g_front, 0);
    g_draw = 1; g_pending = -1;
    if (g_pendingFence) { glDeleteSync(g_pendingFence); g_pendingFence = 0; }
    pthread_mutex_unlock(&g_swap_mutex);
    return 0;
}

// The renderers' target is the scene FBO, NOT the buffer being presented: the
// Y flip happens on the way out, in rewamp_gl_flush().
REWAMP_EXPORT unsigned int rewamp_gl_get_fbo(void)     { return g_sceneFbo; }
REWAMP_EXPORT unsigned int rewamp_gl_get_texture(void) { return g_sceneTex; }
REWAMP_EXPORT int rewamp_gl_width(void)                { return g_width; }
REWAMP_EXPORT int rewamp_gl_height(void)               { return g_height; }

REWAMP_EXPORT void* rewamp_gl_get_front_pixel_buffer(void) {
    pthread_mutex_lock(&g_swap_mutex);
    CVPixelBufferRef buf = g_buf[atomic_load(&g_front)].pixelBuf;
    if (buf) CVPixelBufferRetain(buf);
    pthread_mutex_unlock(&g_swap_mutex);
    return (void*)buf;
}

#endif /* REWAMP_WITH_ANGLE */

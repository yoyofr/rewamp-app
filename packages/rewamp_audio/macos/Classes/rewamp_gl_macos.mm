// macOS OpenGL ES 3.0 offscreen context via ANGLE (Metal backend).
// Renders straight into IOSurface-backed CVPixelBuffers (zero-copy FlutterTexture)
// through EGL_ANGLE_iosurface_client_buffer — same double-buffer + rewamp_gl_*
// interface as the old NSOpenGL implementation, but now GLES3 so the shared
// renderers (REWAMP_GL_GLES path) and projectM run on one Apple GL dialect.
#include "../../src/rewamp_audio.h"
#include "../../src/rewamp_gl.h"

#import <Cocoa/Cocoa.h>
#import <CoreVideo/CoreVideo.h>

#import <EGL/egl.h>
#import <EGL/eglext.h>
#import <GLES3/gl3.h>
#import <GLES2/gl2ext.h>  // GL_BGRA_EXT

#include <stdatomic.h>
#include <pthread.h>
#include <stdio.h>

static EGLDisplay g_dpy     = EGL_NO_DISPLAY;
static EGLConfig  g_config  = NULL;
static EGLContext g_ctx     = EGL_NO_CONTEXT;
static EGLSurface g_baseSurf = EGL_NO_SURFACE; // 1x1 pbuffer: keeps a current surface
static int g_width = 0, g_height = 0;

typedef struct {
    CVPixelBufferRef pixelBuf;
    IOSurfaceRef     ioSurf;
    EGLSurface       eglSurf;   // pbuffer wrapping the IOSurface
    GLuint colorTex, fbo, depthRb;
} VizBuffer;

// THREE buffers, not two: one is being read by Flutter (front), one carries the
// frame we just drew and whose GPU work is still in flight (pending), and one is
// what we draw into. That is what lets the wait be DEFERRED - see rewamp_gl_flush.
static VizBuffer  g_buf[3];
static atomic_int g_front = 0;
static int        g_draw    = 1;     // buffer being rendered into
static int        g_pending = -1;    // rendered last frame, fence in flight
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

static void _destroy_buf(VizBuffer* b) {
    if (b->fbo)      { glDeleteFramebuffers(1,  &b->fbo);      b->fbo=0; }
    if (b->depthRb)  { glDeleteRenderbuffers(1, &b->depthRb);  b->depthRb=0; }
    if (b->colorTex) {
        glBindTexture(GL_TEXTURE_2D, b->colorTex);
        if (b->eglSurf != EGL_NO_SURFACE) eglReleaseTexImage(g_dpy, b->eglSurf, EGL_BACK_BUFFER);
        glBindTexture(GL_TEXTURE_2D, 0);
        glDeleteTextures(1, &b->colorTex); b->colorTex=0;
    }
    if (b->eglSurf != EGL_NO_SURFACE) { eglDestroySurface(g_dpy, b->eglSurf); b->eglSurf=EGL_NO_SURFACE; }
    if (b->ioSurf)   { CFRelease(b->ioSurf);    b->ioSurf=NULL; }
    if (b->pixelBuf) { CVPixelBufferRelease(b->pixelBuf); b->pixelBuf=NULL; }
}

static int _create_buf(VizBuffer* b, int w, int h) {
    NSDictionary* opts = @{(NSString*)kCVPixelBufferIOSurfacePropertiesKey:@{},
                           (NSString*)kCVPixelBufferMetalCompatibilityKey:@YES};
    if (CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA,
        (__bridge CFDictionaryRef)opts, &b->pixelBuf) != kCVReturnSuccess) return -10;
    b->ioSurf = CVPixelBufferGetIOSurface(b->pixelBuf); CFRetain(b->ioSurf);

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
    b->eglSurf = eglCreatePbufferFromClientBuffer(g_dpy, EGL_IOSURFACE_ANGLE,
                     (EGLClientBuffer)b->ioSurf, g_config, surfAttrs);
    if (b->eglSurf == EGL_NO_SURFACE) { _destroy_buf(b); return -11; }

    glGenTextures(1, &b->colorTex);
    glBindTexture(GL_TEXTURE_2D, b->colorTex);
    if (!eglBindTexImage(g_dpy, b->eglSurf, EGL_BACK_BUFFER)) { _destroy_buf(b); return -12; }
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glGenRenderbuffers(1, &b->depthRb);
    glBindRenderbuffer(GL_RENDERBUFFER, b->depthRb);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, w, h);

    glGenFramebuffers(1, &b->fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, b->fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, b->colorTex, 0);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, b->depthRb);
    GLenum st = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
    if (st != GL_FRAMEBUFFER_COMPLETE) { _destroy_buf(b); return -13; }
    return 0;
}

REWAMP_EXPORT int rewamp_gl_init(int w, int h) {
    g_width=w; g_height=h;

    g_dpy = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (g_dpy == EGL_NO_DISPLAY) return -1;
    if (!eglInitialize(g_dpy, NULL, NULL)) return -2;
    eglBindAPI(EGL_OPENGL_ES_API);

    const EGLint cfgAttrs[] = {
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL_SURFACE_TYPE,    EGL_PBUFFER_BIT,
        EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
        EGL_DEPTH_SIZE, 24,
        EGL_NONE
    };
    EGLint numCfg = 0;
    if (!eglChooseConfig(g_dpy, cfgAttrs, &g_config, 1, &numCfg) || numCfg == 0) return -3;

    const EGLint pbufAttrs[] = { EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE };
    g_baseSurf = eglCreatePbufferSurface(g_dpy, g_config, pbufAttrs);
    if (g_baseSurf == EGL_NO_SURFACE) return -4;

    const EGLint ctxAttrs[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
    g_ctx = eglCreateContext(g_dpy, g_config, EGL_NO_CONTEXT, ctxAttrs);
    if (g_ctx == EGL_NO_CONTEXT) return -5;
    if (!eglMakeCurrent(g_dpy, g_baseSurf, g_baseSurf, g_ctx)) return -6;

    for(int i=0;i<3;i++){int e=_create_buf(&g_buf[i],w,h);if(e)return e;}
    atomic_store(&g_front,0); g_draw = 1; g_pending = -1;
    if (g_pendingFence) { glDeleteSync(g_pendingFence); g_pendingFence = 0; }
    return 0;
}

REWAMP_EXPORT void rewamp_gl_make_current(void) {
    if (g_ctx != EGL_NO_CONTEXT) eglMakeCurrent(g_dpy, g_baseSurf, g_baseSurf, g_ctx);
}

// ── Context liveness ────────────────────────────────────────────────────────
// See rewamp_gl_ensure() in rewamp_gl.h for why this exists.
static unsigned g_gl_generation = 0;

REWAMP_EXPORT unsigned rewamp_gl_generation(void) { return g_gl_generation; }

REWAMP_EXPORT int rewamp_gl_ensure(int width, int height) {
    if (g_width != 0 && g_ctx != EGL_NO_CONTEXT) {
        // eglMakeCurrent's return value used to be thrown away, so a context the
        // OS destroyed under us went unnoticed and the visualizer just drew into
        // the void. Catch it and rebuild.
        if (eglMakeCurrent(g_dpy, g_baseSurf, g_baseSurf, g_ctx) == EGL_TRUE) {
            return 0;                       // alive — same generation, caches valid
        }
        rewamp_gl_uninit();                 // lost: drop the corpse, rebuild below
    }
    int err = rewamp_gl_init(width, height);
    if (err != 0) return err;
    g_gl_generation++;                      // caches built on the old one are stale
    return 0;
}

// ── Preload context (background shader compilation — see rewamp_gl.h) ────────
// Same share group as the render context; 1x1 pbuffer because some EGL
// implementations reject EGL_NO_SURFACE without EGL_KHR_surfaceless_context.
static EGLContext g_preload_ctx  = EGL_NO_CONTEXT;
static EGLSurface g_preload_surf = EGL_NO_SURFACE;

REWAMP_EXPORT int rewamp_gl_preload_context_create(void) {
    if (g_preload_ctx != EGL_NO_CONTEXT) return 0;               /* idempotent */
    if (g_dpy == EGL_NO_DISPLAY || g_ctx == EGL_NO_CONTEXT) return -1;
    const EGLint ctxAttrs[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
    g_preload_ctx = eglCreateContext(g_dpy, g_config, g_ctx /* SHARED */, ctxAttrs);
    if (g_preload_ctx == EGL_NO_CONTEXT) {
        fprintf(stderr, "[rewamp_gl] preload eglCreateContext failed 0x%x\n", eglGetError());
        return -2;
    }
    const EGLint pbAttrs[] = { EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE };
    g_preload_surf = eglCreatePbufferSurface(g_dpy, g_config, pbAttrs);
    if (g_preload_surf == EGL_NO_SURFACE) {
        eglDestroyContext(g_dpy, g_preload_ctx);
        g_preload_ctx = EGL_NO_CONTEXT;
        return -3;
    }
    return 0;
}

REWAMP_EXPORT int rewamp_gl_preload_make_current(void) {
    if (g_preload_ctx == EGL_NO_CONTEXT) return -1;
    return eglMakeCurrent(g_dpy, g_preload_surf, g_preload_surf, g_preload_ctx)
               ? 0 : -2;
}

REWAMP_EXPORT void rewamp_gl_preload_release(void) {
    if (g_dpy != EGL_NO_DISPLAY)
        eglMakeCurrent(g_dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
}


REWAMP_EXPORT void rewamp_gl_flush(void) {
    // Deferred barrier. Flutter samples the IOSurface from another thread as soon
    // as we publish it, so a frame must never go out before its GPU work has
    // landed - but glFinish paid for that by BLOCKING this thread, which is the
    // one driving the Flutter frame. Measured on an A18 Pro: 1.6 ms on average
    // and up to 6.5 ms, out of an 8.3 ms budget at 120 Hz, and the device was
    // dropping about one frame in eight.
    //
    // So: fence this frame and let the GPU run, then publish the frame drawn
    // LAST time, whose fence has had a whole frame to signal - normally an
    // instant check. The cost is one more frame of latency, which is constant
    // and therefore invisible; what the eye catches is jitter, not delay.
    GLsync fence = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0);
    glFlush();                       // make sure the fence is actually submitted

    int nextDraw;
    if (g_pending >= 0 && g_pendingFence) {
        // A wait this long means the GPU is in real trouble; showing the frame
        // late still beats blocking the UI thread for ever.
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
    g_pending      = g_draw;
    g_pendingFence = fence;
    g_draw         = nextDraw;
}
REWAMP_EXPORT void rewamp_gl_uninit(void) {
    if(g_dpy==EGL_NO_DISPLAY)return;
    eglMakeCurrent(g_dpy, g_baseSurf, g_baseSurf, g_ctx);
    if (g_pendingFence) { glDeleteSync(g_pendingFence); g_pendingFence = 0; }
    g_pending = -1; g_draw = 1;
    for(int i=0;i<3;i++) _destroy_buf(&g_buf[i]);
    eglMakeCurrent(g_dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    if (g_baseSurf != EGL_NO_SURFACE) { eglDestroySurface(g_dpy, g_baseSurf); g_baseSurf=EGL_NO_SURFACE; }
    if (g_ctx != EGL_NO_CONTEXT) { eglDestroyContext(g_dpy, g_ctx); g_ctx=EGL_NO_CONTEXT; }
    eglTerminate(g_dpy); g_dpy=EGL_NO_DISPLAY; g_config=NULL; g_width=0; g_height=0;
}
REWAMP_EXPORT int rewamp_gl_resize(int w, int h) {
    if(w==g_width&&h==g_height)return 0; g_width=w; g_height=h;
    eglMakeCurrent(g_dpy, g_baseSurf, g_baseSurf, g_ctx);
    pthread_mutex_lock(&g_swap_mutex);
    if (g_pendingFence) { glDeleteSync(g_pendingFence); g_pendingFence = 0; }
    g_pending = -1;
    for(int i=0;i<3;i++){_destroy_buf(&g_buf[i]);int e=_create_buf(&g_buf[i],w,h);if(e){pthread_mutex_unlock(&g_swap_mutex);return e;}}
    atomic_store(&g_front,0); g_draw = 1; pthread_mutex_unlock(&g_swap_mutex); return 0;
}
REWAMP_EXPORT unsigned int rewamp_gl_get_fbo(void)     { return g_buf[back_idx()].fbo; }
REWAMP_EXPORT unsigned int rewamp_gl_get_texture(void) { return g_buf[back_idx()].colorTex; }
REWAMP_EXPORT int rewamp_gl_width(void)                { return g_width; }
REWAMP_EXPORT int rewamp_gl_height(void)               { return g_height; }
REWAMP_EXPORT void* rewamp_gl_get_front_pixel_buffer(void) {
    pthread_mutex_lock(&g_swap_mutex);
    CVPixelBufferRef buf = g_buf[atomic_load(&g_front)].pixelBuf;
    if(buf) CVPixelBufferRetain(buf);
    pthread_mutex_unlock(&g_swap_mutex);
    return (void*)buf;
}

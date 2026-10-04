// Contexte OpenGL ES 3.0 hors écran pour Windows, sur NOTRE ANGLE (Direct3D 11).
//
// Même interface rewamp_gl_* et même discipline triple-tampon + barrière
// décalée que Linux (src/linux/rewamp_gl_linux.cc), dont ce fichier est le
// portage. Trois différences, toutes imposées par la plateforme:
//
//   1. UN ANGLE À NOUS. Celui de Flutter est lié statiquement dans
//      flutter_windows.dll et n'exporte aucun symbole egl*/gl*: impossible de
//      s'en servir. Le nôtre arrive par windows/Libs/angle (libEGL.dll +
//      libGLESv2.dll, scripts/build_angle_windows.ps1). Conséquence heureuse:
//      deux ANGLE dans le même processus ont chacun leur « contexte courant »,
//      donc rien de la danse GLX/EGL de Linux n'existe ici.
//
//   2. Là où Linux publie une EGLImage, on publie le HANDLE DXGI PARTAGÉ d'une
//      texture Direct3D 11. Chaque tampon est un pbuffer ANGLE, dont
//      EGL_ANGLE_surface_d3d_texture_2d_share_handle donne le handle, lié en
//      texture GL (eglBindTexImage) pour recevoir le blit de scène. L'embedder
//      Windows sait ouvrir ce handle dans SON périphérique
//      (kFlutterDesktopGpuSurfaceTypeDxgiSharedHandle). Zéro copie.
//      ⚠️ Un handle partagé ne s'ouvre que sur le MÊME adaptateur graphique.
//
//   3. Un repli par relecture (mode PIXELS, REWAMP_VIZ_PIXEL_MODE=1), calqué sur
//      celui que Linux a pour X11: plus lent, mais sans aucune hypothèse sur le
//      partage entre périphériques.
#include "../rewamp_audio.h"
#include "../rewamp_gl.h"
#include "rewamp_viz_windows.h"

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <EGL/eglext_angle.h>   // EGL_CONTEXT_VIRTUALIZATION_GROUP_ANGLE
#include <GLES3/gl3.h>

#include <atomic>
#include <mutex>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Extensions ANGLE. Déclarées ici plutôt que par <EGL/eglext_angle.h>: selon la
// façon dont ANGLE est empaqueté, cet en-tête n'est pas toujours installé, et
// ce sont des constantes d'ABI stables.
#ifndef EGL_PLATFORM_ANGLE_ANGLE
#define EGL_PLATFORM_ANGLE_ANGLE                 0x3202
#define EGL_PLATFORM_ANGLE_TYPE_ANGLE            0x3203
#define EGL_PLATFORM_ANGLE_TYPE_D3D11_ANGLE      0x3208
#endif
#ifndef EGL_D3D_TEXTURE_2D_SHARE_HANDLE_ANGLE
#define EGL_D3D_TEXTURE_2D_SHARE_HANDLE_ANGLE    0x3200
#endif

// ── État global ─────────────────────────────────────────────────────────────
static EGLDisplay g_dpy      = EGL_NO_DISPLAY;
static EGLConfig  g_config   = nullptr;
static EGLContext g_ctx      = EGL_NO_CONTEXT;
static EGLSurface g_baseSurf = EGL_NO_SURFACE;   // pbuffer 1×1
static int g_width = 0, g_height = 0;

static int g_pixel_mode = 0;

extern "C" void rewamp_gl_windows_set_pixel_mode(int enabled) { g_pixel_mode = enabled ? 1 : 0; }
extern "C" int  rewamp_gl_windows_pixel_mode(void)            { return g_pixel_mode; }

static EGLBoolean gl_bind(void) {
    return eglMakeCurrent(g_dpy, g_baseSurf, g_baseSurf, g_ctx);
}

// ── Mode pixels: relecture par PBO, une image de retard ─────────────────────
// Deux PBO en alternance (la lecture demandée à l'image N est récupérée à
// l'image N+1 — la mapper tout de suite serait un glFinish déguisé) et UN
// tampon CPU partagé avec le fil de rastérisation, sous verrou.
static GLuint     g_pbo[2]     = {0, 0};
static int        g_pbo_cur    = 0;
static int        g_pbo_primed = 0;
static std::mutex g_px_mutex;
static uint8_t*   g_px         = nullptr;   // RGBA, g_px_w × g_px_h
static int        g_px_w = 0, g_px_h = 0;
static int        g_px_valid   = 0;

static void _destroy_pbos(void) {
    if (g_pbo[0]) { glDeleteBuffers(2, g_pbo); g_pbo[0] = g_pbo[1] = 0; }
    g_pbo_primed = 0;
    std::lock_guard<std::mutex> lk(g_px_mutex);
    g_px_valid = 0;
}

static void _create_pbos(int w, int h) {
    _destroy_pbos();
    if (!g_pixel_mode) return;
    glGenBuffers(2, g_pbo);
    for (int i = 0; i < 2; i++) {
        glBindBuffer(GL_PIXEL_PACK_BUFFER, g_pbo[i]);
        glBufferData(GL_PIXEL_PACK_BUFFER, (GLsizeiptr)w * h * 4, nullptr, GL_STREAM_READ);
    }
    glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
    std::lock_guard<std::mutex> lk(g_px_mutex);
    if (g_px_w != w || g_px_h != h) {
        free(g_px);
        g_px = (uint8_t*)malloc((size_t)w * h * 4);
        g_px_w = w; g_px_h = h;
    }
    g_px_valid = 0;
}

// Appelé juste après le blit vers le tampon publié `fbo` (contexte courant).
static void _readback_after_blit(GLuint fbo) {
    if (!g_pixel_mode || !g_pbo[0] || !g_px) return;
    glBindFramebuffer(GL_READ_FRAMEBUFFER, fbo);
    glBindBuffer(GL_PIXEL_PACK_BUFFER, g_pbo[g_pbo_cur]);
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    glReadPixels(0, 0, g_width, g_height, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    const int prev = g_pbo_cur ^ 1;
    if (g_pbo_primed) {
        glBindBuffer(GL_PIXEL_PACK_BUFFER, g_pbo[prev]);
        const size_t sz = (size_t)g_width * g_height * 4;
        void* src = glMapBufferRange(GL_PIXEL_PACK_BUFFER, 0, (GLsizeiptr)sz, GL_MAP_READ_BIT);
        if (src) {
            {
                std::lock_guard<std::mutex> lk(g_px_mutex);
                if (g_px_w == g_width && g_px_h == g_height) {
                    memcpy(g_px, src, sz);
                    g_px_valid = 1;
                }
            }
            glUnmapBuffer(GL_PIXEL_PACK_BUFFER);
        }
    }
    glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
    glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
    g_pbo_primed = 1;
    g_pbo_cur = prev;
}

extern "C" int rewamp_gl_windows_copy_front_pixels(uint8_t** buf, size_t* cap, int* w, int* h) {
    std::lock_guard<std::mutex> lk(g_px_mutex);
    if (!g_px_valid || !g_px) return 0;
    const size_t sz = (size_t)g_px_w * g_px_h * 4;
    if (*cap < sz) {
        uint8_t* nb = (uint8_t*)realloc(*buf, sz);
        if (!nb) return 0;
        *buf = nb; *cap = sz;
    }
    memcpy(*buf, g_px, sz);
    *w = g_px_w; *h = g_px_h;
    return 1;
}

// ── Tampons publiés ─────────────────────────────────────────────────────────
typedef struct {
    EGLSurface pbuf;      // le pbuffer ANGLE = la texture Direct3D partagée
    void*      share;     // son HANDLE DXGI, ce que Flutter ouvre
    GLuint     colorTex;  // le même, vu comme texture GL (eglBindTexImage)
    GLuint     fbo;       // couleur seule: ne reçoit que le blit de scène
} VizBuffer;

// TROIS tampons, pas deux: un lu par Flutter (front), un dont le travail GPU
// est encore en vol (pending), un en cours de dessin (draw) — voir
// rewamp_gl_flush et docs/VISUALIZERS.md.
static VizBuffer        g_buf[3];
static std::atomic<int> g_front{0};
static int              g_draw    = 1;
static int              g_pending = -1;
static GLsync           g_pendingFence = 0;
static std::mutex       g_swap_mutex;

// FBO de SCÈNE: les renderers dessinent toujours ici, jamais directement dans
// le tampon publié — l'id du FBO ne bouge pas d'une image à l'autre, et c'est
// le blit scène → tampon qui met l'image dans le sens que Flutter attend.
static GLuint g_sceneTex = 0, g_sceneFbo = 0, g_sceneDepth = 0;

static void _destroy_scene(void) {
    if (g_sceneFbo)   { glDeleteFramebuffers(1,  &g_sceneFbo);   g_sceneFbo = 0; }
    if (g_sceneDepth) { glDeleteRenderbuffers(1, &g_sceneDepth); g_sceneDepth = 0; }
    if (g_sceneTex)   { glDeleteTextures(1,      &g_sceneTex);   g_sceneTex = 0; }
}

static int _create_scene(int w, int h) {
    _destroy_scene();
    glGenTextures(1, &g_sceneTex);
    glBindTexture(GL_TEXTURE_2D, g_sceneTex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);

    glGenRenderbuffers(1, &g_sceneDepth);
    glBindRenderbuffer(GL_RENDERBUFFER, g_sceneDepth);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, w, h);

    glGenFramebuffers(1, &g_sceneFbo);
    glBindFramebuffer(GL_FRAMEBUFFER, g_sceneFbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, g_sceneTex, 0);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, g_sceneDepth);
    const GLenum st = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    if (st != GL_FRAMEBUFFER_COMPLETE) { _destroy_scene(); return -20; }
    _create_pbos(w, h);   // ne fait rien hors du mode pixels
    return 0;
}

static int spare_idx(void) {
    const int f = g_front.load();
    for (int i = 0; i < 3; i++)
        if (i != f && i != g_pending && i != g_draw) return i;
    return (f + 1) % 3;
}

typedef EGLBoolean (EGLAPIENTRY *PFN_eglQuerySurfacePointerANGLE)(EGLDisplay, EGLSurface, EGLint, void**);
static PFN_eglQuerySurfacePointerANGLE p_querySurfacePointer = nullptr;

static void _destroy_buf(VizBuffer* b) {
    if (b->fbo)      { glDeleteFramebuffers(1, &b->fbo);  b->fbo = 0; }
    if (b->colorTex) {
        if (b->pbuf != EGL_NO_SURFACE) {
            glBindTexture(GL_TEXTURE_2D, b->colorTex);
            eglReleaseTexImage(g_dpy, b->pbuf, EGL_BACK_BUFFER);
            glBindTexture(GL_TEXTURE_2D, 0);
        }
        glDeleteTextures(1, &b->colorTex); b->colorTex = 0;
    }
    if (b->pbuf != EGL_NO_SURFACE) { eglDestroySurface(g_dpy, b->pbuf); b->pbuf = EGL_NO_SURFACE; }
    b->share = nullptr;
}

static int _create_buf(VizBuffer* b, int w, int h) {
    memset(b, 0, sizeof(*b));
    b->pbuf = EGL_NO_SURFACE;

    // Mode pixels: rien à partager avec Flutter, l'image est relue. Une
    // texture ordinaire suffit — et c'est la seule chose qui marche sur le
    // backend OpenGL d'ANGLE, où un pbuffer lié en texture n'est pas une cible
    // de rendu complète (FBO incomplet 0x8CDD, mesuré).
    if (g_pixel_mode) {
        glGenTextures(1, &b->colorTex);
        glBindTexture(GL_TEXTURE_2D, b->colorTex);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glBindTexture(GL_TEXTURE_2D, 0);
        glGenFramebuffers(1, &b->fbo);
        glBindFramebuffer(GL_FRAMEBUFFER, b->fbo);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, b->colorTex, 0);
        const GLenum st = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        if (st == GL_FRAMEBUFFER_COMPLETE) { glClearColor(0.f, 0.f, 0.f, 0.f); glClear(GL_COLOR_BUFFER_BIT); }
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        if (st != GL_FRAMEBUFFER_COMPLETE) {
            fprintf(stderr, "[rewamp_gl] FBO de tampon (pixels) incomplet 0x%x\n", st);
            _destroy_buf(b); return -16;
        }
        return 0;
    }

    const EGLint pbAttrs[] = {
        EGL_WIDTH, w, EGL_HEIGHT, h,
        EGL_TEXTURE_TARGET, EGL_TEXTURE_2D,
        EGL_TEXTURE_FORMAT, EGL_TEXTURE_RGBA,
        EGL_NONE
    };
    b->pbuf = eglCreatePbufferSurface(g_dpy, g_config, pbAttrs);
    if (b->pbuf == EGL_NO_SURFACE) {
        fprintf(stderr, "[rewamp_gl] eglCreatePbufferSurface %dx%d a échoué 0x%x\n",
                w, h, eglGetError());
        return -13;
    }
    if (!p_querySurfacePointer)
        p_querySurfacePointer = (PFN_eglQuerySurfacePointerANGLE)
            eglGetProcAddress("eglQuerySurfacePointerANGLE");
    if (!p_querySurfacePointer ||
        !p_querySurfacePointer(g_dpy, b->pbuf, EGL_D3D_TEXTURE_2D_SHARE_HANDLE_ANGLE, &b->share) ||
        !b->share) {
        fprintf(stderr, "[rewamp_gl] pas de handle DXGI partagé pour le tampon "
                        "(0x%x) — EGL_ANGLE_surface_d3d_texture_2d_share_handle absent ?\n",
                eglGetError());
        if (!g_pixel_mode) { _destroy_buf(b); return -14; }
        b->share = nullptr;   // le mode pixels s'en passe
    }

    glGenTextures(1, &b->colorTex);
    glBindTexture(GL_TEXTURE_2D, b->colorTex);
    if (!eglBindTexImage(g_dpy, b->pbuf, EGL_BACK_BUFFER)) {
        fprintf(stderr, "[rewamp_gl] eglBindTexImage a échoué 0x%x\n", eglGetError());
        glBindTexture(GL_TEXTURE_2D, 0);
        _destroy_buf(b); return -15;
    }
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);

    glGenFramebuffers(1, &b->fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, b->fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, b->colorTex, 0);
    const GLenum st = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (st == GL_FRAMEBUFFER_COMPLETE) {
        // Un tampon neuf a un contenu INDÉFINI, et le triple buffer en publie
        // un avant qu'il ait été dessiné (les deux images qui suivent un
        // resize). Sans ce clear, ce sont deux images de mémoire GPU brute.
        glClearColor(0.f, 0.f, 0.f, 0.f);
        glClear(GL_COLOR_BUFFER_BIT);
    }
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    if (st != GL_FRAMEBUFFER_COMPLETE) {
        fprintf(stderr, "[rewamp_gl] FBO de tampon incomplet 0x%x\n", st);
        _destroy_buf(b); return -16;
    }
    return 0;
}

// ── Cycle de vie ────────────────────────────────────────────────────────────
int rewamp_gl_init(int w, int h) {
    g_width = w; g_height = h;

    typedef EGLDisplay (EGLAPIENTRY *PFN_getPlatformDisplay)(EGLenum, void*, const EGLint*);
    PFN_getPlatformDisplay getPlatformDisplay =
        (PFN_getPlatformDisplay)eglGetProcAddress("eglGetPlatformDisplayEXT");
    // ⚠️ BACKEND D'ANGLE: OpenGL du pilote par DÉFAUT, pas Direct3D 11.
    //
    // Mesuré le 2026-10-03 (ANGLE chromium_7258 du port vcpkg, RTX 3060 Ti):
    // sous D3D11, projectM fait planter le processus au bout de 15 à 80 s de
    // changements de preset — lecture nulle dans
    // rx::StateManager11::syncVertexBuffersAndInputLayout, une entrée VIDE du
    // cache d'input layouts d'ANGLE, appelée par un glDrawElements de projectM.
    // Ce n'est ni notre partage de texture (le mode pixels plante aussi) ni le
    // fil de préchargement (coupé, ça plante encore), et pas la machine: sur le
    // backend OpenGL d'ANGLE, même scénario, plus aucun plantage (2 × 150 s +
    // 60 s en 1920×1080, préchargement actif). Défaut du backend D3D11 de cette
    // révision, non élucidé — le page heap de Windows le fait disparaître sans
    // rien signaler, ce qui ressemble à une adresse réutilisée.
    //
    // Prix: pas de texture D3D partageable, donc le MODE PIXELS (relecture PBO,
    // une image de retard). Mesuré: 9 ms de rendu moyen en 1080p, contre 10 ms
    // en D3D11 sans copie.
    //
    // REWAMP_ANGLE_BACKEND=d3d11 repasse en Direct3D 11 sans copie — pour
    // retester une autre révision d'ANGLE, rien d'autre.
    EGLint backend = 0x320D;   /* EGL_PLATFORM_ANGLE_TYPE_OPENGL_ANGLE */
    if (const char* be = getenv("REWAMP_ANGLE_BACKEND")) {
        if (strcmp(be, "d3d11") == 0) backend = EGL_PLATFORM_ANGLE_TYPE_D3D11_ANGLE;
    }
    if (backend == 0x320D) g_pixel_mode = 1;
    const EGLint dpyAttrs[] = {
        EGL_PLATFORM_ANGLE_TYPE_ANGLE, backend,
        EGL_NONE
    };
    g_dpy = getPlatformDisplay
        ? getPlatformDisplay(EGL_PLATFORM_ANGLE_ANGLE, (void*)EGL_DEFAULT_DISPLAY, dpyAttrs)
        : eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (g_dpy == EGL_NO_DISPLAY) {
        fprintf(stderr, "[rewamp_gl] aucun EGLDisplay ANGLE/D3D11\n");
        return -1;
    }
    if (!eglInitialize(g_dpy, nullptr, nullptr)) {
        fprintf(stderr, "[rewamp_gl] eglInitialize a échoué: 0x%x\n", eglGetError());
        g_dpy = EGL_NO_DISPLAY;
        return -2;
    }
    eglBindAPI(EGL_OPENGL_ES_API);

    // EGL_BIND_TO_TEXTURE_RGBA: les tampons publiés sont des pbuffers liés en
    // texture (eglBindTexImage), ce qu'une config quelconque ne permet pas.
    const EGLint cfgAttrs[] = {
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL_SURFACE_TYPE,    EGL_PBUFFER_BIT,
        EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
        EGL_BIND_TO_TEXTURE_RGBA, EGL_TRUE,
        EGL_NONE
    };
    EGLint numCfg = 0;
    if (!eglChooseConfig(g_dpy, cfgAttrs, &g_config, 1, &numCfg) || numCfg == 0) {
        fprintf(stderr, "[rewamp_gl] aucune config pbuffer liable en texture: 0x%x\n", eglGetError());
        return -3;
    }

    const EGLint ctxAttrs[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
    g_ctx = eglCreateContext(g_dpy, g_config, EGL_NO_CONTEXT, ctxAttrs);
    if (g_ctx == EGL_NO_CONTEXT) {
        fprintf(stderr, "[rewamp_gl] eglCreateContext (GLES 3) a échoué: 0x%x\n", eglGetError());
        return -5;
    }
    const EGLint pbufAttrs[] = { EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE };
    g_baseSurf = eglCreatePbufferSurface(g_dpy, g_config, pbufAttrs);
    if (g_baseSurf == EGL_NO_SURFACE) return -4;
    if (!gl_bind()) {
        fprintf(stderr, "[rewamp_gl] eglMakeCurrent a échoué: 0x%x\n", eglGetError());
        return -6;
    }

    static bool announced = false;
    if (!announced) {
        announced = true;
        fprintf(stderr, "[rewamp_gl] %s | %s | mode %s\n",
                (const char*)glGetString(GL_VERSION), (const char*)glGetString(GL_RENDERER),
                g_pixel_mode ? "PIXELS" : "GPU (handle DXGI partagé)");
    }

    { const int e = _create_scene(w, h); if (e) return e; }
    for (int i = 0; i < 3; i++) { const int e = _create_buf(&g_buf[i], w, h); if (e) return e; }
    g_front.store(0); g_draw = 1; g_pending = -1;
    if (g_pendingFence) { glDeleteSync(g_pendingFence); g_pendingFence = 0; }
    return 0;
}

void rewamp_gl_make_current(void) {
    if (g_ctx != EGL_NO_CONTEXT) gl_bind();
}

static unsigned g_gl_generation = 0;
unsigned rewamp_gl_generation(void) { return g_gl_generation; }

int rewamp_gl_ensure(int width, int height) {
    if (g_width != 0 && g_ctx != EGL_NO_CONTEXT) {
        // Un contexte détruit sous nos pieds (périphérique D3D perdu) doit se
        // voir: sans ce test le visualiseur dessinerait dans le vide.
        if (gl_bind() == EGL_TRUE) return 0;
        rewamp_gl_uninit();
    }
    const int err = rewamp_gl_init(width, height);
    if (err != 0) return err;
    g_gl_generation++;   // les caches bâtis sur l'ancien contexte sont périmés
    return 0;
}

// ── Contexte de préchargement (compilation de shaders en tâche de fond) ──────
static EGLContext g_preload_ctx  = EGL_NO_CONTEXT;
static EGLSurface g_preload_surf = EGL_NO_SURFACE;

int rewamp_gl_preload_context_create(void) {
    // ⚠️ Le préchargeur compile ET « réchauffe » (dessine) le preset suivant
    // dans ce second contexte, sur un AUTRE fil, pendant que le fil de rendu
    // dessine. C'est sûr seulement parce que notre ANGLE est bâti AVEC ses
    // verrous de contexte (ANGLE_ENABLE_SHARE_CONTEXT_LOCK et
    // ANGLE_ENABLE_CONTEXT_MUTEX, triplet windows/angle/triplets) — le port
    // vcpkg les oublie, alors que la build GN autonome d'ANGLE les pose
    // d'office.
    if (getenv("REWAMP_PM_NO_PRELOAD")) return -1;   // diagnostic: chargements synchrones
    if (g_preload_ctx != EGL_NO_CONTEXT) return 0;                 /* idempotent */
    if (g_dpy == EGL_NO_DISPLAY || g_ctx == EGL_NO_CONTEXT) return -1;
    // ⚠️ Backend OpenGL d'ANGLE (DisplayWGL): tous les contextes d'un display y
    // sont « virtualisés » sur UN SEUL contexte WGL natif — et un contexte WGL
    // n'est courant que sur un fil à la fois. Le préchargeur échouait donc à
    // son eglMakeCurrent (EGL_CONTEXT_LOST, 0x300E) et mourait en silence:
    // chaque changement de preset compilait sur le fil de rendu, d'où le gel.
    // Un GROUPE de virtualisation à part lui donne son propre contexte WGL,
    // partagé avec le nôtre — extension qu'ANGLE n'offre sous WGL qu'avec
    // notre patch (windows/angle/ports/angle). D3D11 n'en a pas besoin et ne
    // l'annonce pas: on ne la demande que si elle est là.
    const char *dpyExt = eglQueryString(g_dpy, EGL_EXTENSIONS);
    const bool ownGroup =
        dpyExt && strstr(dpyExt, "EGL_ANGLE_context_virtualization") != nullptr;
    const EGLint ctxAttrsGroup[] = { EGL_CONTEXT_CLIENT_VERSION, 3,
                                     EGL_CONTEXT_VIRTUALIZATION_GROUP_ANGLE, 1, EGL_NONE };
    const EGLint ctxAttrs[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
    g_preload_ctx = eglCreateContext(g_dpy, g_config, g_ctx /* PARTAGÉ */,
                                     ownGroup ? ctxAttrsGroup : ctxAttrs);
    if (g_preload_ctx == EGL_NO_CONTEXT) {
        fprintf(stderr, "[rewamp_gl] preload eglCreateContext a échoué 0x%x\n", eglGetError());
        return -2;
    }
    const EGLint pbAttrs[] = { EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE };
    g_preload_surf = eglCreatePbufferSurface(g_dpy, g_config, pbAttrs);
    if (g_preload_surf == EGL_NO_SURFACE) {
        eglDestroyContext(g_dpy, g_preload_ctx); g_preload_ctx = EGL_NO_CONTEXT; return -3;
    }
    return 0;
}

int rewamp_gl_preload_make_current(void) {
    if (g_preload_ctx == EGL_NO_CONTEXT) return -1;
    if (eglMakeCurrent(g_dpy, g_preload_surf, g_preload_surf, g_preload_ctx)) return 0;
    fprintf(stderr, "[rewamp_gl] preload eglMakeCurrent a échoué 0x%x\n", eglGetError());
    return -2;
}

void rewamp_gl_preload_release(void) {
    if (g_dpy != EGL_NO_DISPLAY)
        eglMakeCurrent(g_dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
}

// ── Publication ─────────────────────────────────────────────────────────────
void rewamp_gl_flush(void) {
    // Barrière DÉCALÉE, comme sur les autres plateformes: on pose un fence, on
    // laisse le GPU courir, et on publie l'image dessinée AU TOUR PRÉCÉDENT.
    // Ici elle a une raison de plus: Flutter lit la texture depuis un AUTRE
    // périphérique Direct3D, donc rien ne l'empêcherait de lire une image dont
    // nos commandes ne sont pas encore soumises.
    const int bi = g_draw;
    if (!g_sceneFbo || !g_buf[bi].fbo) return;

    // Scène → tampon publié, RETOURNÉ EN Y: GL compte ses lignes depuis le
    // bas, une texture Direct3D depuis le haut.
    glBindFramebuffer(GL_READ_FRAMEBUFFER, g_sceneFbo);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, g_buf[bi].fbo);
    glBlitFramebuffer(0, 0,        g_width, g_height,
                      0, g_height, g_width, 0,
                      GL_COLOR_BUFFER_BIT, GL_NEAREST);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    _readback_after_blit(g_buf[bi].fbo);   // mode pixels seulement

    GLsync fence = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0);
    glFlush();   // s'assurer que le fence est réellement soumis

    int nextDraw;
    if (g_pending >= 0 && g_pendingFence) {
        // Plafonné à 50 ms: une image en retard vaut mieux qu'un fil bloqué.
        glClientWaitSync(g_pendingFence, GL_SYNC_FLUSH_COMMANDS_BIT, 50ull * 1000ull * 1000ull);
        glDeleteSync(g_pendingFence);
        int prevFront;
        {
            std::lock_guard<std::mutex> lk(g_swap_mutex);
            prevFront = g_front.load();
            g_front.store(g_pending);
        }
        nextDraw = prevFront;         // Flutter est passé à autre chose
    } else {
        nextDraw = spare_idx();
    }
    g_pending      = g_draw;
    g_pendingFence = fence;
    g_draw         = nextDraw;
}

void rewamp_gl_uninit(void) {
    if (g_dpy == EGL_NO_DISPLAY) return;
    gl_bind();
    if (g_pendingFence) { glDeleteSync(g_pendingFence); g_pendingFence = 0; }
    g_pending = -1; g_draw = 1;
    _destroy_pbos();
    _destroy_scene();
    {
        std::lock_guard<std::mutex> lk(g_swap_mutex);
        for (int i = 0; i < 3; i++) _destroy_buf(&g_buf[i]);
    }
    eglMakeCurrent(g_dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    if (g_preload_surf != EGL_NO_SURFACE) { eglDestroySurface(g_dpy, g_preload_surf); g_preload_surf = EGL_NO_SURFACE; }
    if (g_preload_ctx  != EGL_NO_CONTEXT) { eglDestroyContext(g_dpy, g_preload_ctx);  g_preload_ctx  = EGL_NO_CONTEXT; }
    if (g_baseSurf != EGL_NO_SURFACE) { eglDestroySurface(g_dpy, g_baseSurf); g_baseSurf = EGL_NO_SURFACE; }
    if (g_ctx != EGL_NO_CONTEXT) { eglDestroyContext(g_dpy, g_ctx); g_ctx = EGL_NO_CONTEXT; }
    // PAS d'eglTerminate: un display ANGLE est un singleton par adaptateur, et
    // le recréer coûte l'initialisation de Direct3D à chaque changement de viz.
    g_dpy = EGL_NO_DISPLAY; g_config = nullptr; g_width = 0; g_height = 0;
}

int rewamp_gl_resize(int w, int h) {
    if (w == g_width && h == g_height) return 0;
    g_width = w; g_height = h;
    gl_bind();
    std::lock_guard<std::mutex> lk(g_swap_mutex);
    if (g_pendingFence) { glDeleteSync(g_pendingFence); g_pendingFence = 0; }
    g_pending = -1;
    { const int e = _create_scene(w, h); if (e) return e; }
    for (int i = 0; i < 3; i++) {
        _destroy_buf(&g_buf[i]);
        const int e = _create_buf(&g_buf[i], w, h);
        if (e) return e;
    }
    g_front.store(0); g_draw = 1;
    return 0;
}

unsigned int rewamp_gl_get_fbo(void)     { return g_sceneFbo; }
unsigned int rewamp_gl_get_texture(void) { return g_sceneTex; }
int rewamp_gl_width(void)                { return g_width; }
int rewamp_gl_height(void)               { return g_height; }

// ── Pont vers le greffon ────────────────────────────────────────────────────
// Appelé depuis le fil de rastérisation de Flutter. Le verrou couvre le cas du
// resize, qui détruit et recrée les trois tampons.
extern "C" void* rewamp_gl_windows_front_handle(int* w, int* h) {
    std::lock_guard<std::mutex> lk(g_swap_mutex);
    const int f = g_front.load();
    if (w) *w = g_width;
    if (h) *h = g_height;
    return g_buf[f].share;
}

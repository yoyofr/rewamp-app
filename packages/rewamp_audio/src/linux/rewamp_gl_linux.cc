// Contexte OpenGL ES 3.0 hors écran pour Linux de bureau (EGL natif / Mesa).
//
// Même interface rewamp_gl_* et même discipline triple-tampon + barrière
// décalée que macOS (macos/Classes/rewamp_gl_macos.mm), dont ce fichier est le
// portage direct. Deux différences, toutes deux imposées par la plateforme:
//
//   1. PAS D'ANGLE. ANGLE n'existe chez Apple que parce qu'Apple ne fournit pas
//      GLES; Mesa, lui, expose GLES 3.0 nativement (mesuré ici: « OpenGL ES 3.0
//      Mesa 25.2.8 », renderer virgl/M5). Empiler ANGLE reviendrait à traduire
//      GLES vers Vulkan par-dessus une pile qui parle déjà GLES.
//
//   2. Là où macOS publie une IOSurface, on publie un EGLImageKHR créé depuis
//      notre texture (EGL_KHR_gl_texture_2D_image). Le côté Flutter l'importe
//      dans SON contexte avec glEGLImageTargetTexture2DOES, sans copie et sans
//      que les deux contextes aient à être liés à la création — ce qui est
//      indispensable ici: le contexte de Flutter n'est connu qu'au premier
//      populate(), bien après que nos tampons existent.
//
// ⚠️ Un EGLImage n'est valide que sur SON EGLDisplay. Celui de Flutter n'est
// exposé par aucune API publique de l'embedder; le plugin GTK nous passe donc
// celui qu'il déduit de GdkDisplay (rewamp_gl_linux_set_display), et le premier
// populate() VÉRIFIE l'hypothèse en comparant à eglGetCurrentDisplay(). En cas
// d'écart on ne bricole pas: on note le bon display et on invalide le monde GL
// par la génération — le mécanisme que rewamp_gl_ensure() prévoit déjà pour un
// contexte perdu. Coût: une frame, une seule fois.
#include "../rewamp_audio.h"
#include "../rewamp_gl.h"
#include "rewamp_gl_linux.h"   // les attributs de visibilite du pont
#include "rewamp_viz_linux.h"  // rewamp_viz_stats_lap

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES3/gl3.h>
#include <GLES2/gl2ext.h>   // glEGLImageTargetTexture2DOES

#include <dlfcn.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// ── État global ─────────────────────────────────────────────────────────────
static EGLDisplay g_dpy      = EGL_NO_DISPLAY;
static EGLConfig  g_config   = nullptr;
static EGLContext g_ctx      = EGL_NO_CONTEXT;
static EGLSurface g_baseSurf = EGL_NO_SURFACE;  // pbuffer 1×1, ou EGL_NO_SURFACE si surfaceless
static bool       g_surfaceless = false;        // le display n'offrait aucune config pbuffer
static int g_width = 0, g_height = 0;

// Display fourni par le plugin GTK (déduit de GdkDisplay), puis éventuellement
// corrigé par ce que populate() observe réellement.
static EGLDisplay g_wanted_dpy = EGL_NO_DISPLAY;

// ── Mode PIXELS (X11 / GLX) — voir rewamp_gl_linux.h ────────────────────────
static int g_pixel_mode = 0;

// GLX chargé à la demande: le moteur ne lie PAS libGL (il parle EGL/GLES), et
// il n'a besoin de GLX que pour une chose — écarter le contexte de Flutter le
// temps du rendu, puis le lui rendre. RTLD_NOLOAD d'abord: si GTK ne l'a pas
// chargée, personne n'est en GLX et il n'y a rien à écarter.
typedef void*         (*PFN_glXGetCurrentContext)(void);
typedef void*         (*PFN_glXGetCurrentDisplay)(void);
typedef unsigned long (*PFN_glXGetCurrentDrawable)(void);
typedef unsigned long (*PFN_glXGetCurrentReadDrawable)(void);
typedef int           (*PFN_glXMakeContextCurrent)(void*, unsigned long, unsigned long, void*);
static struct {
    int loaded, ok;
    PFN_glXGetCurrentContext      GetCurrentContext;
    PFN_glXGetCurrentDisplay      GetCurrentDisplay;
    PFN_glXGetCurrentDrawable     GetCurrentDrawable;
    PFN_glXGetCurrentReadDrawable GetCurrentReadDrawable;
    PFN_glXMakeContextCurrent     MakeContextCurrent;
} g_glx;

static void glx_load(void) {
    if (g_glx.loaded) return;
    g_glx.loaded = 1;
    void* h = dlopen("libGLX.so.0", RTLD_NOW | RTLD_NOLOAD);
    if (!h) h = dlopen("libGL.so.1", RTLD_NOW | RTLD_NOLOAD);
    if (!h) return;
    g_glx.GetCurrentContext      = (PFN_glXGetCurrentContext)     dlsym(h, "glXGetCurrentContext");
    g_glx.GetCurrentDisplay      = (PFN_glXGetCurrentDisplay)     dlsym(h, "glXGetCurrentDisplay");
    g_glx.GetCurrentDrawable     = (PFN_glXGetCurrentDrawable)    dlsym(h, "glXGetCurrentDrawable");
    g_glx.GetCurrentReadDrawable = (PFN_glXGetCurrentReadDrawable)dlsym(h, "glXGetCurrentReadDrawable");
    g_glx.MakeContextCurrent     = (PFN_glXMakeContextCurrent)    dlsym(h, "glXMakeContextCurrent");
    g_glx.ok = g_glx.GetCurrentContext && g_glx.GetCurrentDisplay && g_glx.GetCurrentDrawable
            && g_glx.GetCurrentReadDrawable && g_glx.MakeContextCurrent;
}

// Le contexte GLX de Flutter, mis de côté pendant notre rendu.
static struct {
    int saved;
    void* dpy; unsigned long draw, read; void* ctx;
} g_glx_saved;

// Rend NOTRE contexte courant sur ce fil. En mode pixels, écarte d'abord le
// GLX qui s'y trouve — sinon EGL_BAD_ACCESS, la panne d'origine.
static double lap_now_ms(void) {
    struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1e3 + ts.tv_nsec / 1e6;
}

static EGLBoolean gl_bind(void) {
    const double t0 = lap_now_ms();
    const int timed = g_pixel_mode && !g_glx_saved.saved;
    if (g_pixel_mode && !g_glx_saved.saved) {
        glx_load();
        if (g_glx.ok) {
            void* c = g_glx.GetCurrentContext();
            if (c) {
                g_glx_saved.dpy  = g_glx.GetCurrentDisplay();
                g_glx_saved.draw = g_glx.GetCurrentDrawable();
                g_glx_saved.read = g_glx.GetCurrentReadDrawable();
                g_glx_saved.ctx  = c;
                g_glx_saved.saved = 1;
                g_glx.MakeContextCurrent(g_glx_saved.dpy, 0, 0, nullptr);
            }
        }
    }
    const EGLBoolean r = eglMakeCurrent(g_dpy, g_baseSurf, g_baseSurf, g_ctx);
    if (timed) rewamp_viz_stats_lap(0, lap_now_ms() - t0);
    return r;
}

REWAMP_EXPORT void rewamp_gl_release_current(void) {
    if (!g_glx_saved.saved) return;
    const double t0 = lap_now_ms();
    if (g_dpy != EGL_NO_DISPLAY)
        eglMakeCurrent(g_dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    g_glx.MakeContextCurrent(g_glx_saved.dpy, g_glx_saved.draw, g_glx_saved.read, g_glx_saved.ctx);
    g_glx_saved.saved = 0;
    rewamp_viz_stats_lap(3, lap_now_ms() - t0);
}

extern "C" void rewamp_gl_linux_set_pixel_mode(int enabled) { g_pixel_mode = enabled ? 1 : 0; }
extern "C" int  rewamp_gl_linux_pixel_mode(void)            { return g_pixel_mode; }

// Relecture: deux PBO en alternance (la lecture demandée à l'image N est
// récupérée à l'image N+1, quand le GPU l'a finie — le mapper tout de suite
// serait un glFinish déguisé), et UN tampon CPU partagé avec le fil de
// rastérisation, sous verrou. Le plugin copie depuis ce tampon: une copie de
// plus (4 Mo à 1280×800), mais aucune question de durée de vie ni de resize.
static GLuint          g_pbo[2]      = {0, 0};
static int             g_pbo_cur     = 0;
static int             g_pbo_primed  = 0;   // le PBO "précédent" porte-t-il une image ?
static pthread_mutex_t g_px_mutex    = PTHREAD_MUTEX_INITIALIZER;
static uint8_t*        g_px          = nullptr;   // RGBA, g_px_w × g_px_h
static int             g_px_w = 0, g_px_h = 0;
static int             g_px_valid    = 0;

static void _destroy_pbos(void) {
    if (g_pbo[0]) { glDeleteBuffers(2, g_pbo); g_pbo[0] = g_pbo[1] = 0; }
    g_pbo_primed = 0;
    pthread_mutex_lock(&g_px_mutex);
    g_px_valid = 0;
    pthread_mutex_unlock(&g_px_mutex);
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
    pthread_mutex_lock(&g_px_mutex);
    if (g_px_w != w || g_px_h != h) {
        free(g_px);
        g_px = (uint8_t*)malloc((size_t)w * h * 4);
        g_px_w = w; g_px_h = h;
    }
    g_px_valid = 0;
    pthread_mutex_unlock(&g_px_mutex);
}

// Appelé juste après le blit vers le tampon publié `fbo` (contexte courant).
static void _readback_after_blit(GLuint fbo) {
    if (!g_pixel_mode || !g_pbo[0] || !g_px) return;
    // 1. Demander la lecture de CETTE image, asynchrone, dans le PBO courant.
    glBindFramebuffer(GL_READ_FRAMEBUFFER, fbo);
    glBindBuffer(GL_PIXEL_PACK_BUFFER, g_pbo[g_pbo_cur]);
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    const double t0 = lap_now_ms();
    glReadPixels(0, 0, g_width, g_height, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    rewamp_viz_stats_lap(1, lap_now_ms() - t0);
    const double t1 = lap_now_ms();
    // 2. Récupérer celle de l'image PRÉCÉDENTE, que le GPU a eu une image
    //    entière pour finir.
    const int prev = g_pbo_cur ^ 1;
    if (g_pbo_primed) {
        glBindBuffer(GL_PIXEL_PACK_BUFFER, g_pbo[prev]);
        const size_t sz = (size_t)g_width * g_height * 4;
        void* src = glMapBufferRange(GL_PIXEL_PACK_BUFFER, 0, (GLsizeiptr)sz, GL_MAP_READ_BIT);
        if (src) {
            pthread_mutex_lock(&g_px_mutex);
            if (g_px_w == g_width && g_px_h == g_height) {
                memcpy(g_px, src, sz);
                g_px_valid = 1;
            }
            pthread_mutex_unlock(&g_px_mutex);
            glUnmapBuffer(GL_PIXEL_PACK_BUFFER);
        }
    }
    glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
    glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
    if (g_pbo_primed) rewamp_viz_stats_lap(2, lap_now_ms() - t1);
    g_pbo_primed = 1;
    g_pbo_cur = prev;
}

extern "C" int rewamp_gl_linux_copy_front_pixels(uint8_t** buf, size_t* cap, int* w, int* h) {
    pthread_mutex_lock(&g_px_mutex);
    if (!g_px_valid || !g_px) { pthread_mutex_unlock(&g_px_mutex); return 0; }
    const size_t sz = (size_t)g_px_w * g_px_h * 4;
    if (*cap < sz) {
        uint8_t* nb = (uint8_t*)realloc(*buf, sz);
        if (!nb) { pthread_mutex_unlock(&g_px_mutex); return 0; }
        *buf = nb; *cap = sz;
    }
    memcpy(*buf, g_px, sz);
    *w = g_px_w; *h = g_px_h;
    pthread_mutex_unlock(&g_px_mutex);
    return 1;
}

typedef struct {
    GLuint       colorTex;    // notre texture (notre contexte)
    GLuint       fbo;         // couleur seule: ne reçoit que le blit de scène
    EGLImageKHR  image;       // vue partageable de colorTex
} VizBuffer;

// TROIS tampons, pas deux: un lu par Flutter (front), un dont le travail GPU est
// encore en vol (pending), un en cours de dessin (draw). C'est ce qui permet à
// l'attente d'être DÉCALÉE — voir rewamp_gl_flush.
static VizBuffer  g_buf[3];
static atomic_int g_front = 0;
static int        g_draw    = 1;
static int        g_pending = -1;
static GLsync     g_pendingFence = 0;
static atomic_uint g_frame_serial = 0;   // incrémenté à chaque publication
// ⚠️ ÉPOQUE des EGLImage, distincte de la génération GL. Un resize (passage en
// plein écran) détruit et recrée les trois images SANS toucher au contexte,
// donc sans changer la génération — et l'allocateur peut resservir la MÊME
// adresse pour une image neuve. Le plugin, qui décide de relier d'après
// l'adresse, gardait alors une liaison MORTE sur les tampons concernés: un
// mauvais tampon sur trois qui défilent, c'est-à-dire un clignotement rapide.
// L'époque lève l'ambiguïté sans forcer les renderers à se reconstruire (ce que
// ferait un bump de génération, jusqu'à recréer l'instance projectM).
static atomic_uint g_image_epoch = 1;
static pthread_mutex_t g_swap_mutex = PTHREAD_MUTEX_INITIALIZER;

// FBO de SCÈNE: les renderers dessinent toujours ici, jamais directement dans le
// tampon publié. Deux raisons, la seconde étant la vraie:
//   - l'id du FBO ne bouge plus d'une frame à l'autre;
//   - ⚠️ la texture de Flutter sur Linux est lue de HAUT EN BAS, alors que GL
//     a son origine en BAS À GAUCHE. Sans retournement, le visualiseur sort à
//     l'envers. Le même écart existe entre macOS (origine GL conservée) et iOS
//     (lecture haut-bas): Linux se range du côté d'iOS, et on reprend sa
//     solution — un glBlitFramebuffer scène → tampon publié avec l'axe Y
//     inversé, une seule commande GPU, au moment de publier.
static GLuint g_sceneTex = 0, g_sceneFbo = 0, g_sceneDepth = 0;

static inline int back_idx(void) { return g_draw; }

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
    const int f = atomic_load(&g_front);
    for (int i = 0; i < 3; i++)
        if (i != f && i != g_pending && i != g_draw) return i;
    return (f + 1) % 3;
}

// ── Points d'entrée des extensions (résolus une fois) ───────────────────────
static PFNEGLCREATEIMAGEKHRPROC  p_eglCreateImageKHR  = nullptr;
static PFNEGLDESTROYIMAGEKHRPROC p_eglDestroyImageKHR = nullptr;

static void resolve_ext(void) {
    if (p_eglCreateImageKHR) return;
    p_eglCreateImageKHR  = (PFNEGLCREATEIMAGEKHRPROC)eglGetProcAddress("eglCreateImageKHR");
    p_eglDestroyImageKHR = (PFNEGLDESTROYIMAGEKHRPROC)eglGetProcAddress("eglDestroyImageKHR");
}

// ── Tampons ─────────────────────────────────────────────────────────────────
static void _destroy_buf(VizBuffer* b) {
    if (b->image && p_eglDestroyImageKHR) { p_eglDestroyImageKHR(g_dpy, b->image); b->image = nullptr; }
    if (b->fbo)      { glDeleteFramebuffers(1,  &b->fbo);     b->fbo = 0; }
    if (b->colorTex) { glDeleteTextures(1, &b->colorTex);     b->colorTex = 0; }
}

static int _create_buf(VizBuffer* b, int w, int h) {
    memset(b, 0, sizeof(*b));

    glGenTextures(1, &b->colorTex);
    glBindTexture(GL_TEXTURE_2D, b->colorTex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);

    // Pas de profondeur ici: ce FBO ne sert qu'à recevoir le blit de couleur.
    glGenFramebuffers(1, &b->fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, b->fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, b->colorTex, 0);
    const GLenum st = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (st == GL_FRAMEBUFFER_COMPLETE) {
        // Un tampon fraîchement créé a un contenu INDÉFINI, et le triple buffer
        // en publie un avant qu'il ait été dessiné (les deux frames qui suivent
        // un resize). Sans ce clear, ce sont deux frames de mémoire GPU brute.
        glClearColor(0.f, 0.f, 0.f, 0.f);
        glClear(GL_COLOR_BUFFER_BIT);
    }
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    if (st != GL_FRAMEBUFFER_COMPLETE) { _destroy_buf(b); return -13; }

    // ⚠️ EGL_GL_TEXTURE_LEVEL_KHR est OBLIGATOIRE: sans lui certains pilotes
    // refusent l'image (EGL_BAD_PARAMETER) au lieu de supposer le niveau 0.
    resolve_ext();
    if (!p_eglCreateImageKHR) { _destroy_buf(b); return -14; }
    const EGLint imgAttrs[] = { EGL_GL_TEXTURE_LEVEL_KHR, 0, EGL_NONE };
    b->image = p_eglCreateImageKHR(g_dpy, g_ctx, EGL_GL_TEXTURE_2D_KHR,
                                   (EGLClientBuffer)(uintptr_t)b->colorTex, imgAttrs);
    if (!b->image) {
        fprintf(stderr, "[rewamp_gl] eglCreateImageKHR a échoué 0x%x (dpy=%p ctx=%p tex=%u)\n",
                eglGetError(), (void*)g_dpy, (void*)g_ctx, b->colorTex);
        _destroy_buf(b); return -15;
    }
    return 0;
}

// ── Cycle de vie ────────────────────────────────────────────────────────────
REWAMP_EXPORT int rewamp_gl_init(int w, int h) {
    g_width = w; g_height = h;

    g_dpy = (g_wanted_dpy != EGL_NO_DISPLAY) ? g_wanted_dpy
                                             : eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (g_dpy == EGL_NO_DISPLAY) {
        fprintf(stderr, "[rewamp_gl] aucun EGLDisplay (voulu=%p)\n", (void*)g_wanted_dpy);
        return -1;
    }
    if (!eglInitialize(g_dpy, nullptr, nullptr)) {
        fprintf(stderr, "[rewamp_gl] eglInitialize a échoué sur %p: 0x%x\n",
                (void*)g_dpy, eglGetError());
        return -2;
    }
    eglBindAPI(EGL_OPENGL_ES_API);

    // ⚠️ Le display de Flutter n'offre PAS forcément de config pbuffer.
    // Mesuré: sous Wayland, l'EGLDisplay que l'embedder utilise ne publie que
    // des configs WINDOW, et eglChooseConfig échouait (-3) juste après la
    // correction de display — le visualiseur restait noir pour de bon. C'est le
    // symétrique du piège documenté côté Android (là, c'est le bit PBUFFER qui
    // manquait pour le préchargement projectM).
    //
    // On ne rend QUE dans des FBO, donc aucune surface n'est nécessaire:
    // EGL_KHR_surfaceless_context permet un eglMakeCurrent sans surface du tout.
    // On tente quand même une config pbuffer d'abord — elle reste le chemin le
    // plus universel — et on retombe sur surfaceless sinon.
    //
    // EGL_DEPTH_SIZE ne figure PAS dans les critères: la profondeur est un
    // renderbuffer attaché à NOTRE FBO, la config n'a pas à en fournir. L'exiger
    // ne faisait que réduire les configs éligibles.
    const EGLint cfgPbuffer[] = {
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL_SURFACE_TYPE,    EGL_PBUFFER_BIT,
        EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
        EGL_NONE
    };
    const EGLint cfgAny[] = {
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
        EGL_NONE
    };
    EGLint numCfg = 0;
    g_surfaceless = false;
    if (!eglChooseConfig(g_dpy, cfgPbuffer, &g_config, 1, &numCfg) || numCfg == 0) {
        const char* exts = eglQueryString(g_dpy, EGL_EXTENSIONS);
        if (!exts || !strstr(exts, "EGL_KHR_surfaceless_context")) {
            fprintf(stderr, "[rewamp_gl] ni config pbuffer ni surfaceless_context\n");
            return -3;
        }
        if (!eglChooseConfig(g_dpy, cfgAny, &g_config, 1, &numCfg) || numCfg == 0) return -3;
        g_surfaceless = true;
    }

    const EGLint ctxAttrs[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
    g_ctx = eglCreateContext(g_dpy, g_config, EGL_NO_CONTEXT, ctxAttrs);
    if (g_ctx == EGL_NO_CONTEXT) return -5;

    if (!g_surfaceless) {
        const EGLint pbufAttrs[] = { EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE };
        g_baseSurf = eglCreatePbufferSurface(g_dpy, g_config, pbufAttrs);
        if (g_baseSurf == EGL_NO_SURFACE) return -4;
    }
    if (!gl_bind()) {
        fprintf(stderr, "[rewamp_gl] eglMakeCurrent a échoué: 0x%x "
                        "(surfaceless=%d) — un contexte d'une AUTRE API "
                        "(GLX) est-il courant sur ce fil ?\n",
                eglGetError(), (int)g_surfaceless);
        return -6;
    }

    { const int e = _create_scene(w, h); if (e) return e; }
    for (int i = 0; i < 3; i++) { const int e = _create_buf(&g_buf[i], w, h); if (e) return e; }
    atomic_fetch_add(&g_image_epoch, 1u);
    atomic_store(&g_front, 0); g_draw = 1; g_pending = -1;
    if (g_pendingFence) { glDeleteSync(g_pendingFence); g_pendingFence = 0; }
    return 0;
}

REWAMP_EXPORT void rewamp_gl_make_current(void) {
    if (g_ctx != EGL_NO_CONTEXT) gl_bind();
}

static unsigned g_gl_generation = 0;
REWAMP_EXPORT unsigned rewamp_gl_generation(void) { return g_gl_generation; }

// Armé par populate() quand le display observé n'est pas celui qu'on a pris.
static atomic_int g_display_mismatch = 0;

REWAMP_EXPORT int rewamp_gl_ensure(int width, int height) {
    if (atomic_exchange(&g_display_mismatch, 0)) {
        // Le display a été corrigé sous nos pieds: nos EGLImage ne sont pas
        // importables chez Flutter. On reconstruit tout sur le bon display.
        fprintf(stderr, "[rewamp_gl] EGLDisplay corrigé — reconstruction du monde GL\n");
        rewamp_gl_uninit();
    } else if (g_width != 0 && g_ctx != EGL_NO_CONTEXT) {
        // La valeur de retour d'eglMakeCurrent était jadis jetée: un contexte
        // détruit sous nos pieds passait inaperçu et le visualiseur dessinait
        // dans le vide.
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

REWAMP_EXPORT int rewamp_gl_preload_context_create(void) {
    if (g_preload_ctx != EGL_NO_CONTEXT) return 0;                 /* idempotent */
    if (g_dpy == EGL_NO_DISPLAY || g_ctx == EGL_NO_CONTEXT) return -1;
    const EGLint ctxAttrs[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
    g_preload_ctx = eglCreateContext(g_dpy, g_config, g_ctx /* PARTAGÉ */, ctxAttrs);
    if (g_preload_ctx == EGL_NO_CONTEXT) {
        fprintf(stderr, "[rewamp_gl] preload eglCreateContext a échoué 0x%x\n", eglGetError());
        return -2;
    }
    if (!g_surfaceless) {
        const EGLint pbAttrs[] = { EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE };
        g_preload_surf = eglCreatePbufferSurface(g_dpy, g_config, pbAttrs);
        if (g_preload_surf == EGL_NO_SURFACE) {
            eglDestroyContext(g_dpy, g_preload_ctx); g_preload_ctx = EGL_NO_CONTEXT; return -3;
        }
    }
    return 0;
}

REWAMP_EXPORT int rewamp_gl_preload_make_current(void) {
    if (g_preload_ctx == EGL_NO_CONTEXT) return -1;
    return eglMakeCurrent(g_dpy, g_preload_surf, g_preload_surf, g_preload_ctx) ? 0 : -2;
}

REWAMP_EXPORT void rewamp_gl_preload_release(void) {
    if (g_dpy != EGL_NO_DISPLAY)
        eglMakeCurrent(g_dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
}

// ── Publication ─────────────────────────────────────────────────────────────
REWAMP_EXPORT void rewamp_gl_flush(void) {
    // Barrière DÉCALÉE. Flutter échantillonne la texture depuis son fil de
    // rastérisation dès qu'on la publie, donc une frame ne doit jamais sortir
    // avant que son travail GPU ait atterri — mais glFinish paierait ça en
    // BLOQUANT le fil qui pilote la frame Flutter. On pose donc un fence, on
    // laisse le GPU courir, et on publie la frame dessinée AU TOUR PRÉCÉDENT,
    // dont le fence a eu une frame entière pour signaler. Le coût est une frame
    // de latence, CONSTANTE donc invisible: l'œil attrape la gigue, pas le retard.
    const int bi = g_draw;
    if (!g_sceneFbo || !g_buf[bi].fbo) return;

    // Scène → tampon publié, RETOURNÉ EN Y (les lignes de destination sont
    // comptées depuis le haut). Une seule commande GPU; c'est ce qui met
    // l'image à l'endroit pour la texture Flutter de Linux.
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
        // Au-delà, le GPU est en vraie difficulté: une frame en retard vaut
        // mieux qu'un fil bloqué pour toujours.
        {
            const double tw = lap_now_ms();
            glClientWaitSync(g_pendingFence, GL_SYNC_FLUSH_COMMANDS_BIT, 50ull * 1000ull * 1000ull);
            rewamp_viz_stats_lap(4, lap_now_ms() - tw);
        }
        glDeleteSync(g_pendingFence);
        pthread_mutex_lock(&g_swap_mutex);
        const int prevFront = atomic_load(&g_front);
        atomic_store(&g_front, g_pending);
        atomic_fetch_add(&g_frame_serial, 1u);
        pthread_mutex_unlock(&g_swap_mutex);
        nextDraw = prevFront;         // Flutter est passé à autre chose
    } else {
        nextDraw = spare_idx();
    }
    g_pending      = g_draw;
    g_pendingFence = fence;
    g_draw         = nextDraw;
}

REWAMP_EXPORT void rewamp_gl_uninit(void) {
    if (g_dpy == EGL_NO_DISPLAY) return;
    gl_bind();
    if (g_pendingFence) { glDeleteSync(g_pendingFence); g_pendingFence = 0; }
    g_pending = -1; g_draw = 1;
    _destroy_pbos();
    _destroy_scene();
    for (int i = 0; i < 3; i++) _destroy_buf(&g_buf[i]);
    eglMakeCurrent(g_dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    if (g_preload_surf != EGL_NO_SURFACE) { eglDestroySurface(g_dpy, g_preload_surf); g_preload_surf = EGL_NO_SURFACE; }
    if (g_preload_ctx  != EGL_NO_CONTEXT) { eglDestroyContext(g_dpy, g_preload_ctx);  g_preload_ctx  = EGL_NO_CONTEXT; }
    if (g_baseSurf != EGL_NO_SURFACE) { eglDestroySurface(g_dpy, g_baseSurf); g_baseSurf = EGL_NO_SURFACE; }
    if (g_ctx != EGL_NO_CONTEXT) { eglDestroyContext(g_dpy, g_ctx); g_ctx = EGL_NO_CONTEXT; }
    // ⚠️ PAS d'eglTerminate: le display est PARTAGÉ avec Flutter (c'est tout
    // l'intérêt), le terminer emporterait ses propres ressources.
    g_dpy = EGL_NO_DISPLAY; g_config = nullptr; g_width = 0; g_height = 0;
    rewamp_gl_release_current();   // le fil retrouve le GLX de Flutter, s'il y en avait un
}

REWAMP_EXPORT int rewamp_gl_resize(int w, int h) {
    if (w == g_width && h == g_height) return 0;
    g_width = w; g_height = h;
    gl_bind();
    pthread_mutex_lock(&g_swap_mutex);
    if (g_pendingFence) { glDeleteSync(g_pendingFence); g_pendingFence = 0; }
    g_pending = -1;
    { const int e = _create_scene(w, h);
      if (e) { pthread_mutex_unlock(&g_swap_mutex); return e; } }
    for (int i = 0; i < 3; i++) {
        _destroy_buf(&g_buf[i]);
        const int e = _create_buf(&g_buf[i], w, h);
        if (e) { pthread_mutex_unlock(&g_swap_mutex); return e; }
    }
    atomic_fetch_add(&g_image_epoch, 1u);
    atomic_store(&g_front, 0); g_draw = 1;
    pthread_mutex_unlock(&g_swap_mutex);
    return 0;
}

REWAMP_EXPORT unsigned int rewamp_gl_get_fbo(void)     { return g_sceneFbo; }
REWAMP_EXPORT unsigned int rewamp_gl_get_texture(void) { return g_sceneTex; }
REWAMP_EXPORT int rewamp_gl_width(void)                { return g_width; }
REWAMP_EXPORT int rewamp_gl_height(void)               { return g_height; }

// ── Pont vers le plugin GTK ─────────────────────────────────────────────────
// Ces trois-là ne sont PAS de l'API FFI: elles relient rewamp_gl_linux.cc au
// plugin, dans la même .so. Déclarées dans rewamp_gl_linux.h.

extern "C" void rewamp_gl_linux_set_display(void* dpy) {
    g_wanted_dpy = (EGLDisplay)dpy;
}

// Appelé depuis populate(), contexte Flutter courant. Rend l'EGLImage à
// importer, ou nullptr si rien n'est prêt.
extern "C" void* rewamp_gl_linux_front_image(int* w, int* h, unsigned* serial, int* index) {
    pthread_mutex_lock(&g_swap_mutex);
    const int f = atomic_load(&g_front);
    void* img = g_buf[f].image;
    if (w)      *w = g_width;
    if (h)      *h = g_height;
    if (serial) *serial = atomic_load(&g_image_epoch);
    if (index)  *index = f;
    pthread_mutex_unlock(&g_swap_mutex);
    return img;
}

// Vérification de l'hypothèse sur le display, faite une seule fois.
extern "C" int rewamp_gl_linux_display_rebuild_pending(void) {
    return atomic_load(&g_display_mismatch);
}

extern "C" void rewamp_gl_linux_check_display(void* flutter_dpy) {
    static int checked = 0;
    if (checked) return;
    checked = 1;
    if (g_dpy == EGL_NO_DISPLAY || flutter_dpy == (void*)g_dpy) return;
    fprintf(stderr,
            "[rewamp_gl] EGLDisplay de Flutter (%p) != le nôtre (%p) — correction\n",
            flutter_dpy, (void*)g_dpy);
    g_wanted_dpy = (EGLDisplay)flutter_dpy;
    atomic_store(&g_display_mismatch, 1);
}

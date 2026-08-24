// TU unité des renderers partagés pour Linux de bureau.
//
// Pourquoi une unité et pas un TU par fichier: c'est EXACTEMENT le montage
// d'Android (src/android/rewamp_viz_android.cpp), déjà éprouvé. Les renderers
// notes / patterns / spectre réutilisent compile_shader / link_program /
// k_gl_preamble définis par rewamp_viz_render.cpp — ils DOIVENT donc être
// inclus APRÈS lui, dans le même TU. Leurs symboles de portée fichier sont
// préfixés (nv_, pv_, sp_), c'est ce qui rend la cohabitation possible.
//
// Apple, lui, en fait un TU par fichier via les wrappers de podspec; les deux
// montages sont valides, on reprend ici celui dont on sait qu'il compile avec
// ces cinq fichiers ensemble.
//
// projectM (mode 3) reste dans SON TU (src/rewamp_projectm_render.cpp):
// l'inclure ici tirerait ses en-têtes privés aux noms génériques dans ce TU.

#define REWAMP_GL_GLES 1

#include <EGL/egl.h>
#include <GLES3/gl3.h>

#include "../rewamp_audio.h"

#include "../rewamp_viz_render.cpp"
#include "../rewamp_scope_render.cpp"
// Réutilise les helpers de viz_render → après lui. Symboles nv_-préfixés.
#include "../rewamp_notes_render.cpp"
// Vue patterns (mode 4): idem, pv_-préfixés.
#include "../rewamp_pattern_render.cpp"
// Spectre (mode 5): idem, sp_-préfixés.
#include "../rewamp_spectrum_render.cpp"

// ── Points d'entrée FFI ─────────────────────────────────────────────────────
// Ils vivent ICI, dans le MOTEUR, et non dans le plugin GTK: Dart ouvre
// librewamp_audio.so et c'est là qu'il les cherche. Voir rewamp_viz_linux.h
// pour pourquoi Linux a deux bibliothèques là où les autres plateformes n'en
// ont qu'une.
#include <stdio.h>
#include "rewamp_viz_linux.h"
#include "rewamp_gl_linux.h"

static RewampLinuxTextureOps g_ops = {nullptr, nullptr, nullptr, nullptr};
static int64_t g_texture_id = -1;
static bool    g_have_texture = false;

// mode 0 = onde stéréo, 1 = oscilloscope par voix, 2 = défilement de notes,
// 3 = projectM, 4 = patterns, 5 = spectre
static int g_viz_mode = 0;

#ifdef REWAMP_WITH_PROJECTM
extern "C" int  rewamp_projectm_init(int w, int h);
extern "C" void rewamp_projectm_render(void);
extern "C" void rewamp_projectm_uninit(void);
#endif

extern "C" REWAMP_VIZ_LINUX_API
void rewamp_viz_linux_set_texture_ops(const RewampLinuxTextureOps* ops) {
    if (ops) g_ops = *ops;
}

// Changer de visualiseur ne doit PAS reconstruire le monde GL: les renderers
// partagent UN contexte EGL, le démonter entre eux ferait tout recompiler —
// c'est exactement le coût que la version Apple a supprimé. Le contexte ET la
// texture Flutter survivent donc au changement; on n'initialise que le renderer
// entrant et on rend le MÊME identifiant de texture.
static int viz_init_mode(int mode, int w, int h);

static int64_t viz_register_common(int mode, int width, int height) {
    if (!g_ops.create) return -1;
    const bool reuse = g_have_texture;
    g_viz_mode = mode;

    // Un register à une taille que la surface vivante n'a pas doit quand même
    // la redimensionner: rewamp_gl_ensure() IGNORE délibérément la taille quand
    // un contexte est déjà en vie (cette idempotence est ce qui rend le
    // changement de viz peu coûteux), donc sans ça Flutter étirerait l'ancien
    // rapport d'aspect dans la nouvelle boîte.
    if (reuse && (rewamp_gl_width() != width || rewamp_gl_height() != height))
        rewamp_gl_resize(width, height);

    const int err = viz_init_mode(mode, width, height);
    if (err != 0) return (int64_t)err;
    if (reuse) return g_texture_id;

    g_texture_id = g_ops.create(g_ops.user);
    if (g_texture_id < 0) return -2;
    g_have_texture = true;
    return g_texture_id;
}

static int viz_init_mode(int mode, int w, int h) {
    switch (mode) {
        case 1:  return rewamp_scope_init(w, h);
        case 2:  return rewamp_noteviz_init(w, h);
#ifdef REWAMP_WITH_PROJECTM
        case 3:  return rewamp_projectm_init(w, h);
#endif
        case 4:  return rewamp_patternviz_init(w, h);
        case 5:  return rewamp_spectrum_init(w, h);
        default: return rewamp_viz_init(w, h);
    }
}

static void viz_render_and_notify(void) {
    // ⚠️ L'EGLDisplay de Flutter n'est observable que depuis populate(), donc
    // APRÈS que notre contexte et nos EGLImage existent. Quand il diffère du
    // nôtre (c'est le cas sous Wayland/Mesa, mesuré), les images publiées ne
    // sont pas importables chez Flutter et le visualiseur reste NOIR — sans la
    // moindre erreur GL, l'import ne se plaint pas d'une image étrangère.
    //
    // La correction doit donc être appliquée depuis le chemin de RENDU:
    // rewamp_gl_ensure() n'est appelé que par l'init d'un renderer, si bien
    // qu'un écart détecté après coup était noté et jamais suivi d'effet. Une
    // reconstruction orpheline tous les objets GL, d'où la ré-init du renderer
    // courant juste derrière. Une seule fois par session.
    if (rewamp_gl_linux_display_rebuild_pending()) {
        const int w = rewamp_gl_width(), h = rewamp_gl_height();
        const int e = (w > 0 && h > 0) ? rewamp_gl_ensure(w, h) : -99;
        fprintf(stderr, "[rewamp_viz] reconstruction %dx%d -> rewamp_gl_ensure=%d\n", w, h, e);
        if (e == 0) {
            const int ie = viz_init_mode(g_viz_mode, w, h);
            fprintf(stderr, "[rewamp_viz] re-init du renderer %d -> %d\n", g_viz_mode, ie);
        }
    }

    switch (g_viz_mode) {
        case 1:  rewamp_scope_render();      break;
        case 2:  rewamp_noteviz_render();    break;
#ifdef REWAMP_WITH_PROJECTM
        case 3:  rewamp_projectm_render();   break;
#endif
        case 4:  rewamp_patternviz_render(); break;
        case 5:  rewamp_spectrum_render();   break;
        default: rewamp_viz_render();        break;
    }
    if (g_have_texture && g_ops.mark) g_ops.mark(g_ops.user);
}

extern "C" {

REWAMP_EXPORT int64_t rewamp_viz_register(int w, int h)        { return viz_register_common(0, w, h); }
REWAMP_EXPORT int64_t rewamp_scope_register(int w, int h)      { return viz_register_common(1, w, h); }
REWAMP_EXPORT int64_t rewamp_noteviz_register(int w, int h)    { return viz_register_common(2, w, h); }
REWAMP_EXPORT int64_t rewamp_patternviz_register(int w, int h) { return viz_register_common(4, w, h); }
REWAMP_EXPORT int64_t rewamp_spectrum_register(int w, int h)   { return viz_register_common(5, w, h); }

REWAMP_EXPORT void rewamp_viz_render_and_notify(void)        { viz_render_and_notify(); }
REWAMP_EXPORT void rewamp_scope_render_and_notify(void)      { viz_render_and_notify(); }
REWAMP_EXPORT void rewamp_noteviz_render_and_notify(void)    { viz_render_and_notify(); }
REWAMP_EXPORT void rewamp_patternviz_render_and_notify(void) { viz_render_and_notify(); }
REWAMP_EXPORT void rewamp_spectrum_render_and_notify(void)   { viz_render_and_notify(); }

#ifdef REWAMP_WITH_PROJECTM
REWAMP_EXPORT int64_t rewamp_projectm_register(int w, int h)  { return viz_register_common(3, w, h); }
REWAMP_EXPORT void    rewamp_projectm_render_and_notify(void) { viz_render_and_notify(); }
#endif

REWAMP_EXPORT int rewamp_viz_resize_register(int w, int h) {
    if (rewamp_gl_width() == w && rewamp_gl_height() == h) return 0;
    return rewamp_gl_resize(w, h);
}

REWAMP_EXPORT void rewamp_viz_unregister(void) {
    switch (g_viz_mode) {
        case 1:  rewamp_scope_uninit();      break;
        case 2:  rewamp_noteviz_uninit();    break;
#ifdef REWAMP_WITH_PROJECTM
        case 3:  rewamp_projectm_uninit();   break;
#endif
        case 4:  rewamp_patternviz_uninit(); break;
        case 5:  rewamp_spectrum_uninit();   break;
        default: rewamp_viz_uninit();        break;
    }
    if (g_have_texture && g_ops.destroy) g_ops.destroy(g_ops.user);
    g_have_texture = false;
    g_texture_id = -1;
    rewamp_gl_uninit();
}

}  // extern "C"

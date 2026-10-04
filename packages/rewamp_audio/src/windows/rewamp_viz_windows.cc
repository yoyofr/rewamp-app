// TU unité des renderers partagés pour Windows — le pendant exact de
// src/linux/rewamp_viz_linux.cc, dont il reprend le montage et les raisons:
// notes / patterns / spectre / piano réutilisent compile_shader, link_program
// et k_gl_preamble définis par rewamp_viz_render.cpp, donc ils DOIVENT être
// inclus APRÈS lui, dans le même TU.
//
// projectM (mode 3) reste dans SON TU (src/rewamp_projectm_render.cpp).

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
// Piano (mode 6), pk_-préfixé; après la notation (nv_voice_color, nv_now).
#include "../rewamp_piano_render.cpp"

// ── Points d'entrée FFI ─────────────────────────────────────────────────────
// Ils vivent ICI, dans le MOTEUR, et non dans le greffon: Dart ouvre
// rewamp_audio.dll et c'est là qu'il les cherche. Voir rewamp_viz_windows.h.
#include <stdio.h>
#include "rewamp_viz_windows.h"

static RewampWinTextureOps g_ops = {nullptr, nullptr, nullptr, nullptr};
static int64_t g_texture_id = -1;
static bool    g_have_texture = false;

// mode 0 = onde stéréo, 1 = oscilloscope par voix, 2 = défilement de notes,
// 3 = projectM, 4 = patterns, 5 = spectre, 6 = piano
static int g_viz_mode = 0;

#ifdef REWAMP_WITH_PROJECTM
extern "C" int  rewamp_projectm_init(int w, int h);
extern "C" void rewamp_projectm_render(void);
extern "C" void rewamp_projectm_uninit(void);
#endif

extern "C" void rewamp_viz_windows_set_texture_ops(const RewampWinTextureOps* ops) {
    if (ops) g_ops = *ops;
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
        case 6:  return rewamp_pianoviz_init(w, h);
        default: return rewamp_viz_init(w, h);
    }
}

// Changer de visualiseur ne reconstruit PAS le monde GL: les renderers
// partagent UN contexte, et la texture Flutter survit au changement — on
// n'initialise que le renderer entrant et on rend le MÊME identifiant.
static int64_t viz_register_common(int mode, int width, int height) {
    if (!g_ops.create) return -1;
    const bool reuse = g_have_texture;
    g_viz_mode = mode;

    // rewamp_gl_ensure() IGNORE délibérément la taille quand un contexte est
    // en vie (c'est ce qui rend le changement de viz peu coûteux): un register
    // à une autre taille doit donc redimensionner lui-même.
    if (reuse && (rewamp_gl_width() != width || rewamp_gl_height() != height))
        rewamp_gl_resize(width, height);

    const int err = viz_init_mode(mode, width, height);
    if (err != 0) {
        // Un enregistrement qui échoue rend un code négatif que Dart traite en
        // silence (rectangle noir): l'échec DOIT se nommer.
        fprintf(stderr, "[rewamp_viz] enregistrement du mode %d en %dx%d "
                        "ÉCHOUE -> %d (voir rewamp_gl_init)\n",
                mode, width, height, err);
        return (int64_t)err;
    }
    if (reuse) return g_texture_id;

    g_texture_id = g_ops.create(g_ops.user);
    if (g_texture_id < 0) return -2;
    g_have_texture = true;
    return g_texture_id;
}

static void viz_render_and_notify(void) {
    switch (g_viz_mode) {
        case 1:  rewamp_scope_render();      break;
        case 2:  rewamp_noteviz_render();    break;
#ifdef REWAMP_WITH_PROJECTM
        case 3:  rewamp_projectm_render();   break;
#endif
        case 4:  rewamp_patternviz_render(); break;
        case 5:  rewamp_spectrum_render();   break;
        case 6:  rewamp_pianoviz_render();   break;
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
REWAMP_EXPORT int64_t rewamp_pianoviz_register(int w, int h)   { return viz_register_common(6, w, h); }

REWAMP_EXPORT void rewamp_viz_render_and_notify(void)        { viz_render_and_notify(); }
REWAMP_EXPORT void rewamp_scope_render_and_notify(void)      { viz_render_and_notify(); }
REWAMP_EXPORT void rewamp_noteviz_render_and_notify(void)    { viz_render_and_notify(); }
REWAMP_EXPORT void rewamp_patternviz_render_and_notify(void) { viz_render_and_notify(); }
REWAMP_EXPORT void rewamp_spectrum_render_and_notify(void)   { viz_render_and_notify(); }
REWAMP_EXPORT void rewamp_pianoviz_render_and_notify(void)   { viz_render_and_notify(); }

#ifdef REWAMP_WITH_PROJECTM
REWAMP_EXPORT int64_t rewamp_projectm_register(int w, int h)  { return viz_register_common(3, w, h); }
REWAMP_EXPORT void    rewamp_projectm_render_and_notify(void) { viz_render_and_notify(); }
#endif

REWAMP_EXPORT int rewamp_viz_resize_register(int w, int h) {
    if (rewamp_gl_width() == w && rewamp_gl_height() == h) return 0;
    return rewamp_gl_resize(w, h);
}

// Notre contexte doit être courant pour que les glDelete* des uninit visent
// NOS objets. (Rien à rendre à Flutter ensuite: son ANGLE est une autre
// instance, avec son propre « contexte courant » — voir rewamp_gl_windows.cc.)
REWAMP_EXPORT void rewamp_viz_unregister(void) {
    rewamp_gl_make_current();
    switch (g_viz_mode) {
        case 1:  rewamp_scope_uninit();      break;
        case 2:  rewamp_noteviz_uninit();    break;
#ifdef REWAMP_WITH_PROJECTM
        case 3:  rewamp_projectm_uninit();   break;
#endif
        case 4:  rewamp_patternviz_uninit(); break;
        case 5:  rewamp_spectrum_uninit();   break;
        case 6:  rewamp_pianoviz_uninit();   break;
        default: rewamp_viz_uninit();        break;
    }
    // Les objets GL du fond pochette meurent avec ce contexte. Seul l'uninit
    // stéréo appelait art_cleanup(): quitter le lecteur sur le piano (ou
    // notes, motifs…) laissait un g_art_tex périmé et g_art_dirty à 0, et la
    // pochette ne revenait qu'en repassant par le stéréo. Idempotent (handles
    // déjà à 0 après le stéréo) — même correctif que rewamp_viz_android.cpp.
    art_cleanup();
    // La texture Flutter AVANT le monde GL: une fois désenregistrée, le fil de
    // rastérisation ne redemandera plus un handle que rewamp_gl_uninit détruit.
    if (g_have_texture && g_ops.destroy) g_ops.destroy(g_ops.user);
    g_have_texture = false;
    g_texture_id = -1;
    rewamp_gl_uninit();
}

}  // extern "C"

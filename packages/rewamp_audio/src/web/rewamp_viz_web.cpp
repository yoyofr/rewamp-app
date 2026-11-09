// Les visualiseurs partagés pour le web: une TU UNITÉ, exactement le montage
// d'Android et de Linux (src/linux/rewamp_viz_linux.cc) — les renderers notes /
// patterns / spectre / piano réutilisent les helpers de rewamp_viz_render.cpp
// et doivent venir APRÈS lui; leurs symboles de fichier sont préfixés
// (nv_, pv_, sp_, pk_).
//
// Le contexte est celui de rewamp_gl_web.c: le canvas que la page a transféré
// au Worker du moteur, rendu DIRECTEMENT (rewamp_gl_get_fbo() = 0). projectM
// (mode 3) reste dans SA TU et partage ce même contexte, comme ailleurs.
//
// Ce que fait le widget Dart autour du rendu, et qu'il faut refaire ici:
//   - pousser l'horloge d'image (rewamp_viz_set_frame_time) AVANT chaque rendu:
//     notation, piano et motifs défilent sur elle — sans elle dt = 0, rien ne
//     bouge;
//   - demander le LOOK-AHEAD que le viz lit en avance (notation 2 s, piano
//     « chute » 2 s, motifs selon la hauteur de grille) et le RELÂCHER en le
//     quittant: 2 s d'avance coûtent 2 s de latence sur tout réglage audio.
#define REWAMP_GL_GLES 1

#include <GLES3/gl3.h>
#include <emscripten/emscripten.h>

#include "../rewamp_audio.h"
#include "../rewamp_gl.h"

#include "../rewamp_viz_render.cpp"
#include "../rewamp_scope_render.cpp"
#include "../rewamp_notes_render.cpp"
#include "../rewamp_pattern_render.cpp"
#include "../rewamp_spectrum_render.cpp"
#include "../rewamp_piano_render.cpp"

#ifdef REWAMP_WITH_PROJECTM
extern "C" int  rewamp_projectm_init(int w, int h);
extern "C" void rewamp_projectm_render(void);
#endif
extern "C" void   rewamp_set_lookahead_seconds(double s);
extern "C" double rewamp_patternviz_future_seconds(void);

// Même numérotation que partout: 0 stéréo, 1 voies, 2 notation, 3 projectM,
// 4 motifs, 5 spectre, 6 piano.
static int g_web_mode = -1;
static int g_web_piano_fall = 0;   // 0 claviers (défaut de l'app), 1 notes qui tombent
static double g_web_lookahead = 0; // dernière avance demandée

static double web_lookahead_for(int mode) {
    switch (mode) {
        case 2: return 2.0;                                   // 1,5 s de fenêtre + marge
        case 6: return g_web_piano_fall ? 2.0 : 0.0;
        case 4: {
            // Ce que la grille montre AU-DESSUS de la tête, mesuré par le
            // renderer lui-même (hauteur, zoom); +0,5 s, borné [1, 8] comme
            // pattern_scope_widget.dart.
            const double f = rewamp_patternviz_future_seconds();
            const double s = f > 0 ? f + 0.5 : 2.0;
            return s < 1.0 ? 1.0 : (s > 8.0 ? 8.0 : s);
        }
        default: return 0.0;
    }
}

extern "C" {

// Choisit le visualiseur (init idempotente: le contexte et les objets des
// autres renderers survivent au changement). Rend 0 ou le code de l'init.
EMSCRIPTEN_KEEPALIVE int rewamp_web_viz_select(int mode, int w, int h) {
    if (rewamp_gl_init(w, h) != 0) return -1;
    int err;
    switch (mode) {
        case 1:  err = rewamp_scope_init(w, h);      break;
        case 2:  err = rewamp_noteviz_init(w, h);    break;
#ifdef REWAMP_WITH_PROJECTM
        case 3:  err = rewamp_projectm_init(w, h);   break;
#endif
        case 4:  err = rewamp_patternviz_init(w, h); break;
        case 5:  err = rewamp_spectrum_init(w, h);   break;
        case 6:  err = rewamp_pianoviz_init(w, h);   break;
        default: err = rewamp_viz_init(w, h); mode = 0; break;
    }
    if (err != 0) return err;
    g_web_mode = mode;
    g_web_lookahead = web_lookahead_for(mode);
    rewamp_set_lookahead_seconds(g_web_lookahead);
    return 0;
}

// Aspect du piano (la page appelle aussi rewamp_set_piano_options): « notes qui
// tombent » lit 2 s d'avance, « claviers » aucune — comme piano_widget.dart.
EMSCRIPTEN_KEEPALIVE void rewamp_web_viz_set_piano_fall(int fall) {
    g_web_piano_fall = fall ? 1 : 0;
    if (g_web_mode == 6) { g_web_lookahead = web_lookahead_for(6); rewamp_set_lookahead_seconds(g_web_lookahead); }
}

// Arrêt du visualiseur (masqué): on rend l'avance demandée.
EMSCRIPTEN_KEEPALIVE void rewamp_web_viz_idle(void) {
    g_web_lookahead = 0; rewamp_set_lookahead_seconds(0.0);
}

// Une image. `t` = horloge d'image en secondes (celle de requestAnimationFrame).
EMSCRIPTEN_KEEPALIVE void rewamp_web_viz_render(double t) {
    rewamp_viz_set_frame_time(t);
    switch (g_web_mode) {
        case 1:  rewamp_scope_render();      break;
        case 2:  rewamp_noteviz_render();    break;
#ifdef REWAMP_WITH_PROJECTM
        case 3:  rewamp_projectm_render();   break;
#endif
        case 4:  rewamp_patternviz_render();
                 // La grille dit combien de temps elle montre en avance APRÈS
                 // un rendu: l'avance suit (seuil 0,2 s, comme le widget Dart).
                 {
                     const double want = web_lookahead_for(4);
                     if (want - g_web_lookahead > 0.2 || g_web_lookahead - want > 0.2) {
                         g_web_lookahead = want; rewamp_set_lookahead_seconds(want);
                     }
                 }
                 break;
        case 5:  rewamp_spectrum_render();   break;
        case 6:  rewamp_pianoviz_render();   break;
        case 0:  rewamp_viz_render();        break;
        default: break;
    }
}

}  // extern "C"

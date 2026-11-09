/* rewamp_gl.h pour le web (Emscripten, WebGL 2).
 *
 * Même modèle qu'Android (src/android/rewamp_gl_android.cpp): le rendu va
 * DIRECTEMENT dans le framebuffer par défaut d'une surface d'affichage — ici le
 * canvas que la page a transféré au Worker du moteur (OffscreenCanvas). Pas de
 * FBO intermédiaire ni de texture partagée avec Flutter: rewamp_gl_get_fbo()
 * rend 0, et le navigateur compose le canvas lui-même quand le Worker rend la
 * main à sa boucle d'événements.
 *
 * Le contexte WebGL est créé CÔTÉ JAVASCRIPT (le canvas n'existe que là) et
 * inscrit auprès de la bibliothèque GL d'Emscripten par GL.registerContext; la
 * page passe la poignée à rewamp_gl_web_set_context(). Toutes les fonctions
 * ci-dessous doivent être appelées sur le fil qui possède le canvas — le Worker
 * du moteur, celui qui appelle rewamp_projectm_render().
 *
 * Préchargement des presets (second contexte partagé sur un fil à part):
 * IMPOSSIBLE en WebGL, qui n'a pas de groupes de partage entre contextes.
 * rewamp_gl_preload_context_create() rend donc une erreur, et le renderer
 * projectM retombe sur ses chargements synchrones (prévu pour ça).
 */
#include "../rewamp_audio.h"
#include "../rewamp_gl.h"

#include <emscripten/emscripten.h>
#include <emscripten/html5_webgl.h>

static EMSCRIPTEN_WEBGL_CONTEXT_HANDLE g_ctx = 0;
static int      g_width  = 0;
static int      g_height = 0;
static unsigned g_gl_generation = 0;

/* La page donne la poignée (GL.registerContext) et la taille du canvas. Une
 * NOUVELLE poignée = nouveau contexte: les objets GL des renderers sont morts. */
EMSCRIPTEN_KEEPALIVE
void rewamp_gl_web_set_context(int handle, int width, int height) {
    if ((EMSCRIPTEN_WEBGL_CONTEXT_HANDLE)handle != g_ctx) g_gl_generation++;
    g_ctx    = (EMSCRIPTEN_WEBGL_CONTEXT_HANDLE)handle;
    g_width  = width;
    g_height = height;
}

REWAMP_EXPORT int rewamp_gl_init(int width, int height) {
    if (!g_ctx) return -1;                 /* la page n'a pas donné de canvas */
    if (width > 0)  g_width  = width;
    if (height > 0) g_height = height;
    return emscripten_webgl_make_context_current(g_ctx) == EMSCRIPTEN_RESULT_SUCCESS
               ? 0 : -2;
}

REWAMP_EXPORT void rewamp_gl_make_current(void) {
    if (g_ctx) emscripten_webgl_make_context_current(g_ctx);
}

REWAMP_EXPORT unsigned rewamp_gl_generation(void) { return g_gl_generation; }

REWAMP_EXPORT int rewamp_gl_ensure(int width, int height) {
    if (!g_ctx) return -1;
    /* Un contexte WebGL PERDU (GPU réinitialisé, onglet en arrière-plan trop
     * longtemps) ne se ranime pas: il faut un nouveau canvas, donc la page. On
     * le signale comme un échec; la page recrée et rappelle set_context. */
    if (emscripten_is_webgl_context_lost(g_ctx)) return -3;
    return rewamp_gl_init(width, height);
}

REWAMP_EXPORT void rewamp_gl_release_current(void) {
    emscripten_webgl_make_context_current(0);
}

/* Le navigateur présente le canvas tout seul à la fin de la tâche du Worker. */
REWAMP_EXPORT void rewamp_gl_flush(void) {}

REWAMP_EXPORT void rewamp_gl_uninit(void) {
    /* Le contexte appartient à la page (elle a créé le canvas): on le lâche
     * seulement, sans le détruire. */
    emscripten_webgl_make_context_current(0);
}

REWAMP_EXPORT unsigned int rewamp_gl_get_fbo(void)     { return 0; }
REWAMP_EXPORT unsigned int rewamp_gl_get_texture(void) { return 0; }
REWAMP_EXPORT int rewamp_gl_width(void)  { return g_width;  }
REWAMP_EXPORT int rewamp_gl_height(void) { return g_height; }

REWAMP_EXPORT int  rewamp_gl_preload_context_create(void) { return -1; }
REWAMP_EXPORT int  rewamp_gl_preload_make_current(void)   { return -1; }
REWAMP_EXPORT void rewamp_gl_preload_release(void)        {}

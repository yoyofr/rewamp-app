// projectM visualizer renderer — renders a full Milkdrop frame into the shared
// ANGLE/GLES FBO (rewamp_gl_*). Unlike the scope/notes renderers it does NOT
// draw the artwork quad and forces an OPAQUE black framebuffer, so no album
// artwork shows through (per design: projectM owns the whole frame).
//
// GL header (<GLES3/gl3.h> on ANGLE, <OpenGL/gl3.h> desktop) is included by the
// platform wrapper TU before this file, same as the other renderers.
#if defined(__ANDROID__) || (defined(__linux__) && !defined(__ANDROID__))
// Sur Apple, le TU wrapper du podspec inclut l'en-tete GL avant ce fichier; la
// build cmake (Android et Linux de bureau) le compile directement, donc on le
// tire nous-memes. Linux prend le meme <GLES3/gl3.h>, servi par Mesa.
#include <GLES3/gl3.h>
#endif
#if defined(__APPLE__)
#  include <TargetConditionals.h>   // TARGET_OS_OSX — see the blit's flip below
#endif

#include "rewamp_audio.h"
#include "rewamp_viz_idle.h"   /* plafond de cadence: ce qu'on déclare aux presets */
#include "rewamp_waveform.h"
#include "rewamp_gl.h"
#include "rewamp_assets.h"  // rewamp_get_data_dir
#include "rewamp_projectm_sprites.h"

#include <projectM-4/projectM.h>

#include <pthread.h>
#include <algorithm>
#include <atomic>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>
#include <dirent.h>
#include <ctime>

// --- App-side globals required by the (Modizer-patched) libprojectM ----------
// Shader.cpp uses mdzMainThreadId/mdzRenderInProgress for its background
// preset-precompile thread hack; PresetFileParser.cpp uses the permissive flag.
extern "C" {
/* pthread_t (not mach_port_t): the same identity check, portable to Android. */
pthread_t     mdzMainThreadId = {};
volatile bool mdzRenderInProgress = false;
int           mdz_pmMilkPermissiveEvalCode = 1;
}

// ── Preset-load profiling ─────────────────────────────────────────────────────
// Answers "is the preset-switch hiccup CPU-bound (milk parse + HLSL→GLSL +
// projectm_eval compiles) or GL-bound (shader compile/link)?" — the answer
// decides whether a background-precompile design (2nd shared EGL context) is
// worth building. Shader.cpp accumulates the GL half; everything else in the
// load is CPU by elimination. The first frames after a load are timed too:
// GLES drivers can defer the real compile to the first draw, which would show
// up there instead.
// OFF by default: the profiling is not free. Shader.cpp's accumulator does a
// glGetProgramiv right after glLinkProgram to attribute the link cost honestly
// — that is a SYNC POINT, forcing a link the driver might otherwise finish
// lazily/asynchronously. Harmless on the preload worker, but it would also hit
// the render thread on the synchronous fallback path. Build with
// -DREWAMP_PM_PROFILE=1 to get the lines back (Android: adb logcat -s
// rewamp_pmprof; Apple: os_log / Console.app, filter pmprof).
#if !defined(REWAMP_PM_PROFILE)
#define PM_PROF(...) ((void)0)
#elif defined(__ANDROID__)
#include <android/log.h>
#define PM_PROF(...) __android_log_print(ANDROID_LOG_INFO, "rewamp_pmprof", __VA_ARGS__)
#elif defined(__APPLE__)
// stderr is only captured by `flutter run` in DEBUG (lldb attach); in
// --profile/--release it goes nowhere. os_log is captured in every mode —
// both by `flutter run` and by Console.app (filter: pmprof). %{public}s
// because dynamic strings are redacted to <private> by default.
#include <os/log.h>
#include <cstdarg>
static void pm_prof_log(const char* fmt, ...) {
    char buf[1024];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    os_log(OS_LOG_DEFAULT, "[pmprof] %{public}s", buf);
    fprintf(stderr, "[pmprof] %s\n", buf);   // keep the debug-run channel too
}
#define PM_PROF(fmt, ...) pm_prof_log(fmt, ##__VA_ARGS__)
#else
#define PM_PROF(fmt, ...) fprintf(stderr, "[pmprof] " fmt "\n", ##__VA_ARGS__)
#endif
extern "C" {
long long mdzGlCompileNs   = 0;   // accumulated by Shader::CompileProgram
long long mdzGlLinkNs      = 0;
int       mdzGlProgramCount = 0;
}
static long long _prof_now_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long)ts.tv_sec * 1000000000LL + ts.tv_nsec;
}
static int g_prof_frames_after_load = 0;   // log the next N frame times

static projectm_handle g_pm = nullptr;
static int g_w = 0, g_h = 0;
static std::vector<std::string> g_presets; // absolute paths to *.milk
static size_t g_preset_idx = 0;
static std::vector<size_t> g_history;      // visited preset indices (prev = pop)
// Session-scoped: once the presets are scanned + the first preset chosen, the
// history/index survive disabling & re-enabling the visualizer. They are only
// wiped when the process exits (statics die) — never on uninit.
static bool g_session_active = false;
// Does the LIVE projectm instance already have its preset loaded?
//
// Not the same question as g_session_active. A preset load is the expensive
// thing here (~950 ms: milk parse + HLSL→GLSL transpile + GL compile/link), and
// now that the GL context and g_pm both survive a visualizer switch, the preset
// is still loaded when we come back — reloading it would be pure waste. But
// leaving the visualizer entirely DOES destroy g_pm (rewamp_projectm_uninit),
// and a fresh instance has nothing loaded, so we cannot simply skip on
// re-entry. This tracks the instance, not the session.
static bool g_pm_preset_loaded = false;
// The GL generation g_pm's internal objects were built on. A rebuilt context
// invalidates every shader/texture/buffer inside the instance at once.
static unsigned g_pm_gl_gen = 0;
// Current preset display name (basename, no extension) + a serial bumped on
// every load so Dart can detect a change (incl. the core's own auto-switch) and
// briefly show the name. Fixed buffer → no realloc torn read across threads.
static char g_preset_name[512] = {0};
static volatile int g_preset_serial = 0;
static int g_random_mode = 1;              // 1 = random next, 0 = sequential
static int g_blend_mode  = 1;              // 1 = soft-cut blend, 0 = hard cut
static unsigned g_rng = 0x9E3779B9u;       // xorshift state (semé au premier tirage)
static bool     g_rng_seeded = false;      // voir _rng_seed_once

// Tunables (Modizer's projectM settings; pushed from Dart via set_params).
static double g_preset_duration = 15.0;
static double g_blend_time      = 2.7;
static int    g_quality_shift   = 0;   // render at (w>>q, h>>q): 0=Max,1=1/2,2=1/4,3=1/8
static int    g_mesh_x = 32, g_mesh_y = 24;
static double g_beat_sens = 1.0;
static int    g_hardcut_enabled = 0;
static double g_hardcut_time = 20.0, g_hardcut_sens = 1.0;
static int    g_aspect = 1;
static int    g_lock_preset = 0;
// Pinned transition pattern, -1 = pick at random (the default and MilkDrop's
// behaviour). Pushed like every other tunable, so it is re-applied by
// _apply_params at init too — which is what makes it survive the instance being
// destroyed and recreated (a GL context rebuild does exactly that).
static int    g_transition_index = -1;

// Custom preset list + texture dirs pushed from Dart (preset packs / user
// playlists). Both survive uninit (like the session state) so a viz switch or
// re-entry keeps the chosen source. The playlist is DOUBLE-buffered: Dart
// writes g_playlist under its mutex from the platform thread; the render
// thread (or init) adopts it into g_presets — never the other way round.
static pthread_mutex_t g_playlist_mtx = PTHREAD_MUTEX_INITIALIZER;
static std::vector<std::string> g_playlist;       // staged; empty = default dir
static long g_playlist_start = -1;                // preset to open on; -1 = usual pick
static std::atomic<bool> g_playlist_dirty{false};
static pthread_mutex_t g_texdirs_mtx = PTHREAD_MUTEX_INITIALIZER;
static std::vector<std::string> g_tex_dirs;       // staged; empty = default dir
static std::atomic<bool> g_texdirs_dirty{false};
// Absolute path of the current preset (fixed buffer, same reason as the name).
static char g_preset_path[1024] = {0};

// Private render target: projectM draws here (possibly downscaled), then a
// Y-flipping blit copies it into the shared IOSurface FBO — projectM's output
// is bottom-up relative to the pipeline (it appeared upside down), and the
// same blit implements the Modizer-style render-quality downscale for free.
static GLuint g_pmFbo = 0, g_pmTex = 0, g_pmDepth = 0;
static int    g_pmW = 0, g_pmH = 0;

static void _destroy_pm_target(void) {
    if (g_pmFbo)   { glDeleteFramebuffers(1, &g_pmFbo);   g_pmFbo = 0; }
    if (g_pmDepth) { glDeleteRenderbuffers(1, &g_pmDepth); g_pmDepth = 0; }
    if (g_pmTex)   { glDeleteTextures(1, &g_pmTex);        g_pmTex = 0; }
    g_pmW = g_pmH = 0;
}

static int _ensure_pm_target(int w, int h) {
    if (w == g_pmW && h == g_pmH && g_pmFbo) return 0;
    _destroy_pm_target();
    glGenTextures(1, &g_pmTex);
    glBindTexture(GL_TEXTURE_2D, g_pmTex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glGenRenderbuffers(1, &g_pmDepth);
    glBindRenderbuffer(GL_RENDERBUFFER, g_pmDepth);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, w, h);
    glGenFramebuffers(1, &g_pmFbo);
    glBindFramebuffer(GL_FRAMEBUFFER, g_pmFbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, g_pmTex, 0);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, g_pmDepth);
    GLenum st = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    if (st != GL_FRAMEBUFFER_COMPLETE) { _destroy_pm_target(); return -1; }
    g_pmW = w; g_pmH = h;
    return 0;
}

static void _apply_params(void) {
    if (!g_pm) return;
    /* ⚠️ `set_fps` n'est PAS un plafond de rendu: c'est la cadence qu'on
     * DÉCLARE aux presets. `fps` est une variable de leurs équations par frame
     * (les amortissements MilkDrop s'écrivent couramment `pow(x, 30/fps)`),
     * elle part aussi aux shaders dans `_c2.y`, et `1/fps` sert de pas de
     * temps au lissage du spectre. Annoncer 60 en rendant à 120 fait donc
     * décroître tout ça deux fois trop vite. On annonce le plafond quand il y
     * en a un, 60 sinon — faute de connaître le rafraîchissement réel ici. Ici
     * et pas à l'init: le plafond est un réglage, il peut changer en cours de
     * route. */
    {
        const int cap = rewamp_viz_max_fps();
        projectm_set_fps(g_pm, cap > 0 ? cap : 60);
    }
    projectm_set_preset_duration(g_pm, g_preset_duration);
    // Modizer: blend off → soft-cut duration 0 (hard transitions everywhere).
    projectm_set_soft_cut_duration(g_pm, g_blend_mode ? g_blend_time : 0.0);
    projectm_set_mesh_size(g_pm, (size_t)g_mesh_x, (size_t)g_mesh_y);
    projectm_set_beat_sensitivity(g_pm, (float)g_beat_sens);
    projectm_set_hard_cut_enabled(g_pm, g_hardcut_enabled != 0);
    projectm_set_hard_cut_duration(g_pm, g_hardcut_time);
    projectm_set_hard_cut_sensitivity(g_pm, (float)g_hardcut_sens);
    projectm_set_aspect_correction(g_pm, g_aspect != 0);
    projectm_set_preset_locked(g_pm, g_lock_preset != 0);
    // Out-of-range is ignored by the manager and the transition stays
    // random, so no clamping is needed here — but the UI still asks for the
    // count rather than hardcoding it.
    projectm_set_transition_index(g_pm, g_transition_index);
}

/* ⚠️ Le tirage doit être SEMÉ, et là où le semis se faisait il ne se faisait
 * presque jamais: il vivait dans la branche « première activation de la
 * session » de rewamp_projectm_init, or Dart POUSSE sa liste au démarrage
 * (PresetManager restaure la source et le dernier preset), donc
 * _playlist_swap_if_pending() rendait vrai et la branche était sautée. L'état
 * restait la constante de compilation: à CHAQUE lancement, la même suite de
 * presets, dans le même ordre — « je vois toujours les mêmes » (signalé le
 * 2026-09-14; vérifié en rejouant le xorshift à la main sur le pack de
 * l'utilisateur, 278 presets: les huit premiers tirages sont identiques d'un
 * lancement à l'autre).
 *
 * Le semis est donc PARESSEUX, au premier tirage, quel que soit le chemin qui
 * l'atteint. `time()` ne donne qu'une seconde de résolution — deux lancements
 * dans la même seconde repartiraient pareil —, d'où l'adresse d'une variable
 * de pile en second terme: l'ASLR la déplace à chaque lancement. */
static void _rng_seed_once(void) {
    if (g_rng_seeded) return;
    g_rng_seeded = true;
    unsigned mark = 0;
    g_rng ^= ((unsigned)time(nullptr) | 1u);
    g_rng ^= (unsigned)(uintptr_t)&mark;
    g_rng ^= (unsigned)(uintptr_t)&g_rng >> 3;
    if (g_rng == 0) g_rng = 0x9E3779B9u;   /* xorshift meurt sur zéro */
}

static unsigned _rng_next(void) {
    _rng_seed_once();
    g_rng ^= g_rng << 13; g_rng ^= g_rng >> 17; g_rng ^= g_rng << 5;
    return g_rng;
}

static std::vector<std::string> _scan_presets(const std::string& dir) {
    std::vector<std::string> out;
    DIR* d = opendir(dir.c_str());
    if (!d) return out;
    struct dirent* e;
    while ((e = readdir(d)) != nullptr) {
        const char* n = e->d_name;
        size_t l = strlen(n);
        // plain .milk only (assets are pre-gunzipped at bundle time)
        if (l > 5 && strcasecmp(n + l - 5, ".milk") == 0)
            out.push_back(dir + "/" + n);
    }
    closedir(d);
    return out;
}

static std::string _default_preset_dir(void) {
    const char* dd = rewamp_get_data_dir();
    std::string base = (dd && dd[0]) ? std::string(dd) : std::string(".");
    return base + "/projectm/presets";
}

// Every write to g_presets goes through here: the preload worker copies paths
// out of g_presets under g_pl_mtx, so the swap must hold the same lock (and
// cancel any in-flight request/result, which now targets the OLD list).
static void _adopt_presets(std::vector<std::string>&& list);   // defined with the preload code

// Texture search paths: Dart-pushed dirs (pack texture bundles), else the
// bundled default. GL-adjacent (the core may purge/reload textures) → called
// only from init/render with the context current.
static void _apply_texture_dirs(void) {
    if (!g_pm) return;
    pthread_mutex_lock(&g_texdirs_mtx);
    std::vector<std::string> dirs = g_tex_dirs;
    pthread_mutex_unlock(&g_texdirs_mtx);
    if (dirs.empty()) {
        const char* dd = rewamp_get_data_dir();
        std::string base = (dd && dd[0]) ? std::string(dd) : std::string(".");
        dirs.push_back(base + "/projectm/textures");
    }
    std::vector<const char*> ptrs;
    ptrs.reserve(dirs.size());
    for (const auto& s : dirs) ptrs.push_back(s.c_str());
    projectm_set_texture_search_paths(g_pm, ptrs.data(), ptrs.size());
}

// Does the preset read the MilkDrop3 "mouse" uniform? Read off the file rather
// than asked of the library: the shaders live in two separate strings inside
// libprojectM with no accessor, and a preset is a few tens of kB parsed only on
// a preset change. Whole-word match so "mousewheel" or a filename does not
// count; comments do, which at worst lights the badge on a preset that only
// mentions it.
static std::atomic<int> g_preset_uses_mouse{0};

static bool _file_mentions_mouse(const std::string& path) {
    FILE* f = fopen(path.c_str(), "rb");
    if (!f) return false;
    std::string text;
    char buf[8192];
    size_t got;
    while ((got = fread(buf, 1, sizeof(buf), f)) > 0) {
        text.append(buf, got);
        if (text.size() > (1u << 20)) break;   // 1 MB is far past any preset
    }
    fclose(f);

    const std::string needle = "mouse";
    for (size_t at = text.find(needle); at != std::string::npos;
         at = text.find(needle, at + 1)) {
        const char before = (at == 0) ? ' ' : text[at - 1];
        const size_t end = at + needle.length();
        const char after = (end >= text.size()) ? ' ' : text[end];
        auto part = [](char c) {
            return isalnum(static_cast<unsigned char>(c)) != 0 || c == '_';
        };
        if (!part(before) && !part(after)) return true;
        // "mouse_x", "mouse_pos", "mouse_clicked" are the documented spellings.
        if (!part(before) && after == '_') return true;
    }
    return false;
}

static void _update_preset_name(void) {
    if (g_presets.empty() || g_preset_idx >= g_presets.size()) {
        g_preset_name[0] = '\0';
        g_preset_path[0] = '\0';
    } else {
        snprintf(g_preset_path, sizeof(g_preset_path), "%s",
                 g_presets[g_preset_idx].c_str());
        const std::string& path = g_presets[g_preset_idx];
        size_t slash = path.find_last_of('/');
        size_t start = (slash == std::string::npos) ? 0 : slash + 1;
        size_t dot = path.rfind(".milk");
        size_t len = (dot != std::string::npos && dot > start) ? dot - start
                                                               : path.size() - start;
        if (len >= sizeof(g_preset_name)) len = sizeof(g_preset_name) - 1;
        memcpy(g_preset_name, path.c_str() + start, len);
        g_preset_name[len] = '\0';
        g_preset_uses_mouse.store(_file_mentions_mouse(path) ? 1 : 0,
                                  std::memory_order_relaxed);
    }
    g_preset_serial++;
}

// Spawns the sprite blocks of `path`. Called right AFTER the preset was loaded, which is
// what puts the sprites in the right hands: libprojectM empties the slot that load landed
// in (the incoming preset during a soft cut, the current one on a hard cut) and the sprites
// spawned here belong to it. Destroying every sprite here, which is what this did, killed
// the sprite of the preset still on screen on the first frame of the transition and put the
// incoming one up at full strength - the only hard edge in an otherwise smooth blend.
// Render thread only: projectm_sprite_create compiles code and uploads a texture, i.e. GL
// work, and an EGLContext is current to one thread.
static void _sprites_apply(const std::string& path) {
    if (!g_pm) return;
    auto blocks = _spr_parse_file(path);
    if (blocks.empty()) return;
    int spawned = 0;
    for (const auto& b : blocks) {
        const std::string section = _spr_build_section(b, g_w, g_h);
        if (projectm_sprite_create(g_pm, "milkdrop", section.c_str()) != 0) spawned++;
    }
    PM_PROF("sprites: %d/%zu créés pour '%s'", spawned, blocks.size(), path.c_str());
}

// ── Garde-fou « appareil trop lent » ────────────────────────────────────────
//
// Un preset Milkdrop peut être arbitrairement coûteux (boucles de shader,
// maillage fin, plusieurs passes), et sur un appareil modeste il descend à
// quelques images par seconde — l'app paraît alors gelée alors qu'elle rend.
//
// ⚠️ On mesure la PÉRIODE de la boucle de rendu — l'écart entre deux entrées
// de cette fonction — et surtout PAS la durée de l'appel de rendu. GL est
// ASYNCHRONE: `projectm_opengl_render_frame_fbo` ne fait que soumettre des
// commandes et rend la main tout de suite, le coût réel n'apparaissant qu'au
// `eglSwapBuffers`/fence, plus loin. Sur un preset GPU-bound — le cas typique
// d'un appareil qui rame, constaté sur Android — la durée de l'appel restait
// donc petite et le garde-fou ne voyait rien passer, pendant que l'écran
// affichait moins de 5 images/s. La période, elle, comprend tout: soumission,
// échange de tampons, attente du GPU, et le reste de la boucle.
//
// La mesure ne se remet PAS à zéro au changement de preset: un preset peut
// être réglé pour tourner toutes les secondes (hardcut), si bien qu'un
// compteur remis à zéro à chaque chargement n'atteignait JAMAIS sa fenêtre —
// l'appareil ramait sans que rien ne se déclenche. La santé est une propriété
// de la SESSION: ce qui l'efface, c'est du rendu RAPIDE, pas un preset neuf.
//
// Le seuil est à 6 images/s, pas 5: en dessous de ça le visualiseur ne montre
// plus un mouvement mais une suite d'images fixes, et l'app entière paraît
// collée — inutile d'attendre que ce soit franchement pire pour agir.
//
// Verdict quand le temps de frame cumulé au-delà de kSlowFrameNs atteint
// kSlowWindowNs
// sur au moins deux frames. (Le raccourci « UNE frame > kAwfulNs suffit » a été
// retiré: un intervalle isolé a trop de causes étrangères au preset — voir la
// note dans _watch_tick.) À 5 fps soutenus le verdict tombe en ~0,6 s, à 3 fps en
// deux frames. Ce qui remet à zéro, c'est kHealthyNs de rendu rapide accumulé:
// « au-dessus de 6 fps depuis plus d'une seconde, c'est bon », même si les
// presets défilent entre-temps.
//
// Deux précautions contre les faux positifs, chacune pour un cas réel:
//   * la frame qui contient un CHARGEMENT est ignorée, ainsi que la suivante:
//     un auto-switch du cœur charge le preset À L'INTÉRIEUR de render_frame et
//     la compilation des shaders coûte jusqu'à ~950 ms — ce n'est pas la
//     cadence en régime, et c'est le faux positif le plus probable;
//   * une durée absurde (> kGapNs) n'est pas un rendu lent mais un TROU: le
//     fil a été suspendu (arrière-plan, appareil endormi).
static const long long kSlowFrameNs  = 166000000LL;   // > 166 ms = sous 6 fps
static const long long kSlowWindowNs =  600000000LL;  // 0,6 s de rendu lent
static const long long kHealthyNs    = 1000000000LL;  // 1 s de rendu rapide
static const long long kGapNs        = 5000000000LL;  // au-delà: un trou
static long long g_watch_slow_ns    = 0;
static long long g_watch_healthy_ns = 0;
static int       g_watch_slow_frames = 0;
static int       g_watch_skip        = 0;   // frames à ignorer après un chargement
static int       g_watch_loaded      = 0;   // un chargement a eu lieu dans CETTE frame
static std::atomic<int> g_watch_verdict{0};

/* Une frame vient de s'écouler en renderNs. Appelé à l'ENTRÉE de la boucle de
 * rendu: la période mesurée là couvre le travail de la frame PRÉCÉDENTE. */
static void _watch_tick(long long renderNs) {
    // La frame qui a chargé un preset, et la suivante (compilation différée par
    // le pilote), ne disent rien de la cadence en régime. Le drapeau est posé
    // PENDANT la frame fautive et lu ici, au tour d'après, parce que c'est ce
    // tour-là qui en mesure la durée.
    if (g_watch_loaded) { g_watch_loaded = 0; g_watch_skip = 1; return; }
    if (g_watch_skip > 0) { --g_watch_skip; return; }
    if (renderNs > kGapNs) return;                 // un trou, pas une mesure

    if (renderNs <= kSlowFrameNs) {
        g_watch_healthy_ns += renderNs > 0 ? renderNs : 1;
        if (g_watch_healthy_ns >= kHealthyNs) {
            g_watch_healthy_ns  = 0;
            g_watch_slow_ns     = 0;
            g_watch_slow_frames = 0;
        }
        return;
    }
    g_watch_healthy_ns = 0;
    g_watch_slow_ns   += renderNs;
    g_watch_slow_frames++;
    // ⚠️ Une frame affreuse ISOLÉE ne suffit plus, il en faut DEUX d'affilée
    // (lentes, pas forcément affreuses). Un intervalle unique de 0,8 à 5 s a
    // trop de causes qui ne sont pas le preset: fenêtre occultée, mini lecteur
    // (la coquille est hors scène, son ticker coupé), changement d'espace de
    // travail — le ticker Flutter s'arrête sans que rewamp_viz_idle le sache.
    // Un appareil VRAIMENT à 1 image/s enchaîne les frames lentes: il est pris
    // une frame plus tard, et un trou isolé est effacé par la seconde de rendu
    // sain qui suit.
    if (g_watch_slow_ns >= kSlowWindowNs && g_watch_slow_frames >= 2) {
        g_watch_slow_ns     = 0;
        g_watch_slow_frames = 0;
        g_watch_skip        = 2;   // laisse au client le temps d'agir
        g_watch_verdict.store(1);
    }
}

/* Le verdict, CONSOMMÉ: rendre et remettre à zéro en un seul appel, pour qu'un
 * client qui interroge périodiquement ne traite jamais deux fois le même. */
extern "C" REWAMP_EXPORT int rewamp_projectm_take_slow_verdict(void) {
    return g_watch_verdict.exchange(0);
}

static void _load_current(bool smooth) {
    if (g_presets.empty() || !g_pm) return;
    if (g_preset_idx >= g_presets.size()) g_preset_idx = 0;

    mdzGlCompileNs = mdzGlLinkNs = 0;
    mdzGlProgramCount = 0;
    long long t0 = _prof_now_ns();
    projectm_load_preset_file(g_pm, g_presets[g_preset_idx].c_str(), smooth);
    long long totalNs = _prof_now_ns() - t0;

    long long glNs  = mdzGlCompileNs + mdzGlLinkNs;
    long long cpuNs = totalNs - glNs;          // parse + HLSL→GLSL + eval compiles
    if (cpuNs < 0) cpuNs = 0;
    PM_PROF("load '%s': total %.1f ms | CPU %.1f ms | GL %.1f ms "
            "(compile %.1f + link %.1f, %d programs) | smooth=%d",
            g_presets[g_preset_idx].c_str(),
            totalNs / 1e6, cpuNs / 1e6, glNs / 1e6,
            mdzGlCompileNs / 1e6, mdzGlLinkNs / 1e6, mdzGlProgramCount,
            smooth ? 1 : 0);
    g_prof_frames_after_load = 5;   // catch driver-deferred compile at first draws

    _sprites_apply(g_presets[g_preset_idx]);
    g_pm_preset_loaded = true;
    _update_preset_name();
    // Le garde-fou ne repart PAS à zéro ici (voir sa note): un preset réglé
    // pour tourner toutes les secondes ferait alors taire la mesure. On marque
    // seulement la frame comme non représentative — le chargement s'est produit
    // DANS elle quand c'est le cœur qui a changé de preset tout seul.
    g_watch_loaded = 1;
}

static void _on_switch_requested(bool is_hard_cut, void* user); // defined below
static void _preload_start(void);        // defined with the preload worker below
static void _preload_stop(void);
static void _pick_next_and_preload(void);
static void _preload_kick_tick(void);
static void _warm_transitions(void); // defined with the PSO warm code below
static void _warm_rt_forget(void);   // idem — drops handles after a context rebuild
static bool _playlist_swap_if_pending(void);   // defined with the navigation code
// App went background → foreground (iOS): restart the preload worker on the
// NEXT render tick, on the render thread. See rewamp_projectm_set_active.
static std::atomic<bool> g_pl_restart_pending{false};

extern "C" REWAMP_EXPORT int rewamp_projectm_init(int width, int height) {
    // A current GL context must exist before anything else: projectm_create()
    // calls glGetString/SOIL during TextureManager::Preload and segfaults
    // without one.
    //
    // But rewamp_gl_init() BUILDS A NEW context every time (eglGetDisplay +
    // eglInitialize + create context/surface), and the context now survives a
    // visualizer switch. Calling it unguarded here destroyed the live one and
    // orphaned every GL object hanging off it — the artwork texture and the
    // other renderers' programs — which is exactly what was seen: projectM shows
    // the previous visualizer's last frame, and the artwork is gone when you
    // switch back. Only create when there is nothing to reuse (same guard as the
    // other three renderers).
    {
        int glErr = rewamp_gl_ensure(width, height);
        if (glErr != 0) return glErr;
    }

    // If the context was REBUILT (ours was lost — background, memory pressure,
    // GPU reset), projectM's entire GL world went with it: every shader, texture
    // and buffer inside the instance is now a dangling handle. It cannot be
    // salvaged, so drop the instance and build a fresh one. The preset history
    // and index are session state and survive (see rewamp_projectm_uninit).
    if (g_pm && g_pm_gl_gen != rewamp_gl_generation()) {
        _preload_stop();   // worker dereferences g_pm — must be gone first
        projectm_destroy(g_pm);
        g_pm = nullptr;
        g_pm_preset_loaded = false;
        // Our own render target went with the context too. Forget the handles
        // WITHOUT deleting them — the objects are already gone, and _ensure_pm_
        // target() would otherwise reuse a stale-but-non-zero FBO id because the
        // dimensions still match.
        g_pmFbo = g_pmTex = g_pmDepth = 0;
        g_pmW = g_pmH = 0;
        // Same for the render-context warm objects: gone with the context, so
        // forget the handles rather than delete or (worse) reuse them.
        _warm_rt_forget();
    }
    mdzMainThreadId = pthread_self();
    g_w = width; g_h = height;

    if (!g_pm) {
        g_pm = projectm_create();
        if (!g_pm) return -1;
        g_pm_gl_gen = rewamp_gl_generation();   // built on THIS context
        // The instance's transition shaders exist as of now; give them their
        // Metal pipeline states before anything can fade.
        _warm_transitions();
    }
    projectm_set_window_size(g_pm, width >> g_quality_shift, height >> g_quality_shift);
    projectm_set_preset_switch_requested_event_callback(g_pm, _on_switch_requested, nullptr);
    _apply_params();

    _apply_texture_dirs();
    g_texdirs_dirty.store(false);

    // A source pushed from Dart (preset pack / playlist) — possibly while the
    // viz was off — takes precedence; it picks its own starting preset. Else:
    // first activation of the session scans the default dir and picks one.
    // Re-activation (viz toggled back on) keeps the accumulated history and
    // the current preset index untouched, resuming exactly where it left off.
    if (!_playlist_swap_if_pending()) {
        if (!g_session_active) {
            _adopt_presets(_scan_presets(_default_preset_dir()));
            g_history.clear();
            /* (le semis du tirage est PARESSEUX — _rng_seed_once; il vivait
             * ici, où il ne s'exécutait presque jamais.) */
            g_preset_idx = (g_random_mode && g_presets.size() > 1)
                               ? (size_t)(_rng_next() % g_presets.size())
                               : 0;
            g_session_active = true;
        } else if (g_presets.empty()) {
            _adopt_presets(_scan_presets(_default_preset_dir()));  // defensive
        }
    }
    // Only when the live instance has nothing loaded — i.e. we just created it
    // (first activation, or coming back after leaving the visualizer, which
    // destroys g_pm). On a mere visualizer SWITCH both the GL context and g_pm
    // survive, so the preset is still loaded and still on screen: reloading it
    // would re-parse the milk, re-transpile HLSL→GLSL and recompile the shaders
    // for nothing — the single most expensive thing this file does.
    if (!g_pm_preset_loaded) _load_current(false);
    _preload_start();            // preload ctx + worker (no-op if unsupported)
    _pick_next_and_preload();    // start precompiling the predicted next preset
    return 0;
}

static void _apply_pending_preset(void);   // fwd: defined with next/prev below

extern "C" REWAMP_EXPORT void rewamp_projectm_render(void) {
    if (!g_pm) return;
    rewamp_gl_make_current();

    // Cadence: la période depuis l'entrée précédente. Prise ICI, en tête, elle
    // englobe TOUT le travail de la frame d'avant, y compris l'échange de
    // tampons — c'est-à-dire l'endroit où un preset GPU-bound se paie
    // réellement (voir la note du garde-fou).
    {
        static long long lastEntryNs = 0;
        const long long now = _prof_now_ns();
        // ⚠️ Un intervalle qui enjambe un SOMMEIL du viz (lecteur en pause, voir
        // rewamp_viz_idle) n'est pas une frame lente: la boucle n'a simplement
        // pas été appelée. Lu SANS condition pour que le drapeau soit consommé
        // même au tout premier passage.
        const int sleptThrough = rewamp_viz_take_idle_gap();
        if (lastEntryNs != 0 && !sleptThrough) _watch_tick(now - lastEntryNs);
        lastEntryNs = now;
    }

    // Back from the background: the preload worker was stopped (its GPU work
    // is forbidden there and poisons the ANGLE/Metal state — every later
    // switch then paid a synchronous compile, the "slight freeze after
    // resume"). Restart it HERE, on the render thread, like init does.
    if (g_pl_restart_pending.exchange(false)) {
        _preload_start();
        _pick_next_and_preload();
    }

    // GL context is current now — safe to compile the shaders of a preset the
    // UI asked for. Source swap first: it drops any queued manual steps, which
    // indexed the OLD list.
    if (g_texdirs_dirty.exchange(false)) _apply_texture_dirs();
    _playlist_swap_if_pending();
    _apply_pending_preset();
    _preload_kick_tick();   // deferred worker kick — see _pick_next_and_preload

    // Track the live GL/IOSurface size (it changes when the window resizes or the
    // viz goes fullscreen) and hand it to projectM, else it keeps rendering at the
    // stale init resolution (stretched / clipped).
    int cw = rewamp_gl_width(), ch = rewamp_gl_height();
    if (cw > 0 && ch > 0 && (cw != g_w || ch != g_h)) {
        g_w = cw; g_h = ch;
        projectm_set_window_size(g_pm, cw >> g_quality_shift, ch >> g_quality_shift);
    }
    int rw = g_w >> g_quality_shift, rh = g_h >> g_quality_shift;
    if (rw < 16) rw = 16;
    if (rh < 16) rh = 16;
    if (_ensure_pm_target(rw, rh) != 0) return;

    // Feed the real stereo PCM tap as int16 for beat detection.
    //
    // Nothing playing means SILENCE, not "the last window we happened to have".
    // The producer stops, so the waveform ring freezes with the final, full
    // amplitude window still in it, and the smoothed read head clamps onto that
    // frozen position - we then hand projectM a loud CONSTANT signal, which is
    // indistinguishable from loud constant music. Presets that integrate their
    // audio ("j1 = j1*0.95 + sqr(bass*4)*v" then "n = n + j1*0.0052") therefore
    // kept drifting for ever with the music stopped, where MilkDrop and Milkwave
    // sit still. Measured with scripts/projectm/pm_eval_trace on
    // "suksma - penattrition": q3 walks 0.1255 -> 0.1123 -> 0.0994 per frame at
    // bass=1, and is pinned at 0.0201 at bass=0. Time-driven motion is
    // unaffected, which is exactly the residual movement those players show.
    // "Is there NEW audio" is asked of the ring itself, not of a playback-state
    // predicate: rewamp_is_playing() reports the miniaudio sound object, which
    // can still read as playing while nothing is being produced (the end-of-queue
    // trap this repo already paid on iOS). The write head is unambiguous - it
    // only moves when the producer wrote samples. A tolerance is needed because
    // the render thread can outrun the audio callback: at 120 Hz render against
    // a 20 ms callback the head is legitimately unchanged for several frames,
    // and injecting silence there would punch holes in the beat detection.
    static float     L[512], R[512];
    static int16_t   pcm[512 * 2];
    static int64_t   lastWavePos  = -1;
    static long long lastAdvanceNs = 0;
    const int64_t    wavePos = rewamp_waveform_pos();
    const long long  nowNs   = _prof_now_ns();
    if (wavePos != lastWavePos) {
        lastWavePos   = wavePos;
        lastAdvanceNs = nowNs;
    }
    const bool audioIsLive = (lastAdvanceNs != 0) &&
                             (nowNs - lastAdvanceNs) < 250000000LL;   // 250 ms
    if (audioIsLive) {
        rewamp_get_waveform(L, R, 512);
        for (int i = 0; i < 512; ++i) {
            float l = L[i], r = R[i];
            if (l >  1.f) l =  1.f; else if (l < -1.f) l = -1.f;
            if (r >  1.f) r =  1.f; else if (r < -1.f) r = -1.f;
            pcm[i * 2]     = (int16_t)(l * 32767.f);
            pcm[i * 2 + 1] = (int16_t)(r * 32767.f);
        }
    } else {
        memset(pcm, 0, sizeof(pcm));
    }
    projectm_pcm_add_int16(g_pm, pcm, 512, PROJECTM_STEREO);

    long long ft0 = _prof_now_ns();
    mdzRenderInProgress = true;
    projectm_opengl_render_frame_fbo(g_pm, g_pmFbo);
    mdzRenderInProgress = false;
    if (g_prof_frames_after_load > 0) {
        // NOTE: an auto-switch (the core's hardcut/duration callback) fires
        // INSIDE render_frame above, so its whole load is included in this
        // frame's time — the separate "load" line still gives the split.
        PM_PROF("frame after load (-%d): %.1f ms",
                6 - g_prof_frames_after_load, (_prof_now_ns() - ft0) / 1e6);
        g_prof_frames_after_load--;
    }

    // Copy the private target into the destination framebuffer (upscaling when
    // quality < Max), flipping Y only where the destination actually needs it.
    //
    // The split is NOT Apple-vs-Android: it is macOS vs (iOS + Android). The
    // macOS EGL/ANGLE migration left its FBO presenting upright, while the GLES
    // destinations (iOS's ANGLE texture, Android's EGL window surface) present
    // flipped — which is exactly the condition rewamp_viz_render.cpp's ART_UV_Y
    // already encodes for the artwork background, and the same reason it flips
    // its UVs there. This blit's unconditional flip was tuned for macOS, so
    // projectM came out upside-down on BOTH iOS and Android.
    glBindFramebuffer(GL_READ_FRAMEBUFFER, g_pmFbo);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, rewamp_gl_get_fbo());
#if defined(REWAMP_GL_GLES) && !(defined(__APPLE__) && TARGET_OS_OSX)
    glBlitFramebuffer(0, 0, g_pmW, g_pmH,
                      0, 0, g_w, g_h,           // iOS / Android: no flip
                      GL_COLOR_BUFFER_BIT, GL_LINEAR);
#else
    glBlitFramebuffer(0, 0, g_pmW, g_pmH,
                      0, g_h, g_w, 0,           // macOS / desktop GL: dst Y inverted
                      GL_COLOR_BUFFER_BIT, GL_LINEAR);
#endif

    // Force an OPAQUE frame: keep projectM's RGB, stamp alpha = 1 so Flutter
    // composites it over solid black (no artwork bleed-through).
    glBindFramebuffer(GL_FRAMEBUFFER, rewamp_gl_get_fbo());
    glDisable(GL_BLEND);
    glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_TRUE);
    glClearColor(0.f, 0.f, 0.f, 1.f);
    glClear(GL_COLOR_BUFFER_BIT);
    glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);

    rewamp_gl_flush();
}

extern "C" REWAMP_EXPORT void rewamp_projectm_uninit(void) {
    _preload_stop();   // worker dereferences g_pm — must be gone first
    if (g_pm) { projectm_destroy(g_pm); g_pm = nullptr; }
    g_pm_preset_loaded = false;   // a fresh instance will have nothing loaded
    _destroy_pm_target();
    g_w = g_h = 0;
    // Intentionally keep g_presets / g_history / g_preset_idx / g_session_active
    // so the preset history survives disabling & re-enabling the visualizer.
    // They are only reset when the process exits (statics destroyed).
}

// ── Background preset preload ─────────────────────────────────────────────────
//
// A preset load costs ~950 ms on a mid-range Android device, ~87% of it CPU
// (milk parse + HLSL→GLSL transpile + eval compiles) and the rest GL shader
// compile/link — all of which used to happen on the render thread, freezing the
// visualizer for that long on every switch (measured, see the pmprof lines).
//
// This reactivates the vendored fork's own preload design (Modizer's — the
// projectm_preload_preset_file / projectm_loadpreload_preset_file pair and the
// AltMilkdropPreset "preload://" factory path were already in the tree):
//
//   worker thread                          render thread
//   ─────────────                          ─────────────
//   preload ctx current (share group)      renders current preset
//   projectm_preload_preset_file(next)     …
//     = parse + transpile + glCompile/Link …
//   glFlush → publish {idx, warp, comp,     …
//                      seed}
//                                          switch requested →
//                                            projectm_loadpreload_preset_file
//                                            (re-parse .milk + eval only; both
//                                             HLSL transpile and GL compile are
//                                             skipped — the precompiled programs
//                                             are adopted via SetShadersCode)
//
// `seed` is an opaque token, not a value this file interprets: it identifies the
// preload job, and libprojectM keeps the randNN textures that job resolved AND
// warmed keyed on it. The seed alone would not do — the two sides scan
// different file lists, since the scan includes the current preset's directory
// and the worker must never switch it — so the names stay in-process and only
// this integer travels. Measured on three randNN presets: the apply drops from
// 7.6-44.8 ms (whatever file the render thread happened to draw) to a flat
// ~5.0 ms; the variance matters as much as the mean, the worst case being a
// dropped frame in the middle of a transition.
//
// The GL legality of this rests on the second EGL context in the same share
// group (see rewamp_gl.h): programs/shaders are share-group objects, FBOs/VAOs
// are not — and the preload path (AltMilkdropPreset) deliberately creates none.
// If the preload context can't be created, everything falls back to the old
// synchronous load. The target of a preload is always THE predicted next preset
// (g_next_idx, decided at load time so random mode predicts its own draw).
static pthread_t        g_pl_thread;
static bool             g_pl_thread_up = false;
static pthread_mutex_t  g_pl_mtx = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t   g_pl_cv  = PTHREAD_COND_INITIALIZER;
static bool             g_pl_quit = false;
static long             g_pl_req_idx  = -1;   // preload request (-1 = none)
static long             g_pl_done_idx = -1;   // published result (-1 = none)
static uint32_t         g_pl_warp = 0, g_pl_comp = 0;
// Opaque token tying the published result to the randNN textures that
// preload resolved AND warmed. libprojectM keeps the file names keyed on it;
// only this integer travels. 0 = none, in which case the render thread draws
// its own random textures, as before.
static uint64_t         g_pl_seed = 0;
static size_t           g_next_idx = 0;       // predicted next preset
static bool             g_pl_enabled = false; // preload ctx created OK

// ── Worker-side pipeline warm-up (iOS/ANGLE-Metal) ───────────────────────────
//
// On ANGLE's Metal backend, glLinkProgram builds the MTLLibrary but the actual
// MTLRenderPipelineState is created lazily AT FIRST DRAW (ProgramMtl::setupDraw
// → RenderPipelineCache miss → newRenderPipelineStateWithDescriptor), costing
// 30-120 ms on the render thread the first time each preset program is used —
// which is why iOS stuttered on preset switches even after the preload moved
// compile+link to the worker (Android GLES drivers do everything at link, so
// they never had this). The PSO cache lives on the Program object, which is
// share-group-wide: a draw from THIS context with the same pipeline descriptor
// (vertex layout + render-target format + blend state) pre-populates the cache
// the render thread will hit.
//
// Descriptor replication (from projectM's real draws): warp renders a Mesh with
// only attribute 0 enabled (vec2 position, tight stride 8, own VBO); composite
// renders with attributes 0 (vec2), 1 (vec4 color, stride 16) and 2 (vec2 UV),
// each in its own VBO. Both draw blend-OFF into an RGBA8 color-only FBO,
// no MSAA. Harmless on other platforms (one extra 4x4 draw per preload).
//
// The set exists TWICE, and that is not duplication for its own sake: only the
// Programs are share-group objects, FBOs and VAOs are per-context. A single
// global set would be created by whichever context ran first, and the other
// would then see non-zero ids, skip creation, and bind names that do not exist
// in it. One set for the preload worker, one for the render thread.
struct WarmSet {
    GLuint fbo = 0, tex = 0;
    // Second warm target in the OUTPUT surface's format. ANGLE's Metal pipeline
    // cache keys on the render target's pixel format too: the Apple output is a
    // BGRA IOSurface, so a PSO warmed against the RGBA FBO above is a MISS for
    // every program that draws into the output (composite, transitions) — those
    // PSOs were being rebuilt at first real draw on the render thread, ~50 ms a
    // frame right after each preset switch. 0 = BGRA unsupported (Android
    // GLES), where the window surface is RGBA anyway and the first FBO matches.
    GLuint fboBgra = 0, texBgra = 0;
    GLuint vaoWarp = 0, vaoComp = 0, vaoTrans = 0;
    GLuint vbo[3] = {0, 0, 0};
};
static WarmSet g_warm_pl;   // preload context, owned by the worker
static WarmSet g_warm_rt;   // render context

#ifndef GL_BGRA_EXT
#define GL_BGRA_EXT 0x80E1
#endif

static void _warm_objects_ensure(WarmSet& w) {
    if (w.fbo) return;
    glGenTextures(1, &w.tex);
    glBindTexture(GL_TEXTURE_2D, w.tex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 4, 4, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glGenFramebuffers(1, &w.fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, w.fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, w.tex, 0);

    // BGRA twin (EXT_texture_format_BGRA8888, unsized form). Kept only if the
    // driver accepts it as a complete color attachment.
    while (glGetError() != GL_NO_ERROR) {}
    glGenTextures(1, &w.texBgra);
    glBindTexture(GL_TEXTURE_2D, w.texBgra);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_BGRA_EXT, 4, 4, 0, GL_BGRA_EXT,
                 GL_UNSIGNED_BYTE, nullptr);
    glGenFramebuffers(1, &w.fboBgra);
    glBindFramebuffer(GL_FRAMEBUFFER, w.fboBgra);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D,
                           w.texBgra, 0);
    if (glGetError() != GL_NO_ERROR ||
        glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        glDeleteFramebuffers(1, &w.fboBgra); w.fboBgra = 0;
        glDeleteTextures(1, &w.texBgra);     w.texBgra = 0;
        PM_PROF("warm: no BGRA attachment on this driver — RGBA warm only");
    }
    glBindFramebuffer(GL_FRAMEBUFFER, w.fbo);

    static const float pos[6]  = {0, 0, 1, 0, 0, 1};
    static const float col[12] = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
    static const float uv[6]   = {0, 0, 1, 0, 0, 1};
    glGenBuffers(3, w.vbo);
    glBindBuffer(GL_ARRAY_BUFFER, w.vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(pos), pos, GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, w.vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(col), col, GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, w.vbo[2]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(uv), uv, GL_STATIC_DRAW);

    // Warp layout: position only.
    glGenVertexArrays(1, &w.vaoWarp);
    glBindVertexArray(w.vaoWarp);
    glBindBuffer(GL_ARRAY_BUFFER, w.vbo[0]);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), nullptr);
    glEnableVertexAttribArray(0);

    // Composite layout: position + color + UV (matches Mesh's fixed locations).
    glGenVertexArrays(1, &w.vaoComp);
    glBindVertexArray(w.vaoComp);
    glBindBuffer(GL_ARRAY_BUFFER, w.vbo[0]);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), nullptr);
    glEnableVertexAttribArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, w.vbo[1]);
    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, 4 * sizeof(float), nullptr);
    glEnableVertexAttribArray(1);
    glBindBuffer(GL_ARRAY_BUFFER, w.vbo[2]);
    glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), nullptr);
    glEnableVertexAttribArray(2);

    // Transition layout: position + UV, no color (PresetTransition's mesh is
    // Mesh(StaticDraw, useColor=false, useUV=true)). It draws a TriangleStrip,
    // but ANGLE's pipeline cache keys on the primitive-topology CLASS, so the
    // triangle warm draw below covers it.
    glGenVertexArrays(1, &w.vaoTrans);
    glBindVertexArray(w.vaoTrans);
    glBindBuffer(GL_ARRAY_BUFFER, w.vbo[0]);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), nullptr);
    glEnableVertexAttribArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, w.vbo[2]);
    glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), nullptr);
    glEnableVertexAttribArray(2);

    glBindVertexArray(0);
}

enum WarmLayout { WARM_WARP = 0, WARM_COMPOSITE, WARM_TRANSITION };

static void _warm_pipeline(WarmSet& w, uint32_t program, int layout) {
    if (!program) return;
    _warm_objects_ensure(w);
    glViewport(0, 0, 4, 4);
    glDisable(GL_BLEND);
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_SCISSOR_TEST);
    glDisable(GL_CULL_FACE);
    glUseProgram(program);
    glBindVertexArray(layout == WARM_COMPOSITE  ? w.vaoComp
                    : layout == WARM_TRANSITION ? w.vaoTrans
                                                : w.vaoWarp);
    // BOTH target formats: warp draws into projectM's internal RGBA FBOs,
    // composite/transitions into the BGRA output surface — and ANGLE keys the
    // PSO on the target format, so each needs its own warm draw. Which program
    // ends up where isn't worth tracking; a 4x4 draw is free.
    glBindFramebuffer(GL_FRAMEBUFFER, w.fbo);
    glDrawArrays(GL_TRIANGLES, 0, 3);   // PSO created + cached HERE (worker)
    if (w.fboBgra) {
        glBindFramebuffer(GL_FRAMEBUFFER, w.fboBgra);
        glDrawArrays(GL_TRIANGLES, 0, 3);
    }
    glBindVertexArray(0);
    glUseProgram(0);
}

// Warms the six built-in transition shaders' pipeline states, on the RENDER
// thread, right after the instance is created. They are already GL-compiled by
// then (TransitionShaderManager's constructor does all six, from
// ProjectM::Initialize), but on ANGLE/Metal the MTLRenderPipelineState is still
// built at the FIRST DRAW - which lands mid-fade, as a ~100 ms spike the first
// time each pattern is picked.
//
// Unconditional by design. This used to sit in the preload worker, and so was
// silently skipped whenever the preload context could not be created: no
// precompilation AND no warm, with nothing in the logs to tell the two apart.
// Six 4x4 draws cost nothing worth guarding.
// The render context was rebuilt: its warm objects died with it. Forget the
// handles WITHOUT deleting (the names are gone) so the next warm recreates them
// instead of binding stale ids.
static void _warm_rt_forget(void) { g_warm_rt = WarmSet{}; }

static void _warm_transitions(void) {
    if (!g_pm) return;
    // Sized well above the count, and the clamp reads from the array itself:
    // the wrapper returns the REAL number of transitions while filling only
    // `max` entries, so a buffer smaller than the list silently leaves the tail
    // un-warmed. It did — the list grew from 6 to 23 while this stayed at 16,
    // and the last 7 patterns paid their pipeline build mid-fade.
    uint32_t programs[64];
    const int capacity = (int)(sizeof(programs) / sizeof(programs[0]));
    int count = projectm_get_transition_shader_programs(g_pm, programs, capacity);
    if (count > capacity) count = capacity;
    long long t0 = _prof_now_ns();
    for (int i = 0; i < count; i++) _warm_pipeline(g_warm_rt, programs[i], WARM_TRANSITION);
    PM_PROF("warmed %d transition shaders: %.1f ms (render thread)",
            count, (_prof_now_ns() - t0) / 1e6);
}

static void* _preload_thread_main(void*) {
    if (rewamp_gl_preload_make_current() != 0) {
        PM_PROF("preload worker: make_current failed — worker exiting");
        return nullptr;
    }
    pthread_mutex_lock(&g_pl_mtx);
    while (!g_pl_quit) {
        if (g_pl_req_idx < 0) {
            pthread_cond_wait(&g_pl_cv, &g_pl_mtx);
            continue;
        }
        long idx = g_pl_req_idx;
        // Copy the path while still holding the mutex: a playlist swap (render
        // thread) mutates g_presets under this same lock, so reading it after
        // the unlock would race — the string could be freed mid-compile.
        std::string path = g_presets[(size_t)idx];
        pthread_mutex_unlock(&g_pl_mtx);

        uint32_t warp = 0, comp = 0;
        uint64_t seed = 0;
        long long t0 = _prof_now_ns();
        projectm_preload_preset_file(g_pm, path.c_str(), &warp, &comp, &seed);
        // Pre-create the Metal pipeline states too (no-op cost elsewhere): the
        // PSO cache is per-Program and Programs are share-group objects, so
        // these land exactly where the render thread will look.
        long long tW = _prof_now_ns();
        _warm_pipeline(g_warm_pl, warp, WARM_WARP);
        _warm_pipeline(g_warm_pl, comp, WARM_COMPOSITE);
        // Sprite images, warmed HERE rather than at switch time. Creating a
        // sprite on the render thread costs 16 ms for a PNG and 22 ms for a
        // colour-keyed JPEG (measured), nearly all of it decode + upload, and a
        // preset can carry four. Textures are share-group objects, so the one
        // loaded on this context is the object projectm_sprite_create finds
        // cached a moment later. The shader preload above deliberately does NOT
        // do this for preset textures (its descriptors are dummies), so sprites
        // would otherwise be the only thing still decoding mid-switch.
        for (const auto& b : _spr_parse_file(path)) {
            projectm_preload_texture(g_pm, b.img.c_str(),
                                     (int)(b.colorKey < 0 ? -1 : b.colorKey));
        }
        // (The transition shaders are warmed on the render thread, right after
        // the instance is created — see _warm_transitions. They used to be
        // warmed here, which made them hostage to the worker starting at all:
        // when the preload context cannot be created the worker never runs, and
        // then NOTHING warmed them, so the first transition of each pattern
        // built its pipeline state mid-fade on the render thread. Six 4x4 draws
        // are cheap enough to be unconditional.)
        long long warmNs = _prof_now_ns() - tW;
        // Make the freshly linked programs + pipelines visible to the render
        // context: share-group updates require a flush on the producing side.
        glFlush();
        PM_PROF("preload[%ld] '%s': %.1f ms (worker, PSO warm %.1f ms) warp=%u comp=%u",
                idx, path.c_str(),
                (_prof_now_ns() - t0) / 1e6, warmNs / 1e6, warp, comp);

        pthread_mutex_lock(&g_pl_mtx);
        if (g_pl_req_idx == idx) {
            // Still wanted → publish.
            g_pl_req_idx  = -1;
            g_pl_done_idx = idx;
            g_pl_warp = warp;
            g_pl_comp = comp;
            g_pl_seed = seed;
        } else {
            // A newer request (or a reset) superseded this one → discard. We
            // hold the preload context, so deleting here is safe.
            if (warp) glDeleteProgram(warp);
            if (comp) glDeleteProgram(comp);
        }
    }
    pthread_mutex_unlock(&g_pl_mtx);
    // The warm objects live in the preload context, which dies with the
    // worker: forget the handles (no glDelete — context going away) so a
    // restarted worker recreates them instead of binding stale ids.
    g_warm_pl = WarmSet{};
    rewamp_gl_preload_release();
    return nullptr;
}

// Discard a published-but-unconsumed result (render thread, mutex held by
// caller). Programs are share-group objects → deletable from this context too.
static void _pl_drop_result_locked(void) {
    if (g_pl_done_idx >= 0) {
        if (g_pl_warp) glDeleteProgram(g_pl_warp);
        if (g_pl_comp) glDeleteProgram(g_pl_comp);
        g_pl_done_idx = -1;
        g_pl_warp = g_pl_comp = 0;
        g_pl_seed = 0;
    }
}

// Decide the next preset (the ONE prediction preloads aim at) and ARM the
// worker kick. Render thread, after every successful load.
//
// The kick is deferred by a TOKEN 6 frames — just enough to keep the worker's
// startup out of the apply frame itself. It was 90 frames once (to move the
// ANGLE share-lock stalls away from the cut), but KHR_parallel_shader_compile
// killed those stalls, and the long deferral created a STARVATION mode: every
// switch re-arms the countdown, so with short preset durations and a frame
// rate low enough that 90 frames outlast a preset, the kick never fired and
// every switch fell back to the synchronous load — which itself kept the
// frame rate low. Frame-counted deferrals must stay far below a preset's
// lifetime. The prediction itself must NOT wait: _advance_preset consumes
// g_next_idx even when the user skips before the kick fired.
static int g_pl_kick_countdown = -1;   // frames until the worker kick; -1 idle

// The single writer of g_presets (see the decl comment). Cancels the in-flight
// preload request and drops an unconsumed result: both target the OLD list.
// Caller must have the GL context current (the drop deletes programs).
static void _adopt_presets(std::vector<std::string>&& list) {
    pthread_mutex_lock(&g_pl_mtx);
    g_pl_req_idx = -1;
    _pl_drop_result_locked();
    g_presets = std::move(list);
    pthread_mutex_unlock(&g_pl_mtx);
    g_pl_kick_countdown = -1;   // an armed kick predicted an old-list index
}

/* Le preset `idx` a-t-il été vu dans les `window` derniers ? g_history porte
 * déjà les index visités (c'est le « précédent » du navigateur), il suffit
 * d'en regarder la queue. */
static bool _recently_shown(size_t idx, size_t window) {
    size_t n = g_history.size();
    if (window > n) window = n;
    for (size_t k = 0; k < window; k++)
        if (g_history[n - 1 - k] == idx) return true;
    return false;
}

static void _pick_next_and_preload(void) {
    if (g_presets.empty()) return;
    size_t next = g_preset_idx;
    if (g_random_mode && g_presets.size() > 1) {
        /* Un tirage uniforme n'est pas ce qu'un auditeur appelle « aléatoire »:
         * sur 278 presets il en ramène un déjà vu toutes les vingtaines de
         * changements, et la garde d'origine n'excluait QUE le preset courant.
         * On écarte donc aussi les derniers vus — un quart de la liste, plafonné
         * à 32 pour qu'une longue liste ne coûte pas une recherche linéaire
         * démesurée, et borné à n-1 pour qu'il reste toujours un candidat.
         * Tirage borné en essais: si la fenêtre est saturée (liste courte, ou
         * historique qui vient d'être vidé), on prend ce qui vient. */
        const size_t n = g_presets.size();
        size_t window = n / 4;
        if (window > 32) window = 32;
        if (window + 1 >= n) window = n - 1;
        for (int tries = 0; tries < 64; tries++) {
            next = (size_t)(_rng_next() % n);
            if (next != g_preset_idx && !_recently_shown(next, window)) break;
        }
        if (next == g_preset_idx) next = (g_preset_idx + 1) % n;
    } else {
        next = (g_preset_idx + 1) % g_presets.size();
    }
    g_next_idx = next;
    PM_PROF("arm kick: next=%zu enabled=%d", next, (int)g_pl_enabled);
    if (!g_pl_enabled) return;
    g_pl_kick_countdown = 6;
}

// Called once per rendered frame; fires the armed kick when due.
static void _preload_kick_tick(void) {
    if (g_pl_kick_countdown < 0) return;
    if (--g_pl_kick_countdown >= 0) return;
    g_pl_kick_countdown = -1;
    PM_PROF("kick fired: req=%zu enabled=%d", g_next_idx, (int)g_pl_enabled);
    if (!g_pl_enabled) return;
    pthread_mutex_lock(&g_pl_mtx);
    _pl_drop_result_locked();
    g_pl_req_idx = (long)g_next_idx;
    pthread_cond_signal(&g_pl_cv);
    pthread_mutex_unlock(&g_pl_mtx);
}

// Lifecycle. start() is idempotent and called from the render thread with the
// main context current (the shared context creation needs it alive). stop()
// joins the worker; called from uninit before projectm_destroy.
static void _preload_start(void) {
    if (g_pl_thread_up) return;
    if (rewamp_gl_preload_context_create() != 0) {
        PM_PROF("preload: no shared context on this platform — synchronous loads");
        g_pl_enabled = false;
        return;
    }
    g_pl_quit = false;
    g_pl_req_idx = g_pl_done_idx = -1;
    if (pthread_create(&g_pl_thread, nullptr, _preload_thread_main, nullptr) != 0) {
        g_pl_enabled = false;
        return;
    }
    g_pl_thread_up = true;
    g_pl_enabled = true;
    PM_PROF("preload worker up");
}

static void _preload_stop(void) {
    if (!g_pl_thread_up) return;
    pthread_mutex_lock(&g_pl_mtx);
    g_pl_quit = true;
    g_pl_req_idx = -1;
    _pl_drop_result_locked();   // render ctx is current here — deletion is fine
    pthread_cond_signal(&g_pl_cv);
    pthread_mutex_unlock(&g_pl_mtx);
    pthread_join(g_pl_thread, nullptr);
    g_pl_thread_up = false;
    g_pl_enabled = false;
}

// Preset navigation. Next = the predicted g_next_idx (which the worker has
// been precompiling); prev = real back through the history stack.
static void _advance_preset(bool smooth) {
    if (g_presets.empty() || !g_pm) return;
    g_history.push_back(g_preset_idx);
    if (g_history.size() > 256) g_history.erase(g_history.begin());
    g_preset_idx = g_next_idx;

    // Fast path: the worker finished precompiling exactly this preset.
    if (g_pl_enabled) {
        pthread_mutex_lock(&g_pl_mtx);
        PM_PROF("advance: wanted=%zu done=%ld warp=%u comp=%u req=%ld",
                g_preset_idx, g_pl_done_idx, g_pl_warp, g_pl_comp, g_pl_req_idx);
        // The test is "did the worker finish THIS index", NOT "did it produce
        // two programs". A zero program name is a legitimate result: it means
        // the preset has no shader of that kind, and MilkdropShader reads 0 as
        // "nothing precompiled, compile normally" (TranspileHLSLShader's
        // `if (shaderP==0)`). Demanding both non-zero locked out every preset
        // with only one custom shader - measured with the PM_PRELOAD oracle,
        // 11 of a 40-preset sample return an incomplete pair, 4 of them because
        // they carry exactly ONE shader worth 90-100 ms of compile on this Mac
        // (more on a phone). Those paid it on the render thread at every
        // switch, which is the "slight freeze" when stepping through presets.
        if (g_pl_done_idx == (long)g_preset_idx) {
            uint32_t warp = g_pl_warp, comp = g_pl_comp;
            uint64_t seed = g_pl_seed;
            g_pl_done_idx = -1;
            g_pl_warp = g_pl_comp = 0;
            g_pl_seed = 0;
            pthread_mutex_unlock(&g_pl_mtx);

            long long t0 = _prof_now_ns();
            projectm_loadpreload_preset_file(g_pm,
                g_presets[g_preset_idx].c_str(), warp, comp, smooth, seed);
            PM_PROF("apply preloaded '%s': %.1f ms (render thread)",
                    g_presets[g_preset_idx].c_str(),
                    (_prof_now_ns() - t0) / 1e6);
            g_prof_frames_after_load = 5;
            _sprites_apply(g_presets[g_preset_idx]);
            _update_preset_name();
            _pick_next_and_preload();
            return;
        }
        pthread_mutex_unlock(&g_pl_mtx);
    }

    // Slow path (worker still busy / preload disabled / result mismatched):
    // the old synchronous load.
    _load_current(smooth);
    _pick_next_and_preload();
}

// Manual preset changes are REQUESTS, applied at the top of the next render.
//
// Loading a preset parses it and COMPILES ITS SHADERS — GL work. Dart calls
// next/prev from the platform thread, which on Android has no current EGL
// context (the context is current on the SurfaceView render thread, and an
// EGLContext can be current to exactly one thread at a time) → the GL calls hit
// no context and the app crashed. The core's OWN auto-switch never crashed
// because it fires from inside projectm_opengl_render_frame_fbo, i.e. already on
// the render thread. Deferring makes both paths identical — and fixes the same
// latent thread bug on Apple, where it only happened to work because the
// platform thread was also the one that had made the context current.
static std::atomic<int> g_preset_step{0};   // +N next, -N prev; drained by render

extern "C" REWAMP_EXPORT void rewamp_projectm_next_preset(void) {
    g_preset_step.fetch_add(1, std::memory_order_relaxed);
}

// projectM core does NOT auto-switch presets by itself: when preset_duration
// elapses (or a hardcut beat triggers) it fires this callback and the app must
// load the next preset — without registering it there is no automatic
// switching at all (the Modizer playlist plays this role there).
static void _on_switch_requested(bool is_hard_cut, void* /*user*/) {
    _advance_preset(!is_hard_cut && g_blend_mode != 0);
}
extern "C" REWAMP_EXPORT void rewamp_projectm_prev_preset(void) {
    g_preset_step.fetch_sub(1, std::memory_order_relaxed);
}

// Applies any queued manual preset change. Render thread only.
static void _apply_pending_preset(void) {
    int step = g_preset_step.exchange(0, std::memory_order_relaxed);
    if (step == 0 || g_presets.empty() || !g_pm) return;
    const bool smooth = g_blend_mode != 0;
    for (; step > 0; --step) _advance_preset(smooth);
    for (; step < 0; ++step) {
        if (!g_history.empty()) {
            g_preset_idx = g_history.back();
            g_history.pop_back();
        } else {
            // Nothing left to walk back through (fresh session, or the user
            // already rewound to the start): fall back to the POSITION, wrapping
            // round so "previous" on the first preset opens the last one. A dead
            // button on preset #0 reads as a bug, and the list is a ring in the
            // other direction already.
            g_preset_idx = (g_preset_idx == 0) ? g_presets.size() - 1
                                               : g_preset_idx - 1;
        }
        _load_current(smooth);
        _pick_next_and_preload();
    }
}
// Adopt a Dart-pushed preset list. Render thread (or init, context current).
// Returns true when a swap happened.
static bool _playlist_swap_if_pending(void) {
    if (!g_playlist_dirty.exchange(false)) return false;
    pthread_mutex_lock(&g_playlist_mtx);
    std::vector<std::string> list = g_playlist;
    long start = g_playlist_start;
    pthread_mutex_unlock(&g_playlist_mtx);
    // Empty push = back to the bundled default dir.
    if (list.empty()) list = _scan_presets(_default_preset_dir());

    const bool had_preset = g_pm_preset_loaded;
    _adopt_presets(std::move(list));
    g_history.clear();                              // old-list indices
    g_preset_step.store(0, std::memory_order_relaxed);
    g_session_active = true;

    if (g_presets.empty()) {
        // Nothing playable in the new source: keep whatever is on screen,
        // report no preset (Dart shows the empty state).
        g_preset_name[0] = '\0';
        g_preset_path[0] = '\0';
        g_preset_serial++;
        return true;
    }
    // An explicit start (the UI asked for THIS preset) wins over the usual
    // random/first pick — otherwise "play this one" would open a random one.
    if (start >= 0 && (size_t)start < g_presets.size()) {
        g_preset_idx = (size_t)start;
    } else {
        g_preset_idx = (g_random_mode && g_presets.size() > 1)
                           ? (size_t)(_rng_next() % g_presets.size())
                           : 0;
    }
    if (g_pm) {
        _load_current(had_preset && g_blend_mode != 0);
        _pick_next_and_preload();
    } else {
        g_pm_preset_loaded = false;   // defensive: adopted while instance-less
    }
    return true;
}

static void _split_lines(const char* s, std::vector<std::string>& out) {
    out.clear();
    if (!s) return;
    const char* p = s;
    while (*p) {
        const char* nl = strchr(p, '\n');
        size_t len = nl ? (size_t)(nl - p) : strlen(p);
        if (len) out.emplace_back(p, len);
        p += len;
        if (nl) p++;
    }
}

// Dart-facing setters: stage under their mutex, drained by the render thread
// (or the next init when the visualizer is off). Callable from any thread.
extern "C" REWAMP_EXPORT void rewamp_projectm_set_playlist(const char* paths,
                                                          int start_index) {
    pthread_mutex_lock(&g_playlist_mtx);
    _split_lines(paths, g_playlist);
    g_playlist_start = start_index;
    pthread_mutex_unlock(&g_playlist_mtx);
    g_playlist_dirty.store(true);
}

// Pointer state for the MilkDrop3 "mouse" uniform, forwarded into libprojectM
// (which owns no window and no input). x/y are 0..1 from the top-left of the
// visualizer surface, -1 when the pointer is away; held = button down, clicked
// = a release that just happened. Called from the UI thread, read on the render
// thread — the library side keeps it in atomics.
extern "C" void projectm_set_mouse_state(float x, float y, int held, int clicked);

extern "C" REWAMP_EXPORT void rewamp_projectm_set_mouse(float x, float y,
                                                       int held, int clicked) {
    projectm_set_mouse_state(x, y, held, clicked);
}

extern "C" REWAMP_EXPORT void rewamp_projectm_set_texture_dirs(const char* dirs) {
    pthread_mutex_lock(&g_texdirs_mtx);
    _split_lines(dirs, g_tex_dirs);
    pthread_mutex_unlock(&g_texdirs_mtx);
    g_texdirs_dirty.store(true);
}

// 1 when the preset on screen reads the "mouse" uniform, so the UI can say the
// pointer does something here (it does nothing in every other preset).
extern "C" REWAMP_EXPORT int rewamp_projectm_preset_uses_mouse(void) {
    return g_preset_uses_mouse.load(std::memory_order_relaxed);
}

// Number of built-in transition patterns, so the settings list is not a
// hardcoded 23 that silently drifts when a pattern is added.
extern "C" REWAMP_EXPORT int rewamp_projectm_transition_count(void) {
    return g_pm ? projectm_get_transition_count(g_pm) : 0;
}

extern "C" REWAMP_EXPORT int rewamp_projectm_preset_count(void) {
    return (int)g_presets.size();
}
// Absolute path of the current preset; empty until one is loaded.
extern "C" REWAMP_EXPORT const char* rewamp_projectm_preset_path(void) {
    return g_preset_path;
}
// Serial bumped on every preset load (manual next/prev AND the core's own
// auto-switch) so Dart can detect a change without a callback and flash the
// preset name.
extern "C" REWAMP_EXPORT int rewamp_projectm_preset_serial(void) {
    return g_preset_serial;
}
// Current preset display name (basename without ".milk"); empty until loaded.
extern "C" REWAMP_EXPORT const char* rewamp_projectm_preset_name(void) {
    return g_preset_name;
}
// mode setters (from Dart settings): random 0/1, blend 0/1.
extern "C" REWAMP_EXPORT void rewamp_projectm_set_mode(int random_next, int blend) {
    g_random_mode = random_next;
    g_blend_mode  = blend;
}

// App lifecycle (Dart, iOS mainly). Background: STOP the preload worker — a
// backgrounded iOS app must not touch the GPU, and the worker is a plain
// pthread that keeps compiling/warm-drawing regardless of the Flutter ticker;
// its background Metal work left the preload pipeline poisoned, so after
// resume every preset switch fell back to a synchronous compile (a visible
// hitch each transition until a full app restart). Foreground: arm a restart
// consumed by the next render tick, on the render thread (same thread that
// starts the worker at init — _preload_start is not thread-safe against a
// concurrent tick, so never start from here).
// Safe whatever the state: stop is a no-op without a worker, the flag is a
// no-op without an instance (rewamp_projectm_render returns before it when
// g_pm is null, and init starts the worker itself).
extern "C" REWAMP_EXPORT void rewamp_projectm_set_active(int foreground) {
    if (foreground) {
        g_pl_restart_pending.store(true);
    } else {
        g_pl_restart_pending.store(false);
        _preload_stop();
    }
}

// Full tunables push (Settings → Visualisation → projectM; Modizer's set).
// Applied live when an instance exists; also stored for the next init.
extern "C" REWAMP_EXPORT void rewamp_projectm_set_params(
    int random_next, int lock_preset, int blend, double blend_time,
    double preset_duration, int quality_shift,
    int mesh_x, int mesh_y, double beat_sensitivity,
    int hardcut_enabled, double hardcut_time, double hardcut_sensitivity,
    int aspect_correction, int permissive, int transition_index) {
    g_random_mode     = random_next;
    g_lock_preset     = lock_preset;
    g_blend_mode      = blend;
    g_blend_time      = blend_time;
    g_preset_duration = preset_duration;
    g_mesh_x          = mesh_x;
    g_mesh_y          = mesh_y;
    g_beat_sens       = beat_sensitivity;
    g_hardcut_enabled = hardcut_enabled;
    g_hardcut_time    = hardcut_time;
    g_hardcut_sens    = hardcut_sensitivity;
    g_aspect          = aspect_correction;
    mdz_pmMilkPermissiveEvalCode = permissive;
    g_transition_index = transition_index;
    int q = quality_shift < 0 ? 0 : (quality_shift > 3 ? 3 : quality_shift);
    if (q != g_quality_shift) {
        g_quality_shift = q;
        if (g_pm && g_w > 0)
            projectm_set_window_size(g_pm, g_w >> q, g_h >> q);
    }
    _apply_params();
}

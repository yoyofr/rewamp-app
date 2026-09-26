// Statistiques de cadence des visualiseurs (Linux), activées par
// REWAMP_VIZ_STATS=1 — un instrument, pas une fonction du produit.
//
// La question qu'il tranche: « le viz n'est pas fluide » a TROIS causes
// possibles, et elles n'ont pas le même remède. Chacune laisse une empreinte
// distincte, et aucune ne se devine à l'œil:
//
//   rendu     — le fil principal appelle rewamp_*_render_and_notify: sa cadence
//               dit si le ticker Flutter et le plafond de fps livrent ce qu'ils
//               promettent; sa DURÉE dit ce que coûte une image (GL + relecture).
//   populate  — Flutter consomme la texture sur son fil de rastérisation: si le
//               rendu est régulier mais populate ne l'est pas, c'est la
//               composition (Impeller, compositeur, vsync) qui saccade.
//   audio     — les compteurs de rewamp_audio.h: un viz saccadé PENDANT que
//               l'audio est propre exclut le producteur; des underruns ou des
//               trous de rappel en même temps désignent la machine, pas le viz.
//
// Toutes les 5 s: images/s, p50 / p95 / max des intervalles (ms), durée p50 /
// max du rendu, et les DELTAS audio de la fenêtre. Percentiles sur les 600
// derniers échantillons — assez pour voir un à-coup par seconde, pas assez pour
// noyer un à-coup rare dans la moyenne, ce que fait précisément une moyenne.
#include "../rewamp_audio.h"
#include "rewamp_viz_linux.h"
#include "../rewamp_viz_idle.h"   // rewamp_viz_max_fps

#include <algorithm>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <vector>

namespace {

struct Series {
    std::vector<double> samples;   // ms
    long long           last_ns = 0;
    long long           count   = 0;
    void note_now(long long now_ns) {
        if (last_ns) push((now_ns - last_ns) / 1e6);
        last_ns = now_ns;
        count++;
    }
    void push(double v) {
        if (samples.size() >= 600) samples.erase(samples.begin());
        samples.push_back(v);
    }
    // Rend p50 / p95 / max; 0 si vide.
    void percentiles(double* p50, double* p95, double* mx) const {
        *p50 = *p95 = *mx = 0;
        if (samples.empty()) return;
        std::vector<double> s(samples);
        std::sort(s.begin(), s.end());
        *p50 = s[s.size() / 2];
        *p95 = s[(s.size() * 95) / 100];
        *mx  = s.back();
    }
};

pthread_mutex_t g_mtx = PTHREAD_MUTEX_INITIALIZER;
Series g_render, g_populate, g_render_cost;
// Sous-étapes du mode pixels (X11), pour ATTRIBUER un coût et non le deviner.
const char* const kLapNames[6] = {"lier(GLX->EGL)", "readPixels", "map+copie", "rendre(EGL->GLX)",
                                  "attente GPU(fence)", "rendu viz (CPU)"};
Series g_laps[6];
long long g_window_start_ns = 0;
long long g_render_at_window = 0, g_populate_at_window = 0;
int64_t g_underrun0 = 0, g_late0 = 0, g_devgap0 = 0;
int  g_enabled = -1;
long long g_render_begin_ns = 0;

long long now_ns() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long)ts.tv_sec * 1000000000LL + ts.tv_nsec;
}

bool enabled() {
    if (g_enabled < 0) g_enabled = getenv("REWAMP_VIZ_STATS") ? 1 : 0;
    return g_enabled == 1;
}

// Sous le verrou.
void maybe_report(long long now) {
    if (!g_window_start_ns) {
        g_window_start_ns = now;
        g_underrun0 = rewamp_underrun_count();
        g_late0     = rewamp_device_late_count();
        g_devgap0   = rewamp_device_max_gap_us();
        return;
    }
    const double secs = (now - g_window_start_ns) / 1e9;
    if (secs < 5.0) return;

    double r50, r95, rmx, p50, p95, pmx, c50, c95, cmx;
    g_render.percentiles(&r50, &r95, &rmx);
    g_populate.percentiles(&p50, &p95, &pmx);
    g_render_cost.percentiles(&c50, &c95, &cmx);
    const double rfps = (g_render.count - g_render_at_window) / secs;
    const double pfps = (g_populate.count - g_populate_at_window) / secs;
    const int64_t underruns = rewamp_underrun_count() - g_underrun0;
    const int64_t late      = rewamp_device_late_count() - g_late0;
    const int64_t devgap    = rewamp_device_max_gap_us();

    fprintf(stderr,
            "[viz-stats] rendu %.1f img/s (intervalle p50 %.1f  p95 %.1f  max %.1f ms; "
            "durée p50 %.2f  p95 %.2f  max %.2f ms) | "
            "populate %.1f img/s (p50 %.1f  p95 %.1f  max %.1f ms) | "
            "audio: underruns +%lld, rappels en retard +%lld, pire trou %lld ms | "
            "plafond %d fps\n",
            rfps, r50, r95, rmx, c50, c95, cmx,
            pfps, p50, p95, pmx,
            (long long)underruns, (long long)late,
            (long long)((devgap > g_devgap0 ? devgap : 0) / 1000),
            rewamp_viz_max_fps());

    for (int i = 0; i < 6; i++) {
        if (g_laps[i].samples.empty()) continue;
        double a, b, c; g_laps[i].percentiles(&a, &b, &c);
        fprintf(stderr, "[viz-stats]   %-16s p50 %.2f  p95 %.2f  max %.2f ms\n",
                kLapNames[i], a, b, c);
    }
    g_window_start_ns    = now;
    g_render_at_window   = g_render.count;
    g_populate_at_window = g_populate.count;
    g_underrun0 = rewamp_underrun_count();
    g_late0     = rewamp_device_late_count();
    g_devgap0   = devgap;
}

}  // namespace

extern "C" {

// Début d'un rendu (fil principal).
void rewamp_viz_stats_render_begin(void) {
    if (!enabled()) return;
    const long long now = now_ns();
    pthread_mutex_lock(&g_mtx);
    g_render.note_now(now);
    g_render_begin_ns = now;
    pthread_mutex_unlock(&g_mtx);
}

// Fin du même rendu — sa durée, pas sa cadence.
void rewamp_viz_stats_render_end(void) {
    if (!enabled()) return;
    const long long now = now_ns();
    pthread_mutex_lock(&g_mtx);
    if (g_render_begin_ns) g_render_cost.push((now - g_render_begin_ns) / 1e6);
    maybe_report(now);
    pthread_mutex_unlock(&g_mtx);
}

// Une sous-étape chronométrée (fil principal).
void rewamp_viz_stats_lap(int slot, double ms) {
    if (!enabled() || slot < 0 || slot > 5) return;
    pthread_mutex_lock(&g_mtx);
    g_laps[slot].push(ms);
    pthread_mutex_unlock(&g_mtx);
}

// Flutter a consommé une image (fil de rastérisation).
REWAMP_VIZ_LINUX_API void rewamp_viz_stats_populate(void) {
    if (!enabled()) return;
    const long long now = now_ns();
    pthread_mutex_lock(&g_mtx);
    g_populate.note_now(now);
    pthread_mutex_unlock(&g_mtx);
}

}  // extern "C"

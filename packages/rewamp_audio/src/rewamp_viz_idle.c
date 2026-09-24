/* rewamp_viz_idle — voir rewamp_viz_idle.h pour le pourquoi. */
#include "rewamp_viz_idle.h"

#include <stdatomic.h>
#include <time.h>

/* Fenêtre de grâce après le dernier « quelque chose a changé ». Trois secondes:
 * la plus longue animation qui doit pouvoir S'ÉTEINDRE seule est le glissement
 * de plage automatique du piano (ease de 0,7 s, cible réévaluée jusqu'à 4 s
 * après le contenu) et un fondu de preset projectM; les étincelles et le
 * relâchement des touches sont bien plus courts. */
#define VI_GRACE_MS 3000

static atomic_llong g_last_wake_ms = 0;
static atomic_int   g_idle_gap     = 0;   /* une image a été refusée depuis la dernière lecture */

/* Plafond de cadence. 0 = celle de l'écran (aucune limite ici). L'échéance est
 * en MICROSECONDES: à 60 img/s la période fait 16 667 µs, et l'arrondir à la
 * milliseconde dériverait d'une image toutes les trois secondes. */
static atomic_int   g_max_fps      = 0;
static long long    g_next_due_us  = 0;

/* Horloge MONOTONE: une horloge murale reculerait à un changement d'heure et
 * gèlerait le visualiseur jusqu'à ce que le temps la rattrape. */
static long long vi_now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static long long vi_now_us(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long)ts.tv_sec * 1000000 + ts.tv_nsec / 1000;
}

void rewamp_viz_wake(void) {
    atomic_store_explicit(&g_last_wake_ms, vi_now_ms(), memory_order_relaxed);
}

int rewamp_viz_should_render(void) {
    /* Ça joue: on dessine, et on garde l'instant — la grâce part donc de la
     * DERNIÈRE frame jouée, pas du dernier geste de l'utilisateur. */
    if (rewamp_is_playing()) {
        rewamp_viz_wake();
        return 1;
    }
    const long long since =
        vi_now_ms() - atomic_load_explicit(&g_last_wake_ms, memory_order_relaxed);
    if (since < VI_GRACE_MS) return 1;
    /* On REFUSE une image: qui mesure une cadence doit le savoir (voir
     * rewamp_viz_take_idle_gap). Poser un drapeau ne casse pas l'idempotence —
     * deux appels dans la même frame donnent la même réponse. */
    atomic_store_explicit(&g_idle_gap, 1, memory_order_relaxed);
    return 0;
}

int rewamp_viz_take_idle_gap(void) {
    return atomic_exchange_explicit(&g_idle_gap, 0, memory_order_relaxed);
}

void rewamp_viz_set_max_fps(int fps) {
    if (fps < 0) fps = 0;
    if (fps > 240) fps = 240;
    atomic_store_explicit(&g_max_fps, fps, memory_order_relaxed);
    g_next_due_us = 0;   /* la prochaine image est due tout de suite */
}

int rewamp_viz_max_fps(void) {
    return atomic_load_explicit(&g_max_fps, memory_order_relaxed);
}

int rewamp_viz_frame_due(void) {
    if (!rewamp_viz_should_render()) return 0;
    const int fps = atomic_load_explicit(&g_max_fps, memory_order_relaxed);
    if (fps <= 0) return 1;

    const long long period = 1000000 / fps;
    const long long now    = vi_now_us();
    /* ⚠️ Tolérance: les images arrivent sur la GRILLE du vsync. À 120 Hz elles
     * tombent toutes les 8 333 µs, donc l'échéance des 60 img/s (16 667) est
     * ratée d'une poussière et la frame suivante n'arrive qu'à 25 000 —
     * effectivement 40 img/s, saccadées. Un quart de période d'avance est
     * accepté: l'image du deuxième vsync passe, la cadence tient exactement
     * la moitié de l'écran. */
    if (now + period / 4 < g_next_due_us) return 0;

    /* Échéances CUMULÉES (pas « maintenant + période »): sinon chaque frame
     * décale la suivante du temps qu'elle a mis à venir et la cadence dérive
     * vers le bas. Un retard de plus d'une période (viz réveillé après une
     * pause, thread préempté) repart de maintenant plutôt que de rattraper une
     * rafale d'images en retard. */
    if (now - g_next_due_us > period) g_next_due_us = now + period;
    else                              g_next_due_us += period;
    return 1;
}

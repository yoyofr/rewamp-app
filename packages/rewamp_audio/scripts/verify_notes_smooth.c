/* Simulateur de la tête de lecture lissée (rewamp_notes_played_smooth) sur
 * deux scénarios: changement de piste avec démarrage retardé, et lecture
 * normale à rappels irréguliers (dont un en retard de 300 ms). */
#include <stdio.h>
#include <math.h>
#include <stdint.h>
#include "rewamp_notes.h"
double rewamp_notes_played_smooth(void);
static double T = 1.0;
double rewamp_viz_frame_time(void) { return T; }
static const double R = 44100.0;
static void trackchange(void) {
    rewamp_notes_set_rate((int)R);
    double tru = 5000000.0;
    printf("changement de piste (démarrage du son retardé de 0,3 s):\n");
    for (double t = 0; t < 5.0; t += 1.0 / 60) { T += 1.0 / 60; tru += R / 60; rewamp_notes_set_played((int64_t)tru); rewamp_notes_played_smooth(); }
    rewamp_notes_reset(4); rewamp_notes_set_played(0);
    double start = T + 0.3, next = T; double marks[] = {0.5, 1, 2, 4, 8, 12}; int mi = 0;
    for (double t = 0; t < 12.5; t += 1.0 / 60) {
        T += 1.0 / 60;
        double truth = T < start ? 0 : (T - start) * R;
        if (T >= next) { rewamp_notes_set_played((int64_t)truth); next += 0.02; }
        double d = rewamp_notes_played_smooth();
        if (mi < 6 && t >= marks[mi]) { printf("  t=%5.1f s  erreur %+.3f s\n", marks[mi], (d - truth) / R); mi++; }
    }
}
/* Piste sautée après 0,9 s: le recul (sous le recalage d'1 s) laissait
 * l'affichage 0,95 s DEVANT pendant 2-3 s (journal utilisateur 2026-09-11). */
static void shortskip(void) {
    rewamp_notes_set_rate((int)R);
    rewamp_notes_reset(4); rewamp_notes_set_played(0);
    double tru = 0, next = T;
    for (double t = 0; t < 0.9; t += 1.0 / 60) {
        T += 1.0 / 60; tru += R / 60;
        if (T >= next) { rewamp_notes_set_played((int64_t)tru); next += 0.02; }
        rewamp_notes_played_smooth();
    }
    printf("piste sautée après 0,9 s (démarrage du son retardé de 0,3 s):\n");
    rewamp_notes_reset(4); rewamp_notes_set_played(0);
    double start = T + 0.3; next = T; double marks[] = {0.1, 0.3, 0.5, 1, 2}; int mi = 0; double maxAhead = 0;
    for (double t = 0; t < 2.5; t += 1.0 / 60) {
        T += 1.0 / 60;
        double truth = T < start ? 0 : (T - start) * R;
        if (T >= next) { rewamp_notes_set_played((int64_t)truth); next += 0.02; }
        double d = rewamp_notes_played_smooth();
        double e = (d - truth) / R; if (e > maxAhead) maxAhead = e;
        if (mi < 5 && t >= marks[mi]) { printf("  t=%5.1f s  erreur %+.3f s\n", marks[mi], e); mi++; }
    }
    printf("  avance max de l'affichage sur le son: %.3f s\n", maxAhead);
}
static void jitter(void) {
    double tru = 0, next = T, maxErr = 0, prev = -1, maxStep = 0, sumStep = 0; int n = 0;
    unsigned s = 12345;
    for (double t = 0; t < 20; t += 1.0 / 60) {
        T += 1.0 / 60; tru += R / 60;
        if (T >= next) {
            s = s * 1103515245u + 12345u;
            double j = 0.02 + ((int)((s >> 16) % 21) - 10) / 1000.0;
            if (t > 10 && t < 10.02) j = 0.30;                     /* one late callback */
            rewamp_notes_set_played((int64_t)tru); next += j;
        }
        double d = rewamp_notes_played_smooth();
        if (t > 2) {
            double e = fabs(d - tru) / R; if (e > maxErr) maxErr = e;
            if (prev >= 0) { double st = (d - prev) / (R / 60); double w = fabs(st - 1); sumStep += w; n++; if (w > maxStep) maxStep = w; }
        }
        prev = d;
    }
    printf("lecture normale (rappels 20±10 ms, un retard de 300 ms): erreur max %.3f s, variation d'avance par image moyenne %.2f %%, max %.2f %%\n",
           maxErr, 100 * sumStep / n, 100 * maxStep);
}
#include <string.h>
int main(int argc, char** argv) {
    if (argc > 1 && !strcmp(argv[1], "jitter")) jitter();
    else if (argc > 1 && !strcmp(argv[1], "shortskip")) shortskip();
    else trackchange();
    return 0;
}

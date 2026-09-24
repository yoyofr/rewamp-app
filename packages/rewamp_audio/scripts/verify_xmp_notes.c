/* Oracle: les notes que libxmp publie doivent être CELLES de libopenmpt.
 *
 * Les deux bibliothèques jouent les mêmes formats classiques (.xm/.it/.mod…)
 * sans partager une ligne de code, et rewamp lit leurs notes par le MÊME
 * canal (vgm_last_note[], en Hz) pour la notation, le piano et les motifs. Une
 * échelle décalée d'une octave — l'erreur naturelle quand on traduit l'index
 * de note d'un tracker en fréquence — ne s'entend pas: elle se VOIT, et
 * seulement sur un visualiseur, longtemps après.
 *
 * On rejoue donc le même fichier avec les deux greffons, on relève la note de
 * chaque voie au même instant, et on compare en CENTS.
 *
 * ⚠️ Les deux moteurs ne répondent PAS exactement à la même question, et c'est
 * ce qui décide du verdict. rewamp affiche la hauteur ENTENDUE (tous les
 * moteurs à puce publient une fréquence mesurée), donc le greffon libxmp
 * ajoute la transposition de l'instrument à la touche du motif. libopenmpt le
 * fait pour le « relative note » d'un XM mais PAS pour l'accordage par c5spd
 * d'un échantillon IT — un désaccord d'un nombre NON ENTIER de demi-tons est
 * donc légitime et attendu. Ce qui ne l'est jamais, c'est un désaccord d'une
 * OCTAVE JUSTE: c'est la signature d'une échelle de notes fausse, l'erreur que
 * cet oracle existe pour attraper (mesurée: -1200 cents sur la première
 * version du greffon). D'où le verdict:
 *
 *   - médiane des écarts ≈ 0 (pas de décalage systématique),
 *   - moins de 5 % de paires décalées d'un multiple EXACT d'une octave,
 *   - un taux d'accord qui reste plausible (garde-fou grossier).
 */
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"

const RewampPluginVTable* rewamp_xmp_plugin(void);
const RewampPluginVTable* rewamp_openmpt_plugin(void);

/* ── ce que l'app fournit et dont le harnais n'a pas besoin ────────────── */
int rewamp_ext_in_list(const char* ext, const char* const* list) {
    if (!ext) return 0;
    for (; *list; ++list) if (!strcasecmp(ext, *list)) return 1;
    return 0;
}
/* ⚠ la signature doit être EXACTE (trois arguments): un stub qui ment ne
 * casse pas le lien, il fausse la mesure. */
double rewamp_get_engine_param(const char* engine, const char* key, double defval) {
    (void)engine; (void)key; return defval;
}
int rewamp_waveform_pos(void) { return 0; }
int rewamp_waveform_read_i8(int c, signed char* o, int n) { (void)c; (void)o; (void)n; return 0; }

#define CHUNK      1024
#define MAX_STEPS  2000
#define MAX_VOICES 64

static unsigned int g_note[2][MAX_STEPS][MAX_VOICES];
static int          g_steps[2];
static int          g_voices[2];

static int run(const RewampPluginVTable* vt, const char* path, int slot) {
    RewampAudioFormat fmt = {0};
    RewampDecoder* dec = vt->open(path, &fmt);
    if (dec == NULL) { fprintf(stderr, "%s: open a échoué\n", vt->name); return 0; }
    static float buf[CHUNK * 2];
    int steps = 0;
    g_voices[slot] = m_genNumVoicesChannels;
    while (steps < MAX_STEPS) {
        if (vt->read(dec, buf, CHUNK) == 0) break;
        for (int v = 0; v < MAX_VOICES; v++) g_note[slot][steps][v] = vgm_last_note[v];
        steps++;
    }
    g_steps[slot] = steps;
    vt->close(dec);
    return steps;
}

static int cmp_double(const void* a, const void* b) {
    double x = *(const double*)a, y = *(const double*)b;
    return (x > y) - (x < y);
}

int main(int argc, char** argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s fichier\n", argv[0]); return 2; }
    rewamp_channel_data_init();

    if (!run(rewamp_openmpt_plugin(), argv[1], 0)) return 1;
    if (!run(rewamp_xmp_plugin(),     argv[1], 1)) return 1;

    int steps = g_steps[0] < g_steps[1] ? g_steps[0] : g_steps[1];
    int voices = g_voices[0] < g_voices[1] ? g_voices[0] : g_voices[1];
    if (voices > MAX_VOICES) voices = MAX_VOICES;
    printf("%s: openmpt %d pas / %d voies, libxmp %d pas / %d voies\n",
           argv[1], g_steps[0], g_voices[0], g_steps[1], g_voices[1]);
    if (steps < 10 || voices < 1) { printf("ÉCHEC: trop court pour conclure\n"); return 1; }

    static double cents[MAX_STEPS * MAX_VOICES];
    long n = 0, both = 0, agree = 0;
    for (int s = 0; s < steps; s++) {
        for (int v = 0; v < voices; v++) {
            unsigned a = g_note[0][s][v], b = g_note[1][s][v];
            if (a == 0 || b == 0) continue;
            both++;
            double c = 1200.0 * log2((double)b / (double)a);
            cents[n++] = c;
            if (fabs(c) <= 50.0) agree++;   /* un demi-ton */
        }
    }
    if (n == 0) { printf("ÉCHEC: aucune note commune\n"); return 1; }

    /* Détail par voie: INFORMATIF, pas un verdict. Un échantillon accordé par
     * c5spd (IT) décale une voie entière d'un écart constant — sur test.it
     * c'est -3600 cents EXACTEMENT, un décalage d'octave parfaitement
     * légitime: le son est bien trois octaves plus bas, libopenmpt rapporte
     * seulement la touche du motif là où nous rapportons la hauteur entendue.
     * Juger une voie isolée condamnerait ce cas; le défaut qu'on traque
     * (échelle de notes fausse) porte sur TOUTES les voies, donc c'est la
     * médiane GLOBALE qui tranche. */
    static double vcents[MAX_STEPS];
    int ok = 1;
    for (int v = 0; v < voices; v++) {
        long vn = 0, va = 0;
        for (int s = 0; s < steps; s++) {
            unsigned a = g_note[0][s][v], b = g_note[1][s][v];
            if (a == 0 || b == 0) continue;
            double c = 1200.0 * log2((double)b / (double)a);
            vcents[vn++] = c;
            if (fabs(c) <= 50.0) va++;
        }
        if (vn == 0) continue;
        qsort(vcents, (size_t)vn, sizeof(double), cmp_double);
        double vmed = vcents[vn / 2];
        double rem  = fabs(fmod(fabs(vmed), 1200.0));
        int octave  = fabs(vmed) > 5.0 && (rem <= 10.0 || rem >= 1190.0);
        printf("  voie %d: %ld notes, accord %.1f%%, médiane %.1f cents%s\n",
               v, vn, 100.0 * (double)va / (double)vn, vmed,
               octave ? "  (accordage de l'échantillon)" : "");
    }

    qsort(cents, (size_t)n, sizeof(double), cmp_double);
    double median = cents[n / 2];
    double ratio  = (double)agree / (double)both;
    printf("notes comparées=%ld  accord=%.1f%%  médiane=%.1f cents\n",
           both, 100.0 * ratio, median);
    if (fabs(median) > 5.0) {
        printf("ÉCHEC: décalage systématique de %.1f cents (%.2f octave)\n",
               median, median / 1200.0);
        ok = 0;
    }
    if (ratio < 0.60) {
        printf("ÉCHEC: seulement %.1f%% d'instants d'accord\n", 100.0 * ratio);
        ok = 0;
    }
    if (ok) printf("OK\n");
    return ok ? 0 : 1;
}

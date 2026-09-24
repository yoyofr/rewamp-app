/* Oracle de la capture de notes NEZ (.hes / .sgc), hors app.
 * usage: verify_hes_notes <fichier> [sous-chanson=0] [secondes=6]
 * Imprime, par voie: le nombre de trames où une note est active, la plage de
 * hauteurs vue (Hz et note MIDI) et un échantillon de valeurs. Une note hors
 * de [0,128) en MIDI est ce que le viz-piano JETTE — c'est le symptôme que cet
 * oracle doit rendre visible. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>
#include "nezplug.h"
#include "ModizerVoicesData.h"

extern "C" {
void rewamp_channel_data_init(void);
void rewamp_channel_data_reset(int voices);
/* Bouchons: `rewamp_channel_data.c` s'appuie sur l'anneau de forme d'onde du
 * datasource et sur iconv (titres Shift-JIS). Cet oracle ne mesure QUE
 * vgm_last_note[], rien de tout cela n'est atteint — mais il faut lier.
 * ⚠️ Un bouchon dont la SIGNATURE ment ne casse pas le lien, il fausse la
 * mesure (leçon du stub de rewamp_get_engine_param dans l'oracle PSF). */
int64_t rewamp_waveform_pos(void) { return 0; }
int rewamp_waveform_read_i8(int channel, int8_t* out, int n) {
    (void)channel; (void)out; (void)n; return 0;
}
}

int main(int argc, char** argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s file [subsong] [secs]\n", argv[0]); return 2; }
    const int subsong = argc > 2 ? atoi(argv[2]) : 0;
    const double secs = argc > 3 ? atof(argv[3]) : 6.0;
    FILE* f = fopen(argv[1], "rb");
    if (!f) { perror("open"); return 1; }
    fseek(f, 0, SEEK_END); long len = ftell(f); fseek(f, 0, SEEK_SET);
    unsigned char* buf = (unsigned char*)malloc(len);
    if (fread(buf, 1, len, f) != (size_t)len) { perror("read"); return 1; }
    fclose(f);

    const int rate = 44100;
    NEZ_PLAY* play = NEZNew();
    if (!play) { fprintf(stderr, "NEZNew failed\n"); return 1; }
    NEZSetFrequency(play, rate);
    NEZSetChannel(play, 2);
    if (NEZLoad(play, buf, (Uint)len) != 0) { fprintf(stderr, "NEZLoad failed\n"); return 1; }
    NEZSetSongNo(play, (Uint)(subsong + 1));
    rewamp_channel_data_init();
    rewamp_channel_data_reset(16);
    NEZReset(play);

    enum { V = 16, CHUNK = 441 };
    long active[V] = {0};
    double lo[V], hi[V];
    unsigned int sample[V][6]; int nsample[V] = {0};
    for (int v = 0; v < V; v++) { lo[v] = 1e18; hi[v] = 0; }

    short pcm[CHUNK * 2];
    const long chunks = (long)(secs * rate / CHUNK);
    for (long i = 0; i < chunks; i++) {
        NEZRender(play, pcm, CHUNK);
        for (int v = 0; v < V; v++) {
            unsigned int hz = vgm_last_note[v];
            if (hz == 0) continue;
            active[v]++;
            if (hz < lo[v]) lo[v] = hz;
            if (hz > hi[v]) hi[v] = hz;
            if (nsample[v] < 6) sample[v][nsample[v]++] = hz;
        }
    }
    printf("fichier=%s sous-chanson=%d durée=%.1fs blocs=%ld\n",
           argv[1], subsong, secs, chunks);
    int outOfRange = 0, anyActive = 0;
    for (int v = 0; v < V; v++) {
        if (!active[v]) continue;
        anyActive = 1;
        const double mlo = 69.0 + 12.0 * log2(lo[v] / 440.0);
        const double mhi = 69.0 + 12.0 * log2(hi[v] / 440.0);
        const int bad = (mhi < 0 || mlo >= 128);
        if (bad) outOfRange++;
        printf("  voie %2d: %5ld bloc(s) actifs, %8.1f..%8.1f Hz "
               "(MIDI %6.1f..%6.1f)%s\n    ",
               v, active[v], lo[v], hi[v], mlo, mhi,
               bad ? "  ← HORS PLAGE PIANO" : "");
        for (int k = 0; k < nsample[v]; k++) printf("%u ", sample[v][k]);
        printf("\n");
    }
    if (!anyActive) printf("  AUCUNE note capturée\n");
    printf("verdict: %s\n", !anyActive ? "RIEN CAPTURÉ"
           : outOfRange ? "DES VOIES HORS DE LA PLAGE MIDI (le piano les jette)"
                        : "toutes les voies dans la plage MIDI");
    NEZDelete(play);
    return 0;
}

/* Le fondu est-il RÉELLEMENT appliqué par le greffon PS1 sur un vrai .psf ?
 * Mesure le RMS par tranche d'une seconde jusqu'à la fin de la piste. */
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <stdlib.h>
#include "rewamp_plugin.h"
const RewampPluginVTable* rewamp_highlyexp_plugin(void);
long long rewamp_waveform_pos(void) { return 0; }
int rewamp_waveform_read_i8(int a, signed char* b, int c) { (void)a;(void)b;(void)c; return 0; }
int rewamp_ext_in_list(const char* e, const char* const* l) { (void)e;(void)l; return 0; }

int main(int argc, char** argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s <fichier.psf>\n", argv[0]); return 2; }
    RewampAudioFormat fmt; memset(&fmt, 0, sizeof fmt);
    const RewampPluginVTable* vt = rewamp_highlyexp_plugin();
    RewampDecoder* dec = vt->open(argv[1], &fmt);
    if (!dec) { fprintf(stderr, "open a échoué\n"); return 1; }
    const uint64_t total = vt->length ? vt->length(dec) : 0;
    printf("rate=%u ch=%u total=%llu frames (%.1f s)\n", fmt.sampleRate, fmt.channels,
           (unsigned long long)total, total / (double)fmt.sampleRate);
    if (total == 0) { fprintf(stderr, "pas de durée: rien à mesurer\n"); return 3; }
    const uint32_t chunk = fmt.sampleRate;          /* 1 s */
    float* buf = malloc(sizeof(float) * chunk * fmt.channels);
    double last[8] = {0};
    double first0 = 0, first1 = 0;
    int nsec = 0;
    uint64_t done = 0;
    while (done < total) {
        uint64_t n = vt->read(dec, buf, chunk);
        if (n == 0) break;
        double sum = 0;
        for (uint64_t i = 0; i < n * fmt.channels; i++) sum += buf[i] * buf[i];
        double rms = sqrt(sum / (n * fmt.channels));
        for (int k = 7; k > 0; k--) last[k] = last[k - 1];
        last[0] = rms;
        if (nsec == 0) first0 = rms; else if (nsec == 1) first1 = rms;
        nsec++;
        done += n;
    }
    printf("secondes rendues: %d\n", nsec);
    printf("RMS 1re seconde: %.4f | 2e: %.4f\n", first0, first1);
    printf("RMS des 6 dernières secondes (de l'avant-dernière à la fin):\n");
    for (int k = 5; k >= 0; k--) printf("  -%ds : %.4f\n", k + 1, last[k]);
    int decreasing = last[0] < last[1] && last[1] < last[2];
    printf(decreasing ? "=> la fin DESCEND (fondu appliqué)\n"
                      : "=> la fin ne descend pas\n");
    vt->close(dec);
    free(buf);
    return decreasing ? 0 : 4;
}

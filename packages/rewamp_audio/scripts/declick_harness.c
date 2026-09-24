/* Harnais de rewamp_declick: lit un f32le interleaved (décodé par ffmpeg),
 * le passe dans le déclic par blocs de taille variable, et rapporte.
 * usage: declick_harness <in.f32> <channels> <rate> [out.f32]
 * Sortie (une ligne par réparation, puis un bilan):
 *   repair frame=<n> t=<ms> ch=<c> len=<l> peak=<p>
 *   summary repairs=<n> frames_in=<a> frames_out=<b> armed_at_end=<0|1> passthrough_ok=<0|1>
 */
#include "../src/rewamp_declick.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

typedef struct { const float* pcm; uint64_t frames; uint64_t pos; int ch; } Src;

static uint64_t src_read(void* user, float* out, uint64_t frames) {
    Src* s = (Src*)user;
    uint64_t left = s->frames - s->pos;
    if (frames > left) frames = left;
    memcpy(out, s->pcm + s->pos * s->ch, (size_t)frames * s->ch * sizeof(float));
    s->pos += frames;
    return frames;
}

int main(int argc, char** argv) {
    if (argc < 4) { fprintf(stderr, "usage: %s in.f32 channels rate [out.f32]\n", argv[0]); return 2; }
    int ch = atoi(argv[2]), rate = atoi(argv[3]);
    FILE* f = fopen(argv[1], "rb");
    if (!f) { perror("open"); return 1; }
    fseek(f, 0, SEEK_END); long sz = ftell(f); fseek(f, 0, SEEK_SET);
    uint64_t frames = (uint64_t)sz / ((uint64_t)ch * sizeof(float));
    float* pcm = (float*)malloc((size_t)frames * ch * sizeof(float));
    if (fread(pcm, sizeof(float) * ch, frames, f) != frames) { perror("read"); return 1; }
    fclose(f);
    float* out = (float*)calloc((size_t)frames * ch + 4096 * ch, sizeof(float));

    Src s = { pcm, frames, 0, ch };
    RewampDeclick* d = rewamp_declick_create(ch, rate);
    uint64_t done = 0; unsigned seed = 12345;
    while (1) {
        seed = seed * 1103515245u + 12345u;
        uint64_t want = 64 + (seed >> 16) % 4000;   /* 64..4063 trames */
        uint64_t got = rewamp_declick_read(d, out + done * ch, want, src_read, &s);
        if (got == 0) break;
        done += got;
    }
    RewampDeclickRepair log[32];
    int n = rewamp_declick_repairs(d, log, 32);
    for (int i = 0; i < (n < 32 ? n : 32); i++)
        printf("repair frame=%llu t=%.1fms ch=%d len=%d peak=%.4f\n",
               (unsigned long long)log[i].frame, 1000.0 * log[i].frame / rate,
               log[i].channel, log[i].length, log[i].peak);
    /* Passthrough: hors réparations, la sortie doit être IDENTIQUE à l'entrée. */
    uint64_t diff = 0, first_diff = 0;
    for (uint64_t i = 0; i < frames * ch && i < done * ch; i++)
        if (pcm[i] != out[i]) { if (!diff) first_diff = i / ch; diff++; }
    uint64_t repaired = 0;
    for (int i = 0; i < (n < 32 ? n : 32); i++) repaired += log[i].length;
    printf("summary repairs=%d frames_in=%llu frames_out=%llu armed_at_end=%d "
           "diff_samples=%llu first_diff_frame=%llu repaired_frames=%llu\n",
           n, (unsigned long long)frames, (unsigned long long)done,
           rewamp_declick_armed(d), (unsigned long long)diff,
           (unsigned long long)first_diff, (unsigned long long)repaired);
    if (argc > 4 && argv[4][0]) { FILE* o = fopen(argv[4], "wb"); fwrite(out, sizeof(float) * ch, done, o); fclose(o); }
    rewamp_declick_destroy(d);
    free(pcm); free(out);
    return 0;
}

//
//  chp2ym.h
//  libchpconv
//
//  Created by Yohann Magnien David on 20/05/2024.
//

#ifndef chp2ym_h
#define chp2ym_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Convert an Amstrad CPC ChipTracker (.chp) file at `filename` into a malloc'd
// YM3 buffer (*ym_data). Returns the buffer length in bytes, or 0 on failure.
int chp2ym(char *filename,uint8_t **ym_data);

// REWAMP — la chanson (grille de motifs) + la position de chaque image YM3.
// Notes de score: 0 = vide, 1..108 = C-0..B-8, 109 = SFX, 110 = "===" (frein),
// 112 = "^^^" (silence). Note ENTENDUE = n - 1 + transpose + transposition de
// l'ordre (order[c][o][1], signée). Une ligne d'ordre avance au bout de
// scrln[order[2][o][0]] lignes (voie C). cur_order/cur_row: -1 avant la 1re
// ligne. Ne pas réentrer (chp2ym tient tout en globales).
typedef struct ChpSong {
    int orders, loopto, hertz, divisor, transpose;
    unsigned char order[3][256][2];
    unsigned char scrln[256];
    unsigned char score[256][128][2];
    int frames, loop_frame;        // images YM3 (50 Hz), image de reprise
    int16_t *cur_order, *cur_row;  // [frames], malloc'd
} ChpSong;
int  chp2ym_song(char *filename,uint8_t **ym_data,ChpSong *song);
void chp_song_free(ChpSong *song);

#ifdef __cplusplus
}
#endif

#endif /* chp2ym_h */

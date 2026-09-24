#ifndef REWAMP_PATTERN_H
#define REWAMP_PATTERN_H

#include <stdint.h>
#include "rewamp_audio.h"   /* REWAMP_EXPORT */
#include "rewamp_plugin.h"  /* RewampPatternCell, RewampPatternSongInfo */

#ifdef __cplusplus
extern "C" {
#endif

/* Tracker-pattern visualizer support.
 *
 * TWO data paths, both consumer-synced like the notation viz (rewamp_notes):
 *
 * 1. STATIC pattern content (order list, per-cell note/instr/vol/fx). The
 *    plugin builds an immutable table in open(); the engine FFI below dispatches
 *    to the plugin's vtable slots under decodeLock (implemented in
 *    rewamp_audio.c, which owns the active decoder).
 *
 * 2. LIVE cursor (order,row). The producer polls the plugin's pattern_cursor()
 *    each decode step and calls rewamp_pattern_cursor_capture() with the
 *    producer frame; the consumer calls rewamp_pattern_cursor_set_played(); the
 *    UI reads rewamp_pattern_cursor() which returns the (order,row) that matches
 *    what is being HEARD (implemented here, self-contained store). */

/* ── cursor store (producer/consumer, same design as rewamp_notes) ─────────── */

/* Reset for a new track / after a seek. */
void rewamp_pattern_cursor_reset(void);
/* Bumped by every reset — the GL pattern renderer watches it to drop its
 * cached tessellation (track change / seek). */
unsigned rewamp_pattern_song_generation(void);
/* Relais gapless: le décodeur vient d'être échangé, mais l'oreille est encore
 * DANS le morceau précédent. On n'efface donc RIEN — on ouvre une nouvelle
 * époque: les captures suivantes décrivent le morceau suivant et sont
 * étiquetées, celles d'avant restent lisibles jusqu'à ce que la position
 * entendue les dépasse. Voir le commentaire d'époque dans rewamp_pattern.c. */
void rewamp_pattern_cursor_new_epoch(void);
/* Époque que le PRODUCTEUR capture (le morceau que le décodeur joue) et époque
 * de la dernière position LUE (le morceau qu'on entend). Différentes ⇒ une
 * frontière gapless est en attente: le contenu statique (`rewamp_pattern_order`
 * et consorts) décrit déjà le morceau suivant et ne doit PAS être relu. */
unsigned rewamp_pattern_live_epoch(void);
unsigned rewamp_pattern_heard_epoch(void);
/* Producer: store the live (order,row) tagged with [producerSamplePos]. */
void rewamp_pattern_cursor_capture(int64_t producerSamplePos, int order, int row);
/* Consumer: update the heard sample position. */
void rewamp_pattern_cursor_set_played(int64_t playedSamplePos);

/* ── FFI (Dart) ────────────────────────────────────────────────────────────── */

/* 1 when the currently-playing plugin exposes real pattern data. */
REWAMP_EXPORT int rewamp_pattern_supported(void);
/* Fill *out; returns 1 on success, 0 if unavailable. */
REWAMP_EXPORT int rewamp_pattern_song_info(RewampPatternSongInfo* out);
/* Order index → pattern index (-1 on error). */
REWAMP_EXPORT int rewamp_pattern_order(int order);
/* Row count of a pattern (0 on error). */
REWAMP_EXPORT int rewamp_pattern_num_rows(int pattern);
/* Fill out[row*channels + chan] for the whole pattern (≤ maxCells cells).
 * Returns the number of cells written (rows*channels) or 0. */
REWAMP_EXPORT int rewamp_pattern_get(int pattern, RewampPatternCell* out, int maxCells);
/* Consumer-synced live cursor: writes *order and *row (both -1 if unknown).
 * Returns 1 if a cursor is available, else 0. */
REWAMP_EXPORT int rewamp_pattern_cursor(int* order, int* row);

/* Like rewamp_pattern_cursor, but also writes *frac ∈ [0,1): how far the heard
 * position has advanced from THIS row toward the next captured row, for smooth
 * (sub-row) scrolling. Interpolated from the real sample positions of adjacent
 * captures, so it stays synced under tempo changes; 0 when the span is unknown
 * or non-monotonic (pattern break/loop). */
REWAMP_EXPORT int rewamp_pattern_cursor_frac(int* order, int* row, float* frac);

#ifdef __cplusplus
}
#endif

#endif /* REWAMP_PATTERN_H */

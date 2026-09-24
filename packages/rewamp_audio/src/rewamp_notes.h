#ifndef REWAMP_NOTES_H
#define REWAMP_NOTES_H

#include <stdint.h>
#include "rewamp_plugin.h"   /* RewampPluginVTable (typedef anonyme: pas de forward-decl possible) */
#include "rewamp_audio.h"  /* REWAMP_EXPORT */

#ifdef __cplusplus
extern "C" {
#endif

/* Look-ahead note timeline for the scrolling-notation visualizer.
 *
 * The audio data source decodes AHEAD of playback (see rewamp_datasource) and,
 * after each small decode step, captures a "column" of the current per-voice
 * note frequencies (Hz) tagged with the producer sample position. The visualizer
 * polls a window [played, played + aheadSec] and draws scrolling note blocks.
 *
 * Frequencies (not MIDI notes) are stored — the Dart layer maps Hz → vertical
 * position via log2. 0 Hz = voice silent. */

/* Reset the timeline for a new track / after a seek. voiceCount = active voices. */
void rewamp_notes_reset(int voiceCount);

/* Frontière gapless: n'efface RIEN (l'oreille est encore dans le morceau
 * précédent), change seulement le nombre de voix et le taux pour les captures à
 * venir. Voir rewamp_notes.c. */
void rewamp_notes_new_epoch(int voiceCount, int sampleRate);

/* Numéro d'ÉCHANTILLON par voie, lu dans la GRILLE de motifs du greffon au
 * curseur courant (order,row) — pour les moteurs qui ne l'écrivent pas dans
 * vgm_last_instr[] (zxtune, libpt3: leur échantillon vit dans la grille, pas
 * dans l'état par voie). Appelé par le producteur, sous decodeLock, à chaque
 * échantillon du curseur; ne refait le pattern_get qu'au changement de motif.
 * La capture prend vgm_last_instr[] s'il est non nul, sinon cette valeur. */
void rewamp_notes_grid_update(const RewampPluginVTable* vt,
                              RewampDecoder* dec, int order, int row);

/* Capture one column: reads the current vgm_last_note[] (Hz) for all voices and
 * stores it tagged with [producerSamplePos]. Called by the producer per step. */
void rewamp_notes_capture(int64_t producerSamplePos);

/* Updates the playhead (consumer sample position) — what is currently heard. */
void rewamp_notes_set_played(int64_t playedSamplePos);

/* Same, for a SEEK: the playhead moves but the audio from there has not
 * started yet, so the display clock is held until a consumer update moves it
 * (a load holds it too, through rewamp_notes_reset). */
void rewamp_notes_seek_played(int64_t playedSamplePos);

/* Instruments visibles, datés (implémentation et contrat dans le .c). */
int rewamp_notes_instruments_window(double fromSec, double toSec, int32_t* out, int max);
int rewamp_notes_voice_instruments(int32_t* out, int max);

/* Pause flag from the transport (rewamp_pause/play). While paused the
 * interpolated playhead stops extrapolating (it kept running up to the
 * 0.25 s cap after the last consumer update, so the notation scrolled on
 * for a beat after pause and resumed out of sync). */
void rewamp_notes_set_paused(int paused);
REWAMP_EXPORT int rewamp_notes_paused(void);

/* Sample rate of the CURRENT track's data source (frames/sec of the sample
 * positions above). Set at load; defaults to 44100. The notes renderer must
 * scroll at this rate — a hardcoded 44100 made low-rate tracks (32 kHz 2sf,
 * 11 kHz vgmstream) overshoot the playhead and visibly jerk backwards. */
void rewamp_notes_set_rate(int sampleRate);
REWAMP_EXPORT double rewamp_notes_rate(void);

/* ── FFI (visualizer) ──────────────────────────────────────────────────────── */

/* Number of voices currently tracked (0 = none / non-chip backend). */
REWAMP_EXPORT int rewamp_notes_voice_count(void);

/* Current look-ahead in seconds (producer − consumer), capped by the ring. */
REWAMP_EXPORT double rewamp_notes_lead_seconds(void);

/* Fills [out] (cols * voiceCount floats, column-major) with per-voice note Hz
 * over the window [played, played + aheadSec], column 0 = now. out must hold at
 * least cols * rewamp_notes_voice_count() floats. Returns the voice count (0 if
 * none). 0.0 in a cell = voice silent at that time. */
REWAMP_EXPORT int rewamp_notes_window(float* out, int cols, double aheadSec, int sampleRate);

/* Current playhead (consumer) sample position. */
int64_t rewamp_notes_played(void);

/* Playhead extrapolated to wall-clock now (fractional samples) for smooth
 * scrolling between audio callbacks. */
double rewamp_notes_played_interp(int sampleRate);

/* Smoothed, rate-locked, monotonic display playhead built on the above. Every
 * visualizer that scrolls with the music must use THIS one: the interpolated
 * value snaps at each audio callback, and callback jitter is what judder is
 * made of. Call once per rendered frame. */
double rewamp_notes_played_smooth(void);

/* Même valeur, SANS faire avancer l'horloge: pour tout appelant qui n'est pas
 * le rendu (voir le commentaire dans le .c). */
double rewamp_notes_played_display(void);

/* Collects raw stored columns whose sample position is in [fromSample, toSample].
 * outHz   : count * voiceCount floats (per-voice note value, column-major).
 * outPos  : count int64 sample positions.
 * Returns the number of columns written (≤ maxCols). Voice count via
 * rewamp_notes_voice_count(). Used by the GL renderer for smooth, absolutely-
 * positioned note blocks. */
int rewamp_notes_collect(int64_t fromSample, int64_t toSample,
                         float* outHz, uint8_t* outVol, uint8_t* outInstr,
                         int64_t* outPos, int maxCols);

#ifdef __cplusplus
}
#endif

#endif /* REWAMP_NOTES_H */

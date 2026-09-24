#ifndef REWAMP_DATASOURCE_H
#define REWAMP_DATASOURCE_H

#include "miniaudio.h"
#include "rewamp_plugin.h"
#include "rewamp_declick.h"
#include <pthread.h>
#if defined(__APPLE__)
#include <os/lock.h>
#endif

/* The lock the REALTIME audio thread takes to pop from the ring.
 *
 * On Apple this must NOT be a pthread_mutex: Darwin's has no priority
 * inheritance, so if the producer is preempted by the UI while holding it, the
 * realtime thread blocks on a thread that isn't running — a priority inversion.
 * That is audible as a crackle *with the ring still full*, i.e. with no underrun
 * counted, which is exactly what we observed (libopenmpt crackled during a
 * search while the underrun counter stayed put).
 *
 * os_unfair_lock donates the waiter's priority to the owner, so the producer is
 * boosted out of the way instead of stalling the audio thread. Elsewhere, a
 * plain mutex (Linux/Windows futexes behave acceptably here).
 */
#if defined(__APPLE__)
  typedef os_unfair_lock RewampRingLock;
#else
  typedef pthread_mutex_t RewampRingLock;
#endif

/* The one rate the decode-ahead ring runs at (see rewamp_datasource.c). Also
 * the domain of the generic fadeout window (g_loop_fadeout_*): a decoder whose
 * native rate differs is resampled by the producer, so frame counts derived
 * from its native rate must be scaled to this one. */
#define REWAMP_RING_RATE 44100

#ifdef __cplusplus
extern "C" {
#endif

// A miniaudio data source backed by a Rewamp plugin decoder. Bridges our
// float32 PCM plugin output into miniaudio's pipeline (device, resampling,
// position tracking) so the rest of the engine code is decoder-agnostic.
typedef struct {
    ma_data_source_base       base;
    const RewampPluginVTable* vt;
    RewampDecoder*            decoder;
    RewampAudioFormat         format;
    ma_uint64                 cursor;       // consumer position, in frames

    // Decode-ahead ring, filled by a DEDICATED PRODUCER THREAD (ds_producer_main).
    //
    // The audio callback (ds_read) never calls the decoder: it only pops already
    // decoded frames. That is the whole point — decoding a chip emulator inside
    // the realtime callback leaves zero slack, so any spike (a debug build, a
    // GL/UI burst, thermal throttling) misses the device deadline and crackles.
    // With a lead the producer can be starved for the whole buffer instead of a
    // single period. Interleaved float frames.
    float*                    ring;
    int                       ringCap;      // capacity in frames
    int                       ringHead;     // write index (frames) — producer
    int                       ringTail;     // read index  (frames) — consumer
    int                       ringFill;     // frames currently buffered
    float*                    stepBuf;      // scratch for one decode step (producer only)
    int                       stepBufCap;   // frames (a little above DS_STEP_FRAMES)
    int                       channels;
    int64_t                   producerPos;  // frames decoded so far
    int                       eof;          // decoder reached end

    // Guards the plugin decoder: producer thread vs ds_seek()'s thread. For
    // CPU-emulation backends (UADE/vio2sf/SNDH/lazyusf/highlyexp/…) read() and
    // seek() mutate the same live emulator state, not just ds's own fields.
    // The realtime audio thread NEVER takes this — it cannot be blocked by a
    // decode or a seek.
    pthread_mutex_t           decodeLock;

    // Guards the ring fields above (producer vs audio callback vs seek). Held
    // only across a memcpy — never across a decode — so the realtime thread's
    // wait is short AND, on Apple, priority-donating (see RewampRingLock).
    RewampRingLock            ringLock;
    pthread_t                 producer;
    int                       producerStarted;
    volatile int              producerStop;

    // Audio-thread-only: when the previous ds_read entered (µs, monotonic).
    // Used to tell a LATE callback (the OS didn't schedule us) from a SLOW one
    // (we blocked on a lock) — the two have opposite fixes.
    int64_t                   lastReadUs;

    // ── Gapless handoff (see rewamp_set_next_file) ──────────────────────────
    // The producer thread, on decoder EOF, may close the current decoder and
    // open the staged next track IN PLACE — same ring, same ma_sound — so the
    // audio callback never sees a break. `handoffFrame` is the absolute ring
    // frame where the next track's first frame landed; `trackBase` is the
    // absolute frame where the CURRENT track started (0 for the first one).
    // The consumer promotes handoffFrame → trackBase when its cursor crosses
    // it (that is the audible boundary), bumping the global handoff serial
    // Dart polls to flip title/metadata exactly when the ear hears the change.
    // While a handoff's open() runs, `decoder` is briefly NULL — every caller
    // that dereferences it must guard (pattern getters, ds_seek, length).
    int64_t                   trackBase;      // frames — current track's origin
    int                       handoffPending; // producer switched, consumer not yet
    int64_t                   handoffFrame;   // frames — where the next track starts

    // ── Fixed-rate ring: the ring ALWAYS runs at 44100 (DS_RING_RATE) ───────
    // The producer resamples any decoder whose native rate differs (openmpt
    // and SID render at 48 kHz, vgmstream/PSF variants at whatever the rip
    // uses). This is what lets two tracks of DIFFERENT rates share one ring —
    // gapless across rates, and the crossfade's mix stage. The CAPTURES
    // (per-voice scopes, notes, pattern cursor) stay keyed in the decoder's
    // NATIVE domain — their internals never see the resampler — and the
    // consumer-side reads translate ring→native through the per-segment bases
    // below. When nativeRate == 44100 the translation is the identity.
    uint32_t                  nativeRate;         // current decoder's own rate
    uint32_t                  prevNativeRate;     // outgoing track's, while pending
    int                       rsActive;           // nativeRate != DS_RING_RATE
    int                       rsInit;             // ma_linear_resampler is live
    ma_linear_resampler       rs;
    float*                    nativeBuf;          // one native decode step
    int                       nativeBufCap;       // frames
    int64_t                   producerPosNative;  // native frames decoded (monotonic)
    int64_t                   trackBaseNative;    // native origin of current track
    int64_t                   pendingBaseNative;  // native origin of the staged track
    int64_t                   trackLenRing;       // vt->length in RING frames (0 = unknown)

    // ── Crossfade (producer only): the outgoing track's tail, fully decoded
    // ahead of the handoff, mixed equal-power over the incoming track's head.
    // xfMode: 0 = none; 1 = MIX (tail × cos + incoming × sin, the crossfade);
    // 2 = DRAIN (the handoff could not happen after the tail was already
    // pulled out of the decoder — play the tail untouched, then resume).
    float*                    xfTail;             // ring-rate frames, interleaved
    int64_t                   xfTailLen;
    int64_t                   xfTailPos;
    int                       xfMode;
    // Fondu de sortie armé par le producteur (fin de file sous crossfade) —
    // à DÉSARMER si un suivant est finalement armé avant la fin, sinon la
    // fenêtre de ds_read fondrait AUSSI le recouvrement du crossfade.
    int                       endFadeArmed;
    // Déclic de début de piste des rips CD (rewamp_declick.h), NULL sinon.
    // Posé par l'ouverture (rewamp_open_track décide sur le CHEMIN: un `.ape`
    // est joué par MAC, un `.ogg` par vgmstream — le déchet est dans le
    // fichier, pas dans le moteur), traversé par TOUTES les lectures du
    // décodeur, réarmé par un seek à 0, détruit avec le décodeur.
    RewampDeclick*            declick;
} RewampDataSource;

// Initialize a data source from an already-opened plugin decoder.
// Takes ownership: rewamp_data_source_uninit calls vt->close on the decoder.
ma_result rewamp_data_source_init(RewampDataSource* ds,
                                  const RewampPluginVTable* vt,
                                  RewampDecoder* decoder,
                                  RewampAudioFormat format,
                                  RewampDeclick* declick);

// ── Gapless handoff plumbing ────────────────────────────────────────────────
// rewamp_handoff_attempt (rewamp_datasource.c): close the current decoder,
// open the staged next track and swap it into `ds` — same ring, same sound.
// Returns 1 on success. Producer thread only, called WITHOUT decodeLock held.
int rewamp_handoff_attempt(RewampDataSource* ds);
// rewamp_handoff_open_next (rewamp_audio.c, which owns the open
// orchestration): consume the staged next track, apply its per-track loop
// settings and open it through the same registry cascade as rewamp_load_file.
int rewamp_handoff_open_next(const RewampPluginVTable** outVt,
                             RewampDecoder** outDec,
                             RewampAudioFormat* outFmt,
                             RewampDeclick** outDeclick);
// 1 when a next track is staged and not yet consumed (rewamp_audio.c).
int rewamp_next_staged(void);

void rewamp_data_source_uninit(RewampDataSource* ds);

#ifdef __cplusplus
}
#endif

#endif /* REWAMP_DATASOURCE_H */

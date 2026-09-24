#include "rewamp_datasource.h"
#include "rewamp_waveform.h"
#include "rewamp_notes.h"
#include "rewamp_pattern.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"   /* generic_mute_mask (stereo-fallback L/R mute) */

#include <math.h>          /* cos/sin — equal-power crossfade curves */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>          /* nanosleep — producer idle wait */
#if defined(__APPLE__)
#include <mach/mach.h>          /* thread_policy_set — realtime producer */
#include <mach/thread_policy.h>
#include <mach/mach_time.h>
#elif defined(__linux__) || defined(__ANDROID__)
#include <sched.h>              /* SCHED_FIFO — realtime producer */
#endif

/* Generic native forced-loop fadeout window (rewamp_audio.c) — see
 * rewamp_set_forced_loop's doc comment. -1 start = disabled. Applied
 * sample-accurately in ds_read() below, for ANY plugin's output. */
extern int64_t g_loop_fadeout_start_frame;
extern int64_t g_loop_fadeout_total_frames;

/* The ring's ONE rate — see the block comment near DS_STEP_FRAMES. */
#define DS_RING_RATE REWAMP_RING_RATE

/* Ring lock — priority-donating on Apple (see RewampRingLock in the header).
 * Never held across a decode, only across a memcpy. */
static inline void ring_lock_init(RewampRingLock* l) {
#if defined(__APPLE__)
    *l = (os_unfair_lock)OS_UNFAIR_LOCK_INIT;
#else
    pthread_mutex_init(l, NULL);
#endif
}
static inline void ring_lock(RewampRingLock* l) {
#if defined(__APPLE__)
    os_unfair_lock_lock(l);
#else
    pthread_mutex_lock(l);
#endif
}
static inline void ring_unlock(RewampRingLock* l) {
#if defined(__APPLE__)
    os_unfair_lock_unlock(l);
#else
    pthread_mutex_unlock(l);
#endif
}
static inline void ring_lock_destroy(RewampRingLock* l) {
#if !defined(__APPLE__)
    pthread_mutex_destroy(l);
#else
    (void)l;
#endif
}

/* Audio-thread telemetry — the audio thread increments, Dart polls. Plain
 * non-atomic counters on purpose: a torn read of a diagnostic counter is
 * harmless, and the audio thread must not pay for a barrier it doesn't need.
 *
 * Three counters, because a crackle has three different causes and they call
 * for opposite fixes:
 *
 *   underruns  — the ring came up short: the DECODER is falling behind.
 *                Lever: a longer look-ahead, or more producer priority.
 *
 *   slowReads  — ds_read itself took longer than it had any business taking.
 *                It only memcpys, so the time went into WAITING on ringLock:
 *                a lock-contention / priority-inversion problem inside our code.
 *
 *   lateReads  — ds_read was called far later than the device period. The
 *                callback itself was not scheduled in time: the OS is late, not
 *                us. Lever: a bigger device buffer — nothing in the ring will
 *                help.
 *
 * A crackle with underruns=0 AND slowReads=0 AND lateReads climbing means the
 * fix is NOT in this file. */
int64_t g_ds_underruns       = 0;
int64_t g_ds_underrun_frames = 0;
int64_t g_ds_slow_reads      = 0;
int64_t g_ds_late_reads      = 0;
/* Worst gap ever seen between two callbacks (µs). The COUNT says it happens;
 * this says how bad — 100 ms of starvation and 800 ms are not the same illness. */
int64_t g_ds_max_gap_us      = 0;

int64_t rewamp_underrun_count(void)  { return g_ds_underruns; }
int64_t rewamp_underrun_frames(void) { return g_ds_underrun_frames; }
int64_t rewamp_slow_read_count(void) { return g_ds_slow_reads; }
int64_t rewamp_late_read_count(void) { return g_ds_late_reads; }
int64_t rewamp_max_gap_us(void)      { return g_ds_max_gap_us; }

/* Monotonic count of audible track boundaries crossed by the CONSUMER (gapless
 * handoff promotions). Dart polls it each tick and, on change, flips the UI to
 * the next track — the flip happens when the boundary is HEARD, not when the
 * producer switched decoders (that can be a whole look-ahead earlier, 200 ms
 * to 8 s with the pattern viz). Never reset: Dart re-syncs its last-seen value
 * after every explicit load. Same "intentionally racy" discipline as the
 * telemetry counters above — a torn read costs one tick of latency, nothing. */
static int64_t g_handoff_serial = 0;
int64_t rewamp_handoff_serial(void) { return g_handoff_serial; }

/* Miroir global de `ds->handoffPending`: vrai entre le RELAIS (le producteur a
 * échangé le décodeur) et la PROMOTION (l'oreille franchit la frontière).
 *
 * C'est la question que les visualiseurs doivent poser — « ce que le décodeur
 * décrit est-il encore ce que j'entends ? » — et elle doit se répondre pour
 * TOUT moteur. La première version interrogeait l'époque du curseur de motifs,
 * qui n'est mise à jour que par une lecture de ce curseur: en grille
 * synthétisée (UADE n'expose aucun motif) elle restait figée, le gel ne se
 * levait jamais et le visualiseur ne pouvait plus revenir à une vraie grille de
 * motifs. Ici l'état vient de l'endroit qui le connaît. */
static volatile int g_handoff_pending = 0;
int rewamp_handoff_pending(void) { return g_handoff_pending; }

/* Crossfade duration (Réglages → Lecture), seconds; 0 = plain gapless.
 * Written by Dart (rewamp_set_crossfade_seconds, rewamp_audio.c), read by the
 * producer at each track end and by plugin open()s to suppress their own
 * default fadeouts (fading an already-faded tail double-attenuates and the
 * overlap would carry silence instead of music). */
double g_crossfade_seconds = 0.0;

/* Fin de piste posée par DART (secondes; 0 = inconnue). Les formats chip
 * (SID, NSF…) ne s'arrêtent JAMAIS d'eux-mêmes: leur durée vient d'un
 * catalogue (songlengths HVSC, songdb UADE) que seul Dart connaît — y compris
 * ses corrections ASYNCHRONES. Sans cette valeur, ni gapless ni crossfade
 * pour eux: le producteur ne voit jamais d'EOF, et c'était Dart qui coupait
 * (audio.stop → rechargement complet, avec le trou). Le producteur n'y COUPE
 * que lorsqu'un suivant est armé — sinon la fin reste l'affaire de Dart,
 * comportement historique inchangé. Remise à zéro à chaque load/handoff
 * (rewamp_audio.c); Dart re-pose à chaque piste et à chaque correction. */
double g_track_end_seconds = 0.0;

/* Fin effective de la piste EN PRODUCTION, en frames RING absolues.
 * La longueur du décodeur fait foi quand il en a une; sinon la durée Dart.
 * 0 = pas de fin connue. */
static int64_t ds_effective_end_ring(const RewampDataSource* ds) {
    if (ds->trackLenRing > 0) return ds->trackBase + ds->trackLenRing;
    if (g_track_end_seconds > 0.0)
        return ds->trackBase + (int64_t)(g_track_end_seconds * DS_RING_RATE);
    return 0;
}

/* Ring→native translation for the consumer-side capture reads. The store keys
 * are NATIVE frames (chip cores write one entry per native frame); the
 * consumer's cursor runs in ring frames. Segment-aware: while a boundary is
 * pending, frames before it still belong to the OUTGOING track and translate
 * through its rate/base. Identity when the segment's rate is DS_RING_RATE. */
static int64_t ds_ring_to_native(const RewampDataSource* ds, int64_t ringPos) {
    int64_t base, nbase;
    uint32_t rate;
    if (ds->handoffPending && ringPos < ds->handoffFrame) {
        base  = ds->trackBase;
        nbase = ds->trackBaseNative;
        rate  = ds->prevNativeRate;
    } else if (ds->handoffPending) {
        base  = ds->handoffFrame;
        nbase = ds->pendingBaseNative;
        rate  = ds->nativeRate;
    } else {
        base  = ds->trackBase;
        nbase = ds->trackBaseNative;
        rate  = ds->nativeRate;
    }
    if (rate == DS_RING_RATE) return nbase + (ringPos - base);
    return nbase + (ringPos - base) * (int64_t)rate / DS_RING_RATE;
}

static inline int64_t ds_now_us(void) {
    struct timespec t;
#if defined(CLOCK_MONOTONIC)
    clock_gettime(CLOCK_MONOTONIC, &t);
#else
    timespec_get(&t, TIME_UTC);
#endif
    return (int64_t)t.tv_sec * 1000000 + t.tv_nsec / 1000;
}

/* Look-ahead targets. The notation visualizer scrolls FUTURE notes, so it needs
 * a big lead; ordinary playback only needs enough slack to absorb a decode spike
 * and scheduling jitter. The lead is also the latency of a mute / engine-setting
 * change (they are applied at decode time), which is why it is not simply "as
 * large as possible": 200 ms still reads as instant, 2 s would not. */
#define DS_LEAD_MAX_SECS  8.0   /* ring capacity: the largest look-ahead a viz can ask for.
                                 * A fullscreen pattern grid asks for as many seconds as it
                                 * shows future rows, and that grows with BOTH the surface
                                 * height and the user zoom (rows are a fixed logical size,
                                 * so zooming out doubles the row count). 4 s covered a
                                 * laptop window at zoom 1 and nothing beyond it — a tall
                                 * high-DPI screen clipped against the cap and the grid's
                                 * leading edge stayed blank. 8 s of stereo float is ~3 MB.
                                 * Only the pattern viz ever asks for this much; playback
                                 * still runs on DS_PLAY_LEAD_SECS. */
#define DS_PLAY_LEAD_SECS 0.2   /* ordinary playback */
#define DS_STEP_FRAMES    512   /* decode granularity (note-capture resolution ~11.6ms) */
/* DS_RING_RATE (defined at the top): the engine (ma_engine) already runs at
 * 44100; declaring the datasource at the same rate removes miniaudio's
 * per-sound resample and replaces it with ours in the producer — same stage
 * count as before, but now two tracks of different native rates can share one
 * ring (gapless across rates, and the crossfade mix). Captures stay NATIVE —
 * see the header. */
/* Tracker cursor sampling, INSIDE one decode step. The pattern viz interpolates
 * the sub-row scroll between two captures, so the capture period is the phase
 * error of that scroll: at 512 frames (11.6 ms) a 120 ms row (125 BPM, speed 6)
 * spans 10.3 captures and the displayed position sawtooths by 0.077 row, which
 * reads as a slow speed-up/slow-down cycle - measured, and worse on faster
 * tempos (0.17 row at speed 3). Sampling the cursor every 32 frames (0.7 ms)
 * divides it by sixteen, for 16 `read` calls per step on the four backends that
 * HAVE a cursor. That is FREE, measured rather than assumed: decoding 30 s of a
 * .mod costs 17.4 ms in 512-frame blocks and 10.5 ms in 32-frame ones (0.03 % of
 * a core) - the per-call overhead is nothing next to the mixing, and the smaller
 * working set actually helps. The ring must be sized to match: see PAT_COLS. */
#define DS_CURSOR_SUB_FRAMES 32
/* Cursor samples per decode step (see the producer). File-scope because the
 * tail decode of a crossfade reuses the same sampling arrays. */
enum { DS_CURSOR_MAX = DS_STEP_FRAMES / DS_CURSOR_SUB_FRAMES + 1 };
/* The crossfade slider is clamped here: the tail buffer must fit in memory and
 * the whole overlap is decoded in one burst (~300× realtime, so 8 s ≈ 30 ms
 * of decode). */
#define DS_XF_MAX_SECS 8.0

/* ── Ring helpers (interleaved float frames) ───────────────────────────────── */

static void ring_push(RewampDataSource* ds, const float* src, int frames) {
    const int ch = ds->channels;
    for (int i = 0; i < frames; i++) {
        float* dst = ds->ring + (size_t)ds->ringHead * ch;
        for (int c = 0; c < ch; c++) dst[c] = src[i * ch + c];
        ds->ringHead = (ds->ringHead + 1) % ds->ringCap;
    }
    ds->ringFill += frames;
}

static int ring_pop(RewampDataSource* ds, float* dst, int frames) {
    const int ch = ds->channels;
    int n = frames < ds->ringFill ? frames : ds->ringFill;
    for (int i = 0; i < n; i++) {
        const float* src = ds->ring + (size_t)ds->ringTail * ch;
        for (int c = 0; c < ch; c++) dst[i * ch + c] = src[c];
        ds->ringTail = (ds->ringTail + 1) % ds->ringCap;
    }
    ds->ringFill -= n;
    return n;
}

/* Reactive lead growth — defense in depth, self-contained (the UI is never
 * involved: audio immunity to UI load is the realtime scheduling's job, below).
 * An underrun proves the 200 ms lead was too short for whatever just happened,
 * so it grows to 1 s for the next 15 s and decays back — bounding mute latency
 * cost to the aftermath of an actual failure instead of paying it always. */
#define DS_BOOST_LEAD_SECS 1.0
#define DS_BOOST_HOLD_US   (15 * 1000 * 1000)
static volatile int64_t g_ds_boost_until_us = 0;

/* How full the producer keeps the ring, in frames. Follows the visualizer: the
 * notation view scrolls future notes and needs the full lead, everything else
 * just needs slack. Clamped so a step always fits. */
static int ds_target_fill(const RewampDataSource* ds) {
    /* The per-viz seconds value is authoritative (the binary setter keeps it in
     * sync): 0 ⇒ no viz ⇒ ordinary playback slack, so hiding the viz shrinks the
     * lead back immediately. Clamped to the ring below. */
    double secs = rewamp_get_lookahead_seconds();
    if (secs < DS_PLAY_LEAD_SECS) secs = DS_PLAY_LEAD_SECS;
    if (secs > DS_LEAD_MAX_SECS)  secs = DS_LEAD_MAX_SECS;
    if (secs < DS_BOOST_LEAD_SECS && ds_now_us() < g_ds_boost_until_us) {
        secs = DS_BOOST_LEAD_SECS;
    }
    int target = (int)(secs * (double)ds->format.sampleRate);
    const int cap = ds->ringCap - DS_STEP_FRAMES;
    if (target > cap) target = cap;
    if (target < DS_STEP_FRAMES) target = DS_STEP_FRAMES;
    return target;
}

/* Toutes les lectures du décodeur passent ici: le déclic de début de piste,
 * quand il y en a un, lit la source un peu EN AVANCE et rend exactement ce
 * qu'on lui demande; désarmé et vidé, il rappelle la source sans copie. */
static uint64_t ds_decode_src(void* user, float* out, uint64_t frames) {
    RewampDataSource* ds = (RewampDataSource*)user;
    return ds->vt->read(ds->decoder, out, frames);
}
static uint64_t ds_decode(RewampDataSource* ds, float* dst, uint64_t want) {
    if (ds->declick != NULL)
        return rewamp_declick_read(ds->declick, dst, want, ds_decode_src, ds);
    return ds->vt->read(ds->decoder, dst, want);
}

/* Read up to `ringWant` ring-frames' worth of NATIVE audio from the decoder,
 * into nativeBuf (when resampling) or straight into stepBuf (identity),
 * sampling the tracker cursor on the way. Advances producerPosNative.
 * Returns native frames read (0 = EOF or no decoder). decodeLock held by the
 * caller. */
static int ds_read_native_step(RewampDataSource* ds, int ringWant,
                               int* curOff, int* curOrd, int* curRow,
                               int* curCount, int curMax) {
    *curCount = 0;
    if (ds->decoder == NULL) return 0;
    int want = ringWant;
    float* dst = ds->stepBuf;
    if (ds->rsActive) {
        want = (int)((int64_t)ringWant * ds->nativeRate / DS_RING_RATE);
        if (want < 1) want = 1;
        if (want > ds->nativeBufCap) want = ds->nativeBufCap;
        dst = ds->nativeBuf;
    }
    int got = 0;
    if (ds->vt->pattern_cursor != NULL) {
        /* Same total frames, read in sub-steps so the cursor is sampled more
         * often — the pattern viz interpolates between two samples, so their
         * spacing IS its scroll jitter. */
        while (got < want) {
            int w = want - got;
            if (w > DS_CURSOR_SUB_FRAMES) w = DS_CURSOR_SUB_FRAMES;
            int n = (int)ds_decode(ds, dst + (size_t)got * ds->channels,
                                   (uint64_t)w);
            if (n <= 0) break;
            got += n;
            int order = -1, row = -1;
            ds->vt->pattern_cursor(ds->decoder, &order, &row);
            rewamp_notes_grid_update(ds->vt, ds->decoder, order, row);
            /* A decoder is free to return FEWER frames than asked — past the
             * last slot, keep overwriting it: the newest sample wins. */
            int slot = *curCount < curMax ? *curCount : curMax - 1;
            curOff[slot] = got;
            curOrd[slot] = order;
            curRow[slot] = row;
            if (*curCount < curMax) (*curCount)++;
        }
    } else {
        got = (int)ds_decode(ds, dst, (uint64_t)want);
        if (got < 0) got = 0;
    }
    ds->producerPosNative += got;
    return got;
}

/* Convert the native frames just read into ring-rate frames in stepBuf.
 * Identity when the rates match; otherwise runs the producer resampler,
 * looping so no input frame is silently dropped. */
static int ds_to_ring_frames(RewampDataSource* ds, int nativeGot) {
    if (nativeGot <= 0) return 0;
    if (!ds->rsActive) return nativeGot;
    const int cap = ds->stepBufCap;
    const float* src = ds->nativeBuf;
    ma_uint64 remainIn = (ma_uint64)nativeGot;
    ma_uint64 totalOut = 0;
    while (remainIn > 0 && totalOut < (ma_uint64)cap) {
        ma_uint64 in  = remainIn;
        ma_uint64 out = (ma_uint64)cap - totalOut;
        if (ma_linear_resampler_process_pcm_frames(
                &ds->rs, src, &in,
                ds->stepBuf + (size_t)totalOut * ds->channels, &out) != MA_SUCCESS)
            break;
        if (in == 0 && out == 0) break;   /* no progress — bail, don't spin */
        src      += (size_t)in * ds->channels;
        remainIn -= in;
        totalOut += out;
    }
    return (int)totalOut;
}

/* Crossfade trigger — producer thread. When the end of the current track is
 * inside the crossfade window and a next track is staged, pull the WHOLE
 * remaining tail out of the decoder in one burst (the producer decodes far
 * faster than realtime), hand off to the next track, and let the step path
 * mix tail×cos + head×sin from then on. Needs a KNOWN length: a track whose
 * end cannot be predicted plays plain gapless instead. */
static void ds_maybe_start_crossfade(RewampDataSource* ds) {
    double xf = g_crossfade_seconds;
    if (xf <= 0.0) return;
    if (xf > DS_XF_MAX_SECS) xf = DS_XF_MAX_SECS;
    if (ds->xfMode != 0) return;
    ring_lock(&ds->ringLock);
    const int pending = ds->handoffPending;
    ring_unlock(&ds->ringLock);
    if (pending) return;
    const int64_t endRing = ds_effective_end_ring(ds);
    if (endRing <= 0) return;

    const int64_t xfFrames = (int64_t)(xf * DS_RING_RATE);
    if (ds->producerPos + DS_STEP_FRAMES < endRing - xfFrames) return;

    if (!rewamp_next_staged()) {
        // Fin de FILE (rien d'armé) avec crossfade actif: les fondus par
        // défaut des moteurs ont été supprimés à l'open — sans rien à leur
        // place la piste finirait en COUPE SÈCHE (payé sur un SPC: gme coupait
        // net là où son fondu de 4 s adoucissait). On arme la fenêtre de fondu
        // générique de ds_read sur la fin du recouvrement qu'un crossfade
        // aurait couvert — même mécanisme, échantillon-exact, déjà éprouvé par
        // la boucle forcée. Jamais par-dessus une fenêtre déjà armée (boucle
        // forcée avec fondu utilisateur), et une seule fois par piste (le
        // start >= 0 fait office de verrou; remis à -1 par load/handoff).
        if (g_loop_fadeout_start_frame < 0 && !ds->endFadeArmed) {
            g_loop_fadeout_start_frame  = endRing - xfFrames;
            g_loop_fadeout_total_frames = xfFrames;
            ds->endFadeArmed = 1;
        }
        return;
    }
    if (ds->endFadeArmed) {
        // Un suivant vient d'être armé APRÈS le fondu de sortie: le crossfade
        // reprend la main — désarmer la fenêtre, sinon ds_read fondrait AUSSI
        // le recouvrement (tête entrante comprise).
        g_loop_fadeout_start_frame = -1;
        ds->endFadeArmed = 0;
    }

    /* La rafale s'arrête à la FIN DE PISTE, décodeur d'accord ou pas: les
     * moteurs qui ne finissent jamais (SID/NSF, fin posée par Dart) rendraient
     * des frames pour toujours, et un length() menteur tronque à la longueur
     * déclarée — celle que le catalogue annonce de toute façon. */
    int64_t cap = endRing - ds->producerPos;
    if (cap <= 0) return;
    float* tail = (float*)malloc((size_t)cap * ds->channels * sizeof(float));
    if (tail == NULL) return;

    int64_t n = 0;
    int sawEof = 0;
    pthread_mutex_lock(&ds->decodeLock);
    while (n < cap) {
        int co[DS_CURSOR_MAX], cd[DS_CURSOR_MAX], cr[DS_CURSOR_MAX], cc = 0;
        const int64_t sn = ds->producerPosNative;
        int roomN = (int)(cap - n);
        if (roomN > DS_STEP_FRAMES) roomN = DS_STEP_FRAMES;
        int ng = ds_read_native_step(ds, roomN, co, cd, cr, &cc, DS_CURSOR_MAX);
        if (ng <= 0) { sawEof = 1; break; }
        int rg = ds_to_ring_frames(ds, ng);
        if (rg > 0) {
            memcpy(tail + (size_t)n * ds->channels, ds->stepBuf,
                   (size_t)rg * ds->channels * sizeof(float));
            n += rg;
        }
        /* Captures for the tail: it PLAYS later, but its native keys are laid
         * down now — the consumer translation finds them when it gets there. */
        ring_lock(&ds->ringLock);
        rewamp_notes_capture(ds->producerPosNative);
        rewamp_channel_data_capture_delayed(sn,
                                            (int)(ds->producerPosNative - sn));
        for (int i = 0; i < cc; i++)
            rewamp_pattern_cursor_capture(sn + co[i], cd[i], cr[i]);
        ring_unlock(&ds->ringLock);
    }
    pthread_mutex_unlock(&ds->decodeLock);
    /* Bout de rafale atteint = fin de piste, même si le décodeur en avait
     * encore (moteurs sans fin, length() long). */
    if (n >= cap) sawEof = 1;

    if (n == 0) {
        /* Nothing left to fade over (length() said otherwise). Plain path. */
        free(tail);
        if (sawEof && rewamp_next_staged()) rewamp_handoff_attempt(ds);
        return;
    }
    ds->xfTail = tail;
    ds->xfTailLen = n;
    ds->xfTailPos = 0;
    /* Hand off NOW (the boundary lands at the overlap's start — that is where
     * the UI flips, like every streaming player). Failure → DRAIN: the pulled
     * tail plays untouched and the plain end-of-track path follows. */
    ds->xfMode = (sawEof && rewamp_handoff_attempt(ds)) ? 1 : 2;
}

/* The decoder now lives HERE, on its own thread — never on the audio callback.
 *
 * Holds decodeLock across decode+push, so a concurrent ds_seek() (which takes
 * the same lock) can never land between the two and have this thread push stale,
 * pre-seek frames into a ring it just flushed. ringLock is taken only for the
 * memcpy, so the audio thread never waits on a decode. */
static void* ds_producer_main(void* arg) {
    RewampDataSource* ds = (RewampDataSource*)arg;

#if defined(__APPLE__)
    // REALTIME scheduling, not QoS. This is the architectural point: any QoS
    // class — even USER_INTERACTIVE — lives in the same band as UI work, so a
    // search saturating the cores could still starve this thread (measured:
    // 8 underruns during one search). Audio must be immune to UI load BY
    // CONSTRUCTION, and the mechanism for that on Darwin is the time-constraint
    // policy — the same band Core Audio's own IO thread runs in, scheduled by
    // deadline above the entire QoS hierarchy.
    //
    // The contract: we declare a duty cycle (each DS_STEP_FRAMES ≈ 11.6 ms of
    // audio takes ~1-2 ms to decode; budget 5 ms of CPU per 10 ms window) and
    // the kernel guarantees it — but demotes threads that overrun their stated
    // budget, so the numbers are deliberately generous rather than tight.
    {
        mach_timebase_info_data_t tb;
        mach_timebase_info(&tb);
        const double ms2abs = 1e6 * (double)tb.denom / (double)tb.numer;
        thread_time_constraint_policy_data_t p;
        p.period      = (uint32_t)(10.0 * ms2abs);  /* wake every ~10 ms   */
        p.computation = (uint32_t)( 5.0 * ms2abs);  /* CPU needed per wake */
        p.constraint  = (uint32_t)(10.0 * ms2abs);  /* finish within       */
        p.preemptible = TRUE;
        thread_policy_set(mach_thread_self(), THREAD_TIME_CONSTRAINT_POLICY,
                          (thread_policy_t)&p, THREAD_TIME_CONSTRAINT_POLICY_COUNT);
    }
#elif defined(__linux__) || defined(__ANDROID__)
    // Same idea elsewhere: SCHED_FIFO puts the thread above every CFS (i.e.
    // UI) thread. May be refused without privileges — then we keep the default
    // and the ring's slack is the only protection, as before.
    {
        struct sched_param sp = { .sched_priority = 1 };
        pthread_setschedparam(pthread_self(), SCHED_FIFO, &sp);
    }
#endif

    /* Poll rather than wait on a condvar: a condvar needs a pthread_mutex, and
     * the ring lock must be an os_unfair_lock on Apple (priority donation — see
     * the header).
     *
     * 10 ms, not 2: this thread runs at USER_INTERACTIVE, and it only sleeps
     * when the ring is FULL — with a 200 ms lead there is nothing to gain from
     * waking 500×/s, and every wake takes ringLock, i.e. contends with the
     * realtime audio thread. Cheap CPU we should not be spending on a phone. */
    const struct timespec idle = { 0, 10 * 1000 * 1000 };   /* 10 ms */

    while (!ds->producerStop) {
        ring_lock(&ds->ringLock);
        const int atEof = ds->eof;
        const int done = atEof || ds->ringFill >= ds_target_fill(ds);
        int room = ds->ringCap - ds->ringFill;
        ring_unlock(&ds->ringLock);

        if (done) {
            // A next track staged AFTER this decoder already hit EOF (Dart can
            // arm at any time, e.g. once a download lands mid-drain): attempt
            // the handoff from here, not only from the EOF read below —
            // otherwise the loop would sleep on eof forever with a ready next
            // track staged.
            if (atEof && rewamp_next_staged() && rewamp_handoff_attempt(ds)) {
                ring_lock(&ds->ringLock);
                ds->eof = 0;
                ring_unlock(&ds->ringLock);
                continue;
            }
            nanosleep(&idle, NULL);
            continue;
        }

        int step = DS_STEP_FRAMES;
        if (step > room) step = room;
        if (step <= 0) { nanosleep(&idle, NULL); continue; }

        // Crossfade trigger: the end of the current track approaches, a next
        // one is staged, and no boundary is already in flight → pull the whole
        // remaining tail out of the decoder, hand off, and mix from now on.
        ds_maybe_start_crossfade(ds);

        // Fin SYNTHÉTIQUE (gapless sans crossfade): un moteur qui ne s'arrête
        // jamais (SID, NSF…) se termine à la fin effective — length() du
        // décodeur, sinon la durée posée par Dart. SEULEMENT quand un suivant
        // est armé: sans relais, la coupe reste l'affaire de Dart (durées
        // asynchrones, filets existants), comportement historique inchangé.
        int syntheticEof = 0;
        if (ds->xfMode == 0 && rewamp_next_staged()) {
            ring_lock(&ds->ringLock);
            const int pendingNow = ds->handoffPending;
            ring_unlock(&ds->ringLock);
            if (!pendingNow) {
                const int64_t end = ds_effective_end_ring(ds);
                if (end > 0) {
                    const int64_t remain = end - ds->producerPos;
                    if (remain <= 0)                syntheticEof = 1;
                    else if ((int64_t)step > remain) step = (int)remain;
                }
            }
        }

        pthread_mutex_lock(&ds->decodeLock);
        const int64_t stepStartNative = ds->producerPosNative;
        int nativeGot = 0;   // frames read from the decoder (native rate)
        int ringGot   = 0;   // frames produced into stepBuf (ring rate)
        /* Cursor samples taken inside this step: NATIVE frame offset +
         * (order,row). Recorded here and published under the ring lock below,
         * so the decode stays in one place and the publishing in another. */
        int curOff[DS_CURSOR_MAX];
        int curOrd[DS_CURSOR_MAX];
        int curRow[DS_CURSOR_MAX];
        int curCount = 0;

        if (syntheticEof) {
            // Rien à lire: la piste est finie par décision de calendrier. Le
            // got<=0 ci-dessous relaie (le suivant EST armé, condition de la
            // coupe) ou, si le relais échoue, pose l'eof classique.
            nativeGot = 0;
            ringGot   = 0;
        } else if (ds->xfMode == 2) {
            // DRAIN: the tail was already pulled out of the decoder but the
            // handoff never happened — play it back untouched. The decoder is
            // not consulted; captures were taken at tail-decode time.
            int64_t remain = ds->xfTailLen - ds->xfTailPos;
            int n = step < (int)remain ? step : (int)remain;
            memcpy(ds->stepBuf, ds->xfTail + (size_t)ds->xfTailPos * ds->channels,
                   (size_t)n * ds->channels * sizeof(float));
            ds->xfTailPos += n;
            ringGot   = n;
            nativeGot = 1;   // not EOF — the drain is audio, keep the loop alive
            if (ds->xfTailPos >= ds->xfTailLen) {
                free(ds->xfTail); ds->xfTail = NULL;
                ds->xfMode = 0;
            }
        } else {
            nativeGot = ds_read_native_step(ds, step, curOff, curOrd, curRow,
                                            &curCount, DS_CURSOR_MAX);
            ringGot = ds_to_ring_frames(ds, nativeGot);
            if (ds->xfMode == 1) {
                // MIX: equal-power crossfade of the outgoing tail over the
                // incoming track's head. When the incoming track ends inside
                // the overlap (shorter than the fade), finish the tail alone —
                // its curve keeps falling, the incoming side is silence.
                int64_t remain = ds->xfTailLen - ds->xfTailPos;
                int n = ringGot;
                if (n == 0 && remain > 0) {
                    n = step < (int)remain ? step : (int)remain;
                    memset(ds->stepBuf, 0,
                           (size_t)n * ds->channels * sizeof(float));
                    ringGot   = n;
                    nativeGot = 1;   // still audio to publish, not an EOF
                }
                int mixN = n < (int)remain ? n : (int)remain;
                for (int i = 0; i < mixN; i++) {
                    const double th = (double)(ds->xfTailPos + i) /
                                      (double)ds->xfTailLen * 1.5707963267948966;
                    const float gOut = (float)cos(th);
                    const float gIn  = (float)sin(th);
                    const float* t = ds->xfTail +
                                     (size_t)(ds->xfTailPos + i) * ds->channels;
                    float* o = ds->stepBuf + (size_t)i * ds->channels;
                    for (int c = 0; c < ds->channels; c++)
                        o[c] = t[c] * gOut + o[c] * gIn;
                }
                ds->xfTailPos += mixN;
                if (ds->xfTailPos >= ds->xfTailLen) {
                    free(ds->xfTail); ds->xfTail = NULL;
                    ds->xfMode = 0;
                }
            }
        }

        ring_lock(&ds->ringLock);
        if (ringGot > 0) {
            ring_push(ds, ds->stepBuf, ringGot);
            ds->producerPos += ringGot;
        }
        if (nativeGot > 0 && ds->xfMode != 2) {
            // Look-ahead state captured at PRODUCER time, keyed by absolute
            // NATIVE frame position: the note column and the per-voice
            // oscilloscope samples. The consumer side replays them at its own
            // position translated ring→native (ds_ring_to_native), which is
            // what keeps the scopes in sync with what is being HEARD.
            rewamp_notes_capture(ds->producerPosNative);
            rewamp_channel_data_capture_delayed(stepStartNative,
                                                (int)(ds->producerPosNative -
                                                      stepStartNative));
            // Live tracker cursor (order,row), keyed by the same native frame
            // so the pattern viz highlights the row being HEARD, not decoded.
            for (int i = 0; i < curCount; i++) {
                rewamp_pattern_cursor_capture(stepStartNative + curOff[i],
                                              curOrd[i], curRow[i]);
            }
        }
        ring_unlock(&ds->ringLock);
        pthread_mutex_unlock(&ds->decodeLock);

        int got = nativeGot;
        if (got <= 0) {
            // Decoder EOF. If a next track is staged, hand off IN PLACE: close
            // this decoder, open the next one, keep filling the same ring — the
            // audio callback never sees a break (gapless). Runs OUTSIDE
            // decodeLock: the open() of a chip engine can take hundreds of ms
            // and the pattern/param getters must not block on it. Sequential
            // close-then-open keeps the singleton engines (uadecore, sc68,
            // SNDH's single CPU context) safe — at no point do two live
            // instances exist. On failure (nothing staged, open failed, or a
            // rate/channel mismatch) fall back to the plain end-of-track path:
            // eof drains the ring, the sound stops, Dart advances as before.
            if (!(rewamp_next_staged() && rewamp_handoff_attempt(ds))) {
                ring_lock(&ds->ringLock);
                ds->eof = 1;
                ring_unlock(&ds->ringLock);
            }
        }
    }
    return NULL;
}

/* Gapless handoff, producer-thread side. Closes the current decoder, opens the
 * staged next track (rewamp_handoff_open_next, in rewamp_audio.c — the same
 * registry cascade as rewamp_load_file) and swaps it into `ds` so the SAME
 * ring keeps filling and the audio callback never sees a break.
 *
 * Sequential close-then-open on ONE thread is what keeps the singleton engines
 * safe (uadecore's single thread, sc68's process-global state, SNDH's single
 * CPU context): at no point do two live decoder instances exist. That is also
 * why a "pre-open the next track early" design was rejected.
 *
 * Runs OUTSIDE decodeLock except for the two brief swap points: the open() of
 * a chip engine can take hundreds of ms, and the pattern/param getters (Dart
 * UI thread) block on decodeLock — holding it across the open would jank the
 * UI at every track boundary. While the open runs, ds->decoder is NULL and
 * every dereference site guards on it. */
int rewamp_handoff_attempt(RewampDataSource* ds) {
    ring_lock(&ds->ringLock);
    const int alreadyPending = ds->handoffPending;
    ring_unlock(&ds->ringLock);
    // One boundary in flight at a time: a second handoff before the consumer
    // crossed the first would overwrite handoffFrame and a title flip would be
    // lost (only possible when a track is shorter than the look-ahead). Let
    // the plain end-of-track path handle that rarity.
    if (alreadyPending) return 0;
    if (!rewamp_next_staged()) return 0;

    // Detach + close the current decoder FIRST (singleton-engine rule).
    pthread_mutex_lock(&ds->decodeLock);
    const RewampPluginVTable* oldVt  = ds->vt;
    RewampDecoder*            oldDec = ds->decoder;
    RewampDeclick*            oldDk  = ds->declick;
    ds->decoder = NULL;
    ds->declick = NULL;
    pthread_mutex_unlock(&ds->decodeLock);
    if (oldDec != NULL && oldVt != NULL && oldVt->close != NULL)
        oldVt->close(oldDec);
    rewamp_declick_destroy(oldDk);

    const RewampPluginVTable* vt  = NULL;
    RewampDecoder*            dec = NULL;
    RewampDeclick*            dk  = NULL;
    RewampAudioFormat         fmt;
    memset(&fmt, 0, sizeof(fmt));
    if (!rewamp_handoff_open_next(&vt, &dec, &fmt, &dk)) return 0;

    // The ring's INTERLEAVE is fixed: a next track with a different channel
    // count declines the handoff (plain reload path). A different RATE is
    // fine — the producer resampler brings it to DS_RING_RATE.
    if ((int)fmt.channels != ds->channels) {
        if (vt->close != NULL) vt->close(dec);
        rewamp_declick_destroy(dk);
        return 0;
    }

    pthread_mutex_lock(&ds->decodeLock);
    ds->vt      = vt;
    ds->decoder = dec;
    ds->declick = dk;
    // Native-domain segment bookkeeping for the capture translation.
    ds->prevNativeRate    = ds->nativeRate;
    ds->nativeRate        = fmt.sampleRate;
    ds->rsActive          = (fmt.sampleRate != DS_RING_RATE);
    if (ds->rsActive) {
        if (!ds->rsInit) {
            ma_linear_resampler_config rc = ma_linear_resampler_config_init(
                ma_format_f32, (ma_uint32)ds->channels,
                fmt.sampleRate, DS_RING_RATE);
            rc.lpfOrder = MA_MAX_FILTER_ORDER;
            if (ma_linear_resampler_init(&rc, NULL, &ds->rs) == MA_SUCCESS)
                ds->rsInit = 1;
        } else {
            ma_linear_resampler_set_rate(&ds->rs, fmt.sampleRate, DS_RING_RATE);
            ma_linear_resampler_reset(&ds->rs);
        }
        if (!ds->rsInit || ds->nativeBuf == NULL) {
            /* Can't resample — undo the swap and decline (plain end path). */
            ds->decoder    = NULL;
            ds->declick    = NULL;
            ds->nativeRate = ds->prevNativeRate;
            ds->rsActive   = (ds->nativeRate != DS_RING_RATE);
            pthread_mutex_unlock(&ds->decodeLock);
            if (vt->close != NULL) vt->close(dec);
            rewamp_declick_destroy(dk);
            return 0;
        }
    }
    ds->pendingBaseNative = ds->producerPosNative;
    {
        uint64_t lenN = (vt->length != NULL) ? vt->length(dec) : 0;
        ds->trackLenRing = lenN
            ? (int64_t)(lenN * (uint64_t)DS_RING_RATE / fmt.sampleRate) : 0;
    }
    ring_lock(&ds->ringLock);
    ds->handoffPending = 1;
    ds->handoffFrame   = ds->producerPos;
    g_handoff_pending  = 1;
    ring_unlock(&ds->ringLock);
    // The fadeout window the open computed is track-relative; the cursor runs
    // absolute across handoffs.
    if (g_loop_fadeout_start_frame >= 0)
        g_loop_fadeout_start_frame += ds->handoffFrame;
    pthread_mutex_unlock(&ds->decodeLock);

    // ⚠️ **Ces états viz ne se remettent PAS à zéro sur une frontière gapless.**
    // Le relais a lieu des SECONDES avant que l'oreille n'y arrive (le
    // viz-pattern demande lui-même une avance d'une demi-hauteur d'écran), et
    // les effacer ici jetait la queue du morceau EN COURS: le motif s'arrêtait
    // avant la fin, la timeline des notes perdait ce qui n'était pas encore
    // entendu. Les deux réserves sont clefées par position ABSOLUE, donc elles
    // portent les DEUX morceaux à la fois; ce qui change, c'est la FORME d'une
    // capture (table d'ordres pour les motifs, nombre de voix pour les notes),
    // et c'est ce que l'époque étiquette. La bascule se fait quand l'oreille
    // franchit, comme le reste du gapless.
    rewamp_notes_new_epoch(rewamp_channel_count(), (int)fmt.sampleRate);
    rewamp_pattern_cursor_new_epoch();
    return 1;
}

/* Called at every exit of ds_read: the callback only memcpys, so anything past
 * a millisecond means it WAITED — on ringLock, i.e. lock contention inside our
 * own code (as opposed to the OS scheduling the callback late). */
static inline void ds_read_done(int64_t entryUs) {
    if (ds_now_us() - entryUs > 1000) g_ds_slow_reads++;
}

static ma_result ds_read(ma_data_source* pDataSource, void* pFramesOut,
                         ma_uint64 frameCount, ma_uint64* pFramesRead) {
    RewampDataSource* ds = (RewampDataSource*)pDataSource;

    // Which of the two is it? Measure, don't guess.
    //   entry - lastEntry  ≫ period  → the callback was SCHEDULED LATE (the OS).
    //   exit  - entry      ≫ 0       → we BLOCKED inside (a lock: our problem).
    // The callback only memcpys, so anything but microseconds inside is a wait.
    //
    // CAVEAT, learned the hard way: this measures the cadence of DATA-SOURCE
    // reads, not of device callbacks. While paused, the sound is stopped and we
    // are not read at all — so the first read after a resume would clock the
    // whole pause as a "late callback" (it reported 720 ms, which was simply how
    // long the user had paused for). rewamp_play() zeroes lastReadUs for that
    // reason. Any other pause in reads (end of sound, engine buffering) can
    // still colour this number: treat a lone late-read as a hint, not a verdict.
    const int64_t entryUs = ds_now_us();
    if (ds->lastReadUs != 0 && ds->format.sampleRate > 0) {
        const int64_t gapUs = entryUs - ds->lastReadUs;
        const int64_t periodUs =
            (int64_t)frameCount * 1000000 / (int64_t)ds->format.sampleRate;
        // 2× the period of slack before calling it late: normal jitter is fine,
        // and a device may legitimately batch two periods.
        if (gapUs > periodUs * 2 + 5000) g_ds_late_reads++;
        if (gapUs > g_ds_max_gap_us) g_ds_max_gap_us = gapUs;
    }
    ds->lastReadUs = entryUs;

    // No ring (allocation failed) → the old consumer-paced path: decode right
    // here. Same trylock caveat as before: never block the realtime thread on a
    // seek, emit silence for this callback instead.
    if (ds->ring == NULL) {
        if (pthread_mutex_trylock(&ds->decodeLock) != 0) {
            if (pFramesOut != NULL && frameCount > 0) {
                memset(pFramesOut, 0,
                       (size_t)frameCount * (size_t)ds->channels * sizeof(float));
            }
            if (pFramesRead != NULL) *pFramesRead = frameCount;
            ds_read_done(entryUs);
            return MA_SUCCESS;
        }
    }

    // The per-voice scope/notes data is captured at PRODUCER time, which now
    // always runs ahead — so the delayed store is always the one to read from.
    rewamp_channel_data_set_delayed(ds->ring != NULL);

    ma_uint64 framesRead = 0;
    if (pFramesOut != NULL && frameCount > 0) {
        if (ds->ring != NULL) {
            // Realtime path: pop only. NEVER decode here — that is what left the
            // callback with zero slack and made it crackle under load.
            ring_lock(&ds->ringLock);
            framesRead = ring_pop(ds, (float*)pFramesOut, (int)frameCount);
            const int atEnd = ds->eof && ds->ringFill == 0;
            // Gapless boundary: the frames just popped reach INTO the next
            // track — promote it. This is the audible instant the track
            // changes, so this is where the serial Dart polls is bumped
            // (title/metadata flip when the ear hears the change, not when the
            // producer switched a look-ahead earlier).
            if (ds->handoffPending &&
                (int64_t)(ds->cursor + framesRead) >= ds->handoffFrame) {
                ds->trackBase       = ds->handoffFrame;
                ds->trackBaseNative = ds->pendingBaseNative;
                ds->handoffPending  = 0;
                g_handoff_pending   = 0;
                g_handoff_serial++;
            }
            ring_unlock(&ds->ringLock);

            if (framesRead < frameCount && !atEnd) {
                // Underrun: the producer was starved for longer than the whole
                // lead. Pad with silence rather than stall the device, and do
                // NOT advance the cursor past frames that were never decoded —
                // producer and consumer positions must stay consistent or the
                // delayed voice store would be read at the wrong key.
                //
                // Counted, so "it still crackles" can be answered with evidence
                // instead of a guess: a rising count means the producer is being
                // starved (raise the lead / its priority); a flat count means the
                // crackle is NOT an underrun and the cause is elsewhere.
                g_ds_underruns++;
                g_ds_underrun_frames += (frameCount - framesRead);
                // The lead just proved too short for the current load — grow it
                // (reactive half of the adaptive lead; see rewamp_audio_boost).
                g_ds_boost_until_us = ds_now_us() + DS_BOOST_HOLD_US;
                float* out = (float*)pFramesOut;
                memset(out + framesRead * (size_t)ds->channels, 0,
                       (size_t)(frameCount - framesRead) * (size_t)ds->channels
                           * sizeof(float));
                if (pFramesRead != NULL) *pFramesRead = frameCount;
                ds->cursor += framesRead;
                {
                    const int64_t np = ds_ring_to_native(ds, (int64_t)ds->cursor);
                    rewamp_notes_set_played(np);
                    rewamp_channel_data_set_consumer_pos(np);
                    rewamp_pattern_cursor_set_played(np);
                }
                ds_read_done(entryUs);
                return MA_SUCCESS;
            }
        } else {
            framesRead = ds_decode(ds, (float*)pFramesOut, frameCount);
        }
        // Stereo-fallback mute: when the backend exposes no per-voice data
        // (rewamp_channel_count()==0 — MAC, vgmstream, miniaudio fallback),
        // generic_mute_mask bits 0/1 mute the LEFT/RIGHT output channels.
        // Applied BEFORE the waveform write so the stereo oscilloscope (which
        // displays this very output) follows automatically.
        if (framesRead > 0 && rewamp_channel_count_raw() == 0 &&
            (generic_mute_mask & 3) != 0 && ds->channels >= 2) {
            float* s = (float*)pFramesOut;
            const int ch = ds->channels;
            for (ma_uint64 i = 0; i < framesRead; i++) {
                if (generic_mute_mask & 1) s[i * ch]     = 0.0f;
                if (generic_mute_mask & 2) s[i * ch + 1] = 0.0f;
            }
        }
        // Generic native forced-loop fadeout: startPos is ds->cursor BEFORE
        // this read's increment below, so framePos = startPos+i is each
        // produced frame's absolute position — compared against the window
        // rewamp_load_file() computed from the plugin's own single-pass
        // length x (loop count+1).
        if (framesRead > 0 && g_loop_fadeout_start_frame >= 0) {
            const int64_t startPos = (int64_t)ds->cursor;
            float* buf = (float*)pFramesOut;
            const int ch = ds->channels;
            for (ma_uint64 i = 0; i < framesRead; i++) {
                const int64_t framePos = startPos + (int64_t)i;
                if (framePos < g_loop_fadeout_start_frame) continue;
                const int64_t into = framePos - g_loop_fadeout_start_frame;
                const float gain = (into >= g_loop_fadeout_total_frames)
                    ? 0.0f
                    : 1.0f - (float)into / (float)g_loop_fadeout_total_frames;
                for (int c = 0; c < ch; c++) buf[i * ch + c] *= gain;
            }
        }
        if (framesRead > 0)
            rewamp_waveform_write((const float*)pFramesOut, framesRead, ds->channels);
    }
    ds->cursor += framesRead;
    {
        // Captures keyed NATIVE, cursor in ring frames — translate per segment.
        const int64_t np = ds_ring_to_native(ds, (int64_t)ds->cursor);
        rewamp_notes_set_played(np);
        rewamp_channel_data_set_consumer_pos(np);
        rewamp_pattern_cursor_set_played(np);
    }

    if (ds->ring == NULL) pthread_mutex_unlock(&ds->decodeLock);
    if (pFramesRead != NULL) *pFramesRead = framesRead;
    ds_read_done(entryUs);
    if (framesRead == 0) return MA_AT_END;
    ds_read_done(entryUs);
    return MA_SUCCESS;
}

static ma_result ds_seek(ma_data_source* pDataSource, ma_uint64 frameIndex) {
    RewampDataSource* ds = (RewampDataSource*)pDataSource;
    // Blocking lock (unlike ds_read's trylock): this runs on g_seek_thread,
    // never the realtime audio thread, so it's fine to wait out whatever
    // single ds_read() callback is currently in flight (bounded — one
    // callback's worth of decode, milliseconds) before taking over the
    // decoder.
    // decodeLock is also what the producer holds across decode+push, so taking
    // it here guarantees no in-flight step can land in the ring we are about to
    // flush. Lock order everywhere: decodeLock → ringLock.
    pthread_mutex_lock(&ds->decodeLock);
    // Gapless handoff pending at seek time: the producer has already switched
    // to the NEXT decoder, so the previous track can no longer be seeked. The
    // least-surprise resolution is to promote the boundary first — the flush
    // below makes the consumer hear the new track immediately anyway, and the
    // serial bump tells Dart to flip the UI. The seek then lands in the new
    // track (a user dragging within the last look-ahead of a track is rare).
    ring_lock(&ds->ringLock);
    if (ds->handoffPending) {
        ds->trackBase       = ds->handoffFrame;
        ds->trackBaseNative = ds->pendingBaseNative;
        ds->handoffPending  = 0;
        g_handoff_pending   = 0;
        g_handoff_serial++;
    }
    const int64_t base = ds->trackBase;
    ring_unlock(&ds->ringLock);
    // frameIndex is TRACK-RELATIVE (Dart computes seconds×rate for the track
    // it shows); the ring/cursor domain is absolute across handoffs.
    const int64_t absIndex = base + (int64_t)frameIndex;

    // The decoder lives in its NATIVE frame domain; the ring (and Dart's
    // seconds×rate) in DS_RING_RATE. Identity for the 44100 majority.
    const int64_t nativeRel = (ds->nativeRate == DS_RING_RATE)
        ? (int64_t)frameIndex
        : (int64_t)frameIndex * (int64_t)ds->nativeRate / DS_RING_RATE;
    const int64_t nativeAbs = ds->trackBaseNative + nativeRel;

    // A crossfade tail pulled ahead of a seek describes audio whose time has
    // passed — drop it.
    if (ds->xfTail != NULL) { free(ds->xfTail); ds->xfTail = NULL; }
    ds->xfMode = 0;
    if (ds->rsInit) ma_linear_resampler_reset(&ds->rs);

    // Invariant: a seek NEVER changes the user's per-voice mute state. Some
    // plugins implement a backward seek by reloading the tune through their
    // open() path (pmd_load, eup_setup_and_load, …), which runs
    // rewamp_channel_data_reset() and zeroes generic_mute_mask — silently
    // dropping the mutes the user had engaged. Snapshot + restore around the
    // plugin seek so every engine (current and future) keeps the mask.
    {
        int64_t savedMute = generic_mute_mask;
        if (ds->decoder != NULL && ds->vt->seek != NULL) {
            ds->vt->seek(ds->decoder, (uint64_t)nativeRel);
        }
        // L'étage du déclic porte des trames lues en avance, périmées par le
        // repositionnement. Le clic est une propriété du DÉBUT du fichier: on
        // ne réarme que pour un retour à 0.
        if (ds->declick != NULL) rewamp_declick_reset(ds->declick, nativeRel == 0);
        generic_mute_mask = savedMute;
    }
    ds->cursor = (ma_uint64)absIndex;

    ring_lock(&ds->ringLock);
    // Flush the look-ahead ring + note timeline; both refill from the new pos.
    ds->ringHead = ds->ringTail = ds->ringFill = 0;
    ds->producerPos       = absIndex;
    ds->producerPosNative = nativeAbs;
    // A seek also interrupts the read cadence — don't clock the gap it leaves as
    // a late callback (same false positive as pause/resume).
    ds->lastReadUs  = 0;
    ds->eof = 0;
    ring_unlock(&ds->ringLock);

    rewamp_notes_reset(rewamp_channel_count());
    rewamp_notes_seek_played(nativeAbs);
    rewamp_channel_data_set_consumer_pos(nativeAbs);
    rewamp_pattern_cursor_reset();
    rewamp_pattern_cursor_set_played(nativeAbs);
    pthread_mutex_unlock(&ds->decodeLock);
    return MA_SUCCESS;
}

static ma_result ds_get_data_format(ma_data_source* pDataSource, ma_format* pFormat,
                                    ma_uint32* pChannels, ma_uint32* pSampleRate,
                                    ma_channel* pChannelMap, size_t channelMapCap) {
    RewampDataSource* ds = (RewampDataSource*)pDataSource;
    if (pFormat != NULL)     *pFormat     = ma_format_f32;
    if (pChannels != NULL)   *pChannels   = ds->format.channels;
    if (pSampleRate != NULL) *pSampleRate = ds->format.sampleRate;
    if (pChannelMap != NULL) {
        ma_channel_map_init_standard(ma_standard_channel_map_default, pChannelMap,
                                     channelMapCap, ds->format.channels);
    }
    return MA_SUCCESS;
}

static ma_result ds_get_cursor(ma_data_source* pDataSource, ma_uint64* pCursor) {
    RewampDataSource* ds = (RewampDataSource*)pDataSource;
    // Track-relative: the cursor runs absolute across gapless handoffs, the
    // position the UI shows restarts at each audible boundary.
    ma_uint64 base = (ma_uint64)ds->trackBase;
    *pCursor = ds->cursor >= base ? ds->cursor - base : 0;
    return MA_SUCCESS;
}

static ma_result ds_get_length(ma_data_source* pDataSource, ma_uint64* pLength) {
    RewampDataSource* ds = (RewampDataSource*)pDataSource;
    if (ds->decoder == NULL) return MA_NOT_IMPLEMENTED;  // mid-handoff hole
    ma_uint64 len = ds->vt->length != NULL ? ds->vt->length(ds->decoder) : 0;
    if (len == 0) return MA_NOT_IMPLEMENTED;  // unknown / non-seekable
    // Decoder-native frames → ring frames (the domain everything above hears).
    if (ds->nativeRate != DS_RING_RATE && ds->nativeRate > 0)
        len = len * DS_RING_RATE / ds->nativeRate;
    *pLength = len;
    return MA_SUCCESS;
}

static const ma_data_source_vtable g_ds_vtable = {
    ds_read,
    ds_seek,
    ds_get_data_format,
    ds_get_cursor,
    ds_get_length,
    NULL,  // onSetLooping
    0      // flags
};

ma_result rewamp_data_source_init(RewampDataSource* ds,
                                  const RewampPluginVTable* vt,
                                  RewampDecoder* decoder,
                                  RewampAudioFormat format,
                                  RewampDeclick* declick) {
    ma_data_source_config cfg = ma_data_source_config_init();
    cfg.vtable = &g_ds_vtable;

    ma_result result = ma_data_source_init(&cfg, &ds->base);
    if (result != MA_SUCCESS) return result;

    ds->vt      = vt;
    ds->decoder = decoder;
    ds->declick = declick;
    ds->format  = format;
    ds->cursor  = 0;
    pthread_mutex_init(&ds->decodeLock, NULL);
    ring_lock_init(&ds->ringLock);
    ds->producerStarted = 0;
    ds->producerStop    = 0;

    // Decode-ahead ring, sized for the LARGEST lead (the notation visualizer's),
    // since the target is switched at runtime.
    ds->channels    = (int)format.channels;
    ds->ringHead    = ds->ringTail = ds->ringFill = 0;
    ds->producerPos = 0;
    ds->eof         = 0;
    ds->trackBase      = 0;
    ds->handoffPending = 0;
    /* ⚠️ Le MIROIR aussi. Il n'était effacé qu'aux deux PROMOTIONS (l'oreille
     * franchit la frontière, ou un seek la promeut) — or un relais armé peut
     * ne jamais être promu: il suffit de changer de piste à la main pendant la
     * fenêtre du relais, et la source est alors reconstruite ici. Le miroir
     * restait à 1 POUR TOUJOURS, donc `rewamp_handoff_pending()` mentait, et
     * tout visualiseur qui gèle son morceau affiché dessus restait gelé: le
     * viz-pattern gardait la fenêtre du morceau précédent et la dessinait hors
     * écran — en-tête et barre seuls, sans cellules NI numéros de ligne
     * (constaté 2026-09-12). Un champ de structure et son miroir global se
     * remettent à zéro AU MÊME ENDROIT. */
    g_handoff_pending  = 0;
    ds->handoffFrame   = 0;
    ds->ring        = NULL;
    ds->stepBuf     = NULL;

    // The ring runs at DS_RING_RATE; the decoder keeps its native rate and the
    // producer resamples in between (see the header). The declared format —
    // what miniaudio sees — is the RING's.
    const uint32_t nativeRate =
        format.sampleRate > 0 ? format.sampleRate : DS_RING_RATE;
    ds->nativeRate        = nativeRate;
    ds->prevNativeRate    = nativeRate;
    ds->rsActive          = (nativeRate != DS_RING_RATE);
    ds->rsInit            = 0;
    ds->nativeBuf         = NULL;
    ds->nativeBufCap      = 0;
    ds->producerPosNative = 0;
    ds->trackBaseNative   = 0;
    ds->pendingBaseNative = 0;
    ds->xfTail            = NULL;
    ds->xfTailLen         = 0;
    ds->xfTailPos         = 0;
    ds->xfMode            = 0;
    ds->endFadeArmed      = 0;
    ds->format.sampleRate = DS_RING_RATE;
    {
        uint64_t lenN = (vt->length != NULL) ? vt->length(decoder) : 0;
        ds->trackLenRing = lenN
            ? (int64_t)(lenN * (uint64_t)DS_RING_RATE / nativeRate) : 0;
    }

    if (ds->channels > 0) {
        ds->ringCap = (int)(DS_LEAD_MAX_SECS * DS_RING_RATE)
                      + DS_STEP_FRAMES + 4096;
        // A little above DS_STEP_FRAMES: the resampler's output for one native
        // step can overshoot by a frame or two of rounding.
        ds->stepBufCap = DS_STEP_FRAMES + 32;
        // Native scratch sized for rates up to 4× the ring's (176.4 kHz rips).
        ds->nativeBufCap = DS_STEP_FRAMES * 4;
        ds->ring      = (float*)malloc((size_t)ds->ringCap * ds->channels * sizeof(float));
        ds->stepBuf   = (float*)malloc((size_t)ds->stepBufCap * ds->channels * sizeof(float));
        ds->nativeBuf = (float*)malloc((size_t)ds->nativeBufCap * ds->channels * sizeof(float));
        if (!ds->ring || !ds->stepBuf || !ds->nativeBuf) {
            free(ds->ring); free(ds->stepBuf); free(ds->nativeBuf);
            ds->ring = ds->stepBuf = ds->nativeBuf = NULL;  // callback-decode fallback
            // The callback-decode fallback reads NATIVE frames straight into
            // the output: the declared rate must match them.
            ds->rsActive = 0;
            ds->format.sampleRate = nativeRate;
        }
    }
    if (ds->rsActive && ds->ring != NULL) {
        ma_linear_resampler_config rc = ma_linear_resampler_config_init(
            ma_format_f32, (ma_uint32)ds->channels, nativeRate, DS_RING_RATE);
        // Max-order LPF — the same lesson as the device resampler: the default
        // order smears full-spectrum content (see audio-resampler-lpf).
        rc.lpfOrder = MA_MAX_FILTER_ORDER;
        if (ma_linear_resampler_init(&rc, NULL, &ds->rs) == MA_SUCCESS) {
            ds->rsInit = 1;
        } else {
            // Can't resample → declare the NATIVE rate instead and let
            // miniaudio's own sound-level resampler take over (pre-gapless
            // behavior; handoffs to a different rate will decline).
            ds->rsActive = 0;
            ds->format.sampleRate = nativeRate;
        }
    }
    // Notes timeline + delayed voice store track the real voice count
    // (set by the plugin's open()). The producer always runs ahead now, so the
    // delayed store is the one the scopes read whenever the ring exists.
    rewamp_notes_reset(rewamp_channel_count());
    rewamp_notes_set_rate((int)nativeRate);   // captures scroll at the NATIVE rate
    rewamp_pattern_cursor_reset();
    rewamp_channel_data_set_delayed(ds->ring != NULL);

    if (ds->ring != NULL &&
        pthread_create(&ds->producer, NULL, ds_producer_main, ds) == 0) {
        ds->producerStarted = 1;
    } else if (ds->ring != NULL) {
        // No thread → fall back to decoding in the callback rather than play
        // silence. Worse under load, but it plays.
        free(ds->ring);      ds->ring      = NULL;
        free(ds->stepBuf);   ds->stepBuf   = NULL;
        free(ds->nativeBuf); ds->nativeBuf = NULL;
        ds->rsActive = 0;
        ds->format.sampleRate = ds->nativeRate;  // callback path emits native
        rewamp_channel_data_set_delayed(0);
    }
    return MA_SUCCESS;
}

void rewamp_data_source_uninit(RewampDataSource* ds) {
    // Stop and JOIN the producer before anything else: it holds a pointer to the
    // decoder we are about to close, and may be inside vt->read right now.
    if (ds->producerStarted) {
        ring_lock(&ds->ringLock);
        ds->producerStop = 1;
        ring_unlock(&ds->ringLock);
        pthread_join(ds->producer, NULL);
        ds->producerStarted = 0;
    }
    /* Plus de source, donc plus de frontière en attente: même règle qu'à
     * l'init, sinon le miroir survit à la piste qu'il décrivait. */
    ds->handoffPending = 0;
    g_handoff_pending  = 0;
    // Safe without locking from here: the caller (rewamp_unload(), rewamp_audio.c)
    // already cancels + joins any in-flight seek thread before reaching here, and
    // the producer is now joined.
    if (ds->decoder != NULL && ds->vt != NULL && ds->vt->close != NULL) {
        ds->vt->close(ds->decoder);
    }
    ds->decoder = NULL;
    rewamp_declick_destroy(ds->declick);
    ds->declick = NULL;
    free(ds->ring);      ds->ring      = NULL;
    free(ds->stepBuf);   ds->stepBuf   = NULL;
    free(ds->nativeBuf); ds->nativeBuf = NULL;
    free(ds->xfTail);    ds->xfTail    = NULL;
    if (ds->rsInit) { ma_linear_resampler_uninit(&ds->rs, NULL); ds->rsInit = 0; }
    ring_lock_destroy(&ds->ringLock);
    pthread_mutex_destroy(&ds->decodeLock);
    ma_data_source_uninit(&ds->base);
}

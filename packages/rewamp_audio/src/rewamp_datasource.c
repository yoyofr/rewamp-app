#include "rewamp_datasource.h"
#include "rewamp_waveform.h"
#include "rewamp_notes.h"
#include "rewamp_pattern.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"   /* generic_mute_mask (stereo-fallback L/R mute) */

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
        const int done = ds->eof || ds->ringFill >= ds_target_fill(ds);
        int room = ds->ringCap - ds->ringFill;
        ring_unlock(&ds->ringLock);

        if (done) { nanosleep(&idle, NULL); continue; }

        int step = DS_STEP_FRAMES;
        if (step > room) step = room;
        if (step <= 0) { nanosleep(&idle, NULL); continue; }

        pthread_mutex_lock(&ds->decodeLock);
        const int64_t stepStart = ds->producerPos;
        int got = 0;
        /* Cursor samples taken inside this step: frame offset + (order,row).
         * Recorded here and published under the ring lock below, so the decode
         * stays in one place and the publishing in another. */
        enum { DS_CURSOR_MAX = DS_STEP_FRAMES / DS_CURSOR_SUB_FRAMES + 1 };
        int curOff[DS_CURSOR_MAX];
        int curOrd[DS_CURSOR_MAX];
        int curRow[DS_CURSOR_MAX];
        int curCount = 0;
        if (ds->vt->pattern_cursor != NULL) {
            /* Same total frames, read in sub-steps so the cursor is sampled
             * four times as often — the pattern viz interpolates between two
             * samples, so their spacing IS its scroll jitter. */
            while (got < step) {
                int want = step - got;
                if (want > DS_CURSOR_SUB_FRAMES) want = DS_CURSOR_SUB_FRAMES;
                int n = (int)ds->vt->read(ds->decoder,
                                          ds->stepBuf + (size_t)got * ds->channels,
                                          want);
                if (n <= 0) break;
                got += n;
                int order = -1, row = -1;
                ds->vt->pattern_cursor(ds->decoder, &order, &row);
                /* A decoder is free to return FEWER frames than asked, and one
                 * that returned a handful at a time would run past the end of
                 * these arrays. Past the last slot, keep overwriting it: the
                 * newest sample is the one worth having. */
                int slot = curCount < DS_CURSOR_MAX ? curCount : DS_CURSOR_MAX - 1;
                curOff[slot] = got;
                curOrd[slot] = order;
                curRow[slot] = row;
                if (curCount < DS_CURSOR_MAX) curCount++;
            }
        } else {
            got = (int)ds->vt->read(ds->decoder, ds->stepBuf, step);
        }

        ring_lock(&ds->ringLock);
        if (got <= 0) {
            ds->eof = 1;
        } else {
            ring_push(ds, ds->stepBuf, got);
            ds->producerPos += got;
            // Look-ahead state captured at PRODUCER time, keyed by absolute
            // frame position: the note column and the per-voice oscilloscope
            // samples. The consumer side replays them at its own position (see
            // rewamp_channel_data_set_consumer_pos), which is what keeps the
            // scopes in sync with what is being HEARD rather than decoded.
            rewamp_notes_capture(ds->producerPos);
            rewamp_channel_data_capture_delayed(stepStart, got);
            // Live tracker cursor (order,row), keyed by the same producer frame
            // so the pattern viz highlights the row being HEARD, not decoded.
            for (int i = 0; i < curCount; i++) {
                rewamp_pattern_cursor_capture(stepStart + curOff[i],
                                              curOrd[i], curRow[i]);
            }
        }
        ring_unlock(&ds->ringLock);
        pthread_mutex_unlock(&ds->decodeLock);
    }
    return NULL;
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
                rewamp_notes_set_played((int64_t)ds->cursor);
                rewamp_channel_data_set_consumer_pos((int64_t)ds->cursor);
                rewamp_pattern_cursor_set_played((int64_t)ds->cursor);
                ds_read_done(entryUs);
                return MA_SUCCESS;
            }
        } else {
            framesRead = ds->vt->read(ds->decoder, (float*)pFramesOut, frameCount);
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
    rewamp_notes_set_played((int64_t)ds->cursor);
    rewamp_channel_data_set_consumer_pos((int64_t)ds->cursor);
    rewamp_pattern_cursor_set_played((int64_t)ds->cursor);

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
    // Invariant: a seek NEVER changes the user's per-voice mute state. Some
    // plugins implement a backward seek by reloading the tune through their
    // open() path (pmd_load, eup_setup_and_load, …), which runs
    // rewamp_channel_data_reset() and zeroes generic_mute_mask — silently
    // dropping the mutes the user had engaged. Snapshot + restore around the
    // plugin seek so every engine (current and future) keeps the mask.
    {
        int64_t savedMute = generic_mute_mask;
        if (ds->vt->seek != NULL) {
            ds->vt->seek(ds->decoder, frameIndex);
        }
        generic_mute_mask = savedMute;
    }
    ds->cursor = frameIndex;

    ring_lock(&ds->ringLock);
    // Flush the look-ahead ring + note timeline; both refill from the new pos.
    ds->ringHead = ds->ringTail = ds->ringFill = 0;
    ds->producerPos = (int64_t)frameIndex;
    // A seek also interrupts the read cadence — don't clock the gap it leaves as
    // a late callback (same false positive as pause/resume).
    ds->lastReadUs  = 0;
    ds->eof = 0;
    ring_unlock(&ds->ringLock);

    rewamp_notes_reset(rewamp_channel_count());
    rewamp_notes_set_played((int64_t)frameIndex);
    rewamp_channel_data_set_consumer_pos((int64_t)frameIndex);
    rewamp_pattern_cursor_reset();
    rewamp_pattern_cursor_set_played((int64_t)frameIndex);
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
    *pCursor = ds->cursor;
    return MA_SUCCESS;
}

static ma_result ds_get_length(ma_data_source* pDataSource, ma_uint64* pLength) {
    RewampDataSource* ds = (RewampDataSource*)pDataSource;
    ma_uint64 len = ds->vt->length != NULL ? ds->vt->length(ds->decoder) : 0;
    if (len == 0) return MA_NOT_IMPLEMENTED;  // unknown / non-seekable
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
                                  RewampAudioFormat format) {
    ma_data_source_config cfg = ma_data_source_config_init();
    cfg.vtable = &g_ds_vtable;

    ma_result result = ma_data_source_init(&cfg, &ds->base);
    if (result != MA_SUCCESS) return result;

    ds->vt      = vt;
    ds->decoder = decoder;
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
    ds->ring        = NULL;
    ds->stepBuf     = NULL;
    if (ds->channels > 0 && format.sampleRate > 0) {
        ds->ringCap = (int)(DS_LEAD_MAX_SECS * format.sampleRate)
                      + DS_STEP_FRAMES + 4096;
        ds->ring    = (float*)malloc((size_t)ds->ringCap * ds->channels * sizeof(float));
        ds->stepBuf = (float*)malloc((size_t)DS_STEP_FRAMES * ds->channels * sizeof(float));
        if (!ds->ring || !ds->stepBuf) {
            free(ds->ring); free(ds->stepBuf);
            ds->ring = ds->stepBuf = NULL;   // fall back to decoding in the callback
        }
    }
    // Notes timeline + delayed voice store track the real voice count
    // (set by the plugin's open()). The producer always runs ahead now, so the
    // delayed store is the one the scopes read whenever the ring exists.
    rewamp_notes_reset(rewamp_channel_count());
    rewamp_notes_set_rate((int)format.sampleRate);   // scroll at the TRACK's rate
    rewamp_pattern_cursor_reset();
    rewamp_channel_data_set_delayed(ds->ring != NULL);

    if (ds->ring != NULL &&
        pthread_create(&ds->producer, NULL, ds_producer_main, ds) == 0) {
        ds->producerStarted = 1;
    } else if (ds->ring != NULL) {
        // No thread → fall back to decoding in the callback rather than play
        // silence. Worse under load, but it plays.
        free(ds->ring);    ds->ring    = NULL;
        free(ds->stepBuf); ds->stepBuf = NULL;
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
    // Safe without locking from here: the caller (rewamp_unload(), rewamp_audio.c)
    // already cancels + joins any in-flight seek thread before reaching here, and
    // the producer is now joined.
    if (ds->decoder != NULL && ds->vt != NULL && ds->vt->close != NULL) {
        ds->vt->close(ds->decoder);
    }
    ds->decoder = NULL;
    free(ds->ring);    ds->ring    = NULL;
    free(ds->stepBuf); ds->stepBuf = NULL;
    ring_lock_destroy(&ds->ringLock);
    pthread_mutex_destroy(&ds->decodeLock);
    ma_data_source_uninit(&ds->base);
}

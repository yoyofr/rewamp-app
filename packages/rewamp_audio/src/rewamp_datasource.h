#ifndef REWAMP_DATASOURCE_H
#define REWAMP_DATASOURCE_H

#include "miniaudio.h"
#include "rewamp_plugin.h"
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
} RewampDataSource;

// Initialize a data source from an already-opened plugin decoder.
// Takes ownership: rewamp_data_source_uninit calls vt->close on the decoder.
ma_result rewamp_data_source_init(RewampDataSource* ds,
                                  const RewampPluginVTable* vt,
                                  RewampDecoder* decoder,
                                  RewampAudioFormat format);

void rewamp_data_source_uninit(RewampDataSource* ds);

#ifdef __cplusplus
}
#endif

#endif /* REWAMP_DATASOURCE_H */

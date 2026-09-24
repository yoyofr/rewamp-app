/* rewamp: per-voice oscilloscope capture for libxmp (hooked into mixer.c).
 *
 * libxmp has no per-voice output: every mixer voice accumulates into ONE
 * shared int32 buffer (s->buf32). A voice's own contribution is therefore the
 * DELTA of that buffer across its mix call — snapshot the span before
 * mix_fn(), subtract after. That is exact (the mixer only adds), and it costs
 * one copy of the span actually mixed, not of the whole tick.
 *
 * Two libxmp facts the hooks have to respect:
 *   - voices are VIRTUAL: with IT's NNA several mixer voices map to the same
 *     module channel (vi->chn), so contributions ACCUMULATE into the ring
 *     slot rather than overwrite it — the ring is zeroed once per tick by
 *     rewamp_xmp_capture_begin();
 *   - a voice is mixed in CHUNKS (loop points, sample end), so each hook gets
 *     the chunk's offset within the tick.
 *
 * The write head advances once per tick, for EVERY voice at once
 * (rewamp_xmp_capture_advance) — silent voices included, so the voices never
 * drift apart and the delayed store's window stays aligned (PLUGINS.md §2.2).
 */
#ifndef REWAMP_XMP_CAPTURE_H
#define REWAMP_XMP_CAPTURE_H

#include <stdlib.h>
#include <string.h>

/* Chemin RELATIF: ce header est inclus par mixer.c, et les deux systèmes de
 * build doivent le trouver sans qu'aucun chemin d'inclusion de rewamp
 * n'atteigne l'arbre libxmp (mêmes noms génériques que tout le monde). */
#include "../../src/ModizerVoicesData.h"

/* Ring geometry: the 4096-sample window every other engine uses (PLUGINS.md
 * §2.3 — smaller and the scope's stabilization trigger silently stops). */
#define RWXMP_RING_SIZE (SOUND_BUFFER_SIZE_SAMPLE * 4 * 2)
#define RWXMP_RING_MASK (RWXMP_RING_SIZE - 1)

/* Scratch copy of the shared mix buffer span, reused across voices. */
static int *rwxmp_pre;
static int  rwxmp_pre_len;

/* Zero the tick's window for every voice, so accumulation starts clean and a
 * voice that does not mix this tick draws a flat line instead of freezing on
 * its last waveform. */
static void rewamp_xmp_capture_begin(int voices, int ticksize)
{
    int v, i;
    if (voices > SOUND_MAXVOICES_BUFFER_FX) voices = SOUND_MAXVOICES_BUFFER_FX;
    for (v = 0; v < voices; v++) {
        signed char *ring = m_voice_buff[v];
        long long base;
        if (ring == NULL) continue;
        base = m_voice_current_ptr[v] >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT;
        for (i = 0; i < ticksize; i++)
            ring[(base + i) & RWXMP_RING_MASK] = 0;
    }
}

static void rewamp_xmp_capture_pre(const int *buf, int samples, int stride)
{
    int n = samples * stride;
    if (n <= 0) return;
    if (n > rwxmp_pre_len) {
        int *p = (int *)realloc(rwxmp_pre, (size_t)n * sizeof(int));
        if (p == NULL) { rwxmp_pre_len = 0; return; }
        rwxmp_pre = p;
        rwxmp_pre_len = n;
    }
    memcpy(rwxmp_pre, buf, (size_t)n * sizeof(int));
}

/* chn: module channel (vi->chn). offset: chunk position within the tick.
 * shift: buf32 -> 8-bit scope scale, computed by the caller from the mixer's
 * own downmix shift so a player amplification change keeps the scope in
 * range. */
static void rewamp_xmp_capture_post(int chn, const int *buf, int samples,
                                    int stride, int offset, int shift)
{
    signed char *ring;
    long long base;
    int i;
    if (chn < 0 || chn >= SOUND_MAXVOICES_BUFFER_FX) return;
    if (samples <= 0 || samples * stride > rwxmp_pre_len) return;
    ring = m_voice_buff[chn];
    if (ring == NULL) return;
    base = (m_voice_current_ptr[chn] >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT) + offset;
    for (i = 0; i < samples; i++) {
        int d;
        if (stride == 2) {
            d = (buf[i * 2] - rwxmp_pre[i * 2]) +
                (buf[i * 2 + 1] - rwxmp_pre[i * 2 + 1]);
        } else {
            d = (buf[i] - rwxmp_pre[i]) * 2;
        }
        d >>= shift;
        {
            long long idx = (base + i) & RWXMP_RING_MASK;
            int acc = (int)ring[idx] + d;
            ring[idx] = (signed char)LIMIT8(acc);
        }
    }
}

static void rewamp_xmp_capture_advance(int voices, int ticksize)
{
    int v;
    if (voices > SOUND_MAXVOICES_BUFFER_FX) voices = SOUND_MAXVOICES_BUFFER_FX;
    for (v = 0; v < voices; v++)
        m_voice_current_ptr[v] += (long long)ticksize << MODIZER_OSCILLO_OFFSET_FIXEDPOINT;
}

#endif /* REWAMP_XMP_CAPTURE_H */

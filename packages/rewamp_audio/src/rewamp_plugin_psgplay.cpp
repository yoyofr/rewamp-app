/* PSG play plugin — Atari ST .sndh through the vendored psgplay library
 * (Fredrik Noring, third_party/psgplay: full Atari ST machine — 68000 via a
 * context-based Musashi, cf2149 YM2149, cf68901 MFP, cf300588 LMC1992 tone and
 * volume mixer). Second engine for .sndh and the DEFAULT one — but never by
 * probe score: it deliberately scores one point BELOW the AtariAudio plugin,
 * and the app selects it with
 * `rewamp_registry_set_preferred_plugin("sndh", "psgplay")` at startup (same
 * mechanism as nsfplay/gbsplay and the Amiga engines). Pointing that
 * preference at "sndh" picks AtariAudio back.
 *
 * Three things this engine does that AtariAudio does not:
 *  - it models the STE/TT LMC1992 (SNDH flag 'l'), so tunes that set hardware
 *    bass/treble/volume are rendered with them;
 *  - its machine state lives INSIDE `struct psgplay` (Musashi context passed by
 *    pointer), so two instances can decode at once — AtariAudio's Musashi is a
 *    single process-global context;
 *  - it renders stereo natively (the empiric YM2149 channel mix measured on
 *    real hardware), where AtariAudio gives us mono.
 *
 * TRAP, paid in the harness: psgplay_init() REFUSES nothing for ICE-packed
 * data — it happily boots the machine on the compressed bytes and plays noise
 * at full level. The header says "must not be in compressed form" and the
 * upstream CLI depacks first (system/unix/sndh.c); AtariAudio depacked inside
 * SndhFile::Load, so this is a real behavioural difference between the two
 * engines, not a detail. We depack here, before anything else.
 *
 * Per-voice scope / notes / mute are OURS (upstream exposes no such thing):
 * they hang off the digital→stereo callback, which sees every 250.332 kHz
 * sample with the three PSG channel levels and the STE DMA sample still
 * separate — see psg_mix_cb below. */
#ifdef REWAMP_WITH_PSGPLAY

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"

extern "C" {
#include "psgplay/psgplay.h"
#include "psgplay/sndh.h"
#include "psgplay/stereo.h"
#include "psgplay/digital.h"
#include "ice/ice.h"
}

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define PSG_RATE       44100
#define PSG_VOICES     4      /* YM2149 A, B, C + STE DMA */
#define PSG_RING_SIZE  (SOUND_BUFFER_SIZE_SAMPLE * 4 * 2)   /* ≥ outLen+TRIGGER_SEARCH_LEN, see rewamp_channel_data.c */
/* Rate the digital callback runs at, from psgplay's own documentation
 * ("250.332 kHz digital samples"). Only used to turn a measured square-wave
 * period into Hz for the notes display. */
#define PSG_DIGITAL_HZ 250332.0

struct RewampDecoder {
    struct psgplay* pp;
    int      subsong;      /* 1-based, SNDH's own convention */
    uint64_t framePos;
    uint64_t totalFrames;  /* 0 = unknown */
    uint8_t* data;         /* depacked SNDH, kept for re-init on seek */
    size_t   size;
};

/* ── Per-voice capture ─────────────────────────────────────────────────────
 * The callback is called at 250 kHz; the scope ring runs at the output rate,
 * so writes are decimated by the same ratio the downsampler uses. Frequency is
 * measured as the distance between two rising edges of the channel's own level
 * stream — the PSG square wave is right there in the digital samples, so this
 * is the real period, not an estimate from registers we cannot see. */
static int64_t g_psg_edge_last[3];   /* digital-sample index of the last rising edge */
static int     g_psg_prev_on[3];
static int64_t g_psg_digital_idx;
static double  g_psg_decim_acc;

static void psg_cap_reset(void) {
    for (int i = 0; i < 3; i++) { g_psg_edge_last[i] = -1; g_psg_prev_on[i] = 0; }
    g_psg_digital_idx = 0;
    g_psg_decim_acc   = 0.0;
    for (int v = 0; v < PSG_VOICES; v++) {
        vgm_last_vol[v]   = 0;
        vgm_last_note[v]  = 0;
        vgm_last_instr[v] = (unsigned char)v;
    }
}

static inline void psg_cap_write(int v, int value) {
    signed char* buf = m_voice_buff[v];
    if (!buf) return;                       /* reset() not run yet */
    int64_t ptr = m_voice_current_ptr[v];
    buf[(ptr >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT) % PSG_RING_SIZE] =
        (signed char)LIMIT8(value);
    m_voice_current_ptr[v] = ptr + ((int64_t)1 << MODIZER_OSCILLO_OFFSET_FIXEDPOINT);
}

/* Our digital→stereo transform: mute, capture, then hand the (possibly muted)
 * samples to psgplay's own empiric mix so the audio path stays upstream's.
 * `digital` is const — muting therefore works on a copy, which is also what
 * makes the mute affect the ACTUAL mix and not just the scope. */
static void psg_mix_cb(struct psgplay* pp, struct psgplay_stereo* stereo,
                       const struct psgplay_digital* digital,
                       size_t count, void* arg) {
    (void)arg;
    const uint64_t mute = generic_mute_mask;
    const double   decim = PSG_DIGITAL_HZ / (double)PSG_RATE;

    enum { CHUNK = 256 };
    struct psgplay_digital tmp[CHUNK];

    for (size_t off = 0; off < count; off += CHUNK) {
        size_t n = count - off;
        if (n > CHUNK) n = CHUNK;
        memcpy(tmp, digital + off, n * sizeof(tmp[0]));

        for (size_t i = 0; i < n; i++) {
            struct psgplay_digital* d = &tmp[i];
            const int lv[3] = { d->psg.lva.u5, d->psg.lvb.u5, d->psg.lvc.u5 };

            for (int v = 0; v < 3; v++) {
                if (mute & (1ULL << v)) {
                    /* Whole union, not the 5-bit field: the mixer reads
                     * whichever width its model wants. */
                    if (v == 0) d->psg.lva.u8 = 0;
                    else if (v == 1) d->psg.lvb.u8 = 0;
                    else d->psg.lvc.u8 = 0;
                }
                /* Rising edge → one square-wave period since the previous one. */
                const int on = lv[v] > 0;
                if (on && !g_psg_prev_on[v]) {
                    if (g_psg_edge_last[v] >= 0) {
                        const int64_t period = g_psg_digital_idx - g_psg_edge_last[v];
                        if (period > 0 && period < 250332)   /* ≥ 1 Hz */
                            vgm_last_note[v] = (int)(PSG_DIGITAL_HZ / (double)period);
                    }
                    g_psg_edge_last[v] = g_psg_digital_idx;
                }
                g_psg_prev_on[v] = on;
                vgm_last_vol[v] = (unsigned char)((lv[v] * 255) / 31);
            }
            if (mute & (1ULL << 3)) { d->sound.left = 0; d->sound.right = 0; }

            /* One scope sample per output frame. The PSG level is unipolar
             * (0..31 around a silent 0), so it is centred here — writing it raw
             * would draw a waveform sitting entirely above the midline. */
            g_psg_decim_acc += 1.0;
            if (g_psg_decim_acc >= decim) {
                g_psg_decim_acc -= decim;
                for (int v = 0; v < 3; v++)
                    psg_cap_write(v, (mute & (1ULL << v)) ? 0 : (lv[v] * 8 - 124));
                psg_cap_write(3, (mute & (1ULL << 3)) ? 0 : (d->sound.left >> 8));
            }
            g_psg_digital_idx++;
        }

        psgplay_digital_to_stereo_empiric(pp, stereo + off, tmp, n, NULL);
    }
    vgm_last_vol[3] = 0;   /* DMA level is a sample, not an envelope */
}

/* ── File loading ─────────────────────────────────────────────────────────── */

/* Reads `path` and depacks ICE when needed. Caller owns the buffer. */
static uint8_t* psg_load_file(const char* path, size_t* outSize) {
    FILE* f = fopen(path, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (len <= 0 || len > 16 * 1024 * 1024) { fclose(f); return NULL; }
    uint8_t* data = (uint8_t*)malloc((size_t)len);
    if (!data) { fclose(f); return NULL; }
    size_t got = fread(data, 1, (size_t)len, f);
    fclose(f);
    if (got != (size_t)len) { free(data); return NULL; }

    size_t size = (size_t)len;
    if (ice_identify(data, size)) {
        const size_t out = ice_decrunched_size(data, size);
        uint8_t* b = out ? (uint8_t*)malloc(out) : NULL;
        if (!b || ice_decrunch(b, data, size) == -1) {
            free(b);
            free(data);
            return NULL;
        }
        free(data);
        data = b;
        size = out;
    }
    if (!sndh_identify(data, size)) { free(data); return NULL; }
    *outSize = size;
    return data;
}

static int psg_probe(const char* ext, const uint8_t* header, size_t headerSize) {
    const int extMatch = ext && strcmp(ext, "sndh") == 0;
    if (!extMatch) return 0;
    /* One point under the AtariAudio plugin at every step: both claim .sndh,
     * and which one actually opens the file is the user's setting (the registry
     * pins the preferred plugin to the front of the candidate list). */
    if (header && headerSize >= 16 && 0 == memcmp(header + 12, "SNDH", 4)) return 99;
    if (header && headerSize >= 4  && 0 == memcmp(header, "ICE!", 4))      return 94;
    return 89;
}

static RewampDecoder* psg_open(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;

    char clean[4096];
    int  subsong = 0;
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    char* q = strrchr(clean, '?');
    if (q && strncmp(q, "?subsong=", 9) == 0) { subsong = atoi(q + 9); *q = '\0'; }

    size_t size = 0;
    uint8_t* data = psg_load_file(clean, &size);
    if (!data) return NULL;

    int count = 1, deflt = 1;
    if (!sndh_tag_subtune_count(&count, data, size) || count < 1) count = 1;
    if (!sndh_tag_default_subtune(&deflt, data, size) || deflt < 1) deflt = 1;

    RewampDecoder* dec = new RewampDecoder();
    dec->data    = data;
    dec->size    = size;
    dec->subsong = (subsong > 0 && subsong <= count) ? subsong : deflt;

    /* Ring buffers BEFORE the first sample is rendered — the callback writes
     * m_voice_buff inline, and a reset after that would hand it NULL buffers. */
    rewamp_channel_data_reset(PSG_VOICES);
    rewamp_channel_data_set_ring_write_size(PSG_RING_SIZE);
    rewamp_channel_data_set_ring_circular(1);
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("YM2149", 0, 3);
    rewamp_voices_add_chip("STE DMA", 3, 1);
    rewamp_voice_set_name(0, "PSG A");
    rewamp_voice_set_name(1, "PSG B");
    rewamp_voice_set_name(2, "PSG C");
    rewamp_voice_set_name(3, "DMA");
    psg_cap_reset();

    dec->pp = psgplay_init(dec->data, dec->size, dec->subsong, PSG_RATE);
    if (!dec->pp) { free(dec->data); delete dec; return NULL; }
    psgplay_digital_to_stereo_callback(dec->pp, psg_mix_cb, NULL);

    float secs = 0;
    if (sndh_tag_subtune_time(&secs, dec->subsong, dec->data, dec->size) && secs > 0)
        dec->totalFrames = (uint64_t)(secs * PSG_RATE);

    char tag[256];
    if (sndh_tag_title(tag, sizeof(tag), dec->data, dec->size) && tag[0])
        rewamp_track_message_append("Title: %s\n", tag);
    if (sndh_tag_composer(tag, sizeof(tag), dec->data, dec->size) && tag[0])
        rewamp_track_message_append("Composer: %s\n", tag);
    if (sndh_tag_year(tag, sizeof(tag), dec->data, dec->size) && tag[0])
        rewamp_track_message_append("Year: %s\n", tag);
    if (count > 1 &&
        sndh_tag_subtune_name(tag, sizeof(tag), dec->subsong, dec->data, dec->size) && tag[0])
        rewamp_track_message_append("Subtune: %s\n", tag);
    struct sndh_timer timer;
    if (sndh_tag_timer(&timer, dec->data, dec->size) && timer.frequency > 0)
        rewamp_track_message_append("Timer: %c %dHz\n", (char)timer.type, timer.frequency);
    rewamp_track_message_append("Subsongs: %d\nEngine: PSG play\n", count);

    if (outFormat) {
        outFormat->channels   = 2;
        outFormat->sampleRate = PSG_RATE;
    }
    return dec;
}

static uint64_t psg_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || !dec->pp || frameCount == 0) return 0;

    static struct psgplay_stereo buf[2048];
    const float scale = 1.0f / 32768.0f;
    uint64_t written = 0;
    while (written < frameCount) {
        uint64_t remain = frameCount - written;
        size_t want = (size_t)(remain > 2048 ? 2048 : remain);
        ssize_t got = psgplay_read_stereo(dec->pp, buf, want);
        if (got <= 0) break;    /* stopped / end of tune */
        for (ssize_t i = 0; i < got; i++) {
            out[(written + (uint64_t)i) * 2 + 0] = buf[i].left  * scale;
            out[(written + (uint64_t)i) * 2 + 1] = buf[i].right * scale;
        }
        written    += (uint64_t)got;
        dec->framePos += (uint64_t)got;
        if ((size_t)got < want) break;
    }
    return written;
}

extern "C" volatile int    g_seek_cancel;
extern "C" volatile int    g_is_seeking;
extern "C" volatile double g_seek_progress_s;

/* No native seek: the position IS the running 68000 + chip state. Backwards →
 * rebuild the machine and fast-forward, same idiom as the AtariAudio, vio2sf
 * and UADE plugins. */
static void psg_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec || !dec->pp) return;
    if (frameIndex < dec->framePos) {
        psgplay_free(dec->pp);
        dec->pp = psgplay_init(dec->data, dec->size, dec->subsong, PSG_RATE);
        if (!dec->pp) return;
        psgplay_digital_to_stereo_callback(dec->pp, psg_mix_cb, NULL);
        psg_cap_reset();
        dec->framePos = 0;
    }
    if (dec->framePos == frameIndex) return;
    g_is_seeking = 1;
    static struct psgplay_stereo tmp[512];
    while (dec->framePos < frameIndex && !g_seek_cancel) {
        uint64_t room = frameIndex - dec->framePos;
        size_t want = (size_t)(room > 512 ? 512 : room);
        ssize_t got = psgplay_read_stereo(dec->pp, tmp, want);
        if (got <= 0) break;
        dec->framePos += (uint64_t)got;
        g_seek_progress_s = (double)dec->framePos / (double)PSG_RATE;
    }
    g_is_seeking = 0;
}

static uint64_t psg_length(RewampDecoder* dec) {
    return dec ? dec->totalFrames : 0;
}

static void psg_close(RewampDecoder* dec) {
    if (!dec) return;
    if (dec->pp) psgplay_free(dec->pp);
    free(dec->data);
    delete dec;
}

static const RewampPluginVTable kPsgPlayVTable = {
    "psgplay",
    psg_probe,
    psg_open,
    psg_read,
    psg_seek,
    psg_length,
    psg_close,
};

extern "C" const RewampPluginVTable* rewamp_psgplay_plugin(void) { return &kPsgPlayVTable; }

#endif /* REWAMP_WITH_PSGPLAY */

/* libgbsplay plugin — Game Boy GBS decoder with per-channel voice data.
 * Compiled only when REWAMP_WITH_GBSPLAY is defined. */
#ifdef REWAMP_WITH_GBSPLAY

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"
#include "ModizerConstants.h"

#include "libgbsplay/libgbs.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>

/* seek_needed: used by gbhw.c YOYOFR patches to gate voice-buffer writes.
 * -1 = normal playback (writes enabled); other values = seeking (skip writes). */
int gbs_seek_needed = -1;

#define GBS_RATE          44100
#define GBS_STEREO        2
#define GBS_VOICE_COUNT   4
/* gbhw flushes its sound buffer in chunks of this many frames (one sound
 * callback per chunk).  Must match the integration loop in gbhw.c. */
#define GBS_BATCH_FRAMES  SOUND_BUFFER_SIZE_SAMPLE
/* gbs_step()'s time_to_work argument is in MILLISECONDS of emulated time.
 * Drive ~one batch of audio per step (512 frames @44100 ≈ 11.6 ms); a single
 * step may flush 1-2 callbacks, all captured into the FIFO below. */
#define GBS_STEP_MS       12
/* PCM FIFO capacity (frames).  Holds callback output until read() drains it. */
#define GBS_FIFO_FRAMES   (GBS_BATCH_FRAMES * 8)
/* Oscilloscope ring size (samples).  MUST match GBS_OSCILLO_SIZE in gbhw.c. */
#define GBS_OSCILLO_SIZE  4096

struct RewampDecoder {
    struct gbs              *gbs;
    struct gbs_output_buffer outbuf_desc;
    int16_t                 *pcm_buf;      /* GBS_BATCH_FRAMES * GBS_STEREO scratch */
    int16_t                 *fifo;         /* GBS_FIFO_FRAMES * GBS_STEREO */
    int                      fifo_frames;  /* frames currently queued */
    int                      voiceCount;
    int                      finished;
    int64_t                  lastMuteMask; /* applied generic_mute_mask snapshot */
};

static const char* const kGbsExts[] = { "gbs", NULL };

/* ── sound callback ──────────────────────────────────────────────────────── */
// Called by gbhw each time its buffer fills (buf->pos frames).  Append the
// frames to the FIFO so read() can drain arbitrary amounts later.

static void gbsplay_sound_cb(struct gbs *gbs,
                              struct gbs_output_buffer *buf,
                              void *priv)
{
    struct RewampDecoder *dec = (struct RewampDecoder*)priv;
    (void)gbs;
    int frames = (int)buf->pos;
    if (frames <= 0) return;
    if (dec->fifo_frames + frames > GBS_FIFO_FRAMES)
        frames = GBS_FIFO_FRAMES - dec->fifo_frames; /* drop overflow (shouldn't happen) */
    if (frames <= 0) return;
    memcpy(dec->fifo + dec->fifo_frames * GBS_STEREO,
           buf->data,
           (size_t)frames * GBS_STEREO * sizeof(int16_t));
    dec->fifo_frames += frames;
}

/* ── probe ───────────────────────────────────────────────────────────────── */

static int gbsplay_probe(const char *ext, const uint8_t *hdr, size_t hdrSize)
{
    int extMatch = rewamp_ext_in_list(ext, kGbsExts);
    if (hdr && hdrSize >= 3 &&
        hdr[0] == 'G' && hdr[1] == 'B' && hdr[2] == 'S')
        return extMatch ? 100 : 90;
    return extMatch ? 60 : 0;
}

/* ── open ────────────────────────────────────────────────────────────────── */

static RewampDecoder* gbsplay_open(const char *path,
                                    RewampAudioFormat *outFormat)
{
    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    int subsong = 0;
    char *q = strrchr(cleanPath, '?');
    if (q) {
        if (strncmp(q + 1, "subsong=", 8) == 0)
            subsong = atoi(q + 9);
        *q = '\0';
    }

    struct gbs *gbs = gbs_open(cleanPath);
    if (!gbs) return NULL;

    struct RewampDecoder *dec =
        (struct RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { gbs_close(gbs); return NULL; }

    dec->gbs = gbs;

    /* Allocate int16 PCM batch (gbhw render target) + drain FIFO */
    dec->pcm_buf = (int16_t*)calloc(GBS_BATCH_FRAMES * GBS_STEREO, sizeof(int16_t));
    dec->fifo    = (int16_t*)calloc(GBS_FIFO_FRAMES * GBS_STEREO, sizeof(int16_t));
    if (!dec->pcm_buf || !dec->fifo) {
        gbs_close(gbs);
        if (dec->pcm_buf) free(dec->pcm_buf);
        if (dec->fifo)    free(dec->fifo);
        free(dec);
        return NULL;
    }

    /* Configure output: batch size in bytes = frames * stereo * sizeof(int16) */
    dec->outbuf_desc.data  = dec->pcm_buf;
    dec->outbuf_desc.bytes = GBS_BATCH_FRAMES * GBS_STEREO * (int)sizeof(int16_t);
    dec->outbuf_desc.pos   = 0;
    gbs_configure_output(gbs, &dec->outbuf_desc, GBS_RATE);
    gbs_set_sound_callback(gbs, gbsplay_sound_cb, dec);

    /* Voice / oscilloscope setup (4 GB channels: sq1, sq2, wave, noise).
     * GBS_OSCILLO_SIZE must match the value hard-coded in gbhw.c. */
    dec->voiceCount = GBS_VOICE_COUNT;
    rewamp_channel_data_reset(GBS_VOICE_COUNT);
    rewamp_channel_data_set_ring_write_size(GBS_OSCILLO_SIZE);
    rewamp_channel_data_set_ring_circular(1);

    /* Voice metadata for the mute/grouping UI. */
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("DMG", 0, GBS_VOICE_COUNT);
    rewamp_voice_set_name(0, "Square 1");
    rewamp_voice_set_name(1, "Square 2");
    rewamp_voice_set_name(2, "Wave");
    rewamp_voice_set_name(3, "Noise");

    /* accumul_temp[0] is allocated by reset(); allocate 1..3 manually. */
    for (int ch = 1; ch < GBS_VOICE_COUNT; ch++) {
        m_voice_buff_accumul_temp[ch] =
            (signed int*)calloc(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2, sizeof(signed int));
    }

    /* init the subsong first (populates subsong_len), then configure with no
     * timeout (0) so playback loops; rewamp enforces the known duration. */
    gbs_init(gbs, subsong);
    gbs_configure(gbs, subsong, 0, 0, 0, 0);

    /* Info panel: GBS header metadata. */
    {
        const struct gbs_metadata *md = gbs_get_metadata(gbs);
        const struct gbs_status   *st = gbs_get_status(gbs);
        if (md) {
            if (md->title && md->title[0])
                rewamp_track_message_append("Title: %s\n", md->title);
            if (md->author && md->author[0])
                rewamp_track_message_append("Author: %s\n", md->author);
            if (md->copyright && md->copyright[0])
                rewamp_track_message_append("Copyright: %s\n", md->copyright);
        }
        if (st && st->songs > 1)
            rewamp_track_message_append("Subsongs: %d (default %d)\n",
                                        st->songs, st->defaultsong);
    }

    if (outFormat) {
        outFormat->channels   = GBS_STEREO;
        outFormat->sampleRate = GBS_RATE;
    }
    return dec;
}

/* ── capture per-channel note/vol ────────────────────────────────────────── */

static void gbsplay_capture_voices(struct RewampDecoder *dec)
{
    const struct gbs_status *st = gbs_get_status(dec->gbs);
    if (!st) return;
    for (int ch = 0; ch < GBS_VOICE_COUNT; ch++) {
        long vol   = st->ch[ch].vol;
        long div_t = st->ch[ch].div_tc;
        int  on    = (int)st->ch[ch].playing;

        /* Frequency estimation from div_tc.
         * ch0,1 (square): f = 131072 / div_tc
         * ch2  (wave):    f = 65536  / div_tc
         * ch3  (noise):   approximate */
        unsigned int freq_hz = 0;
        if (div_t > 0) {
            if (ch == 0 || ch == 1)
                freq_hz = (unsigned int)(131072.0 / div_t);
            else if (ch == 2)
                freq_hz = (unsigned int)(65536.0 / div_t);
        }
        vgm_last_note[ch] = freq_hz;
        vgm_last_vol[ch]  = (on && vol > 0) ? (unsigned int)(vol * 255 / 15) : 0;
    }
}

/* ── read ────────────────────────────────────────────────────────────────── */

static uint64_t gbsplay_read(RewampDecoder *dec, float *out,
                              uint64_t frameCount)
{
    if (!dec || !dec->gbs || dec->finished || frameCount == 0) return 0;

    /* Apply voice-mute changes from the UI (Modizer: gbs_toggle_setmute). */
    if (dec->lastMuteMask != generic_mute_mask) {
        dec->lastMuteMask = generic_mute_mask;
        for (int ch = 0; ch < GBS_VOICE_COUNT; ch++)
            gbs_toggle_setmute(dec->gbs, ch,
                               (generic_mute_mask >> ch) & 1 ? 1 : 0);
    }

    uint64_t written = 0;
    while (written < frameCount) {
        /* Pump the emulator until the FIFO has data (or we hit EOF). */
        if (dec->fifo_frames == 0) {
            if (!gbs_step(dec->gbs, GBS_STEP_MS)) { dec->finished = 1; break; }
            if (dec->fifo_frames == 0) continue; /* step produced no flush yet */
        }

        int take = (int)(frameCount - written);
        if (take > dec->fifo_frames) take = dec->fifo_frames;

        const int16_t *src = dec->fifo;
        float         *dst = out + written * GBS_STEREO;
        for (int i = 0; i < take * GBS_STEREO; i++)
            dst[i] = src[i] / 32768.0f;

        /* Shift remaining FIFO frames down. */
        int remain = dec->fifo_frames - take;
        if (remain > 0) {
            memmove(dec->fifo,
                    dec->fifo + take * GBS_STEREO,
                    (size_t)remain * GBS_STEREO * sizeof(int16_t));
        }
        dec->fifo_frames = remain;
        written += (uint64_t)take;
    }

    gbsplay_capture_voices(dec);
    return written;
}

/* ── seek ────────────────────────────────────────────────────────────────── */

static void gbsplay_seek(RewampDecoder *dec, uint64_t frameIndex)
{
    if (!dec || !dec->gbs) return;
    /* Re-init the current subsong and fast-forward by skipping audio */
    const struct gbs_status *st = gbs_get_status(dec->gbs);
    int subsong = st ? (int)st->subsong : 0;
    gbs_init(dec->gbs, subsong);
    dec->fifo_frames = 0;
    dec->finished    = 0;
    /* gbs_init resets the engine's per-channel mute state while the plugin's
     * change-detection cache (and the restored generic_mute_mask) kept their
     * values — re-apply the user's mutes or they are silently dropped. */
    for (int ch = 0; ch < GBS_VOICE_COUNT; ch++)
        gbs_toggle_setmute(dec->gbs, ch,
                           (generic_mute_mask >> ch) & 1 ? 1 : 0);

    /* Fast-forward by running gbs_step and discarding audio.
     * Disable voice-buffer writes during seek (gbhw.c checks seek_needed). */
    gbs_seek_needed = 0;
    uint64_t done = 0;
    while (done < frameIndex) {
        if (!gbs_step(dec->gbs, GBS_STEP_MS)) break;
        done += (uint64_t)dec->fifo_frames;
        dec->fifo_frames = 0;
    }
    gbs_seek_needed = -1;
}

/* ── length ──────────────────────────────────────────────────────────────── */

static uint64_t gbsplay_length(RewampDecoder *dec)
{
    if (!dec || !dec->gbs) return 0;
    const struct gbs_status *st = gbs_get_status(dec->gbs);
    if (!st) return 0;
    /* subsong_len is in GBS_LEN_DIV ticks (1024 ticks = 1 second) */
    if (st->subsong_len == 0) return 0;
    return (uint64_t)((double)st->subsong_len / 1024.0 * GBS_RATE);
}

/* ── close ───────────────────────────────────────────────────────────────── */

static void gbsplay_close(RewampDecoder *dec)
{
    if (!dec) return;
    if (dec->gbs)     gbs_close(dec->gbs);
    if (dec->pcm_buf) free(dec->pcm_buf);
    if (dec->fifo)    free(dec->fifo);
    free(dec);
}

/* ── vtable ──────────────────────────────────────────────────────────────── */

/* Live settings change (called under the decode lock). */
static void gbsplay_param_changed(struct RewampDecoder* dec, const char* key) {
    (void)key;
    if (dec && dec->gbs)
        gbs_set_filter(dec->gbs, (enum gbs_filter_type)
            (int)rewamp_get_engine_param("gbsplay", "hp_filter", 1));
}

static const RewampPluginVTable kGbsplayVTable = {
    "gbsplay",
    gbsplay_probe,
    gbsplay_open,
    gbsplay_read,
    gbsplay_seek,
    gbsplay_length,
    gbsplay_close,
    NULL,                   /* configure_loop */
    0,                      /* supportsNativeFadeout */
    "gbsplay",              /* engine_id */
    gbsplay_param_changed,  /* live settings */
};

const RewampPluginVTable* rewamp_gbsplay_plugin(void) {
    return &kGbsplayVTable;
}

#endif /* REWAMP_WITH_GBSPLAY */

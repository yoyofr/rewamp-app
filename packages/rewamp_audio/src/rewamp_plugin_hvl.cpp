/* HivelyTracker plugin — .hvl (HivelyTracker) + .ahx (AHX) via the vendored
 * hvl_replay from Modizer (third_party/hivelytracker, inline voice-capture
 * patches: cores honor generic_mute_mask and write m_voice_buff with a
 * circular 1024-sample ring). Native replayer — preferred over UADE for AHX
 * (probe 64 > uade's suffix 58), like Modizer's MMP_HVL. */
#ifdef REWAMP_WITH_HVL

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"

#include "hvl_replay.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define HVL_RATE 44100

struct RewampDecoder {
    struct hvl_tune* ht;
    int              voices;
    /* One-frame FIFO: hvl_DecodeFrame renders rate/50 frames per call
     * (it runs the sequencer via hvl_play_irq — mixchunk alone is silent). */
    int16_t*         fifo;        /* frameSamples * 2 int16 */
    int              fifoSamples; /* capacity in frames */
    int              fifoPos;     /* consumed frames */
    int              fifoLen;     /* valid frames */
};

static const char* const kHvlExts[] = { "hvl", "ahx", "thx", NULL };

static int hvl_probe(const char* ext, const uint8_t* h, size_t n) {
    /* Magic: "HVL" (Hively) / "THX" (AHX). */
    int magic = 0;
    if (h && n >= 3) {
        if (h[0] == 'H' && h[1] == 'V' && h[2] == 'L') magic = 1;
        if (h[0] == 'T' && h[1] == 'H' && h[2] == 'X') magic = 1;
    }
    const int extMatch = ext && rewamp_ext_in_list(ext, kHvlExts);
    if (magic) return extMatch ? 100 : 64;   /* 64 beats uade's suffix 58 */
    if (extMatch) return 64;
    return 0;
}

static RewampDecoder* hvl_open(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;

    char cleanPath[4096];
    int  subsong = 0;
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char* q = strrchr(cleanPath, '?');
    if (q && strncmp(q, "?subsong=", 9) == 0) { subsong = atoi(q + 9); *q = '\0'; }

    hvl_InitReplayer();   /* idempotent table setup */
    struct hvl_tune* ht = hvl_LoadTune((TEXT*)cleanPath, HVL_RATE, 1);
    if (!ht) return NULL;

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { hvl_FreeTune(ht); return NULL; }
    dec->ht     = ht;
    dec->voices = ht->ht_Channels;
    if (dec->voices < 1) dec->voices = 4;
    if (dec->voices > HVL_MAX_CHANNELS) dec->voices = HVL_MAX_CHANNELS;

    /* Ring buffers BEFORE InitSubsong/mix (cores write m_voice_buff inline,
     * circular ring masked SOUND_BUFFER_SIZE_SAMPLE*4*2-1 = 4096 samples).
     * MUST be >= ~2212 (rewamp_channel_buf_triggered's outLen+TRIGGER_SEARCH_LEN)
     * or the scope's stabilization search silently never runs — see PLUGINS.md
     * §2.3 (was SOUND_BUFFER_SIZE_SAMPLE*2=1024, undersized, fixed 2026-07-07). */
    m_genNumVoicesChannels = dec->voices;
    rewamp_channel_data_reset(dec->voices);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2);
    rewamp_channel_data_set_ring_circular(1);

    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("Paula", 0, dec->voices);

    /* Info panel. */
    if (ht->ht_Name[0])
        rewamp_track_message_append("Title: %s\n", ht->ht_Name);
    rewamp_track_message_append("Channels: %d\nSubsongs: %d\n",
                                (int)ht->ht_Channels,
                                (int)ht->ht_SubsongNr + 1);

    if (!hvl_InitSubsong(ht, (uint32)(subsong > 0 ? subsong : 0))) {
        hvl_FreeTune(ht);
        free(dec);
        return NULL;
    }

    if (outFormat) {
        outFormat->channels   = 2;
        outFormat->sampleRate = HVL_RATE;
    }
    return dec;
}

static uint64_t hvl_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || !dec->ht || frameCount == 0) return 0;

    if (!dec->fifo) {
        dec->fifoSamples = (int)(dec->ht->ht_Frequency / 50);
        if (dec->fifoSamples <= 0) return 0;
        dec->fifo = (int16_t*)malloc((size_t)dec->fifoSamples * 2 *
                                     sizeof(int16_t));
        if (!dec->fifo) return 0;
    }

    const float scale = 1.0f / 32768.0f;
    uint64_t written = 0;
    while (written < frameCount) {
        if (dec->fifoPos >= dec->fifoLen) {
            if (dec->ht->ht_SongEndReached) break;
            /* DecodeFrame = hvl_play_irq (sequencer) + mix of one 1/50s frame,
             * int16 L/R via two byte pointers with stride 4. */
            hvl_DecodeFrame(dec->ht, (int8*)dec->fifo,
                            (int8*)dec->fifo + 2, 4);
            dec->fifoPos = 0;
            dec->fifoLen = dec->fifoSamples;
        }
        const int take0 = (int)(frameCount - written);
        const int avail = dec->fifoLen - dec->fifoPos;
        const int take  = take0 < avail ? take0 : avail;
        const int16_t* src = dec->fifo + (size_t)dec->fifoPos * 2;
        float* dst = out + written * 2;
        for (int i = 0; i < take * 2; i++) dst[i] = src[i] * scale;
        dec->fifoPos += take;
        written += (uint64_t)take;
    }
    return written;
}

static void hvl_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec || !dec->ht) return;
    hvl_Seek(dec->ht, (int)(frameIndex * 1000ull / HVL_RATE));
    dec->fifoPos = dec->fifoLen = 0;   /* drop stale mixed audio */
}

static uint64_t hvl_length(RewampDecoder* dec) {
    if (!dec || !dec->ht) return 0;
    const int ms = hvl_GetPlayTime(dec->ht);
    if (ms <= 0) return 0;
    return (uint64_t)ms * HVL_RATE / 1000ull;
}

static void hvl_close(RewampDecoder* dec) {
    if (!dec) return;
    if (dec->ht) hvl_FreeTune(dec->ht);
    free(dec->fifo);
    free(dec);
}

static const RewampPluginVTable kHvlVTable = {
    "hivelytracker",
    hvl_probe,
    hvl_open,
    hvl_read,
    hvl_seek,
    hvl_length,
    hvl_close,
};

extern "C" const RewampPluginVTable* rewamp_hvl_plugin(void) { return &kHvlVTable; }

/* Subsong count probe (AHX/HVL list subsongs in the header). */
extern "C" int rewamp_hvl_probe_subsong_count(const char* path) {
    if (!path) return 0;
    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char* q = strrchr(cleanPath, '?');
    if (q) *q = '\0';
    hvl_InitReplayer();
    struct hvl_tune* ht = hvl_LoadTune((TEXT*)cleanPath, HVL_RATE, 1);
    if (!ht) return 0;
    const int n = ht->ht_SubsongNr + 1;
    hvl_FreeTune(ht);
    return n;
}

#endif /* REWAMP_WITH_HVL */

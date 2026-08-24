/* ASAP plugin — Atari 8-bit POKEY formats (SAP, CMC, RMT, TMC, MPT, …).
 * Backed by the vendored generated ASAP C (third_party/asap: upstream release
 * + rewamp patches for per-channel voice capture, see patches/asap/).
 * Mirrors Modizer's MMP_ASAP: ASAP_Load / ASAP_PlaySong / ASAP_Generate /
 * ASAP_MutePokeyChannels; the patched core mirrors each POKEY channel into
 * m_voice_buff at (write ptr + sample idx) — this plugin advances the write
 * pointers after every generate call. */
#ifdef REWAMP_WITH_ASAP

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"

#include "asap.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ASAP_RING_SIZE (SOUND_BUFFER_SIZE_SAMPLE * 4 * 2)

struct RewampDecoder {
    ASAP*    asap;
    int      voices;        /* 4 (mono POKEY) or 8 (stereo/dual POKEY) */
    int      outChannels;   /* 1 or 2 */
    int      song;
    int      durationMs;    /* per-song duration from the file, -1 = unknown */
    int64_t  lastMuteMask;  /* applied generic_mute_mask snapshot */
    int16_t* pcm;           /* int16 scratch */
    int      pcmFrames;
};

/* Extensions ASAP owns (Modizer's SUPPORTED_FILETYPE_ASAP). NB: '.mpt' here is
 * Atari Music ProTracker, unrelated to OpenMPT (whose native ext is .mptm). */
static const char* const kAsapExts[] = {
    "sap", "cmc", "cm3", "cmr", "cms", "dmc", "dlt",
    "mpt", "mpd", "rmt", "tmc", "tm8", "tm2", NULL
};

static int asap_probe(const char* ext, const uint8_t* header, size_t headerSize) {
    /* SAP header magic is decisive; must beat libgme's generic SAP claim. */
    if (header && headerSize >= 3 &&
        header[0] == 'S' && header[1] == 'A' && header[2] == 'P') {
        return (ext && strcmp(ext, "sap") == 0) ? 110 : 90;
    }
    if (!ext) return 0;
    return rewamp_ext_in_list(ext, kAsapExts) ? 65 : 0;
}

static RewampDecoder* asap_open(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;

    char cleanPath[4096];
    int  subsong = 0;
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char* q = strrchr(cleanPath, '?');
    if (q && strncmp(q, "?subsong=", 9) == 0) { subsong = atoi(q + 9); *q = '\0'; }

    FILE* f = fopen(cleanPath, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (len <= 0 || len > 64 * 1024 * 1024) { fclose(f); return NULL; }
    uint8_t* data = (uint8_t*)malloc((size_t)len);
    if (!data) { fclose(f); return NULL; }
    size_t got = fread(data, 1, (size_t)len, f);
    fclose(f);
    if (got != (size_t)len) { free(data); return NULL; }

    ASAP* asap = ASAP_New();
    if (!asap) { free(data); return NULL; }
    if (!ASAP_Load(asap, cleanPath, data, (int)len)) {
        ASAP_Delete(asap);
        free(data);
        return NULL;
    }
    free(data);   /* ASAP copies what it needs */

    const ASAPInfo* info = ASAP_GetInfo(asap);
    const int songs   = ASAPInfo_GetSongs(info);
    int song = subsong;
    if (song < 0 || song >= songs) song = ASAPInfo_GetDefaultSong(info);
    const int durationMs = ASAPInfo_GetDuration(info, song); /* -1 = unknown */

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { ASAP_Delete(asap); return NULL; }
    dec->asap        = asap;
    dec->song        = song;
    dec->durationMs  = durationMs;
    dec->outChannels = ASAPInfo_GetChannels(info);   /* 1 or 2 */
    dec->voices      = dec->outChannels == 2 ? 8 : 4;

    /* Voice ring buffers BEFORE PlaySong (the patched core writes on the
     * first generated sample) + the *4*2 write mask used by the patch. */
    rewamp_channel_data_reset(dec->voices);
    rewamp_channel_data_set_ring_write_size(ASAP_RING_SIZE);
    /* accumul_temp[0] is allocated by reset(); the patch needs one per voice. */
    for (int ch = 1; ch < dec->voices; ch++) {
        if (!m_voice_buff_accumul_temp[ch]) {
            m_voice_buff_accumul_temp[ch] =
                (signed int*)calloc(ASAP_RING_SIZE, sizeof(signed int));
        }
    }

    /* Chip grouping + voice names (after reset — it wipes the tables). */
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip(dec->voices > 4 ? "POKEY 1" : "POKEY", 0, 4);
    if (dec->voices > 4) rewamp_voices_add_chip("POKEY 2", 4, 4);
    for (int v = 0; v < dec->voices; v++) {
        char nm[12];
        snprintf(nm, sizeof(nm), "Ch %d", (v % 4) + 1);
        rewamp_voice_set_name(v, nm);
    }

    /* Info panel. */
    {
        const char* s;
        s = ASAPInfo_GetTitle(info);
        if (s && s[0]) rewamp_track_message_append("Title: %s\n", s);
        s = ASAPInfo_GetAuthor(info);
        if (s && s[0]) rewamp_track_message_append("Author: %s\n", s);
        s = ASAPInfo_GetDate(info);
        if (s && s[0]) rewamp_track_message_append("Date: %s\n", s);
        rewamp_track_message_append("POKEY chips: %d\nSongs: %d\n",
                                    dec->outChannels, songs);
    }

    if (!ASAP_PlaySong(asap, song, durationMs)) {
        ASAP_Delete(asap);
        free(dec);
        return NULL;
    }

    if (outFormat) {
        outFormat->channels   = (uint32_t)dec->outChannels;
        outFormat->sampleRate = ASAP_SAMPLE_RATE;
    }
    return dec;
}

static uint64_t asap_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || !dec->asap || frameCount == 0) return 0;

    /* Apply voice-mute changes (bit v ⇒ muted; ASAP mask bit = mute). */
    if (dec->lastMuteMask != generic_mute_mask) {
        dec->lastMuteMask = generic_mute_mask;
        ASAP_MutePokeyChannels(dec->asap, (int)(generic_mute_mask & 0xFF));
    }

    if (dec->pcmFrames < (int)frameCount) {
        free(dec->pcm);
        dec->pcm = (int16_t*)malloc((size_t)frameCount * dec->outChannels *
                                    sizeof(int16_t));
        dec->pcmFrames = (int)frameCount;
    }
    if (!dec->pcm) return 0;

    const int wantBytes =
        (int)frameCount * dec->outChannels * (int)sizeof(int16_t);
    const int gotBytes = ASAP_Generate(dec->asap, (uint8_t*)dec->pcm,
                                       wantBytes, ASAPSampleFormat_S16_L_E);
    const int frames = gotBytes / (dec->outChannels * (int)sizeof(int16_t));
    if (frames <= 0) return 0;

    const float scale = 1.0f / 32768.0f;
    for (int i = 0; i < frames * dec->outChannels; i++)
        out[i] = dec->pcm[i] * scale;

    /* Advance the voice-scope write pointers by the frames just generated —
     * the patched Pokey_StoreSample wrote at (ptr + sample idx). */
    for (int v = 0; v < dec->voices; v++) {
        m_voice_current_ptr[v] +=
            (int64_t)frames << MODIZER_OSCILLO_OFFSET_FIXEDPOINT;
    }

    return (uint64_t)frames;
}

static void asap_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec || !dec->asap) return;
    const int ms = (int)(frameIndex * 1000ull / ASAP_SAMPLE_RATE);
    ASAP_Seek(dec->asap, ms);
}

static uint64_t asap_length(RewampDecoder* dec) {
    if (!dec || dec->durationMs <= 0) return 0;
    return (uint64_t)dec->durationMs * ASAP_SAMPLE_RATE / 1000ull;
}

static void asap_close(RewampDecoder* dec) {
    if (!dec) return;
    if (dec->asap) ASAP_Delete(dec->asap);
    free(dec->pcm);
    free(dec);
}

static const RewampPluginVTable kAsapVTable = {
    "asap",
    asap_probe,
    asap_open,
    asap_read,
    asap_seek,
    asap_length,
    asap_close,
};

const RewampPluginVTable* rewamp_asap_plugin(void) { return &kAsapVTable; }

/* Subsong probe for the Dart container UI (SAP files list N songs). */
int rewamp_asap_probe_subsong_count(const char* path) {
    if (!path) return 0;
    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char* q = strrchr(cleanPath, '?');
    if (q) *q = '\0';

    FILE* f = fopen(cleanPath, "rb");
    if (!f) return 0;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (len <= 0 || len > 16 * 1024 * 1024) { fclose(f); return 0; }
    uint8_t* data = (uint8_t*)malloc((size_t)len);
    if (!data) { fclose(f); return 0; }
    size_t got = fread(data, 1, (size_t)len, f);
    fclose(f);
    if (got != (size_t)len) { free(data); return 0; }

    ASAP* asap = ASAP_New();
    int songs = 0;
    if (asap && ASAP_Load(asap, cleanPath, data, (int)len))
        songs = ASAPInfo_GetSongs(ASAP_GetInfo(asap));
    if (asap) ASAP_Delete(asap);
    free(data);
    return songs;
}

#endif /* REWAMP_WITH_ASAP */

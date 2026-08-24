/* SNDH plugin — Atari ST .sndh chiptunes via the vendored AtariAudio library
 * (Arnaud Carré / Leonard, third_party/atariaudio: real 68000 emulation via
 * Musashi + cycle-accurate YM2149 + STE DAC). Mono output; miniaudio mirrors
 * it to stereo. Per-voice scope + notes + mute live in the vendored cores
 * (ym2149c.cpp fills m_voice_buff[0..2] for the PSG channels + honors
 * generic_mute_mask in the actual mix; AtariMachine.cpp does the same for
 * the STE DAC as voice 3 — grep YOYOFR). ICE-compressed .sndh (packed with
 * the classic Atari "Ice! 2.4" packer) is decompressed transparently inside
 * SndhFile::Load. NOTE: Musashi's CPU core is process-global state (single
 * static context) — only one SNDH file can be actively decoding at a time,
 * which matches rewamp's one-active-decoder architecture. */
#ifdef REWAMP_WITH_SNDH

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"

#include "SndhFile.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SNDH_RATE      44100
#define SNDH_VOICES    4   /* YM2149 A, B, C + STE DAC */
#define SNDH_RING_SIZE (SOUND_BUFFER_SIZE_SAMPLE * 4 * 2)   /* = ASAP's ring; see rewamp_channel_data_set_ring_write_size call below */

struct RewampDecoder {
    SndhFile sndh;
    int      subsongId;    /* 1-based, matches SNDH's own convention */
    uint64_t framePos;
    uint64_t totalFrames;  /* one loop's length; 0 = unknown */
};

static int sndh_probe(const char* ext, const uint8_t* header, size_t headerSize) {
    const int extMatch = ext && strcmp(ext, "sndh") == 0;
    /* Uncompressed files carry "SNDH" at offset 12; ICE-packed ones start
     * with "ICE!" instead (SndhFile::Load depacks before checking magic, so
     * we can't verify the inner magic here without doing that work twice —
     * the extension alone is decisive since no other plugin claims .sndh). */
    if (header && headerSize >= 16 && 0 == memcmp(header + 12, "SNDH", 4))
        return extMatch ? 100 : 90;
    if (header && headerSize >= 4 && 0 == memcmp(header, "ICE!", 4))
        return extMatch ? 95 : 40;
    return extMatch ? 90 : 0;
}

static RewampDecoder* sndh_open(const char* path, RewampAudioFormat* outFormat) {
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
    if (len <= 0 || len > 16 * 1024 * 1024) { fclose(f); return NULL; }
    uint8_t* data = (uint8_t*)malloc((size_t)len);
    if (!data) { fclose(f); return NULL; }
    size_t got = fread(data, 1, (size_t)len, f);
    fclose(f);
    if (got != (size_t)len) { free(data); return NULL; }

    RewampDecoder* dec = new RewampDecoder();
    if (!dec->sndh.Load(data, (int)len, SNDH_RATE)) {
        free(data);
        delete dec;
        return NULL;
    }
    free(data);   /* SndhFile keeps its own (possibly depacked) copy */

    const int songs = dec->sndh.GetSubsongCount();
    dec->subsongId = (subsong > 0 && subsong <= songs)
        ? subsong : dec->sndh.GetDefaultSubsong();

    SndhFile::SubSongInfo info;
    if (!dec->sndh.GetSubsongInfo(dec->subsongId, info) ||
        !dec->sndh.InitSubSong(dec->subsongId)) {
        delete dec;
        return NULL;
    }
    dec->totalFrames = (uint64_t)info.playerTickCount * (uint64_t)info.samplePerTick;

    /* Ring buffers BEFORE rendering (the patched cores write m_voice_buff
     * inline, circular ring masked to SNDH_RING_SIZE-1). SNDH_RING_SIZE MUST be
     * large enough for rewamp_channel_buf_triggered's stabilization search
     * (outLen=512 + TRIGGER_SEARCH_LEN=1700 ≈ 2212, see rewamp_channel_data.c) —
     * a too-small ring (e.g. bare SOUND_BUFFER_SIZE_SAMPLE=512, first tried
     * here) makes ring_read cap `available` at the ring size, so `searchLen`
     * comes out 0 and the correlation search never runs: the scope shows the
     * raw unaligned window every frame (looks unstable/jittery). Match ASAP's
     * SOUND_BUFFER_SIZE_SAMPLE*4*2=4096, which has the required headroom. */
    rewamp_channel_data_reset(SNDH_VOICES);
    rewamp_channel_data_set_ring_write_size(SNDH_RING_SIZE);
    rewamp_channel_data_set_ring_circular(1);
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("YM2149", 0, 3);
    rewamp_voices_add_chip("STE DAC", 3, 1);
    rewamp_voice_set_name(0, "PSG A");
    rewamp_voice_set_name(1, "PSG B");
    rewamp_voice_set_name(2, "PSG C");
    rewamp_voice_set_name(3, "DAC");

    /* Info panel. */
    if (info.musicTitle && info.musicTitle[0])
        rewamp_track_message_append("Title: %s\n", info.musicTitle);
    if (info.musicSubTitle && info.musicSubTitle[0])
        rewamp_track_message_append("Subtitle: %s\n", info.musicSubTitle);
    if (info.musicAuthor && info.musicAuthor[0])
        rewamp_track_message_append("Author: %s\n", info.musicAuthor);
    if (info.year && info.year[0])
        rewamp_track_message_append("Year: %s\n", info.year);
    if (info.ripper && info.ripper[0])
        rewamp_track_message_append("Ripper: %s\n", info.ripper);
    if (info.converter && info.converter[0])
        rewamp_track_message_append("Converter: %s\n", info.converter);
    rewamp_track_message_append("Player rate: %dHz\nSubsongs: %d\n",
                                info.playerTickRate, songs);

    if (outFormat) {
        outFormat->channels   = 1;
        outFormat->sampleRate = SNDH_RATE;
    }
    return dec;
}

static uint64_t sndh_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || frameCount == 0) return 0;

    static int16_t buf[4096];
    const float scale = 1.0f / 32768.0f;
    uint64_t written = 0;
    while (written < frameCount) {
        const uint64_t remain = frameCount - written;
        int want = (int)(remain > 4096 ? 4096 : remain);
        int loops = dec->sndh.AudioRender(buf, want, NULL);
        for (int i = 0; i < want; i++)
            out[written + (uint64_t)i] = buf[i] * scale;
        written += (uint64_t)want;
        dec->framePos += (uint64_t)want;
        if (loops > 0) break;   /* one full loop rendered → report EOF next call */
    }
    return written;
}

extern "C" volatile int    g_seek_cancel;
extern "C" volatile int    g_is_seeking;
extern "C" volatile double g_seek_progress_s;

static void sndh_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec) return;
    if (frameIndex < dec->framePos) {
        dec->sndh.InitSubSong(dec->subsongId);
        dec->framePos = 0;
    }
    if (dec->framePos == frameIndex) return;
    g_is_seeking = 1;
    int16_t tmp[512];
    while (dec->framePos < frameIndex && !g_seek_cancel) {
        uint64_t room = frameIndex - dec->framePos;
        int want = (int)(room > 512 ? 512 : room);
        dec->sndh.AudioRender(tmp, want, NULL);   /* discard, still writes the scope */
        dec->framePos += (uint64_t)want;
        g_seek_progress_s = (double)dec->framePos / (double)SNDH_RATE;
    }
    g_is_seeking = 0;
}

static uint64_t sndh_length(RewampDecoder* dec) {
    return dec ? dec->totalFrames : 0;
}

static void sndh_close(RewampDecoder* dec) {
    delete dec;
}

static const RewampPluginVTable kSndhVTable = {
    "sndh",
    sndh_probe,
    sndh_open,
    sndh_read,
    sndh_seek,
    sndh_length,
    sndh_close,
};

extern "C" const RewampPluginVTable* rewamp_sndh_plugin(void) { return &kSndhVTable; }

/* ── Subsong probe (Dart container UI: SNDH files may list up to 128 songs) ── */
static SndhFile g_probe_sndh;
static bool     g_probe_loaded = false;
static char     g_probe_title[256];

extern "C" int rewamp_sndh_probe_subsong_count(const char* path) {
    g_probe_sndh.Unload();
    g_probe_loaded = false;
    if (!path) return 0;
    char clean[4096];
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    char* q = strrchr(clean, '?');
    if (q) *q = '\0';

    FILE* f = fopen(clean, "rb");
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

    const bool ok = g_probe_sndh.Load(data, (int)len, SNDH_RATE);
    free(data);
    if (!ok) return 0;
    g_probe_loaded = true;
    return g_probe_sndh.GetSubsongCount();
}

/* SNDH subsong ids are 1-based already — base=1 so the absolute index the
 * Dart layer advertises via ?subsong= is exactly what InitSubSong() expects. */
extern "C" int rewamp_sndh_probe_base(void) { return 1; }

extern "C" const char* rewamp_sndh_probe_get_title(int idx) {
    if (!g_probe_loaded) return "";
    SndhFile::SubSongInfo info;
    if (!g_probe_sndh.GetSubsongInfo(idx + 1, info)) return "";
    const char* t = (info.musicSubTitle && info.musicSubTitle[0])
        ? info.musicSubTitle : info.musicTitle;
    if (!t) return "";
    strncpy(g_probe_title, t, sizeof(g_probe_title) - 1);
    g_probe_title[sizeof(g_probe_title) - 1] = '\0';
    return g_probe_title;
}

extern "C" int rewamp_sndh_probe_get_duration_ms(int idx) {
    if (!g_probe_loaded) return -1;
    SndhFile::SubSongInfo info;
    if (!g_probe_sndh.GetSubsongInfo(idx + 1, info)) return -1;
    if (info.playerTickCount <= 0 || info.playerTickRate <= 0) return -1;
    return info.playerTickCount * 1000 / info.playerTickRate;
}

#endif /* REWAMP_WITH_SNDH */

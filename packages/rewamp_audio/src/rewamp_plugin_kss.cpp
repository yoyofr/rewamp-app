// rewamp_plugin_kss.cpp — libkss decoder plugin (MSX chiptunes).
//
// Plays the MSX music formats libkss covers, auto-detected by content:
//   .kss  — native KSS/KSSX ROM dumps (also claimed by libgme; we score above
//           it so the per-chip voice grouping below wins)
//   .mgs  — MGSDRV                .bgm — Kinrou5
//   .mpk  — MuSICA MPK 103/106    .mbm — MoonBlaster
//   .opx  — OPX                   .mus — MSX music (MGS/… by content)
//
// libkss mixes up to four MSX sound chips; the exact set is stamped in the KSS
// header flags. The Modizer per-voice scope/notes/mute capture lives inside the
// vendored cores (kssplay.c + the emu2149/emu2212/emu2413/emu8950/emu76489
// cores write m_voice_buff[] via m_voicesForceOfs and honor generic_mute_mask —
// grep YOYOFR). This plugin wires playback + the chip grouping metadata that the
// cores' fixed voice-offset order expects:
//   [Y8950 15][YM2413 14][SN76489 4 | AY-PSG 3][Konami SCC 5]
// (OPL/OPLL only when the header advertises them; PSG + SCC are always present,
// matching kssplay.c's calc_stereo offset advances).

#ifdef REWAMP_WITH_KSS

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"   // per-voice scope + chip grouping

extern "C" {
#include "kssplay.h"               // KSSPLAY API + full struct (opll_stereo, kss…)
#include "kss.h"                   // KSS struct, KSS_load_file, KSS_check_type
}

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

// kssplay.c's YOYOFR post-loop reads this global to know how many voice buffers
// to filter — the plugin owns it (like openmpt/sid/v2m/hvl).
extern "C" int m_genNumVoicesChannels;

#define KSS_CHANNELS 2
#define KSS_RATE     44100
// kssplay.c voice ring mask: SOUND_BUFFER_SIZE_SAMPLE*4*2 = 512*4*2.
#define KSS_RING_SAMPLES (512 * 4 * 2)

struct RewampDecoder {
    KSSPLAY*  play;
    KSS*      kss;
    int       track;      // absolute KSS track number
    int       rate;
    int16_t*  pcm;        // scratch interleaved int16 stereo
    uint64_t  pcmFrames;
    uint64_t  lengthFrames;
};

static const char* const kKssExts[] = {
    "kss", "mgs", "bgm", "mpk", "mbm", "opx", "mus", NULL
};

static int kss_probe(const char* ext, const uint8_t* hdr, size_t n) {
    if (!ext || !rewamp_ext_in_list(ext, kKssExts)) return 0;
    // Confirm the bytes actually decode to a libkss format (KSS_check_type reads
    // magic for MGS/MPK/OPX/BGM/KSS and the extension for MBM). This declines
    // e.g. Doom-style .mus files so we don't hijack them.
    char fakename[32];
    snprintf(fakename, sizeof(fakename), "probe.%s", ext);
    int type = KSS_check_type((uint8_t*)hdr, (uint32_t)n, fakename);
    if (type == KSS_TYPE_UNKNOWN) return 0;
    // .kss is shared with libgme (header score 100); beat it for the voice model.
    return (strcmp(ext, "kss") == 0) ? 101 : 90;
}

// Register the chip groups in the exact order kssplay.c advances m_voicesForceOfs
// so each chip's scope writes land in the matching voice slots. Returns total.
static int kss_setup_voices(const KSS* kss) {
    rewamp_voices_meta_reset();
    char nm[24];
    int total = 0;
    #define ADD_CHIP(label, cnt)                                            \
        do {                                                                \
            rewamp_voices_add_chip(label, total, (cnt));                    \
            for (int i = 0; i < (cnt); i++) {                               \
                snprintf(nm, sizeof(nm), label " %d", i + 1);              \
                rewamp_voice_set_name(total + i, nm);                       \
            }                                                               \
            total += (cnt);                                                 \
        } while (0)

    if (kss->msx_audio) ADD_CHIP("Y8950", 15);   // MSX-Audio (OPL, ch14 = ADPCM)
    if (kss->fmpac)     ADD_CHIP("YM2413", 14);  // FMPAC (OPLL)
    if (kss->sn76489)   ADD_CHIP("SN76489", 4);  // SG/GG/SMS PSG
    else                ADD_CHIP("PSG", 3);      // AY-3-8910 (YM2149)
    ADD_CHIP("SCC", 5);                          // Konami SCC (always mixed)

    #undef ADD_CHIP
    return total;
}

static RewampDecoder* kss_open(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;

    // Strip ?subsong=N (rewamp convention, 0-based); keep the clean path for the
    // format converters that key off the filename extension (MBM).
    char clean[4096];
    int subsong = 0;
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    char* q = strrchr(clean, '?');
    if (q && strncmp(q, "?subsong=", 9) == 0) { subsong = atoi(q + 9); *q = '\0'; }

    KSS* kss = KSS_load_file(clean);
    if (!kss) return NULL;

    // ?subsong=N is the ABSOLUTE KSS song number (KSSPLAY_reset's argument), the
    // same value the native probe advertises (base+i) and the server/m3u raw
    // numbers carry. A bare open (N=0) or an out-of-range value clamps into the
    // file's [trk_min, trk_max] range → the first song. (Adding trk_min here would
    // double-count the base for KSSX files whose first song is >0.)
    int track = subsong;
    if (track < (int)kss->trk_min) track = (int)kss->trk_min;
    if (track > (int)kss->trk_max) track = (int)kss->trk_max;

    KSSPLAY* play = KSSPLAY_new(KSS_RATE, KSS_CHANNELS, 16);
    if (!play) { KSS_delete(kss); return NULL; }
    KSSPLAY_set_data(play, kss);

    // Per-voice scope + chip grouping. Allocate the voice buffers BEFORE the
    // first render — kssplay.c/emu cores write m_voice_buff[*] unguarded.
    int voices = kss_setup_voices(kss);
    m_genNumVoicesChannels = voices;
    rewamp_channel_data_reset(voices);
    rewamp_channel_data_set_ring_write_size(KSS_RING_SAMPLES);
    // The cores wrap m_voice_current_ptr mod the ring (not monotonic) → circular
    // read so the scope shows a full window instead of blanking on each wrap.
    rewamp_channel_data_set_ring_circular(1);

    KSSPLAY_reset(play, (uint32_t)track, 0);

    // Mixer setup (mirrors Modizer): higher device quality, stereo spread.
    KSSPLAY_set_device_quality(play, EDSC_PSG, 1);
    KSSPLAY_set_device_quality(play, EDSC_SCC, 1);
    KSSPLAY_set_device_quality(play, EDSC_OPLL, 1);
    KSSPLAY_set_master_volume(play, 64);
    KSSPLAY_set_device_pan(play, EDSC_PSG, -32);
    KSSPLAY_set_device_pan(play, EDSC_SCC,  32);
    play->opll_stereo = 1;
    for (int c = 0; c < 6; c++)
        KSSPLAY_set_channel_pan(play, EDSC_OPLL, c, (c & 1) ? 2 : 1);

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { KSSPLAY_delete(play); KSS_delete(kss); return NULL; }
    dec->play  = play;
    dec->kss   = kss;
    dec->track = track;
    dec->rate  = KSS_RATE;

    // Duration from the KSS info table (ms) when present, else host default.
    if (kss->info && track < (int)kss->info_num && kss->info[track].time_in_ms > 0)
        dec->lengthFrames = (uint64_t)kss->info[track].time_in_ms * KSS_RATE / 1000;

    // Info panel metadata.
    if (kss->title[0]) rewamp_track_message_append("Title: %s\n", (const char*)kss->title);
    if (kss->info && track < (int)kss->info_num && kss->info[track].title[0])
        rewamp_track_message_append("Track: %s\n", kss->info[track].title);
    int subCount = (int)kss->trk_max - (int)kss->trk_min + 1;
    if (subCount > 1) rewamp_track_message_append("Subsongs: %d\n", subCount);
    if (kss->extra && kss->extra[0])
        rewamp_track_message_append("\n%s\n", (const char*)kss->extra);

    outFormat->channels   = KSS_CHANNELS;
    outFormat->sampleRate  = (uint32_t)KSS_RATE;
    return dec;
}

static uint64_t kss_read_frames(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || !dec->play || !out || frameCount == 0) return 0;
    if (frameCount > dec->pcmFrames) {
        free(dec->pcm);
        dec->pcm = (int16_t*)malloc(frameCount * KSS_CHANNELS * sizeof(int16_t));
        dec->pcmFrames = dec->pcm ? frameCount : 0;
    }
    if (!dec->pcm) return 0;

    KSSPLAY_calc(dec->play, dec->pcm, (uint32_t)frameCount);
    const int samples = (int)(frameCount * KSS_CHANNELS);
    const float inv = 1.0f / 32768.0f;
    for (int i = 0; i < samples; i++) out[i] = dec->pcm[i] * inv;
    return frameCount;   // KSS loops; the host enforces length/fade
}

static void kss_seek_frames(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec || !dec->play) return;
    // No random seek: reset and render-skip to the target (Modizer approach).
    KSSPLAY_reset(dec->play, (uint32_t)dec->track, 0);
    uint64_t remaining = frameIndex;
    while (remaining > 0) {
        uint32_t chunk = remaining > 4096 ? 4096 : (uint32_t)remaining;
        KSSPLAY_calc_silent(dec->play, chunk);
        remaining -= chunk;
    }
}

static uint64_t kss_length_frames(RewampDecoder* dec) {
    return dec ? dec->lengthFrames : 0;   // 0 → host uses the default length
}

static void kss_close(RewampDecoder* dec) {
    if (!dec) return;
    if (dec->play) KSSPLAY_delete(dec->play);
    if (dec->kss)  KSS_delete(dec->kss);
    free(dec->pcm);
    free(dec);
}

// ── Subsong probe (libkss-authoritative) ────────────────────────────────────
// libgme can't reliably count KSS tracks (a plain KSCC file carries no track
// count → GME guesses 256; KSSX indexes its first/last song differently), so the
// registry routes kss-family files here. The count is the KSS song range and the
// index i (0-based, matching kss_open's `track = trk_min + i`) maps title/duration
// through kss->info. State is kept until the next probe (rewamp_audio.c contract).
static KSS* g_probe_kss    = NULL;
static int  g_probe_trkmin = 0;
static char g_probe_title[KSS_TITLE_MAX];

extern "C" int rewamp_kss_probe_subsong_count(const char* path) {
    if (g_probe_kss) { KSS_delete(g_probe_kss); g_probe_kss = NULL; }
    if (!path) return 0;
    char clean[4096];
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    char* q = strrchr(clean, '?');
    if (q && strncmp(q, "?subsong=", 9) == 0) *q = '\0';

    KSS* kss = KSS_load_file(clean);
    if (!kss) return 0;
    g_probe_kss    = kss;
    g_probe_trkmin = (int)kss->trk_min;
    return (int)kss->trk_max - (int)kss->trk_min + 1;
}

// The first song number (trk_min). The native-probe path adds this to its 0-based
// position so the subsong index it advertises is the ABSOLUTE KSS song number,
// matching the m3u/server raw numbers and kss_open's `track = subsong`.
extern "C" int rewamp_kss_probe_base(void) { return g_probe_trkmin; }

extern "C" const char* rewamp_kss_probe_get_title(int idx) {
    KSS* kss = g_probe_kss;
    if (!kss) return "";
    int track = g_probe_trkmin + idx;
    if (kss->info && track >= 0 && track < (int)kss->info_num && kss->info[track].title[0]) {
        strncpy(g_probe_title, kss->info[track].title, sizeof(g_probe_title) - 1);
        g_probe_title[sizeof(g_probe_title) - 1] = '\0';
        return g_probe_title;
    }
    return "";
}

extern "C" int rewamp_kss_probe_get_duration_ms(int idx) {
    KSS* kss = g_probe_kss;
    if (!kss) return -1;
    int track = g_probe_trkmin + idx;
    if (kss->info && track >= 0 && track < (int)kss->info_num && kss->info[track].time_in_ms > 0)
        return kss->info[track].time_in_ms;
    return -1;
}

static const RewampPluginVTable kKssVTable = {
    "kss",
    kss_probe,
    kss_open,
    kss_read_frames,
    kss_seek_frames,
    kss_length_frames,
    kss_close,
};

extern "C" const RewampPluginVTable* rewamp_kss_plugin(void) { return &kKssVTable; }

#endif /* REWAMP_WITH_KSS */

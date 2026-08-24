// rewamp_plugin_nez.cpp — NEZplug++ decoder plugin (HES + SGC/SMS).
//
// rewamp already covers nsf/gbs/hes/kss/ay via libgme; nez is wired specifically
// for the formats where its per-chip voice model shines:
//   .hes → HuC6280 (PC-Engine), 6 voices   — taken over from GME for the grouping
//   .sgc → SN76489 (SG-1000/Game Gear/SMS), 4 PSG voices; Sega Master System
//          tunes add a YM2413 FM chip (11 voices)
//
// Per-voice oscilloscope + notes + mute are produced inside the vendored nez
// cores (device/s_hes.c, s_sng.c, opl/s_opl.c write nezChan_output[]; format/
// audiosys.c copies that into m_voice_buff[] and honors generic_mute_mask). This
// plugin just wires playback + the chip grouping metadata.

#ifdef REWAMP_WITH_NEZ

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"   // per-voice scope + chip grouping

extern "C" {
#include "nezplug.h"               // NEZ_PLAY, NEZ*, SONGINFO_GetType (via songinfo.h)
}

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

// nez global config knobs (defined in the vendored cores); mirror Modizer's setup.
extern "C" {
extern int NSF_noise_random_reset, NSF_2A03Type, Namco106_Realmode, Namco106_Volume;
extern int GBAMode, MSXPSGType, MSXPSGVolume, FDS_RealMode, LowPassFilterLevel;
extern int NESAPUVolume, NESRealDAC, Always_stereo;
}

#define NEZ_CHANNELS 2
#define NEZ_RING_SAMPLES (512 * 2 * 4)   // audiosys.c mask: SOUND_BUFFER_SIZE_SAMPLE*2*4

struct RewampDecoder {
    NEZ_PLAY* play;
    uint8_t*  file;       // nez keeps no copy of the module data → we own it
    uint32_t  fileLen;
    int       rate;
    int16_t*  pcm;        // scratch interleaved int16 stereo
    uint64_t  pcmFrames;
    int       ended;
};

static const char* const kNezExts[] = { "hes", "sgc", NULL };

static int nez_probe(const char* ext, const uint8_t* hdr, size_t n) {
    if (!ext || !rewamp_ext_in_list(ext, kNezExts)) return 0;
    // HES is also claimed by libgme (score 100 on header). Register nez BEFORE
    // gme and score above it so .hes routes here for the HuC6280 voice grouping.
    if (strcmp(ext, "hes") == 0) {
        if (n >= 4 && memcmp(hdr, "HESM", 4) == 0) return 120;
        return 101;
    }
    // .sgc has no other claimant.
    return 70;
}

static void nez_apply_config(void) {
    NSF_noise_random_reset = 0;
    NSF_2A03Type   = 1;
    Namco106_Realmode = 1;
    Namco106_Volume   = 16;
    GBAMode        = 0;
    MSXPSGType     = 1;
    MSXPSGVolume   = 64;
    FDS_RealMode   = 3;
    LowPassFilterLevel = 16;
    NESAPUVolume   = 64;
    NESRealDAC     = 1;
    Always_stereo  = 1;
}

// Describe the chip layout so the voices UI can group + mute (mirrors Modizer
// ModizMusicPlayer.mm:10640-10689). Returns the total voice count.
static int nez_setup_voices(NEZ_PLAY* play, const char* ext) {
    rewamp_voices_meta_reset();
    char nm[16];
    if (ext && strcmp(ext, "hes") == 0) {
        rewamp_voices_add_chip("HuC6280", 0, 6);
        for (int i = 0; i < 6; i++) { snprintf(nm, sizeof(nm), "HuC6280 %d", i + 1); rewamp_voice_set_name(i, nm); }
        return 6;
    }
    // SGC: SN76489 PSG (4), plus YM2413 FM (11) for Sega Master System tunes.
    rewamp_voices_add_chip("SN76489", 0, 4);
    for (int i = 0; i < 4; i++) { snprintf(nm, sizeof(nm), "PSG %d", i + 1); rewamp_voice_set_name(i, nm); }
    int total = 4;
    const char* type = SONGINFO_GetType(play->song);
    if (type && strcmp(type, "Sega Master System") == 0) {
        rewamp_voices_add_chip("YM2413", 4, 11);
        for (int i = 0; i < 11; i++) { snprintf(nm, sizeof(nm), "FM %d", i + 1); rewamp_voice_set_name(4 + i, nm); }
        total = 15;
    }
    return total;
}

static RewampDecoder* nez_open(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;

    // Strip ?subsong=N (rewamp convention) and derive the lowercase extension.
    char clean[4096];
    int subsong = 0;
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    char* q = strrchr(clean, '?');
    if (q && strncmp(q, "?subsong=", 9) == 0) { subsong = atoi(q + 9); *q = '\0'; }
    const char* dot = strrchr(clean, '.');
    char ext[16] = {0};
    if (dot) { for (int i = 0; dot[i + 1] && i < 15; i++) ext[i] = (char)tolower((unsigned char)dot[i + 1]); }

    FILE* f = fopen(clean, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (len <= 0) { fclose(f); return NULL; }
    uint8_t* buf = (uint8_t*)malloc((size_t)len);
    if (!buf) { fclose(f); return NULL; }
    if (fread(buf, 1, (size_t)len, f) != (size_t)len) { free(buf); fclose(f); return NULL; }
    fclose(f);

    NEZ_PLAY* play = NEZNew();
    if (!play) { free(buf); return NULL; }

    int rate = 44100;
    NEZSetFrequency(play, (Uint)rate);
    NEZSetChannel(play, NEZ_CHANNELS);
    nez_apply_config();
    SONGINFO_Reset(play->song);

    if (NEZLoad(play, buf, (Uint)len) != 0) {   // 0 = NESERR_NOERROR (success)
        NEZDelete(play);
        free(buf);
        return NULL;
    }

    // rewamp ?subsong=N is 0-based; nez song numbers are 1-based (Modizer maps
    // m3u hex index → NEZSetSongNo(track+1)). Mapping N as-is collapsed
    // subsongs 0 and 1 onto the same nez song.
    NEZSetSongNo(play, (Uint)(subsong + 1));

    // Per-voice scope + chip grouping. Reset BEFORE NEZReset so the cores write
    // into freshly-allocated m_voice_buff[*] on the first render.
    int voices = nez_setup_voices(play, ext);
    rewamp_channel_data_reset(voices);
    rewamp_channel_data_set_ring_write_size(NEZ_RING_SAMPLES);
    // audiosys.c wraps m_voice_current_ptr mod NEZ_RING_SAMPLES (not monotonic),
    // like libnsfplay → mark the ring circular so the scope always reads a full
    // window instead of blanking each time the write pointer wraps (flicker fix).
    rewamp_channel_data_set_ring_circular(1);

    NEZReset(play);   // required — no sound without it

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { NEZDelete(play); free(buf); return NULL; }
    dec->play    = play;
    dec->file    = buf;
    dec->fileLen = (uint32_t)len;
    dec->rate    = rate;

    // Info panel: HES/SGC header metadata via SONGINFO.
    if (play->song) {
        const char* v;
        v = SONGINFO_GetTitle(play->song);
        if (v && v[0]) rewamp_track_message_append("Title: %s\n", v);
        v = SONGINFO_GetArtist(play->song);
        if (v && v[0]) rewamp_track_message_append("Artist: %s\n", v);
        v = SONGINFO_GetCopyright(play->song);
        if (v && v[0]) rewamp_track_message_append("Copyright: %s\n", v);
        v = SONGINFO_GetType(play->song);
        if (v && v[0]) rewamp_track_message_append("System: %s\n", v);
        int maxSong = (int)SONGINFO_GetMaxSongNo(play->song);
        if (maxSong > 1)
            rewamp_track_message_append("Subsongs: %d\n", maxSong);
        v = SONGINFO_GetDetail(play->song);
        if (v && v[0]) rewamp_track_message_append("\n%s\n", v);
    }

    outFormat->channels   = NEZ_CHANNELS;
    outFormat->sampleRate = (uint32_t)rate;
    return dec;
}

static uint64_t nez_read_frames(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || !dec->play || !out || frameCount == 0) return 0;
    if (frameCount > dec->pcmFrames) {
        free(dec->pcm);
        dec->pcm = (int16_t*)malloc(frameCount * NEZ_CHANNELS * sizeof(int16_t));
        dec->pcmFrames = dec->pcm ? frameCount : 0;
    }
    if (!dec->pcm) return 0;

    NEZRender(dec->play, dec->pcm, (Uint)frameCount);
    const int samples = (int)(frameCount * NEZ_CHANNELS);
    const float inv = 1.0f / 32768.0f;
    for (int i = 0; i < samples; i++) out[i] = dec->pcm[i] * inv;
    return frameCount;   // nez renders a full buffer (looping); host handles length
}

static void nez_seek_frames(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec || !dec->play) return;
    // No random seek: reset and render-skip to the target (Modizer approach).
    NEZReset(dec->play);
    int16_t tmp[4096 * NEZ_CHANNELS];
    uint64_t remaining = frameIndex;
    while (remaining > 0) {
        uint64_t chunk = remaining > 4096 ? 4096 : remaining;
        NEZRender(dec->play, tmp, (Uint)chunk);
        remaining -= chunk;
    }
    dec->ended = 0;
}

static uint64_t nez_length_frames(RewampDecoder* dec) {
    (void)dec;
    return 0;   // nez exposes no reliable duration → host uses the default length
}

static void nez_close(RewampDecoder* dec) {
    if (!dec) return;
    if (dec->play) NEZDelete(dec->play);
    free(dec->file);
    free(dec->pcm);
    free(dec);
}

static const RewampPluginVTable kNezVTable = {
    "nez",
    nez_probe,
    nez_open,
    nez_read_frames,
    nez_seek_frames,
    nez_length_frames,
    nez_close,
};

extern "C" const RewampPluginVTable* rewamp_nez_plugin(void) { return &kNezVTable; }

#endif /* REWAMP_WITH_NEZ */

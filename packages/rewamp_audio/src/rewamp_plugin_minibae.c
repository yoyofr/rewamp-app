// miniBAE plugin — Beatnik RMF (Rich Music Format), via the vendored NeoBAE
// fork of the Beatnik Audio Engine (third_party/minibae: Beatnik BSD-3 core,
// zefie's changes LGPL-3.0+, see its NOTICE).
//
// An RMF is an `IREZ` resource file: one SONG, its MIDI (usually `ecmi` =
// encrypted + compressed) and the instruments/samples it redefines (`INST`,
// `esnd`…). Everything it does NOT redefine comes from the General MIDI bank,
// which is embedded in the binary (rewamp_minibae_bank.h, generated from
// banks/patches111.hsb — the « Beatnik Standard » bank).
//
// Platform layer = the library's own BAE_API_Dummy.c: no audio device, no
// frame thread. We PULL audio with BAE_BuildMixerSlice, one 11 ms slice at a
// time, from the producer thread.
//
// ⚠️ The engine's current mixer is THREAD-LOCAL (GM_SetCurrentMixer). open()
// runs on the load isolate, read()/seek() on the producer: every entry point
// rebinds it with BAEMixer_MakeCurrent, or the slice renders into nothing.
//
// Symbols that exist elsewhere in the binary (adpcm-xq, minimp3, g72x) are
// renamed by the forced include third_party/minibae/rewamp_minibae_rename.h.
//
// Loop: generic (configure_loop NULL). The song is started with no repeat and
// ends by itself (BAESong_IsDone); the Dart side drives forced loops.
//
// Voices: one per MIDI channel, all 16 (the MIDI is encrypted inside the RMF:
// no cheap scan of the channels it uses — same rule as libADLMIDI for the
// formats it cannot scan).
//   - mute:  BAESong_MuteChannel, pushed when generic_mute_mask moves;
//   - notes: the sequencer's own held-note map (BAESong_GetAllActiveNotes),
//            polled once per 11 ms slice; a key going 0 → velocity = attack;
//   - scope: NeoBAE already splits the DRY mix per MIDI channel
//            (channelCaptureBuf, made for its WAV export). The REWAMP patch in
//            GenSynth.c (REWAMP_BAE_CAPTURE) hands each slice to
//            rewamp_bae_channel_slice below instead of writing files. DRY:
//            reverb and chorus are applied to the whole mix afterwards.
#ifdef REWAMP_WITH_MINIBAE

#include "rewamp_plugin.h"
#include "rewamp_audio.h"
#include "rewamp_channel_data.h"
#include "rewamp_gm_drums.h"
#include "ModizerVoicesData.h"
#include "ModizerConstants.h"
#include "NeoBAE.h"
#include "GenPriv.h"              /* GM_Mixer: the per-channel capture buffers */
/* ⚠️ GM_Mixer's LAYOUT depends on the build defines (BAE_FIX_SPAN_DC gates a
 * field before the capture ones): this TU must see EXACTLY the library's set,
 * or it writes channelCaptureEnabled at the wrong offset — silently, the
 * scope just stays flat (paid in the harness). cmake/podspecs pass the same
 * set to both; refuse to build otherwise. */
#if !defined(BAE_FIX_SPAN_DC) || !defined(REWAMP_BAE_CAPTURE) || !defined(USE_MPEG_DECODER)
#error "rewamp_plugin_minibae.c needs the miniBAE build defines (see cmake rewamp_add_minibae)"
#endif
#include "rewamp_minibae_bank.h"

#include <math.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern void BAE_BuildMixerSlice(void* threadContext, void* pAudioBuffer,
                                int32_t bufferByteLength, int32_t sampleFrames);

#define BAE_OUT_RATE   44100
#define BAE_SLICE      512        /* frames per BAE_BuildMixerSlice (11 ms) */
#define BAE_CHANNELS   16
#define BAE_DRUM_CH    9
#define BAE_RING_SIZE  (SOUND_BUFFER_SIZE_SAMPLE * 4 * 2)   /* power of 2 */
#define BAE_FP         MODIZER_OSCILLO_OFFSET_FIXEDPOINT

/* Plugin-private state: NOT `struct RewampDecoder` (ODR: each plugin has its
 * own state type, see check_decoder_odr.sh). */
typedef struct {
    BAEMixer mixer;
    BAESong  song;
    void*    data;           /* the RMF image: the song references it */
    uint32_t dataSize;
    uint64_t totalFrames;    /* song time, frozen at open (0 = unknown) */
    uint64_t framePos;       /* song time */
    double   speed, frac;
    uint32_t baseTempo;      /* the SONG's own master tempo (16.16), see set_speed */
    int16_t  slice[BAE_SLICE * 2];
    int      sliceLeft;      /* frames of `slice` not yet handed out */
    int      done;
    int64_t  muteApplied;    /* generic_mute_mask last pushed (-1 = none) */
    unsigned char notes[BAE_MAX_MIDI_CHANNELS][BAE_MAX_NOTES];  /* last poll */
    int      shown[BAE_CHANNELS];      /* key shown per channel, -1 none */
    unsigned attackVel[BAE_CHANNELS];
    int      written[BAE_CHANNELS];    /* scope: channel written this slice */
    int      capture;                  /* capture buffers allocated by us */
} BaeDec;

/* The decoder whose slice is being rendered: the GenSynth hook has no context
 * argument. One decoder at a time (the gapless handoff opens N+1 only after
 * closing N). */
static BaeDec* s_cur;

/* REWAMP_BAE_CAPTURE hook (GenSynth.c): one channel's DRY slice, interleaved
 * stereo, 16-bit range → mono 8-bit oscilloscope ring. */
void rewamp_bae_channel_slice(int ch, const int32_t* buf, int validSamples) {
    BaeDec* d = s_cur;
    if (!d || ch < 0 || ch >= BAE_CHANNELS || !m_voice_buff[ch]) return;
    const int mask = BAE_RING_SIZE - 1;
    const int frames = validSamples / 2;
    const int64_t base = m_voice_current_ptr[ch] >> BAE_FP;
    for (int k = 0; k < frames; k++) {
        int32_t s8 = (buf[2 * k] + buf[2 * k + 1]) >> 9;   /* (L+R)/2, 16 → 8 bits */
        if (s8 > 127) s8 = 127;
        if (s8 < -128) s8 = -128;
        m_voice_buff[ch][(base + k) & mask] = (signed char)s8;
    }
    d->written[ch] = 1;
}

static void bae_capture_on(BaeDec* d) {
    GM_Mixer* m = MusicGlobals;
    if (!m || m->channelCaptureEnabled) return;
    m->channelCaptureBufSamples = (m->maxChunkSize + 64) * 2;
    const size_t bytes = (size_t)m->channelCaptureBufSamples * sizeof(int32_t);
    m->channelCaptureSnapshot = (int32_t*)malloc(bytes);
    if (!m->channelCaptureSnapshot) return;
    for (int c = 0; c < 16; c++) {
        m->channelCaptureBuf[c] = (int32_t*)calloc(1, bytes);
        if (!m->channelCaptureBuf[c]) {
            for (int j = 0; j < c; j++) { free(m->channelCaptureBuf[j]); m->channelCaptureBuf[j] = NULL; }
            free(m->channelCaptureSnapshot); m->channelCaptureSnapshot = NULL;
            return;
        }
        m->channelCaptureFiles[c] = NULL;
        m->channelCaptureActive[c] = false;
    }
    m->channelCaptureEnabled = true;
    d->capture = 1;
}

static void bae_capture_off(BaeDec* d) {
    GM_Mixer* m = MusicGlobals;
    if (!m || !d->capture) return;
    m->channelCaptureEnabled = false;
    for (int c = 0; c < 16; c++) { free(m->channelCaptureBuf[c]); m->channelCaptureBuf[c] = NULL; }
    free(m->channelCaptureSnapshot); m->channelCaptureSnapshot = NULL;
    d->capture = 0;
}

static void bae_silence_notes(BaeDec* d) {
    memset(d->notes, 0, sizeof d->notes);
    for (int c = 0; c < BAE_CHANNELS; c++) {
        d->shown[c] = -1;
        d->attackVel[c] = 0;
        vgm_last_note[c] = 0;
        vgm_last_vol[c] = 0;
    }
}

static unsigned bae_key_hz(int key) {
    return (unsigned)(440.0 * pow(2.0, (key - 69) / 12.0) + 0.5);
}

/* After each slice: the sequencer's held keys → one note per channel. A key
 * that was up at the previous poll and is down now is an ATTACK (255 for one
 * read, then its velocity — the notation/piano cut a note when its volume
 * RISES, UADE's rule); otherwise the shown key stays while held, else the
 * highest held key, else silence. */
static void bae_poll_notes(BaeDec* d) {
    unsigned char now[BAE_MAX_MIDI_CHANNELS][BAE_MAX_NOTES];
    if (BAESong_GetAllActiveNotes(d->song, now) != BAE_NO_ERROR) return;
    for (int c = 0; c < BAE_CHANNELS; c++) {
        int attacked = -1, highest = -1;
        for (int k = 0; k < 128; k++) {
            if (!now[c][k]) continue;
            highest = k;
            if (!d->notes[c][k]) attacked = k;
        }
        int key;
        if (attacked >= 0) key = attacked;
        else if (d->shown[c] >= 0 && now[c][d->shown[c]]) key = d->shown[c];
        else key = highest;
        if (key < 0) {
            d->shown[c] = -1;
            vgm_last_note[c] = 0;
            vgm_last_vol[c] = 0;
            continue;
        }
        d->shown[c] = key;
        vgm_last_note[c] = bae_key_hz(key);
        if (attacked >= 0) {
            vgm_last_vol[c] = 255;
            d->attackVel[c] = now[c][key];
            if (c == BAE_DRUM_CH) {
                vgm_last_instr[c] = (unsigned char)rewamp_drum_instr_index(key);
            } else {
                unsigned char prog = 0, bank = 0;
                BAESong_GetProgramBank(d->song, (unsigned char)c, &prog, &bank, FALSE);
                vgm_last_instr[c] = (unsigned char)(prog + 1u);
            }
        } else if (vgm_last_vol[c] != 255) {
            vgm_last_vol[c] = now[c][key];
        }
    }
    memcpy(d->notes, now, sizeof d->notes);
}

static void bae_apply_mute(BaeDec* d) {
    if (d->muteApplied == generic_mute_mask) return;
    for (int c = 0; c < BAE_CHANNELS; c++) {
        if ((generic_mute_mask >> c) & 1) BAESong_MuteChannel(d->song, (uint16_t)c);
        else                              BAESong_UnmuteChannel(d->song, (uint16_t)c);
    }
    d->muteApplied = generic_mute_mask;
}

static const char* const kBaeExts[] = { "rmf", NULL };

static int bae_probe(const char* ext, const uint8_t* h, size_t n) {
    const int magic = n >= 4 && memcmp(h, "IREZ", 4) == 0;
    const int extMatch = rewamp_ext_in_list(ext, kBaeExts);
    if (magic && extMatch) return 110;
    if (magic) return 90;     /* an IREZ of another name is still an RMF */
    return extMatch ? 60 : 0;
}

static void bae_info(BaeDec* d, uint32_t size, BAEInfoType type, const char* label) {
    char buf[512];
    buf[0] = '\0';
    if (BAEUtil_GetRmfSongInfo(d->data, size, 0, type, buf, sizeof buf) == BAE_NO_ERROR &&
        buf[0] != '\0') {
        rewamp_track_message_append("%s: %s\n", label, buf);
    }
}

static void bae_free(BaeDec* d) {
    if (!d) return;
    if (d->mixer) BAEMixer_MakeCurrent(d->mixer);
    if (s_cur == d) s_cur = NULL;
    if (d->mixer) bae_capture_off(d);
    if (d->song) { BAESong_Stop(d->song, FALSE); BAESong_Delete(d->song); }
    if (d->mixer) { BAEMixer_Close(d->mixer); BAEMixer_Delete(d->mixer); }
    free(d->data);
    free(d);
}

static uint64_t bae_read(RewampDecoder* rd, float* out, uint64_t frameCount);
static int bae_set_speed(RewampDecoder* rd, double speed);

/* (Re)creates the song from the RMF image and starts it at its beginning, at
 * its own tempo. Also the seek path: see bae_seek. */
static int bae_start_song(BaeDec* d) {
    if (d->song) { BAESong_Stop(d->song, FALSE); BAESong_Delete(d->song); d->song = NULL; }
    d->song = BAESong_New(d->mixer);
    if (!d->song) return 0;
    if (BAESong_LoadRmfFromMemory(d->song, d->data, d->dataSize, 0, TRUE) != BAE_NO_ERROR)
        return 0;
    BAESong_SetLoops(d->song, 0);
    BAESong_Preroll(d->song);
    if (BAESong_Start(d->song, 0) != BAE_NO_ERROR) return 0;
    d->framePos = 0;
    d->frac = 0.0;
    d->sliceLeft = 0;
    d->done = 0;
    d->muteApplied = -1;           /* a new song: push the mask again */
    bae_silence_notes(d);
    return 1;
}

static RewampDecoder* bae_open(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;
    char clean[4096];
    strncpy(clean, path, sizeof clean - 1);
    clean[sizeof clean - 1] = '\0';
    char* q = strrchr(clean, '?');
    if (q) *q = '\0';

    FILE* f = fopen(clean, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (size <= 12 || size > (64L << 20)) { fclose(f); return NULL; }

    BaeDec* d = (BaeDec*)calloc(1, sizeof *d);
    if (!d) { fclose(f); return NULL; }
    d->speed = 1.0;
    d->data = malloc((size_t)size);
    if (!d->data || fread(d->data, 1, (size_t)size, f) != (size_t)size) {
        fclose(f); bae_free(d); return NULL;
    }
    fclose(f);

    d->mixer = BAEMixer_New();
    if (!d->mixer) { bae_free(d); return NULL; }
    /* Same parameters as the library's own player (playbae): 64 MIDI voices,
     * 8 sound voices, mix level 64. */
    if (BAEMixer_Open(d->mixer, BAE_RATE_44K, BAE_LINEAR_INTERPOLATION,
                      BAE_USE_16 | BAE_USE_STEREO, 64, 8, 64, TRUE) != BAE_NO_ERROR) {
        BAEMixer_Delete(d->mixer); d->mixer = NULL;
        bae_free(d); return NULL;
    }
    BAEMixer_MakeCurrent(d->mixer);
    if (BAEMixer_LoadBankFromMemory(d->mixer, kRewampMinibaeBank, REWAMP_MINIBAE_BANK_SIZE,
                                    "patches111.hsb", NULL) != BAE_NO_ERROR) {
        fprintf(stderr, "rewamp_minibae: built-in bank refused\n");
        bae_free(d); return NULL;
    }
    d->dataSize = (uint32_t)size;

    /* Voices BEFORE the first slice (rewamp_channel_data_reset sizes the rings
     * the capture writes into). */
    m_genNumVoicesChannels = BAE_CHANNELS;
    rewamp_channel_data_reset(BAE_CHANNELS);
    rewamp_channel_data_set_ring_write_size(BAE_RING_SIZE);
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("Beatnik", 0, BAE_CHANNELS);
    for (int c = 0; c < BAE_CHANNELS; c++) {
        char nm[MODIZ_VOICE_NAME_MAX_CHAR];
        if (c == BAE_DRUM_CH) snprintf(nm, sizeof nm, "Drums");
        else                  snprintf(nm, sizeof nm, "Ch %d", c + 1);
        rewamp_voice_set_name(c, nm);
    }
    rewamp_drum_register_names();
    bae_capture_on(d);
    s_cur = d;

    if (!bae_start_song(d)) { bae_free(d); return NULL; }
    BAE_UNSIGNED_FIXED mt = 0;
    BAESong_GetMasterTempo(d->song, &mt);
    d->baseTempo = mt ? (uint32_t)mt : 0x10000u;

    uint32_t us = 0;
    if (BAESong_GetMicrosecondLength(d->song, &us) == BAE_NO_ERROR && us > 0)
        d->totalFrames = (uint64_t)us * BAE_OUT_RATE / 1000000u;

    bae_info(d, d->dataSize, TITLE_INFO, "Title");
    bae_info(d, d->dataSize, COMPOSER_INFO, "Composer");
    bae_info(d, d->dataSize, PERFORMED_BY_INFO, "Performed by");
    bae_info(d, d->dataSize, COPYRIGHT_INFO, "Copyright");
    rewamp_track_message_append("Format: RMF (Beatnik Rich Music Format), %d Hz, stereo\n",
                                BAE_OUT_RATE);

    if (outFormat) {
        outFormat->channels = 2;
        outFormat->sampleRate = BAE_OUT_RATE;
    }
    return (RewampDecoder*)d;
}

static uint64_t bae_read(RewampDecoder* rd, float* out, uint64_t frameCount) {
    BaeDec* d = (BaeDec*)rd;
    if (!d || frameCount == 0) return 0;
    BAEMixer_MakeCurrent(d->mixer);
    s_cur = d;
    /* The attack columns were captured after the previous read: back to the
     * velocity (a key released since then is already at 0). */
    for (int c = 0; c < BAE_CHANNELS; c++) {
        if (d->attackVel[c] && vgm_last_vol[c] == 255) vgm_last_vol[c] = d->attackVel[c];
        d->attackVel[c] = 0;
    }
    bae_apply_mute(d);
    const float scale = 1.0f / 32768.0f;
    uint64_t written = 0;
    while (written < frameCount) {
        if (d->sliceLeft == 0) {
            if (d->done) break;
            memset(d->written, 0, sizeof d->written);
            BAE_BuildMixerSlice(NULL, d->slice, (int32_t)sizeof d->slice, BAE_SLICE);
            d->sliceLeft = BAE_SLICE;
            /* Scope: a silent channel is not called by the hook — zeros, and
             * every ring advances by the slice. */
            for (int c = 0; c < BAE_CHANNELS; c++) {
                if (!m_voice_buff[c]) continue;
                if (!d->written[c]) {
                    const int mask = BAE_RING_SIZE - 1;
                    const int64_t base = m_voice_current_ptr[c] >> BAE_FP;
                    for (int k = 0; k < BAE_SLICE; k++) m_voice_buff[c][(base + k) & mask] = 0;
                }
                m_voice_current_ptr[c] += (int64_t)BAE_SLICE << BAE_FP;
            }
            bae_poll_notes(d);
            BAE_BOOL isDone = FALSE;
            BAESong_IsDone(d->song, &isDone);
            if (isDone) d->done = 1;   /* hand out this last slice, then stop */
        }
        int n = d->sliceLeft;
        if ((uint64_t)n > frameCount - written) n = (int)(frameCount - written);
        const int16_t* src = d->slice + (BAE_SLICE - d->sliceLeft) * 2;
        float* dst = out + written * 2;
        for (int i = 0; i < n * 2; i++) dst[i] = src[i] * scale;
        d->sliceLeft -= n;
        written += (uint64_t)n;
        /* framePos is SONG time: it advances by speed × what was rendered. */
        d->frac += (double)n * d->speed;
        const uint64_t whole = (uint64_t)d->frac;
        d->frac -= (double)whole;
        d->framePos += whole;
    }
    /* A quiet passage is not an end while the sequence has events left. */
    if (!d->done) rewamp_decoder_activity();
    return written;
}

/* EXACT seek: restart the song and render-and-discard up to the target.
 *
 * BAESong_SetMicrosecondPosition jumps the sequencer, but every note that
 * started BEFORE the target is lost — RMF music leans on long sustained pads,
 * and 3 s after a native seek the output still correlated only 0.51 with the
 * continuous render. The engine renders ~1000× real time, so discarding up to
 * a 3-minute target costs ~0.2 s, on the seek thread. Done at 1× (the seek
 * advances in song time), speed restored afterwards. */
static void bae_seek(RewampDecoder* rd, uint64_t frameIndex) {
    BaeDec* d = (BaeDec*)rd;
    if (!d) return;
    BAEMixer_MakeCurrent(d->mixer);
    const double speed = d->speed;
    if (!bae_start_song(d)) { d->done = 1; return; }
    d->speed = 1.0;
    if (d->totalFrames > 0 && frameIndex > d->totalFrames) frameIndex = d->totalFrames;
    float scratch[BAE_SLICE * 2];
    while (d->framePos < frameIndex && !(d->done && d->sliceLeft == 0)) {
        uint64_t want = frameIndex - d->framePos;
        if (want > BAE_SLICE) want = BAE_SLICE;
        if (bae_read(rd, scratch, want) == 0) break;
    }
    if (speed != 1.0) bae_set_speed(rd, speed);
    d->speed = speed;
}

static uint64_t bae_length(RewampDecoder* rd) {
    BaeDec* d = (BaeDec*)rd;
    return d ? d->totalFrames : 0;
}

/* Native speed: the master tempo scales the SEQUENCER (pitch untouched).
 * ⚠️ An RMF SONG carries its OWN master tempo (3-D Ultra Pinball: ≈0.92):
 * posing `speed` as an absolute factor played every speed 1.088× too fast,
 * 1× included. Always relative to the tempo read at open. */
static int bae_set_speed(RewampDecoder* rd, double speed) {
    BaeDec* d = (BaeDec*)rd;
    if (!d || speed < 0.2 || speed > 3.0) return 0;
    BAEMixer_MakeCurrent(d->mixer);
    if (BAESong_SetMasterTempo(d->song,
                               (BAE_UNSIGNED_FIXED)(d->baseTempo * speed + 0.5)) !=
        BAE_NO_ERROR) {
        return 0;
    }
    d->speed = speed;
    return 1;
}

static void bae_close(RewampDecoder* rd) { bae_free((BaeDec*)rd); }

static const RewampPluginVTable kBaeVTable = {
    "minibae",
    bae_probe,
    bae_open,
    bae_read,
    bae_seek,
    bae_length,
    bae_close,
    NULL,                   /* configure_loop: generic */
    0,                      /* supportsNativeFadeout */
    NULL,                   /* engine_id */
    NULL,                   /* param_changed */
    NULL, NULL, NULL, NULL, NULL, /* pattern view */
    NULL,                   /* probe_path */
    0,                      /* noPrefixProbe */
    bae_set_speed,          /* native speed */
};

const RewampPluginVTable* rewamp_minibae_plugin(void) { return &kBaeVTable; }

#endif /* REWAMP_WITH_MINIBAE */

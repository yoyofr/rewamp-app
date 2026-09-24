// FMP plugin — PC-98 FM music driver (.opi/.ovi/.ozi) via the vendored
// libfmpmini (third_party/fmpmini: the 98fmplayer FMP driver + its own libopna
// OPNA/SSG/ADPCM/rhythm emulation + the PPZ8 PCM driver, behind fmpmini.c's
// small C API — that wrapper was written for Modizer).
//
// Distinct from the neighbouring PMD engine: FMP is a different PC-98 music
// DRIVER, and libfmpmini is a different OPNA implementation (98fmplayer's C
// libopna, not pmdmini's C++ ymfm) — no shared symbols. It DOES share the
// YM2608 rhythm ROM, though: fmpmini's drum-ROM loader reads
// ym2608_adpcm_rom.bin from the same `bundlePath` global PMD uses (defined in
// rewamp_channel_data.c, pointed at <datadir>/opna/).
//
// Voice layout is fixed by libopna's mixer order: FM 0-5, SSG 6-8, rhythm
// drums 9-14, ADPCM 15, then PPZ8 PCM channels 16+ (count only known after the
// tune has been simulated — fmpmini_getLength fills fmp_ppz8_maxChannel).
//
// Per-voice scope/notes already live in the vendored cores (grep YOYOFR in
// libopna/opnafm.c, opnassg.c, opnadrum.c, opnaadpcm.c, fmdriver/ppz8.c), ring
// mask SOUND_BUFFER_SIZE_SAMPLE*2*4 = 4096. MUTE is different from the other
// engines: the cores don't read generic_mute_mask — libopna has its own
// per-channel mask set through opna_set_mask/ppz8_set_mask, driven by
// fmpmini_mute(mask). So the plugin translates generic_mute_mask into that
// call each read() (bits 0-15 → OPNA, 16+ → PPZ8, exactly fmpmini_mute's
// layout, which matches our voice numbering above).
//
// Process-global singleton (fmpmini.c's `static struct g`) — fine, rewamp
// never runs two decoders concurrently.
#ifdef REWAMP_WITH_FMP

#include "rewamp_plugin.h"

/* Boucle forcée (rewamp_audio.c) — lus à l'open. */
extern "C" int g_force_loop_mode;
extern "C" int g_force_loop_native_veto;
#include "rewamp_channel_data.h"
#include "rewamp_assets.h"   // rewamp_get_data_dir() → bundled ym2608_adpcm_rom.bin
#include "ModizerVoicesData.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

extern "C" {
#include "../third_party/fmpmini/fmpmini.h"
}

#define FMP_RATE       44100
#define FMP_BASE_VOICES 16   // FM 6 + SSG 3 + drums 6 + ADPCM 1; PPZ8 adds more

// bundlePath (the OPNA rhythm-ROM directory) lives in rewamp_channel_data.c —
// shared with PMD, which is why neither plugin owns it. fmp_ppz8_maxChannel is
// libfmpmini's own extern, the count of PPZ8 PCM channels the tune uses.
extern "C" {
extern char bundlePath[1024];
extern int  fmp_ppz8_maxChannel;
}

struct RewampDecoder {
    uint64_t totalFrames;   // single-pass-ish length (getLength honours max_loop)
    uint64_t framePos;
    int      voices;
    int      lastMuteMask;  // diff generic_mute_mask against this before re-masking
    int      muteDirty;     // force a re-mask (a reset cleared libopna's mask)
    char     path[4096];
};

static const char* const kFmpExts[] = { "opi", "ovi", "ozi", NULL };

static int fmp_probe(const char* ext, const uint8_t* h, size_t n) {
    (void)h; (void)n;
    // libfmpmini identifies FMP by content in fmplayer_file_alloc, but that
    // needs the file on disk; the extensions are FMP-exclusive, so claim on
    // extension (score 90) and let open() fail cleanly if the content isn't FMP.
    return rewamp_ext_in_list(ext, kFmpExts) ? 90 : 0;
}

static void fmp_set_bundle_path(void) {
    const char* dd = rewamp_get_data_dir();
    if (dd && *dd) snprintf(bundlePath, sizeof(bundlePath), "%s/opna/", dd);
    else           bundlePath[0] = '\0';
}

static void fmp_apply_voice_layout(int voices) {
    m_genNumVoicesChannels = voices;
    rewamp_channel_data_reset(voices);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 2 * 4);
    rewamp_channel_data_set_ring_circular(1);
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("OPNA FM", 0, 6);
    rewamp_voices_add_chip("OPNA SSG", 6, 3);
    rewamp_voices_add_chip("OPNA Rhythm", 9, 6);
    rewamp_voices_add_chip("OPNA ADPCM", 15, 1);
    if (voices > FMP_BASE_VOICES)
        rewamp_voices_add_chip("PPZ8", FMP_BASE_VOICES, voices - FMP_BASE_VOICES);
}

static RewampDecoder* fmp_open(const char* path, RewampAudioFormat* outFormat) {
    /* Mode 1 (N boucles): pas de compte natif -> veto, le generique
     * Dart compte les passes (voir configure_loop). */
    if (g_force_loop_mode == 1) g_force_loop_native_veto = 1;
    if (!path) return NULL;

    char cleanPath[4096];
    snprintf(cleanPath, sizeof(cleanPath), "%s", path);
    char* q = strrchr(cleanPath, '?');
    if (q) *q = '\0';

    fmp_set_bundle_path();
    fmpmini_init();
    // maxloop matches the other generic-loop engines' single-pass convention:
    // fmpmini_getLength counts frames until loop_cnt exceeds this.
    fmpmini_setMaxLoop(1);
    if (!fmpmini_loadFile(cleanPath)) return NULL;

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { fmpmini_close(); return NULL; }
    snprintf(dec->path, sizeof(dec->path), "%s", cleanPath);
    dec->lastMuteMask = 0;

    // getLength runs the driver to the loop point with no mixing; it also fills
    // fmp_ppz8_maxChannel and reloads the file, leaving it ready to play from 0.
    int64_t lengthMs = fmpmini_getLength();
    if (lengthMs > 0) dec->totalFrames = (uint64_t)lengthMs * FMP_RATE / 1000;

    dec->voices = fmpmini_channelsNb();
    if (dec->voices <= 0) dec->voices = FMP_BASE_VOICES;
    if (dec->voices > SOUND_MAXVOICES_BUFFER_FX) dec->voices = SOUND_MAXVOICES_BUFFER_FX;
    fmp_apply_voice_layout(dec->voices);

    // Title is Shift-JIS (PC-98 format); the 3 comment lines usually are too.
    const char* name = fmpmini_getName();
    if (name && name[0]) {
        char utf8[1024];
        rewamp_sjis_to_utf8(name, utf8, sizeof(utf8));
        rewamp_track_message_append("Title: %s\n", utf8);
    }
    for (int line = 0; line < 3; line++) {
        const char* c = fmpmini_getComment(line);
        if (c && c[0]) {
            char utf8[1024];
            rewamp_sjis_to_utf8(c, utf8, sizeof(utf8));
            rewamp_track_message_append("%s\n", utf8);
        }
    }
    rewamp_track_message_append("Format: FMP (PC-98 FM driver), OPNA + PPZ8, "
                                "%d Hz, stereo\n", FMP_RATE);
    if (dec->totalFrames > 0) {
        unsigned total = (unsigned)(dec->totalFrames / FMP_RATE);
        rewamp_track_message_append("Duration: %u:%02u\n", total / 60, total % 60);
    }

    if (outFormat) {
        outFormat->channels   = 2;
        outFormat->sampleRate = FMP_RATE;
    }
    return dec;
}

// Push generic_mute_mask into libopna/ppz8's own masks whenever it changes —
// bits 0-15 are the OPNA channels, 16+ the PPZ8 ones, which is exactly the
// packing fmpmini_mute expects and matches our voice numbering.
static void fmp_sync_mute(RewampDecoder* dec) {
    int mask = (int)(generic_mute_mask & 0xFFFFFFFF);
    // muteDirty covers the case where the cached value happens to equal the new
    // one but libopna's own mask was cleared by a reset — a plain != test can't
    // see that (and -1 is a legitimate all-muted mask, so no int sentinel works).
    if (dec->muteDirty || mask != dec->lastMuteMask) {
        fmpmini_mute(mask);
        dec->lastMuteMask = mask;
        dec->muteDirty    = 0;
    }
}

static uint64_t fmp_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || frameCount == 0) return 0;
    if (dec->totalFrames > 0) {
        if (dec->framePos >= dec->totalFrames) return 0;
        uint64_t remain = dec->totalFrames - dec->framePos;
        if (frameCount > remain) frameCount = remain;
    }
    fmp_sync_mute(dec);

    static int16_t s_buf[4096 * 2];
    const float scale = 1.0f / 32768.0f;
    uint64_t written = 0;
    while (written < frameCount) {
        uint32_t want = (uint32_t)(frameCount - written);
        if (want > 4096) want = 4096;
        fmpmini_render(s_buf, (int)want);   // fills, self-loops (never stops)
        float* dst = out + written * 2;
        for (uint32_t i = 0; i < want * 2; i++) dst[i] = s_buf[i] * scale;
        written += want;
        dec->framePos += want;
    }
    return written;
}

// No native seek. fmpmini_reset reloads from the top (cheap); both directions
// then render-and-discard to the target with fmpmini_render(NULL, n), which
// advances the driver without mixing.
static void fmp_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec) return;
    if (frameIndex < dec->framePos) {
        fmpmini_reset();
        fmp_apply_voice_layout(dec->voices);
        dec->muteDirty = 1;   // fmpmini_reset re-applied g.mutemask, but re-sync anyway
        dec->framePos = 0;
    }
    while (dec->framePos < frameIndex) {
        uint64_t skip = frameIndex - dec->framePos;
        if (skip > SOUND_BUFFER_SIZE_SAMPLE) skip = SOUND_BUFFER_SIZE_SAMPLE;
        fmpmini_render(NULL, (int)skip);
        dec->framePos += skip;
    }
}

static uint64_t fmp_length(RewampDecoder* dec) {
    return dec ? dec->totalFrames : 0;
}


/* Boucle FORCÉE (repeat-morceau): le moteur ÉMULÉ boucle DE LUI-MÊME au point
 * de boucle de la musique — c'est notre troncature à totalFrames (longueur de
 * catalogue/tag) qui coupait, et la relance générique repartait du DÉBUT, ce
 * qui s'entend (même famille que le .ay zxtune, « Midnight Resistance »).
 * Mode 2 (infini): on lève la troncature, l'émulation joue et boucle au bon
 * endroit. Mode 1 (N passes): pas de compte natif ici → VETO posé à l'open,
 * le générique Dart compte — comportement inchangé. Filet: un moteur qui
 * s'arrêterait quand même rend un read() à 0 → rechargement replayCurrent,
 * exactement le comportement d'avant ce câblage. */
static void fmp_configure_loop_fn(RewampDecoder* dec, int mode, int count) {
    (void)count;
    if (dec != NULL && mode == 2) dec->totalFrames = 0;
}

static void fmp_close(RewampDecoder* dec) {
    if (!dec) return;
    fmpmini_close();
    free(dec);
}

static const RewampPluginVTable kFmpVTable = {
    "fmp",
    fmp_probe,
    fmp_open,
    fmp_read,
    fmp_seek,
    fmp_length,
    fmp_close,
    fmp_configure_loop_fn,
};

extern "C" const RewampPluginVTable* rewamp_fmp_plugin(void) { return &kFmpVTable; }

#endif /* REWAMP_WITH_FMP */

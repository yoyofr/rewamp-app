// libsidplayfp plugin — decodes C64 SID formats (.sid/.psid/.rsid/.mus).
// Compiled only when REWAMP_WITH_SID is defined.
#ifdef REWAMP_WITH_SID

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "rewamp_assets.h"
#include "ModizerVoicesData.h"

// libsidplayfp public API
#include "sidplayfp/sidplayfp.h"
#include "sidplayfp/SidTune.h"
#include "sidplayfp/SidInfo.h"
#include "sidplayfp/SidTuneInfo.h"
#include "sidplayfp/SidConfig.h"
#include "sidlite.h"
#include "sid_filter_maps.h"
#include "builders/residfp-builder/residfp.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define SID_RENDER_RATE     48000
// Frames per read call.
#define SID_FRAMES_PER_CALL 2048
// Scratch buffer holds stereo int16: 2 samples/frame, plus generous slack
// because play() may return slightly more samples than the requested cycles
// imply (the cycle→sample ratio is fractional).
#define SID_IBUF_SAMPLES   (SID_FRAMES_PER_CALL * 2 * 2)

// Real SID voices per chip (C64 SID has 3 oscillators).
#define SID_VOICES_PER_CHIP 3
// Oscilloscope channels per chip: 3 voices + 1 digi/sample channel.
// SID.cpp's clock() patch writes m_voice_buff[chip*4 + 0..3], so the
// per-chip stride MUST be 4 or those writes overflow into the next chip /
// past the allocated buffers.
#define SID_CHANS_PER_CHIP  4

// Cycles per sample at PAL clock (985248 Hz / 48000 Hz ≈ 20.53).
// Deliberately rounded DOWN so play() never returns more samples than the
// caller's buffer can hold (overshoot would overflow ibuf / out).
#define SID_CYCLES_PER_SAMPLE 20u

/* sidplayfp's --autofilter: recommended 6581 filter RANGE by tune author
 * (tables regenerated from upstream by scripts/sync_sidplayfp_filtermaps.sh;
 * upstream formula (adjustment*20-1)/39). Returns -1 when unknown.
 *
 * kSidFilterCurveMap is deliberately NOT applied: its values (up to 1.55) are
 * the OLD filter6581Curve scale — upstream only uses it on pre-FEAT_FILTER_RANGE
 * libs. On this reSIDfp, setFilterCurve is a 0..1 position and the DAC model
 * asserts from ~0.88 up (verified empirically) — the modern player's auto mode
 * is rangeMap-only, same as here. */
static double sid_recommended_range(const char* author) {
    if (!author || !author[0]) return -1.0;
    for (int i = 0; i < kSidFilterRangeMapCount; i++) {
        if (strcmp(kSidFilterRangeMap[i].author, author) == 0)
            return (kSidFilterRangeMap[i].value * 20.0 - 1.0) / 39.0;
    }
    return -1.0;
}

/* ReSIDfp filter knobs (Settings → Moteurs → SID) — appliable live. ALL
 * three take 0..1 (Filter8580::setFilterCurve maps the curve position
 * internally, default 0.5). ReSIDfp only — SIDLite has no filter knobs.
 * auto_filter (default ON) replaces the 6581 RANGE with sidplayfp's
 * per-author recommendation when the tune's author is known. */
static void sid_apply_builder_params(sidbuilder* sb, int engineChoice,
                                     const char* author) {
    if (engineChoice != 0) return;   /* 0 = ReSIDfp */
    ReSIDfpBuilder* b = (ReSIDfpBuilder*)sb;
    double v;
    v = rewamp_get_engine_param("sid", "f6581_curve", 0.5);
    /* The 6581 DAC model overflows its ushort table (debug assert, garbage in
     * release) from ~0.88 up — verified empirically. Hard-cap at 0.85. */
    b->filter6581Curve(v < 0 ? 0 : (v > 0.85 ? 0.85 : v));
    v = rewamp_get_engine_param("sid", "f6581_range", 0.5);
    if (rewamp_get_engine_param("sid", "auto_filter", 1) > 0.5) {
        double rec = sid_recommended_range(author);
        if (rec >= 0.0) v = rec;
    }
    b->filter6581Range(v < 0 ? 0 : (v > 1 ? 1 : v));
    v = rewamp_get_engine_param("sid", "f8580_curve", 0.5);
    b->filter8580Curve(v < 0 ? 0 : (v > 1 ? 1 : v));
}

struct RewampDecoder {
    sidplayfp*      engine;
    sidbuilder*     builder;
    int             engineChoice;   /* 0 = ReSIDfp, 1 = SIDLite */
    char            author[128];    /* tune infoString(1), for the auto filter */
    SidTune*        tune;
    int             numVoices;   // 4, 8, or 12 (chans/chip = 4) depending on 1/2/3-SID
    int16_t         ibuf[SID_IBUF_SAMPLES]; // stereo int16 scratch (with slack)
    uint64_t        framePos;    // current playback position in decoded frames
    int64_t         lastMuteMask; // applied generic_mute_mask snapshot
    // Per-voice release-hold, in render frames: a SID voice stays AUDIBLE after
    // its gate drops (the ADSR release tail), so keying the visualizer note on
    // the gate bit alone dropped notes that could still be heard — the "audible
    // note, empty pattern row" the pattern viz showed. On gate-off we keep
    // showing the pitch for the release duration (from the SR register) instead.
    int             noteHold[12]; // <= max voices (3 per chip * up to ~4 chips)
};

// SID envelope release rate (SR register low nibble) → approximate tail length
// in ms (the standard 6581/8580 release periods). Used to hold the visualizer
// note through the audible decay after gate-off; capped when applied so a very
// long release doesn't leave a stale note lingering on screen forever.
static const int kSidReleaseMs[16] = {
    6, 24, 48, 72, 114, 168, 204, 240, 300, 750, 1500, 2400, 3000, 9000, 15000, 24000
};
#define SID_HOLD_CAP_MS 1500

static const char* const kSidExts[] = {
    "sid", "psid", "rsid", "mus", "str", "dat", "prg", "p00", NULL
};

static int sid_probe(const char* ext, const uint8_t* header, size_t headerSize) {
    int extMatch = rewamp_ext_in_list(ext, kSidExts);

    // PSID/RSID magic in header bytes 0-3.
    if (header != NULL && headerSize >= 4) {
        if ((memcmp(header, "PSID", 4) == 0) ||
            (memcmp(header, "RSID", 4) == 0)) {
            return extMatch ? 100 : 90;
        }
    }
    return extMatch ? 60 : 0;
}

static RewampDecoder* sid_open(const char* path, RewampAudioFormat* outFormat) {
    // Strip ?subsong=N suffix to get the real file path.
    char  cleanPath[4096];
    int   subsong = 0;
    const char* q = strrchr(path, '?');
    if (q) {
        size_t len = (size_t)(q - path);
        if (len >= sizeof(cleanPath)) len = sizeof(cleanPath) - 1;
        memcpy(cleanPath, path, len);
        cleanPath[len] = '\0';
        sscanf(q, "?subsong=%d", &subsong);
    } else {
        strncpy(cleanPath, path, sizeof(cleanPath) - 1);
        cleanPath[sizeof(cleanPath) - 1] = '\0';
    }

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(RewampDecoder));
    if (!dec) return NULL;

    dec->engine  = new sidplayfp;
    /* Emulation choice (Settings → Moteurs → SID): 0 = ReSIDfp (accurate,
     * default), 1 = SIDLite (fast). */
    dec->engineChoice = (int)rewamp_get_engine_param("sid", "engine", 0);
    if (dec->engineChoice == 1) {
        dec->builder = new SIDLiteBuilder("SidLite");
    } else {
        ReSIDfpBuilder* rb = new ReSIDfpBuilder("ReSIDfp");
        // combinedWaveformsStrength is a ReSIDfpBuilder method, not SidConfig.
        rb->combinedWaveformsStrength(SidConfig::STRONG);
        dec->builder = rb;
    }

    // Engine params (Settings → Moteurs → SID). Curves also re-apply LIVE via
    // sid_param_changed; engine/sampling/clock/model take effect on the next
    // track.
    sid_apply_builder_params(dec->builder, dec->engineChoice, NULL);

    // Configure engine.
    SidConfig cfg = dec->engine->config();
    cfg.frequency       = SID_RENDER_RATE;
    cfg.playback        = SidConfig::STEREO;
    cfg.samplingMethod  =
        rewamp_get_engine_param("sid", "sampling", 0) > 0.5
            ? SidConfig::RESAMPLE_INTERPOLATE   /* best, CPU-heavy */
            : SidConfig::INTERPOLATE;
    cfg.digiBoost       = true;
    cfg.defaultSidModel = SidConfig::MOS6581;
    cfg.defaultC64Model = SidConfig::PAL;
    cfg.ciaModel        = SidConfig::MOS6526;
    cfg.powerOnDelay    = 0;
    /* clock: 0 auto (tune header), 1 force PAL, 2 force NTSC. */
    {
        int clk = (int)rewamp_get_engine_param("sid", "clock", 0);
        cfg.forceC64Model   = clk != 0;
        cfg.defaultC64Model = clk == 2 ? SidConfig::NTSC : SidConfig::PAL;
    }
    /* model: 0 auto (tune header), 1 force 6581, 2 force 8580. */
    {
        int mdl = (int)rewamp_get_engine_param("sid", "model", 0);
        cfg.forceSidModel   = mdl != 0;
        cfg.defaultSidModel = mdl == 2 ? SidConfig::MOS8580 : SidConfig::MOS6581;
    }
    /* Extra SIDs (2SID/3SID tunes): address of the 2nd/3rd chip, 0 = none.
     * Usual addresses 0xD420 / 0xD440. */
    cfg.secondSidAddress =
        (uint_least16_t)(int)rewamp_get_engine_param("sid", "second_sid_addr", 0);
    cfg.thirdSidAddress =
        (uint_least16_t)(int)rewamp_get_engine_param("sid", "third_sid_addr", 0);
    cfg.sidEmulation    = dec->builder;
    if (!dec->engine->config(cfg)) {
        delete dec->builder;
        delete dec->engine;
        free(dec);
        return NULL;
    }

    // Load C64 ROMs from the internal data dir if present. PSID tunes play
    // fine without them; RSID and BASIC tunes need the kernal/basic ROMs.
    {
        uint8_t *kernal = NULL, *basic = NULL, *chargen = NULL;
        size_t kn = 0, bn = 0, cn = 0;
        rewamp_load_asset("c64/kernal.c64",  &kernal,  &kn);
        rewamp_load_asset("c64/basic.c64",   &basic,   &bn);
        rewamp_load_asset("c64/chargen.c64", &chargen, &cn);
        dec->engine->setRoms(kernal, basic, chargen); // NULLs are tolerated
        if (kernal)  free(kernal);
        if (basic)   free(basic);
        if (chargen) free(chargen);
    }

    /* SID filter on/off (all three possible chips) — also live via
     * sid_param_changed. */
    {
        bool fon = rewamp_get_engine_param("sid", "filter", 1) > 0.5;
        for (unsigned int c = 0; c < 3; c++) dec->engine->filter(c, fon);
    }

    // Load tune.
    dec->tune = new SidTune(cleanPath);
    if (!dec->tune->getStatus()) {
        delete dec->tune;
        delete dec->builder;
        delete dec->engine;
        free(dec);
        return NULL;
    }

    dec->tune->selectSong((unsigned int)(subsong + 1));

    /* Author (infoString(1)) → sidplayfp per-author recommended filter range
     * (auto_filter). Re-apply the builder knobs now that it's known. */
    {
        const SidTuneInfo* ti = dec->tune->getInfo();
        const char* author =
            (ti && ti->numberOfInfoStrings() == 3) ? ti->infoString(1) : NULL;
        if (author) {
            strncpy(dec->author, author, sizeof(dec->author) - 1);
            dec->author[sizeof(dec->author) - 1] = '\0';
        }
        sid_apply_builder_params(dec->builder, dec->engineChoice, dec->author);
    }

    // CRITICAL: allocate the oscilloscope buffers BEFORE load(). load() runs
    // the psid driver which clocks the SID, and the SID.cpp Modizer patch
    // writes into m_voice_buff[] on the very first cycle — if those buffers
    // are still NULL it dereferences a null pointer and crashes. The SID chip
    // count is known from the tune info before load (installedSIDs() is only
    // valid after load, so we use SidTuneInfo::sidChips()).
    int numSids = 1;
    {
        const SidTuneInfo* ti = dec->tune->getInfo();
        if (ti) {
            int n = ti->sidChips();
            if (n >= 1 && n <= 3) numSids = n;
        }
    }
    // 4 oscilloscope channels per chip (3 voices + digi).
    dec->numVoices = numSids * SID_CHANS_PER_CHIP;

    // Oscilloscope state used by SID.cpp clock() patches.
    m_sid_chipNb = numSids;
    memset(m_sid_chipId, 0, sizeof(m_sid_chipId));
    mSIDSeekInProgress = 0;

    m_genNumVoicesChannels = dec->numVoices;
    rewamp_channel_data_reset(dec->numVoices);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 8);

    // Voice metadata for the mute/grouping UI: one group per SID chip,
    // 3 voices + the samples/digi channel.
    rewamp_voices_meta_reset();
    for (int s = 0; s < numSids; s++) {
        char nm[16];
        if (numSids > 1) snprintf(nm, sizeof(nm), "SID %d", s + 1);
        else             snprintf(nm, sizeof(nm), "SID");
        const int base = s * SID_CHANS_PER_CHIP;
        rewamp_voices_add_chip(nm, base, SID_CHANS_PER_CHIP);
        rewamp_voice_set_name(base + 0, "Voice 1");
        rewamp_voice_set_name(base + 1, "Voice 2");
        rewamp_voice_set_name(base + 2, "Voice 3");
        rewamp_voice_set_name(base + 3, "Samples");
    }

    if (!dec->engine->load(dec->tune)) {
        delete dec->tune;
        delete dec->builder;
        delete dec->engine;
        free(dec);
        return NULL;
    }

    // Initialize stereo mixer (must be after load()).
    dec->engine->initMixer(true);

    // Info panel: PSID header strings (title / author / released) + MUS
    // comments + chip layout. STIL data is appended by the Dart layer (it
    // already caches get_sid_info per HVSC MD5).
    {
        const SidTuneInfo* ti = dec->tune->getInfo();
        if (ti) {
            static const char* const kLabels[] =
                { "Title", "Author", "Released" };
            /* PSID header strings are 8-bit Latin (ISO-8859-1), not UTF-8:
             * published raw, "Börje Sieling" reaches the panel as an invalid
             * byte and shows up as a replacement glyph. Converted here rather
             * than at the sink — every other engine already appends UTF-8, and
             * a blanket conversion would double-encode those. */
            char conv[512];
            for (unsigned int i = 0; i < ti->numberOfInfoStrings() && i < 3; i++) {
                const char* v = ti->infoString(i);
                if (v && v[0]) {
                    rewamp_latin1_to_utf8(v, conv, sizeof(conv));
                    rewamp_track_message_append("%s: %s\n", kLabels[i], conv);
                }
            }
            for (unsigned int i = 0; i < ti->numberOfCommentStrings(); i++) {
                const char* v = ti->commentString(i);
                if (v && v[0]) {
                    rewamp_latin1_to_utf8(v, conv, sizeof(conv));
                    rewamp_track_message_append("%s\n", conv);
                }
            }
            rewamp_track_message_append("Format: %s\n", ti->formatString());
            if (numSids > 1)
                rewamp_track_message_append("SID chips: %d\n", numSids);
        }
    }

    if (outFormat) {
        outFormat->channels   = 2;
        outFormat->sampleRate = SID_RENDER_RATE;
    }
    return dec;
}

// Push generic_mute_mask into sidplayfp's per-voice mute state. NOTE: despite
// sidplayfp.h's doc ("enable true unmutes"), the vendored implementation
// forwards the flag straight to sidemu::voice(voice, bool MUTE) — so pass
// `muted` as-is. Modizer consistency rule: the samples channel is forced off
// when all three voices of its chip are muted.
// `force` re-applies even when the cached mask is unchanged — needed after a
// backward seek, whose engine->load()+initMixer() reset the ENGINE's mute state
// while the cache (and the restored generic_mute_mask) kept their values, so
// the change-detection below would never fire. (An int sentinel can't express
// "dirty": -1 is a legitimate all-muted mask — same lesson as fmp's muteDirty.)
static void sid_sync_mute(RewampDecoder* dec, bool force) {
    if (!force && dec->lastMuteMask == generic_mute_mask) return;
    dec->lastMuteMask = generic_mute_mask;
    const int chips = dec->numVoices / SID_CHANS_PER_CHIP;
    for (int s = 0; s < chips; s++) {
        bool anyVoiceOn = false;
        for (int v = 0; v < SID_VOICES_PER_CHIP; v++) {
            const bool muted =
                (generic_mute_mask >> (s * SID_CHANS_PER_CHIP + v)) & 1;
            if (!muted) anyVoiceOn = true;
            dec->engine->mute((unsigned)s, (unsigned)v, muted);
        }
        const bool sampMuted =
            (((generic_mute_mask >> (s * SID_CHANS_PER_CHIP + 3)) & 1) != 0) ||
            !anyVoiceOn;
        dec->engine->mute((unsigned)s, 3, sampMuted);
    }
}

static uint64_t sid_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || !dec->engine) return 0;

    // Apply voice-mute changes from the UI.
    sid_sync_mute(dec, false);

    // SID chip clock: PAL=985248 Hz, NTSC=1022727 Hz. Use PAL.
    static const double kSidClock = 985248.0;

    uint64_t rendered = 0;
    while (rendered < frameCount) {
        uint64_t want = frameCount - rendered;
        if (want > SID_FRAMES_PER_CALL) want = SID_FRAMES_PER_CALL;

        // play(cycles) emulates cycles and returns number of produced samples.
        unsigned int cycles = (unsigned int)(want * SID_CYCLES_PER_SAMPLE);
        int produced = dec->engine->play(cycles);
        if (produced <= 0) break;

        // Clamp produced to what ibuf can hold (SID_IBUF_SAMPLES int16 =
        // SID_IBUF_SAMPLES/2 stereo frames), guarding against play() overshoot.
        if (produced > SID_IBUF_SAMPLES / 2) produced = SID_IBUF_SAMPLES / 2;

        // mix(buf, samples) renders `samples` frames into int16 stereo.
        // Returns the number of int16 values written (= frames*2 for stereo).
        unsigned int mixed = dec->engine->mix(dec->ibuf, (unsigned int)produced);
        if (mixed == 0) break;

        int frames = (int)(mixed / 2); // stereo: 2 int16 per frame
        // Never write past the caller's buffer.
        uint64_t room = frameCount - rendered;
        if ((uint64_t)frames > room) frames = (int)room;

        float* dst = out + rendered * 2;
        for (int i = 0; i < frames * 2; i++)
            dst[i] = dec->ibuf[i] * (1.0f / 32768.0f);

        // Note detection via SID registers (voice freq → Hz). A voice keeps
        // sounding through its release tail after the gate drops, so instead of
        // zeroing the note the instant gate=0 (which blanked pattern rows for
        // notes that were still audible), hold the pitch for the release
        // duration read from the SR register.
        int numChips = dec->numVoices / SID_CHANS_PER_CHIP;
        for (int s = 0; s < numChips; s++) {
            uint8_t regs[32];
            if (dec->engine->getSidStatus(s, regs)) {
                for (int v = 0; v < SID_VOICES_PER_CHIP; v++) {
                    int ch  = s * SID_CHANS_PER_CHIP + v; // 4-channel stride
                    int ofs = v * 7; // 7 bytes per voice in SID register map
                    uint16_t freq_reg = (uint16_t)(regs[ofs] | (regs[ofs + 1] << 8));
                    uint8_t  gate     = regs[ofs + 4] & 0x01;
                    int      relRate  = regs[ofs + 6] & 0x0F;
                    double   hz       = (kSidClock * freq_reg) / 16777216.0;
                    if (gate && freq_reg > 0) {
                        vgm_last_note[ch] = (unsigned int)hz;
                        vgm_last_vol[ch]  = 64;   // sounding
                        int ms = kSidReleaseMs[relRate];
                        if (ms > SID_HOLD_CAP_MS) ms = SID_HOLD_CAP_MS;
                        dec->noteHold[ch] = ms * SID_RENDER_RATE / 1000; // arm for gate-off
                    } else if (freq_reg > 0 && dec->noteHold[ch] > 0) {
                        // Release tail: pitch unchanged, still audible.
                        vgm_last_note[ch] = (unsigned int)hz;
                        vgm_last_vol[ch]  = 32;   // dimmer while it decays
                        dec->noteHold[ch] -= frames;
                        if (dec->noteHold[ch] < 0) dec->noteHold[ch] = 0;
                    } else {
                        vgm_last_note[ch] = 0;
                        vgm_last_vol[ch]  = 0;
                        dec->noteHold[ch] = 0;
                    }
                }
            }
        }

        rendered += (uint64_t)frames;
    }
    dec->framePos += rendered;
    return rendered;
}

// Shared seek-state globals defined in rewamp_audio.c.
extern volatile int    g_seek_cancel;
extern volatile int    g_is_seeking;
extern volatile double g_seek_progress_s;

static void sid_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec || !dec->engine || !dec->tune) return;

    memset(dec->noteHold, 0, sizeof(dec->noteHold)); // no stale release tails across a seek

    uint64_t startFrame = 0;

    if (frameIndex >= dec->framePos) {
        startFrame = dec->framePos;
    } else {
        // Backward seek: reload from start.
        const SidTuneInfo* ti = dec->tune->getInfo();
        unsigned int song = ti ? ti->currentSong() : 1;
        dec->tune->selectSong(song);
        dec->engine->load(dec->tune);
        dec->engine->initMixer(true);
        // load()+initMixer() reset the engine's per-voice mute state — re-apply
        // the user's mutes or the fast-forward below (and playback after it)
        // runs with everything audible.
        sid_sync_mute(dec, true);
        dec->framePos = 0;
        startFrame = 0;
    }

    if (frameIndex == dec->framePos) return;

    mSIDSeekInProgress = 1;
    g_is_seeking       = 1;
    // Snapshot where we started so progress is reported relative to seek start.
    const double kRate = (double)SID_RENDER_RATE;

    const uint64_t kBatch = (uint64_t)SID_FRAMES_PER_CALL * 64;
    uint64_t remaining = frameIndex - startFrame;
    while (remaining > 0 && !g_seek_cancel) {
        uint64_t want = remaining > kBatch ? kBatch : remaining;
        unsigned int cycles = (unsigned int)(want * SID_CYCLES_PER_SAMPLE);
        int produced = dec->engine->play(cycles);
        if (produced <= 0) break;
        uint64_t f    = (uint64_t)produced;
        uint64_t step = (f > remaining) ? remaining : f;
        remaining     -= step;
        dec->framePos += step;
        // Update progress for Dart to poll.
        g_seek_progress_s = (double)dec->framePos / kRate;
    }

    mSIDSeekInProgress = 0;
    g_is_seeking       = 0;
}

static uint64_t sid_length(RewampDecoder* dec) {
    // This version of libsidplayfp has no songLength() in SidTuneInfo.
    // Length is unknown without SLDB; return 0.
    (void)dec;
    return 0;
}

static void sid_close(RewampDecoder* dec) {
    if (!dec) return;
    if (dec->tune)    { delete dec->tune;    dec->tune    = NULL; }
    if (dec->builder) { delete dec->builder; dec->builder = NULL; }
    if (dec->engine)  { delete dec->engine;  dec->engine  = NULL; }
    free(dec);
}

/* Live settings change (called under the decode lock): only the filter curves
 * apply mid-song; sampling/clock/model need a new engine (next track). */
static void sid_param_changed(RewampDecoder* dec, const char* key) {
    (void)key;
    if (!dec) return;
    if (dec->builder)
        sid_apply_builder_params(dec->builder, dec->engineChoice, dec->author);
    if (dec->engine) {
        bool fon = rewamp_get_engine_param("sid", "filter", 1) > 0.5;
        for (unsigned int c = 0; c < 3; c++) dec->engine->filter(c, fon);
    }
}

static const RewampPluginVTable g_sid_vtable = {
    "libsidplayfp",
    sid_probe,
    sid_open,
    sid_read,
    sid_seek,
    sid_length,
    sid_close,
    NULL,               /* configure_loop */
    0,                  /* supportsNativeFadeout */
    "sid",              /* engine_id */
    sid_param_changed,  /* live settings (curves) */
};

extern "C" const RewampPluginVTable* rewamp_sid_plugin(void) {
    return &g_sid_vtable;
}

// Number of subsongs (tunes) in a SID file. Used to build the album/subsong
// playlist. Returns 1 when unknown.
extern "C" int rewamp_sid_probe_subsong_count(const char* path) {
    if (!path) return 1;
    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char* q = strrchr(cleanPath, '?');
    if (q) *q = '\0';

    SidTune tune(cleanPath);
    if (!tune.getStatus()) return 1;
    const SidTuneInfo* ti = tune.getInfo();
    if (!ti) return 1;
    int n = (int)ti->songs();
    return n > 0 ? n : 1;
}

// HVSC MD5 for a SID file (SidTune::createMD5New algorithm, same key used by
// Songlengths.md5 and STIL.txt). Returns a 32-char lowercase hex string in a
// static buffer, or "" on error. Caller must copy before the next call.
extern "C" const char* rewamp_sid_md5(const char* path) {
    static char md5buf[33];
    md5buf[0] = '\0';
    if (!path) return md5buf;

    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char* q = strrchr(cleanPath, '?');
    if (q) *q = '\0';

    SidTune tune(cleanPath);
    if (!tune.getStatus()) return md5buf;

    const char* result = tune.createMD5New(md5buf);
    return result ? result : md5buf;
}

#endif /* REWAMP_WITH_SID */

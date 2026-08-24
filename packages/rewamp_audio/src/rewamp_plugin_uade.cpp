// libuade plugin — Amiga custom-chip music via UADE (Unix Amiga Delitracker
// Emulator). Real 68k emulation + bundled "eagleplayer" players. Compiled only
// when REWAMP_WITH_UADE is defined.
//
// Process model: upstream UADE spawns uadecore (the 68k emulator) as a
// subprocess. rewamp builds the vendored tree with -DUADE_IN_PROCESS so uadecore
// runs in a pthread instead (iOS-safe, no fork). See third_party/uade patches
// (ossupport.c / uadestate.c / uademain.c) and the uade-integration memory.
#ifdef REWAMP_WITH_UADE

#include "rewamp_plugin.h"
#include "rewamp_assets.h"   // rewamp_get_data_dir() → bundled players/score/confs
#include "rewamp_channel_data.h" // per-voice scope + chip grouping (Paula 4 voices)

extern "C" {
#include <uade/uade.h>
#include <uade/amifilemagic.h>   // uade_filemagic() — content detection for prefix-form files
}

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <signal.h>

struct RewampDecoder {
    struct uade_state* st;
    int       rate;
    int16_t*  pcm;        // scratch interleaved int16 stereo
    uint64_t  pcmFrames;
    int       ended;
};

/* Settings → Moteurs → UADE (Modizer's UADE family; uade_effect_run applies
 * these inside libuade's own read pipeline). Defaults: post-FX ON, panning ON
 * at 0.7, the rest OFF — matching Modizer. */
static void uade_apply_engine_params(struct uade_state* st) {
    int postfx = (int)rewamp_get_engine_param("uade", "postfx", 1);
    int pan    = (int)rewamp_get_engine_param("uade", "pan_enabled", 1);
    int head   = (int)rewamp_get_engine_param("uade", "headphones", 0);
    int gain   = (int)rewamp_get_engine_param("uade", "gain_enabled", 0);
    double panv  = rewamp_get_engine_param("uade", "pan_value", 0.7);
    double gainv = rewamp_get_engine_param("uade", "gain_value", 0.5);
    (postfx ? uade_effect_enable : uade_effect_disable)(st, UADE_EFFECT_ALLOW);
    (pan    ? uade_effect_enable : uade_effect_disable)(st, UADE_EFFECT_PAN);
    (head   ? uade_effect_enable : uade_effect_disable)(st, UADE_EFFECT_HEADPHONES);
    /* LED (Paula low-pass filter): 0 = auto (song controls its own LED —
     * don't touch), 1 = force ON, 2 = force OFF. Forcing works live:
     * uade_set_filter_state queues the filter command to uadecore (uade123
     * does exactly this after toggling UC_FORCE_LED). */
    int led = (int)rewamp_get_engine_param("uade", "led", 0);
    if (led != 0) {
        struct uade_config* ec = uade_get_effective_config(st);
        if (ec) uade_config_set_option(ec, UC_FORCE_LED, led == 1 ? "on" : "off");
        uade_set_filter_state(st, led == 1 ? 1 : 0);
    }
    /* NOTE: modern libuade dropped UADE_EFFECT_NORMALISE — not exposed. */
    (gain   ? uade_effect_enable : uade_effect_disable)(st, UADE_EFFECT_GAIN);
    uade_effect_pan_set_amount(st, (float)panv);
    uade_effect_gain_set_amount(st, (float)gainv);
}

// Amiga formats UADE handles, addressed by file *suffix*. This is Modizer's full
// UADE extension set, cross-checked against the bundled eagleplayer.conf, with the
// extensions owned by a better-suited plugin removed to keep their routing intact
// (openmpt: mod/med/okt/digi; sidplayfp: sid; highlyexp: psf; zxtune: ay/sqt; …)
// and the prefix-form tokens with dots ("tfmx1.5") dropped (a suffix probe can't
// match them). Many UADE files use the Amiga *prefix* convention ("ahx.song") —
// those don't reach a suffix probe and are out of scope. Score 58: beats
// vgmstream's catch-all (50), loses to any format-specific plugin with a header.
static const char* const kUadeExts[] = {
    "arp", "ast", "ahx", "thx", "amc", "abk", "aam", "alp", "aon", "aon4",
    "aon8", "adsc", "mod_adsc4", "bss", "bd", "bds", "uds", "kris", "cin", "core",
    "cus", "cust", "custom", "cm", "rk", "rkb", "dz", "mkiio", "dl", "dl_deli",
    "dln", "dh", "dw", "dwold", "dlm2", "dm2", "dlm1", "dm1", "dsr", "db",
    "dsc", "dss", "dns", "ems", "emsv6", "ex", "fc13", "fc3", "fc", "fc14",
    "fc4", "fred", "gray", "bfc", "bsi", "fc-bsi", "fp", "fw", "glue", "gm",
    "ea", "mg", "hd", "hipc", "soc", "emod", "qc", "ims", "dum", "is",
    "is20", "jam", "jc", "jmf", "jcb", "jcbo", "jpn", "jpnd", "jp", "jt",
    "mon_old", "jo", "hip", "mcmd", "sog", "hip7", "s7g", "hst", "kh", "powt",
    "pt", "lme", "mon", "mfp", "hn", "mtp2", "thn", "mc", "mcr", "mco",
    "mk2", "mkii", "avp", "mw", "max", "mcmd_org", "mmd0", "mmd1", "mmd2", "mso",
    "md", "mmdc", "dmu", "mug", "dmu2", "mug2", "ma", "mm4", "mm8", "mms",
    "ntp", "two", "octamed", "okta", "one", "ps", "snk", "pvp", "pap", "psa",
    "mod_doc", "mod15", "mod15_mst", "mod_ntk", "mod_ntk1", "mod_ntk2", "mod_ntkamp", "mod_flt4", "mod_comp", "40a",
    "40b", "41a", "50a", "60a", "61a", "ac1", "ac1d", "aval", "chan", "cp",
    "cplx", "crb", "di", "eu", "fc-m", "fcm", "ft", "fuz", "fuzz", "gmc",
    "gv", "hmc", "hrt", "ice", "it1", "kef", "kef7", "krs", "ksm", "lax",
    "mexxmp", "mpro", "np", "np1", "np2", "noisepacker2", "np3", "noisepacker3", "nr", "nru",
    "ntpk", "p10", "p21", "p30", "p40a", "p40b", "p41a", "p4x", "p50a", "p5a",
    "p5x", "p60", "p60a", "p61", "p61a", "p6x", "pha", "pin", "pm", "pm0",
    "pm01", "pm1", "pm10c", "pm18a", "pm2", "pm20", "pm4", "pm40", "pmz", "polk",
    "pp10", "pp20", "pp21", "pp30", "ppk", "pr1", "pr2", "prom", "pru", "pru1",
    "pru2", "prun", "prun1", "prun2", "pwr", "pyg", "pygm", "pygmy", "skt", "skyt",
    "snt", "st2", "st26", "st30", "star", "stpk", "tp", "tp1", "tp2", "tp3",
    "un2", "unic", "unic2", "wn", "xan", "xann", "zen", "puma", "rjp", "sng",
    "riff", "rh", "rho", "sa-p", "scumm", "s-c", "scn", "scr", "sid1", "smn",
    "sid2", "mok", "sa", "sonic", "sa_old", "smus", "snx", "tiny", "spl", "sc",
    "sct", "sfx", "sfx13", "tw", "sm", "sm1", "sm2", "sm3", "smpro", "bp",
    "sndmon", "bp3", "sjs", "jd", "doda", "sas", "ss", "sb", "jpo", "jpold",
    "sun", "syn", "sdr", "osp", "st", "synmod", "tfmx7v", "tfhd7v", "mdat", "tfmxpro",
    "tfhdpro", "tfmx", "mdst", "thm", "tf", "tme", "sg", "dp", "trc", "tro",
    "tronic", "mod15_ust", "vss", "wb", "ml", "mod15_st-iv", "agi", "tpu", "qpa", "qts",
    // Quartet ST scores are named NAME.4v by modland while UADE knows the
    // format as the "qts" prefix; eagleplayer.conf carries 4v as an alias so
    // both spellings reach Quartet_ST (it tries the prefix, then the suffix).
    "4v",
    "oss", "ymst", "lion",
    // Andrew Parton (eagleplayer.conf: "Andrew_Parton prefixes=bye") — a
    // prefix-convention format ("bye.NAME"); listed here because the registry
    // probes the Amiga prefix token against this same list (see
    // extract_prefix), so one entry covers both bye.NAME and NAME.bye.
    "bye",
    // Remaining eagleplayer.conf prefixes not owned by a better-suited plugin.
    // Deliberately still excluded: dat/sid/mus (sidplayfp), psf (highlyexp),
    // ftm (furnace), midi (FluidLite), ptm (openmpt), ym/sqt (zxtune), and
    // "adpcm" (vgmstream owns it — UADE's 58 would hijack every game-stream
    // .adpcm to the Amiga raw-ADPCM player). The dotted tokens (tfmx1.5,
    // tfhd1.5) are unmatchable by either a suffix or a first-dot prefix.
    "!pm!", "aps", "ash", "dm", "hot", "hrt!", "ism", "jb", "js", "kim",
    "mod3", "mosh", "mth", "npp", "oldw", "pat", "pn", "prt", "rj", "sdata",
    "sdc", "sfx20", "sj", "smod", "snt!", "tcb", "tits", "tmk", "tron", "ufo",
    // webUADE+ soundcore players (audio.device/multitasking score extensions):
    // Digital Sound Creations ("han.NAME" — UnExotica's Hanlon rips), Music-X
    // driver, MaxTrax, GT Game Systems, SoundTracker Pro II, Stonetracker,
    // PlayAY's amad/strc. "ay" stays deliberately EXCLUDED (zxtune owns it).
    // "stp" is NOT here: zxtune claims .stp too (ZX Sound Tracker Pro, score
    // 55), so it lives in kUadeSharedExts below (40) — zx files keep their
    // engine, the Amiga prefix-form "stp.NAME" still routes here (zxtune only
    // matches the suffix), and the per-extension preference can pin UADE.
    "han", "mx", "mxp", "mxtx", "dux", "spm", "amad", "strc",
    NULL
};

// Formats normally owned by libopenmpt but also playable by UADE (real Amiga
// replay): claimed at a LOW score so libopenmpt keeps winning by default,
// while the user's per-extension preference (Settings → Moteurs) can pin UADE.
static const char* const kUadeSharedExts[] = {
    "mod", "med", "mmd0", "mmd1", "mmd2", "mmd3", "okt", "digi", "stp", NULL,
};

static int uade_probe(const char* ext, const uint8_t* hdr, size_t n) {
    // 1. Suffix match (covers song.ahx / song.tfmx / …).
    if (ext && rewamp_ext_in_list(ext, kUadeExts)) return 58;
    if (ext && rewamp_ext_in_list(ext, kUadeSharedExts)) return 40;

    // 2. Content detection — catches Amiga *prefix*-convention names ("ahx.song",
    //    "mdat.turrican") whose suffix isn't a format token, by inspecting the
    //    header. uade_filemagic() recognises TFMX/AHX/HIP/FC/… by magic and fills
    //    `pre` with a format token ("" = unknown, "reject" = WAV). We pass no path
    //    (AS/NT sibling probing is skipped safely) and realfilesize == header size,
    //    which makes the size-validated MOD checks bow out — fine, plain MODs route
    //    to libopenmpt by suffix anyway. Score 56: below a suffix/header-confirmed
    //    format plugin, above vgmstream's catch-all (50).
    if (hdr && n > 0) {
        char pre[64] = {0};
        uade_filemagic((unsigned char*)hdr, n, pre, n, "", 0);
        if (pre[0] != '\0' && strcmp(pre, "reject") != 0) return 56;
    }
    return 0;
}

static RewampDecoder* uade_open(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;

    // A dying uadecore write can raise SIGPIPE; ignore it process-wide (the
    // in-process build talks over a socketpair to the uadecore thread).
    signal(SIGPIPE, SIG_IGN);

    char clean[4096];
    int subsong = 0;
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    char* q = strrchr(clean, '?');
    if (q && strncmp(q, "?subsong=", 9) == 0) { subsong = atoi(q + 9); *q = '\0'; }

    const char* dataDir = rewamp_get_data_dir();
    if (!dataDir || !dataDir[0]) return NULL;

    char baseDir[4096];
    size_t dl = strlen(dataDir);
    int hasSlash = (dl > 0 && dataDir[dl - 1] == '/');
    snprintf(baseDir, sizeof(baseDir), "%s%suade", dataDir, hasSlash ? "" : "/");

    struct uade_config* uc = uade_new_config();
    if (!uc) return NULL;
    uade_config_set_option(uc, UC_BASE_DIR, baseDir);
    /* Paula filter model: 0 = A500 (library default), 1 = A1200, 2 = none.
     * Initialised per song (UC_FILTER_TYPE). */
    {
        int ft = (int)rewamp_get_engine_param("uade", "filter_type", 0);
        uade_config_set_option(uc, UC_FILTER_TYPE,
                               ft == 2 ? "none" : (ft == 1 ? "a1200" : "a500"));
    }
    /* LED forced state must also be part of the song config so led_forced is
     * set from the start (live toggles then use uade_set_filter_state). */
    {
        int led = (int)rewamp_get_engine_param("uade", "led", 0);
        if (led != 0)
            uade_config_set_option(uc, UC_FORCE_LED, led == 1 ? "on" : "off");
    }

    struct uade_state* st = uade_new_state(uc);
    free(uc);                       // uade_new_state copies the config
    if (!st) return NULL;

    // subsong=0 means "default subsong" by rewamp convention → pass -1 to UADE.
    int playret = uade_play(clean, subsong > 0 ? subsong : -1, st);
    if (playret != 1) {             // 0 = unplayable, -1 = fatal
        uade_cleanup_state(st);
        return NULL;
    }

    int rate = uade_get_sampling_rate(st);
    if (rate <= 0) rate = 44100;

    /* Engine params (Settings → Moteurs → UADE) — also live via
     * uade_param_changed (uade_effect_run sits in the library's own read
     * pipeline, so toggles take effect on the next chunk). */
    uade_apply_engine_params(st);

    // Per-voice oscilloscope + note capture: Amiga Paula has 4 hardware voices.
    // Set up the ring buffers + chip grouping BEFORE the first uade_read() so
    // audio.c's uade_capture_voices() has allocated m_voice_buff[0..3] to write.
    rewamp_channel_data_reset(4);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 4);
    // audio.c's uade_capture_voices() WRAPS m_voice_current_ptr modulo the
    // ring size; without the circular flag ring_read() treats a just-wrapped
    // pointer as "almost nothing written" → the voice scope flashes flat on
    // every ring cycle (~every 0.3s).
    rewamp_channel_data_set_ring_circular(1);
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("Paula", 0, 4);
    for (int i = 0; i < 4; i++) {
        char nm[MODIZ_VOICE_NAME_MAX_CHAR];
        snprintf(nm, sizeof(nm), "Voice %d", i + 1);
        rewamp_voice_set_name(i, nm);
    }

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { uade_cleanup_state(st); return NULL; }
    dec->st   = st;
    dec->rate = rate;

    // Info panel: eagleplayer / format / module metadata from libuade.
    {
        const struct uade_song_info* si = uade_get_song_info(st);
        if (si) {
            if (si->modulename[0])
                rewamp_track_message_append("Module: %s\n", si->modulename);
            if (si->formatname[0])
                rewamp_track_message_append("Format: %s\n", si->formatname);
            if (si->playername[0])
                rewamp_track_message_append("Player: %s\n", si->playername);
            if (si->subsongs.max > si->subsongs.min)
                rewamp_track_message_append("Subsongs: %d (%d..%d)\n",
                    si->subsongs.max - si->subsongs.min + 1,
                    si->subsongs.min, si->subsongs.max);
            if (si->modulebytes > 0)
                rewamp_track_message_append("Size: %zu bytes\n",
                                            si->modulebytes);
            if (si->duration > 0.0)
                rewamp_track_message_append("Duration: %d:%02d\n",
                    (int)si->duration / 60, (int)si->duration % 60);
        }
    }

    outFormat->channels   = UADE_CHANNELS;   // 2
    outFormat->sampleRate = (uint32_t)rate;
    return dec;
}

static uint64_t uade_read_frames(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || !dec->st || !out || frameCount == 0 || dec->ended) return 0;

    if (frameCount > dec->pcmFrames) {
        free(dec->pcm);
        dec->pcm = (int16_t*)malloc(frameCount * UADE_CHANNELS * sizeof(int16_t));
        dec->pcmFrames = dec->pcm ? frameCount : 0;
    }
    if (!dec->pcm) return 0;

    size_t bytes = (size_t)frameCount * UADE_BYTES_PER_FRAME;
    ssize_t n = uade_read(dec->pcm, bytes, dec->st);
    if (n <= 0) { dec->ended = 1; return 0; }   // 0 = song end, -1 = error

    const int samples = (int)(n / (ssize_t)sizeof(int16_t));
    const float inv = 1.0f / 32768.0f;
    for (int i = 0; i < samples; i++) out[i] = dec->pcm[i] * inv;
    return (uint64_t)(samples / UADE_CHANNELS);
}

static void uade_seek_frames(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec || !dec->st) return;
    double seconds = (double)frameIndex / (double)dec->rate;
    if (uade_seek(UADE_SEEK_SONG_RELATIVE, seconds, 0, dec->st) == 0)
        dec->ended = 0;
}

static uint64_t uade_length_frames(RewampDecoder* dec) {
    if (!dec || !dec->st) return 0;
    const struct uade_song_info* si = uade_get_song_info(dec->st);
    if (!si || si->duration <= 0.0) return 0;
    return (uint64_t)(si->duration * (double)dec->rate);
}

static void uade_close(RewampDecoder* dec) {
    if (!dec) return;
    if (dec->st) uade_cleanup_state(dec->st);   // implies uade_stop()
    free(dec->pcm);
    free(dec);
}

/* Live settings change (called under the decode lock). */
static void uade_param_changed(RewampDecoder* dec, const char* key) {
    (void)key;
    if (dec && dec->st) uade_apply_engine_params(dec->st);
}

static const RewampPluginVTable kUadeVTable = {
    "uade",
    uade_probe,
    uade_open,
    uade_read_frames,
    uade_seek_frames,
    uade_length_frames,
    uade_close,
    NULL,                /* configure_loop */
    0,                   /* supportsNativeFadeout */
    "uade",              /* engine_id */
    uade_param_changed,  /* live settings */
};

extern "C" const RewampPluginVTable* rewamp_uade_plugin(void) { return &kUadeVTable; }

#endif /* REWAMP_WITH_UADE */

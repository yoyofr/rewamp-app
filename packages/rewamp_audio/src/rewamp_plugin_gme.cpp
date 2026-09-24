// libgme plugin — decodes NES/GB/SNES/PCE/AY/HES/KSS/SAP formats.
// Compiled only when REWAMP_WITH_GME is defined and libgme is linked.
#ifdef REWAMP_WITH_GME

#include <math.h>
#include <stdio.h>
#include "rewamp_plugin.h"

/* Boucle forcée (rewamp_audio.c) — lus à l'open. */
extern "C" int g_force_loop_mode;
extern "C" int g_force_loop_native_veto;
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"   // generic_mute_mask

#include "gme/gme.h"

#include <stdlib.h>
#include <string.h>

// RSN support (SNES SPC sets packed as *solid* RARv3/v4) is built into libgme's
// Spc_Emu/Rsn_Emu: it opens the archive by path and exposes each SPC as a track.
// That path needs the official UnRAR library — bundled in third_party/unrar/ and
// enabled via RARDLL + RAR_HDR_DLL_HPP in the podspec.  libarchive (bundled too)
// covers the other container formats (ZIP, 7z, gz, bzip2, LHA, tar, xz, …).

#define GME_SAMPLE_RATE 44100
#define GME_FADE_MS      4000
/* Crossfade actif (rewamp_datasource.c): on supprime alors le fondu de fin —
 * fondre une queue déjà fondue double l'atténuation et le recouvrement du
 * crossfade porterait du silence au lieu de musique. 1 ms et non 0: libgme
 * traite 0 comme « pas de longueur » et jouerait sans fin. */
extern "C" double g_crossfade_seconds;

struct RewampDecoder {
    Music_Emu* emu;
    int        subsong;
    int64_t    lastMuteMask;   // applied generic_mute_mask snapshot
};

static const char* const kGmeExts[] = {
    "nsf", "nsfe",  // NES
    "gbs",          // Game Boy
    "spc",          // SNES
    "hes",          // PC Engine
    "kss",          // MSX/Sega Master System
    "sap",          // Atari
    "ay",           // ZX Spectrum / Amstrad
    "rsn",          // SNES SPC in RAR archive
    NULL
};

// Formats libgme can identify by header but libvgm handles better.
static const char* const kDeferToVgm[] = { "VGM", "VGZ", "GYM", NULL };

static int gme_probe_fn(const char* ext, const uint8_t* header, size_t headerSize) {
    int extMatch = rewamp_ext_in_list(ext, kGmeExts);

    if (header != NULL && headerSize >= 4) {
        const char* detected = gme_identify_header(header);
        if (detected && detected[0] != '\0') {
            for (int i = 0; kDeferToVgm[i]; i++) {
                if (strcmp(detected, kDeferToVgm[i]) == 0)
                    return extMatch ? 50 : 0;
            }
            // RSN header ("Rar!") only makes sense when extension is .rsn.
            if (strcmp(detected, "RSN") == 0)
                return (ext && strcmp(ext, "rsn") == 0) ? 90 : 0;
            return extMatch ? 100 : 90;
        }
    }

    return extMatch ? 60 : 0;
}

static void gme_apply_engine_params(Music_Emu* emu, bool firstOpen) {
    int    sil    = (int)rewamp_get_engine_param("gme", "silence_detection", 0);
    double depth  = rewamp_get_engine_param("gme", "stereo_depth", 0.0);
    bool   eqOn   = rewamp_get_engine_param("gme", "eq_enabled", 0) > 0.5;
    double bass   = rewamp_get_engine_param("gme", "eq_bass", 2.3);
    double treble = rewamp_get_engine_param("gme", "eq_treble", -14.0);
    gme_ignore_silence(emu, !sil);
    /* stereo depth 0..1 (echo-based surround; 0 = neutral). */
    if (depth > 0.0 || !firstOpen) gme_set_stereo_depth(emu, depth);
    /* equalizer (classic emus only, not SPC): Modizer bass=pow(10,4.2-v),
     * treble in dB. Off → library defaults (only touched when needed). */
    static gme_equalizer_t s_defaultEq;
    static bool s_haveDefault = false;
    if (!s_haveDefault) { gme_equalizer(emu, &s_defaultEq); s_haveDefault = true; }
    if (eqOn) {
        gme_equalizer_t eq;
        gme_equalizer(emu, &eq);
        eq.bass   = pow(10.0, 4.2 - bass);
        eq.treble = treble;
        gme_set_equalizer(emu, &eq);
    } else if (!firstOpen) {
        gme_set_equalizer(emu, &s_defaultEq);
    }
}

/* Live settings change (called under the decode lock). */
static void gme_param_changed(RewampDecoder* dec, const char* key) {
    (void)key;
    if (dec && dec->emu) gme_apply_engine_params(dec->emu, /*firstOpen=*/false);
}

static RewampDecoder* gme_open_fn(const char* path, RewampAudioFormat* outFormat) {
    /* Mode 1 (N boucles): pas de compte natif -> veto, le generique
     * Dart compte les passes. Mode 2: voir le saut de fade plus bas. */
    if (g_force_loop_mode == 1) g_force_loop_native_veto = 1;
    if (!path) return NULL;

    // Parse optional ?subsong=N suffix appended by the Dart layer for multi-track
    // archives (RSN, NSF, etc.).  Work on a local copy so we can strip the suffix.
    char cleanPath[4096];
    int  subsong = 0;
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char* q = strrchr(cleanPath, '?');
    if (q && strncmp(q, "?subsong=", 9) == 0) {
        subsong = atoi(q + 9);
        *q = '\0';
    }

    Music_Emu* emu = NULL;

    // libgme opens every format — including .rsn (Rsn_Emu unpacks the solid RAR
    // and presents each SPC as a track).  subsong selects the track for all
    // multi-track formats (NSF, GBS, RSN, …); it is 0 for single-track files.
    if (gme_open_file(cleanPath, &emu, GME_SAMPLE_RATE) || !emu) return NULL;

    /* Engine params (Settings → Moteurs → GME) — also re-applied LIVE on a
     * settings change via gme_param_changed below. NOTE: the equalizer only
     * affects the classic-emu cores (AY/GBS/HES/KSS/NSF/NSFE/SAP/VGM), not
     * SPC (its DSP has no EQ). */
    gme_apply_engine_params(emu, /*firstOpen=*/true);

    gme_enable_accuracy(emu, 1);

    // Allocate the oscilloscope ring buffers BEFORE starting the track:
    // gme_start_track() runs fill_buf() → the chip DSP, which writes into
    // m_voice_buff[*].  Resetting afterwards would leave those buffers NULL on
    // the first frame → crash (e.g. Spc_Dsp::run).  voice_count is valid once
    // the file is loaded.
    int voices = gme_voice_count(emu);
    rewamp_channel_data_reset(voices > 0 ? voices : 2);

    // Voice metadata for the mute/grouping UI: one group named after the
    // emulated system, per-voice names from libgme (Square 1, Wave, DPCM, …).
    rewamp_voices_meta_reset();
    const char* sys = gme_type_system(gme_type(emu));
    rewamp_voices_add_chip(sys && sys[0] ? sys : "GME",
                           0, voices > 0 ? voices : 2);
    for (int i = 0; i < voices; i++) {
        const char* vn = gme_voice_name(emu, i);
        if (vn && vn[0]) rewamp_voice_set_name(i, vn);
    }

    if (gme_start_track(emu, subsong)) { gme_delete(emu); return NULL; }

    gme_info_t* info = NULL;
    if (!gme_track_info(emu, &info, subsong) && info) {
        if (g_force_loop_mode == 2) {
            /* Repeat-morceau: PAS de fade du tout — l'émulation joue et
             * boucle d'elle-même au point de boucle de la musique. La
             * troncature play+fade la coupait et la relance générique
             * repartait de l'INTRO (même famille que le .ay zxtune). */
        } else if (info->play_length > 0) {
            /* Crossfade actif: la région de fondu se joue NON FONDUE — la
             * musique boucle, donc c'est de la vraie matière — et la fin
             * reste à play+fade: la durée affichée (catalogue, mesurée AVEC
             * le fondu) retombe juste, et c'est le producteur qui fond
             * (crossfade vers la piste suivante, ou fondu de sortie s'il
             * n'y en a pas). Sans crossfade: le fondu gme historique. */
            int fade_ms = (info->fade_length > 0) ? info->fade_length
                                                  : GME_FADE_MS;
            if (g_crossfade_seconds > 0.0)
                gme_set_fade_msecs(emu, info->play_length + fade_ms, 1);
            else
                gme_set_fade_msecs(emu, info->play_length, fade_ms);
        }
        // Info panel: everything libgme knows about this track.
        struct { const char* v; const char* label; } kFields[] = {
            { info->system,    "System" },   { info->game,   "Game" },
            { info->song,      "Song" },     { info->author, "Author" },
            { info->copyright, "Copyright" },{ info->dumper, "Dumper" },
        };
        for (size_t k = 0; k < sizeof(kFields) / sizeof(kFields[0]); k++) {
            if (kFields[k].v && kFields[k].v[0])
                rewamp_track_message_append("%s: %s\n",
                                            kFields[k].label, kFields[k].v);
        }
        if (info->comment && info->comment[0])
            rewamp_track_message_append("\n%s\n", info->comment);
        gme_free_info(info);
    }

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { gme_delete(emu); return NULL; }
    dec->emu     = emu;
    dec->subsong = subsong;

    if (outFormat) {
        outFormat->channels   = 2;
        outFormat->sampleRate = GME_SAMPLE_RATE;
    }
    return dec;
}

static uint64_t gme_read_fn(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || !dec->emu || gme_track_ended(dec->emu)) return 0;

    // Apply voice-mute changes from the UI (generic_mute_mask, bit v = muted).
    // While anything is muted, disable silence detection so muting every voice
    // doesn't end the track (Modizer does the same).
    if (dec->lastMuteMask != generic_mute_mask) {
        dec->lastMuteMask = generic_mute_mask;
        gme_mute_voices(dec->emu, (int)generic_mute_mask);
        gme_ignore_silence(dec->emu, generic_mute_mask != 0 ? 1 : 0);
    }

    int sampleCount = (int)(frameCount * 2);  // stereo: 2 int16 per frame
    short* buf = (short*)malloc((size_t)sampleCount * sizeof(short));
    if (!buf) return 0;

    gme_err_t err = gme_play(dec->emu, sampleCount, buf);
    if (err) { free(buf); return 0; }

    const float scale = 1.0f / 32768.0f;
    for (int i = 0; i < sampleCount; i++)
        out[i] = buf[i] * scale;
    free(buf);
    return frameCount;
}

static void gme_seek_fn(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec || !dec->emu) return;
    // gme_seek_samples counts individual int16 values; stereo = 2 per frame.
    gme_seek_samples(dec->emu, (int)(frameIndex * 2));
}

static uint64_t gme_length_fn(RewampDecoder* dec) {
    if (!dec || !dec->emu) return 0;
    gme_info_t* info = NULL;
    if (gme_track_info(dec->emu, &info, dec->subsong) || !info) return 0;
    int play_ms = info->play_length;
    int fade_ms = (info->fade_length > 0) ? info->fade_length : GME_FADE_MS;
    /* Sous crossfade la fin est aussi a play+fade (region jouee non fondue)
     * — la longueur annoncee ne change pas. */
    gme_free_info(info);
    if (play_ms <= 0) return 0;
    return (uint64_t)((double)(play_ms + fade_ms) / 1000.0 * GME_SAMPLE_RATE);
}


/* Décision prise à l'OPEN (le fade gme se pose avant le premier rendu) —
 * cette fonction n'existe que pour annoncer le support natif (champ non-NULL,
 * même patron que vgmstream). */
static void gme_configure_loop_fn(RewampDecoder* dec, int mode, int count) {
    (void)dec; (void)mode; (void)count;
}

static void gme_close_fn(RewampDecoder* dec) {
    if (!dec) return;
    if (dec->emu) gme_delete(dec->emu);
    free(dec);
}

static const RewampPluginVTable kGmeVTable = {
    "libgme",
    gme_probe_fn,
    gme_open_fn,
    gme_read_fn,
    gme_seek_fn,
    gme_length_fn,
    gme_close_fn,
    gme_configure_loop_fn,
    0,                  /* supportsNativeFadeout */
    "gme",              /* engine_id */
    gme_param_changed,  /* live settings */
};

extern "C" const RewampPluginVTable* rewamp_gme_plugin(void) { return &kGmeVTable; }

// ── Probe cache — written by rewamp_gme_probe_subsong_info, read by accessors ──

#define GME_PROBE_MAX 512

static int   s_probe_count = 0;
static char  s_probe_titles[GME_PROBE_MAX][256];
static int   s_probe_durations_ms[GME_PROBE_MAX];

/* Probes a file: opens it, reads count + per-track title/duration into the
 * static cache, then closes.  Returns count (0 on failure). */
extern "C" int rewamp_gme_probe_subsong_info(const char* path) {
    s_probe_count = 0;
    if (!path) return 0;

    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    char* q = strrchr(cleanPath, '?');
    if (q) *q = '\0';

    Music_Emu* emu = NULL;
    if (gme_open_file(cleanPath, &emu, GME_SAMPLE_RATE) || !emu) return 0;

    int count = gme_track_count(emu);
    if (count <= 0) count = 1;
    if (count > GME_PROBE_MAX) count = GME_PROBE_MAX;

    for (int i = 0; i < count; ++i) {
        s_probe_titles[i][0]    = '\0';
        s_probe_durations_ms[i] = -1;
        gme_info_t* info = NULL;
        if (!gme_track_info(emu, &info, i) && info) {
            if (info->song && info->song[0]) {
                strncpy(s_probe_titles[i], info->song, sizeof(s_probe_titles[i]) - 1);
                s_probe_titles[i][sizeof(s_probe_titles[i]) - 1] = '\0';
            }
            if (info->length > 0)
                s_probe_durations_ms[i] = (int)info->length;
            else if (info->intro_length > 0)
                s_probe_durations_ms[i] = (int)(info->intro_length + (info->loop_length > 0 ? info->loop_length * 2 : 0));
            gme_free_info(info);
        }
    }

    gme_delete(emu);
    s_probe_count = count;
    return count;
}

/* Legacy shim — count only, no metadata. */
extern "C" int rewamp_gme_probe_subsong_count(const char* path) {
    return rewamp_gme_probe_subsong_info(path);
}

extern "C" const char* rewamp_gme_probe_get_title(int idx) {
    if (idx < 0 || idx >= s_probe_count) return "";
    return s_probe_titles[idx];
}

extern "C" int rewamp_gme_probe_get_duration_ms(int idx) {
    if (idx < 0 || idx >= s_probe_count) return -1;
    return s_probe_durations_ms[idx];
}

#endif /* REWAMP_WITH_GME */

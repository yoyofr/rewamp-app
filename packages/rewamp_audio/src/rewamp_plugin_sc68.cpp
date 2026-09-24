// sc68 plugin — Atari ST *and* Amiga chip music (.sc68) via the real sc68
// library (third_party/sc68: file68 + libsc68's emu68 68000 emulator + io68
// chip emulators + unice68 ICE depacker — Modizer's vendored copy, which is
// Juergen Wothke's webAudio-era fork carrying the per-voice "trace stream"
// scope plumbing). A .sc68 bundles the original 68k replay routine (or
// references one of the ~99 built-in replays, gzip-embedded in
// file68/src/replay.inc.h and also shipped as loose files under
// <datadir>/sc68/Replay) and drives it against emulated hardware:
// YM-2149 + STE MicroWire DMA for Atari tracks, Paula for Amiga tracks.
//
// Glue ported from Modizer's ModizMusicPlayer.mm (setupSc68 + mmp_sc68Load):
// sc68_init(argv --sc68-user-path=<datadir>/sc68) once → sc68_create per
// open → sc68_load_uri → sc68_play(track) → sc68_process(NULL,0) to apply
// the change → sc68_music_info. sc68_process(buf,&n) renders n int16-stereo
// frames. Track numbers are 1-based (?subsong= carries them directly,
// base=1, like SNDH).
//
// Per-voice scope: the vendored emulators fill sc68->mix.scopes[] (YM A/B/C
// = 0-2 via ym_blep's fake_voice_output, STE DMA = 3 via mwemul, Paula 0-3
// via paulaemul), and api68.c's process loop hands block-aligned slices to
// getScopeBuffers() — two externs THIS plugin implements (Modizer stubbed
// them to NULL, so its sc68 scope was never actually wired). The guard
// `EMSCRIPTEN||__APPLE__` was extended with REWAMP_SC68 for Android.
// read() converts the int16 traces into the m_voice_buff[] int8 rings.
//
// Mute silences the REAL mix (rewamp convention): rewamp_sc68_set_mute()
// (patched into api68.c) maps generic_mute_mask onto ym_active_channels
// (honored natively by ym_puls and by the rewamp dacstate patch in ym_blep,
// the default engine), the patched Paula active-channels mask, and the
// patched STE-DMA gate in mwemul.c. Scope rings of muted voices are zeroed
// in the conversion loop here.
//
// TWO INSTANCES, TWO PROCESS-GLOBALS: the scope plumbing routes through
// gIntScopeBufs/gMixBuffer, process-globals that upstream bound in
// sc68_create() and cleared in sc68_destroy(). This plugin keeps a SECOND,
// never-playing sc68_t alive (the subsong-probe cache below), so probing
// the next track — on the Dart thread, while the current one still renders
// on the audio thread — hijacked both globals: gIntScopeBufs pointed at the
// probe's all-NULL scopes and gMixBuffer was zeroed, so ym_blep/paulaemul
// wrote through NULL. Fixed in api68.c: create no longer binds, destroy only
// unbinds what belongs to it, and rewamp_sc68_bind_scopes() (called here
// before every sc68_process) points them at the instance being rendered.
#ifdef REWAMP_WITH_SC68

#include "rewamp_plugin.h"

/* Boucle forcée (rewamp_audio.c) — lus à l'open. */
extern "C" int g_force_loop_mode;
extern "C" int g_force_loop_native_veto;
#include "rewamp_channel_data.h"
#include "rewamp_assets.h"
#include "ModizerVoicesData.h"

#include <sc68/sc68.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SC68_RATE       44100
#define SC68_MAX_VOICES 4
#define SC68_CHUNK      2048   // frames per sc68_process call

struct RewampDecoder {
    sc68_t*  sc68;
    int      track;        // 1-based
    int      voices;
    uint64_t totalFrames;  // 0 = unknown
    uint64_t framePos;
    // Note-attack tracking (see sc68_capture_notes).
    unsigned prevGate[4];
    unsigned prevSample[4];
    unsigned env[4];            // envelope follower, 0..255
    unsigned char noteGen[4];   // bumped on each re-trigger
};

static const char* const kSc68Exts[] = { "sc68", NULL };

// ── Wothke trace-stream contract (api68.c calls these during process) ──────
// The scope copy in api68.c memcpys each emulator trace stream into
// s_scope_bufs[v] at the accumulated frame offset of the current process
// call, so each buffer must hold at least one full read chunk.
static short  s_scope_storage[8][SC68_CHUNK * 2];
static short* s_scope_bufs[8];
static int    s_scope_voices = 0;

extern "C" int getNumberTraceStreams(void) { return s_scope_voices; }
extern "C" short** getScopeBuffers(void) {
    if (!s_scope_bufs[0])
        for (int i = 0; i < 8; i++) s_scope_bufs[i] = s_scope_storage[i];
    return s_scope_bufs;
}

// ── One-time library init (mandatory-init check: sc68_init fills the 68k
// tables + option/config machinery; Modizer does it once at app launch) ────
static bool sc68_lib_init(void) {
    static int s_state = 0;   // 0 = not tried, 1 = ok, -1 = failed
    if (s_state) return s_state > 0;

    static char pathArg[4200];
    const char* dataDir = rewamp_get_data_dir();
    if (dataDir && dataDir[0]) {
        size_t len = strlen(dataDir);
        int hasSlash = len > 0 && dataDir[len - 1] == '/';
        snprintf(pathArg, sizeof(pathArg), "--sc68-user-path=%s%ssc68",
                 dataDir, hasSlash ? "" : "/");
    } else {
        pathArg[0] = '\0';
    }

    static char arg0[] = "sc68";
    char* argv[3] = { arg0, pathArg[0] ? pathArg : NULL, NULL };

    sc68_init_t init68;
    memset(&init68, 0, sizeof(init68));
    init68.argc = pathArg[0] ? 2 : 1;
    init68.argv = argv;
    init68.flags.no_load_config = 1;   // no sc68.cfg — explicit params only
    init68.flags.no_save_config = 1;

    s_state = sc68_init(&init68) ? -1 : 1;
    return s_state > 0;
}

static int sc68_probe(const char* ext, const uint8_t* h, size_t n) {
    // Plain files start with "SC68 Music-file". gzip (1f 8b) and
    // ICE-packed ("ICE!") .sc68 exist too — extension-gated for those.
    int magic = n >= 15 && !memcmp(h, "SC68 Music-file", 15);
    int extMatch = rewamp_ext_in_list(ext, kSc68Exts);
    if (magic) return extMatch ? 110 : 90;
    if (extMatch) {
        int packed = (n >= 2 && h[0] == 0x1f && h[1] == 0x8b) ||
                     (n >= 4 && !memcmp(h, "ICE!", 4));
        return packed ? 100 : 60;
    }
    return 0;
}

// Voice metadata for the current track's hardware.
static void sc68_register_voices(RewampDecoder* dec) {
    sc68_music_info_t info;
    if (sc68_music_info(dec->sc68, &info, SC68_CUR_TRACK, 0)) return;

    int voices;
    const char* chip;
    if (info.trk.amiga) {
        voices = 4;
        chip   = "Paula";
    } else if (info.trk.ste) {
        voices = 4;                    // YM A/B/C + STE DMA
        chip   = "YM2149+STE";
    } else {
        voices = 3;
        chip   = "YM2149";
    }
    dec->voices    = voices;
    s_scope_voices = voices;

    m_genNumVoicesChannels = voices;
    rewamp_channel_data_reset(voices);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2);
    rewamp_channel_data_set_ring_circular(1);
    m_voice_current_samplerate = SC68_RATE;
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip(chip, 0, voices);
    if (info.trk.amiga) {
        rewamp_voice_set_name(0, "Paula 1");
        rewamp_voice_set_name(1, "Paula 2");
        rewamp_voice_set_name(2, "Paula 3");
        rewamp_voice_set_name(3, "Paula 4");
    } else {
        rewamp_voice_set_name(0, "YM A");
        rewamp_voice_set_name(1, "YM B");
        rewamp_voice_set_name(2, "YM C");
        if (voices > 3) rewamp_voice_set_name(3, "STE DMA");
    }
}

static RewampDecoder* sc68_open_impl(const char* path, RewampAudioFormat* outFormat) {
    /* Mode 1 (N boucles): pas de compte natif -> veto, le generique
     * Dart compte les passes (voir configure_loop). */
    if (g_force_loop_mode == 1) g_force_loop_native_veto = 1;
    if (!path || !sc68_lib_init()) return NULL;

    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    int track = 0;
    char* q = strrchr(cleanPath, '?');
    if (q && strncmp(q, "?subsong=", 9) == 0) { track = atoi(q + 9); *q = '\0'; }

    sc68_create_t create;
    memset(&create, 0, sizeof(create));
    create.sampling_rate = SC68_RATE;
    create.name          = "rewamp";
    sc68_t* sc = sc68_create(&create);
    if (!sc) return NULL;

    if (sc68_load_uri(sc, cleanPath)) {
        sc68_destroy(sc);
        return NULL;
    }

    // Start: requested track, else the disk's default (Modizer plays track 1
    // first only to read info.dsk.track, then switches — go direct instead).
    sc68_music_info_t info;
    if (sc68_music_info(sc, &info, 1, 0)) { sc68_destroy(sc); return NULL; }
    if (track < 1 || track > info.tracks) track = 0;   // 0 → resolve default
    if (track == 0) track = info.dsk.track >= 1 ? (int)info.dsk.track : 1;

    rewamp_sc68_bind_scopes(sc);
    /* Repeat-morceau: SC68_INF_LOOP (-1) — sc68 boucle lui-même la piste
     * (sinon il émet SC68_END en fin de piste et le read s'arrête). */
    const int sc68Loops = (g_force_loop_mode == 2) ? -1 : 0;
    if (sc68_play(sc, track, sc68Loops) < 0) { sc68_destroy(sc); return NULL; }
    sc68_process(sc, NULL, NULL);     // apply the track change (n==NULL)

    if (sc68_music_info(sc, &info, SC68_CUR_TRACK, 0)) { sc68_destroy(sc); return NULL; }

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { sc68_destroy(sc); return NULL; }
    dec->sc68  = sc;
    dec->track = track;
    if (info.trk.time_ms > 0)
        dec->totalFrames = (uint64_t)info.trk.time_ms * SC68_RATE / 1000;

    sc68_register_voices(dec);

    if (info.title  && info.title[0])
        rewamp_track_message_append("Title: %s\n", info.title);
    if (info.artist && info.artist[0])
        rewamp_track_message_append("Artist: %s\n", info.artist);
    if (info.album  && info.album[0] &&
        (!info.title || strcmp(info.album, info.title)))
        rewamp_track_message_append("Album: %s\n", info.album);
    if (info.format && info.format[0])
        rewamp_track_message_append("Format: %s\n", info.format);
    if (info.trk.hw && info.trk.hw[0])
        rewamp_track_message_append("Hardware: %s\n", info.trk.hw);
    if (info.replay && info.replay[0])
        rewamp_track_message_append("Replay: %s\n", info.replay);
    if (info.year   && info.year[0])
        rewamp_track_message_append("Year: %s\n", info.year);
    if (info.ripper && info.ripper[0])
        rewamp_track_message_append("Ripper: %s\n", info.ripper);
    if (info.tracks > 1)
        rewamp_track_message_append("Subsongs: %d\n", info.tracks);

    if (outFormat) {
        outFormat->channels   = 2;
        outFormat->sampleRate = SC68_RATE;
    }
    return dec;
}

// Notes: pitch + gate come from the chips' live registers (the scope traces
// carry no pitch). Sampled once per process chunk, which is one ds_read worth
// of frames — the granularity the notes renderer captures at.
//
// The renderer ends a note box on a pitch change, an "instrument" change, or a
// volume JUMP (`vol[n] > vol[n-1] + 2`). Feeding it a raw per-chunk amplitude
// splits a held note into dozens of boxes, because chip music modulates
// amplitude constantly *within* a note (YM SID-voice/buzz effects, tremolo,
// the wandering local peak of a Paula sample). So the reported volume is an
// envelope follower with an instant attack and a slow release: it only ever
// RISES on a real attack, which is exactly the rule this is meant to express —
// volume held or falling stays one note, a marked rise starts a new one.
//
// Where the per-chunk amplitude comes from differs per chip, and getting this
// backwards is what made the first two attempts wrong:
//   YM    — the volume register is rewritten at kHz rates by SID-voice and
//           digidrum tricks; sampled per chunk it aliases into noise. Its
//           trace's peak-to-peak swing IS the note envelope. (Bonus: a silent
//           YM voice still emits a constant trace — the DAC's DC offset — so a
//           swing of zero identifies it, which a raw level cannot.)
//   Paula — the opposite: the trace is sampled PCM whose local peak wanders
//           with the waveform, while the per-voice volume register is the
//           honest, stable note amplitude.
//
// A Paula sample restarted at the SAME volume — what a tracker normally does —
// produces no rise at all, so a re-trigger is ALSO detected structurally, from
// the DMA gate rising or the sample start address changing, and forces both a
// follower reset and a bump of vgm_last_instr (a per-voice note counter; the
// renderer only compares that field for equality, nothing else reads it).
#define SC68_ATTACK_THRESH 24   // /255: a rise this big starts a new note
#define SC68_RELEASE_STEP   3   // /255 per chunk (~11.6 ms): ~1 s full fade

static void sc68_capture_notes(RewampDecoder* dec, int frames) {
    rewamp_sc68_notes_t n;
    rewamp_sc68_get_notes(dec->sc68, &n);
    for (int v = 0; v < n.count && v < dec->voices; v++) {
        // 1. This chunk's raw amplitude, from whichever source is honest.
        unsigned amp = 0;
        if (n.gate[v]) {
            if (n.swing_amp) {
                const short* t = s_scope_bufs[v];
                int lo = 32767, hi = -32768;
                for (int i = 0; i < frames; i++) {
                    if (t[i] < lo) lo = t[i];
                    if (t[i] > hi) hi = t[i];
                }
                // Full scale is one 16-bit half-range: ym2149_fake_voice_output
                // returns (ymout5[]+1)>>1.
                int64_t a = (int64_t)(hi - lo) * 255 / 16384;
                amp = (unsigned)(a > 255 ? 255 : a);
            } else {
                amp = n.vol[v];
            }
        }

        // 2. Re-trigger: a rise past the threshold, or a structural restart.
        const unsigned prev = dec->env[v];
        const int retrig = n.gate[v] &&
            (!dec->prevGate[v] || n.sample[v] != dec->prevSample[v] ||
             amp > prev + SC68_ATTACK_THRESH);
        if (retrig) dec->noteGen[v]++;
        dec->prevGate[v]   = n.gate[v];
        dec->prevSample[v] = n.sample[v];

        // 3. Follower: jump to the peak on attack; hold while the amplitude is
        //    steady or rising below the threshold (so the renderer never sees a
        //    rise it would split on); ease down, at most one step per chunk,
        //    while it falls.
        if (retrig || amp == 0) {
            dec->env[v] = amp;
        } else if (amp >= prev) {
            dec->env[v] = prev;                       // hold — never rise
        } else {
            unsigned floor = prev > SC68_RELEASE_STEP ? prev - SC68_RELEASE_STEP : 0;
            dec->env[v] = amp > floor ? amp : floor;  // decay, bounded by amp
        }

        const int muted = (int)((generic_mute_mask >> v) & 1);
        vgm_last_note[v]  = muted ? 0 : n.freq[v];
        vgm_last_vol[v]   = muted ? 0 : dec->env[v];
        vgm_last_instr[v] = dec->noteGen[v];
    }
}

static uint64_t sc68_read_impl(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || frameCount == 0) return 0;
    if (dec->totalFrames > 0) {
        if (dec->framePos >= dec->totalFrames) return 0;
        uint64_t remain = dec->totalFrames - dec->framePos;
        if (frameCount > remain) frameCount = remain;
    }

    rewamp_sc68_set_mute(dec->sc68, (unsigned)generic_mute_mask);
    // Re-point the scope/mix globals at us: a subsong probe on another
    // thread may have created/destroyed an sc68_t since the last read.
    rewamp_sc68_bind_scopes(dec->sc68);
    s_scope_voices = dec->voices;

    static int16_t s_buf[SC68_CHUNK * 2];
    const float scale = 1.0f / 32768.0f;
    uint64_t written = 0;
    while (written < frameCount) {
        int n = (int)(frameCount - written);
        if (n > SC68_CHUNK) n = SC68_CHUNK;
        int want = n;
        int code = sc68_process(dec->sc68, s_buf, &n);
        if (code == SC68_ERROR || n <= 0) break;

        float* dst = out + written * 2;
        for (int i = 0; i < n * 2; i++) dst[i] = s_buf[i] * scale;

        // After sc68_process: s_scope_bufs[v][0..n) hold this chunk's traces.
        sc68_capture_notes(dec, n);

        // Scope traces → per-voice int8 rings (muted voices read flat).
        for (int v = 0; v < dec->voices; v++) {
            if (!m_voice_buff[v]) continue;
            const short* src = s_scope_bufs[v];
            int muted = (int)((generic_mute_mask >> v) & 1);
            int64_t ofs = m_voice_current_ptr[v];
            for (int i = 0; i < n; i++) {
                int8_t smp = muted ? 0 : (int8_t)(src[i] >> 7);
                m_voice_buff[v][(ofs >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT) &
                                (SOUND_BUFFER_SIZE_SAMPLE * 4 * 2 - 1)] = smp;
                ofs += 1 << MODIZER_OSCILLO_OFFSET_FIXEDPOINT;
            }
            while ((ofs >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT) >=
                   SOUND_BUFFER_SIZE_SAMPLE * 4 * 2)
                ofs -= (int64_t)(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2)
                       << MODIZER_OSCILLO_OFFSET_FIXEDPOINT;
            m_voice_current_ptr[v] = ofs;
        }

        written += (uint64_t)n;
        dec->framePos += (uint64_t)n;
        if (code & SC68_END) break;
        if (n < want) break;
    }
    return written;
}

static void sc68_seek_impl(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec) return;
    // No native seek: restart the track, then discard-render forward (same
    // CPU-emulation idiom as UADE/vio2sf/SNDH/lazyusf).
    rewamp_sc68_bind_scopes(dec->sc68);
    if (frameIndex < dec->framePos) {
        if (sc68_play(dec->sc68, dec->track,
                      (g_force_loop_mode == 2) ? -1 : 0) < 0) return;
        sc68_process(dec->sc68, NULL, NULL);
        dec->framePos = 0;
    }
    static int16_t s_skip[SC68_CHUNK * 2];
    while (dec->framePos < frameIndex) {
        int n = (int)(frameIndex - dec->framePos);
        if (n > SC68_CHUNK) n = SC68_CHUNK;
        int code = sc68_process(dec->sc68, s_skip, &n);
        if (code == SC68_ERROR || n <= 0) break;
        dec->framePos += (uint64_t)n;
        if (code & SC68_END) break;
    }
}

static uint64_t sc68_length_impl(RewampDecoder* dec) {
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
static void sc68_configure_loop_fn(RewampDecoder* dec, int mode, int count) {
    (void)count;
    if (dec != NULL && mode == 2) dec->totalFrames = 0;
}

static void sc68_close_impl(RewampDecoder* dec) {
    if (!dec) return;
    s_scope_voices = 0;
    if (dec->sc68) {
        sc68_close(dec->sc68);
        sc68_destroy(dec->sc68);
    }
    free(dec);
}

// ── Subsong probe (Dart container dispatch), SNDH-style 1-based ────────────
static sc68_t*  s_probe_sc68 = NULL;
static char     s_probe_path[4096];

static sc68_t* sc68_probe_disk(const char* path) {
    if (s_probe_sc68 && !strcmp(s_probe_path, path)) return s_probe_sc68;
    if (s_probe_sc68) { sc68_destroy(s_probe_sc68); s_probe_sc68 = NULL; }
    if (!sc68_lib_init()) return NULL;
    sc68_create_t create;
    memset(&create, 0, sizeof(create));
    create.sampling_rate = SC68_RATE;
    sc68_t* sc = sc68_create(&create);
    if (!sc) return NULL;
    if (sc68_load_uri(sc, path)) { sc68_destroy(sc); return NULL; }
    strncpy(s_probe_path, path, sizeof(s_probe_path) - 1);
    s_probe_path[sizeof(s_probe_path) - 1] = '\0';
    s_probe_sc68 = sc;
    return sc;
}

extern "C" int rewamp_sc68_probe_subsong_count(const char* path) {
    const char* dot = strrchr(path, '.');
    if (!dot || strcasecmp(dot + 1, "sc68") != 0) return 0;
    sc68_t* sc = sc68_probe_disk(path);
    if (!sc) return 0;
    sc68_music_info_t info;
    if (sc68_music_info(sc, &info, 1, 0)) return 0;
    return info.tracks;
}

extern "C" const char* rewamp_sc68_probe_get_title(int subsong) {
    static char title[256];
    if (!s_probe_sc68) return "";
    sc68_music_info_t info;
    if (sc68_music_info(s_probe_sc68, &info, subsong, 0)) return "";
    snprintf(title, sizeof(title), "%s", info.title ? info.title : "");
    return title;
}

extern "C" int rewamp_sc68_probe_get_duration_ms(int subsong) {
    if (!s_probe_sc68) return 0;
    sc68_music_info_t info;
    if (sc68_music_info(s_probe_sc68, &info, subsong, 0)) return 0;
    return (int)info.trk.time_ms;
}

// sc68 track numbers are 1-based; ?subsong= carries them directly.
extern "C" int rewamp_sc68_probe_base(void) { return 1; }

static const RewampPluginVTable kSc68VTable = {
    "sc68",
    sc68_probe,
    sc68_open_impl,
    sc68_read_impl,
    sc68_seek_impl,
    sc68_length_impl,
    sc68_close_impl,
    sc68_configure_loop_fn,
};

extern "C" const RewampPluginVTable* rewamp_sc68_plugin(void) { return &kSc68VTable; }

#endif /* REWAMP_WITH_SC68 */

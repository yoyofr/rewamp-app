// libnsfplay plugin — NES NSF/NSFe decoder with per-channel voice data.
// Compiled only when REWAMP_WITH_NSFPLAY is defined.
#ifdef REWAMP_WITH_NSFPLAY

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"

// libnsfplay uses C++ namespace xgm; include via the top-level header.
#include "libnsfplay/xgm.h"
#include "libnsfplay/player/nsf/nsf.h"
#include "libnsfplay/player/nsf/nsfplay.h"
#include "libnsfplay/player/nsf/nsfconfig.h"
#include "libnsfplay/player/nsf/pls/ppls.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <stdio.h>
#include <dirent.h>
#include <string>

// Forced-loop setting (Settings → Lecture) — see rewamp_audio.c.
extern "C" int    g_force_loop_mode;
extern "C" int    g_force_loop_count;
extern "C" int    g_force_fadeout_enabled;
extern "C" double g_force_fadeout_seconds;
extern "C" double g_force_base_duration_secs;
extern "C" int    g_force_loop_native_veto;
extern "C" int    g_loop_lift_refused;
extern "C" double g_track_end_fade_secs;          /* rewamp_audio.c */
extern "C" int    g_track_length_authoritative;   /* rewamp_audio.c */
extern "C" double g_crossfade_seconds;            /* rewamp_datasource.c */

#define NSFPLAY_RATE     44100
#define NSFPLAY_CHANNELS 2

// Must match REWAMP_NSF_OSCILLO_SIZE in nsfplay_symbol_rename.h — the number of
// samples the native nsfplay.cpp scope writes before wrapping m_voice_current_ptr.
#define NSFPLAY_OSCILLO_SIZE 4096

/* Settings → Moteurs → NSF (nsfplay): Modizer's NSFPLAY family, applied on
 * open AND live (config keys + Notify(-1)). Defaults = Modizer's. */
static void nsfplay_apply_engine_params(xgm::NSFPlayerConfig* cfg) {
    (*cfg)["QUALITY"]    = (int)rewamp_get_engine_param("nsfplay", "quality", 10);
    (*cfg)["LPF"]        = (int)rewamp_get_engine_param("nsfplay", "lpf", 112);
    (*cfg)["HPF"]        = (int)rewamp_get_engine_param("nsfplay", "hpf", 164);
    (*cfg)["REGION"]     = (int)rewamp_get_engine_param("nsfplay", "region", 0);
    (*cfg)["IRQ_ENABLE"] = (int)rewamp_get_engine_param("nsfplay", "irq", 0);
    static const int apu1_def[5] = {1, 1, 1, 0, 0};
    static const int apu2_def[9] = {1, 1, 1, 0, 1, 1, 1, 1, 0};
    static const int n163_def[3] = {1, 0, 0};
    char key[32], ck[32];
    for (int i = 0; i < 5; i++) {
        snprintf(key, sizeof(key), "apu1_%d", i);
        snprintf(ck,  sizeof(ck),  "APU1_OPTION%d", i);
        (*cfg)[ck] = (int)rewamp_get_engine_param("nsfplay", key, apu1_def[i]);
    }
    for (int i = 0; i < 9; i++) {
        snprintf(key, sizeof(key), "apu2_%d", i);
        snprintf(ck,  sizeof(ck),  "APU2_OPTION%d", i);
        (*cfg)[ck] = (int)rewamp_get_engine_param("nsfplay", key, apu2_def[i]);
    }
    for (int i = 0; i < 3; i++) {
        snprintf(key, sizeof(key), "n163_%d", i);
        snprintf(ck,  sizeof(ck),  "N163_OPTION%d", i);
        (*cfg)[ck] = (int)rewamp_get_engine_param("nsfplay", key, n163_def[i]);
    }
    (*cfg)["FDS_OPTION0"]  = (int)rewamp_get_engine_param("nsfplay", "fds_lpf_hz", 2000);
    (*cfg)["FDS_OPTION1"]  = (int)rewamp_get_engine_param("nsfplay", "fds_1", 0);
    (*cfg)["FDS_OPTION2"]  = (int)rewamp_get_engine_param("nsfplay", "fds_2", 0);
    (*cfg)["MMC5_OPTION0"] = (int)rewamp_get_engine_param("nsfplay", "mmc5_0", 1);
    (*cfg)["MMC5_OPTION1"] = (int)rewamp_get_engine_param("nsfplay", "mmc5_1", 1);
    (*cfg)["VRC7_PATCH"]   = (int)rewamp_get_engine_param("nsfplay", "vrc7_patch", 0);
    (*cfg)["VRC7_OPTION0"] = (int)rewamp_get_engine_param("nsfplay", "vrc7_opll", 0);
}

struct RewampDecoder {
    xgm::NSFPlayer*       player;
    xgm::NSFPlayerConfig* config;
    xgm::NSF*             nsf;
    int                   voiceCount;
    // Maps oscilloscope buffer-channel index -> infobuf[] enum index, so the
    // per-channel freq/volume read from infobuf aligns with the native
    // ring-buffer write order (APU, FDS, FME7, MMC5, N106, VRC6, VRC7).
    int                   infoMap[REWAMP_MAX_CHANNELS];
    // Per-voice bit index into the nsfplay "MASK" config (layout in
    // nsfplay.cpp Reset(): APU 0-4, FDS 5, MMC5 6-8, FME7 9-11, VRC6 12-14,
    // VRC7 15-23, N163 24+).
    int                   maskBit[REWAMP_MAX_CHANNELS];
    int64_t               lastMuteMask; // applied generic_mute_mask snapshot
    bool                  infinite;     // configure_loop(2): no end any more
    // Fondu de fin sur du SILENCE: un morceau qui ne boucle pas a fini à la
    // durée du .m3u, et nsfplay fond quand même — `fade` secondes de vide.
    // Muet ≥ kNsfSilentEndMs PENDANT le fondu ⇒ fin du morceau.
    uint32_t              silentFrames; // trames muettes consécutives en sortie
    bool                  endedEarly;   // fin décidée par ce filet (seek la lève)
};

static const uint32_t kNsfSilentEndMs = 400;

static const char* const kNsfplayExts[] = { "nsf", "nsfe", NULL };

// ── probe ─────────────────────────────────────────────────────────────────────

static int nsfplay_probe(const char* ext, const uint8_t* hdr, size_t hdrSize) {
    int extMatch = rewamp_ext_in_list(ext, kNsfplayExts);
    if (hdr && hdrSize >= 4 &&
        hdr[0]=='N' && hdr[1]=='E' && hdr[2]=='S' && hdr[3]=='M')
        return extMatch ? 100 : 90;
    return extMatch ? 60 : 0;
}

// ── .m3u sidecar loop metadata ─────────────────────────────────────────────────
// The classic Winamp/NEZplug NSF playlist format encodes per-track timing:
//   filename::NSF,song,title,time,loop,fade,loopcount
// libnsfplay already parses such a line (PLSITEM_new) and NSF::LoadFile accepts
// it directly. We look for a sibling .m3u referencing this NSF+subsong and, if
// found, hand LoadFile that line (with the filename rewritten to the absolute
// NSF path so it resolves regardless of CWD). Only consulted when force-loop is
// OFF — an active force-loop Settings takes priority (see nsfplay_open).

static const char* base_name(const char* p) {
    const char* s = strrchr(p, '/');
    return s ? s + 1 : p;
}

// Scan the NSF's directory for a *.m3u whose entry matches this file+subsong.
// Returns the synthetic "<absNsfPath>::NSF,..." line, or "" if none. iOS note:
// opendir on the file's own directory may be sandbox/TCC-denied — that just
// yields no match (graceful: playback proceeds with no m3u metadata).
static std::string find_m3u_line(const char* nsfPath, int subsong) {
    std::string dir, nsfBase = base_name(nsfPath);
    { const char* s = strrchr(nsfPath, '/'); dir.assign(nsfPath, s ? (size_t)(s - nsfPath) : 0); }
    if (dir.empty()) dir = ".";

    DIR* d = opendir(dir.c_str());
    if (!d) return std::string();

    std::string result;
    struct dirent* e;
    while ((e = readdir(d)) != NULL) {
        const char* nm = e->d_name;
        size_t nl = strlen(nm);
        if (nl < 4 || strcasecmp(nm + nl - 4, ".m3u") != 0) continue;

        std::string m3u = dir + "/" + nm;
        FILE* fp = fopen(m3u.c_str(), "rb");
        if (!fp) continue;

        char line[2048];
        while (fgets(line, sizeof(line), fp)) {
            // Strip trailing CR/LF.
            size_t ll = strlen(line);
            while (ll > 0 && (line[ll-1] == '\n' || line[ll-1] == '\r')) line[--ll] = '\0';
            if (line[0] == '#' || ll == 0) continue;
            const char* sep = strstr(line, "::");
            if (!sep) continue;

            PLSITEM* it = PLSITEM_new(line);
            if (it) {
                // type 3 == NSF; PLSITEM already decremented song to 0-based.
                bool hit = (it->type == 3) && it->filename &&
                           strcasecmp(base_name(it->filename), nsfBase.c_str()) == 0 &&
                           it->song == subsong;
                PLSITEM_delete(it);
                if (hit) {
                    // Rewrite the filename half with the absolute NSF path,
                    // keep the "::NSF,..." timing half verbatim.
                    result = std::string(nsfPath) + sep;
                    break;
                }
            }
        }
        fclose(fp);
        if (!result.empty()) break;
    }
    closedir(d);
    return result;
}

// ── open ──────────────────────────────────────────────────────────────────────

static RewampDecoder* nsfplay_open(const char* path, RewampAudioFormat* outFormat) {
    char cleanPath[4096];
    strncpy(cleanPath, path, sizeof(cleanPath) - 1);
    cleanPath[sizeof(cleanPath) - 1] = '\0';
    int subsong = 0;
    char* q = strrchr(cleanPath, '?');
    if (q) {
        if (strncmp(q + 1, "subsong=", 8) == 0)
            subsong = atoi(q + 9);
        *q = '\0';
    }

    xgm::NSFPlayerConfig* cfg = new xgm::NSFPlayerConfig();
    (*cfg)["RATE"]          = NSFPLAY_RATE;
    // Render applies (out*MASTER_VOLUME)>>8, so 256 = unity gain.  The library
    // default of 128 halves the output, leaving NSF quieter than libgme; use 256
    // to match (same value nsf2wav uses).
    (*cfg)["MASTER_VOLUME"] = 256;

    /* Engine params (Settings → Moteurs → NSF) — also live via
     * nsfplay_param_changed. */
    nsfplay_apply_engine_params(cfg);

    xgm::NSFPlayer* player = new xgm::NSFPlayer();
    player->SetConfig(cfg);

    xgm::NSF* nsf = new xgm::NSF();
    // Force-loop OFF → let a sibling .m3u supply per-track time/loop/fade/
    // loopcount (Settings win when force-loop is on, so skip the m3u then and
    // load the plain path; the force-loop block below drives everything).
    std::string m3uLine;
    if (g_force_loop_mode == 0)
        m3uLine = find_m3u_line(cleanPath, subsong);
    const bool loaded = m3uLine.empty()
        ? nsf->LoadFile(cleanPath)
        : nsf->LoadFile(m3uLine.c_str());
    if (!loaded) {
        delete nsf; delete player; delete cfg; return NULL;
    }

    if (!player->Load(nsf)) {
        delete nsf; delete player; delete cfg; return NULL;
    }

    player->SetChannels(NSFPLAY_CHANNELS);
    player->SetPlayFreq(NSFPLAY_RATE);
    player->SetSong(subsong);   // GetPlayTime() below reads the song's entry

    // ── Length and end fade (after SetSong: an NSFe/.m3u time is per song) ──
    // Fade = Settings → Moteurs → NSF (0-16 s, 0 = hard stop) when the file
    // gives none; none either under a crossfade (the overlap is the fade —
    // same rule as libvgm and the PSF ramp).
    const int fadeSetMs = g_crossfade_seconds > 0.0 ? 0
        : (int)(rewamp_get_engine_param("nsfplay", "fade_secs", 5.0) * 1000.0);
    // Base of a song WITHOUT a known time: the APP's length, not libnsfplay's
    // 5:00 — Dart sends the catalogue length, else Settings → Lecture →
    // default length.
    const int baseMs = (g_force_base_duration_secs > 0.0)
        ? (int)(g_force_base_duration_secs * 1000.0)
        : 5 * 60 * 1000;
    nsf->SetDefaults(-1, fadeSetMs, 0);          // -1 = probe: time unknown?
    const bool timeKnown = nsf->GetPlayTime() >= 0;
    if (g_force_loop_mode == 0) {
        if (timeKnown) {
            // NSFe / .m3u time = the MUSIC; libnsfplay plays its loops and
            // fade AFTER it, and length() (GetLength) counts them. A
            // catalogue length counts the music only and Dart, which prefers
            // it, cut the fade off — the same trap as libvgm: say so.
            const int fadeMs = nsf->GetFadeTime();
            if (fadeMs > 50) g_track_end_fade_secs = fadeMs / 1000.0;
            if (nsf->GetLoopTime() > 0 && nsf->GetLoopNum() > 0)
                g_track_length_authoritative = 1;
        } else {
            // Unknown time: the length asked for is the TOTAL, fade included
            // (never more than half of it).
            const int fadeMs = fadeSetMs < baseMs / 2 ? fadeSetMs : baseMs / 2;
            nsf->SetDefaults(baseMs - fadeMs, fadeMs, 0);
        }
    } else {
        // Forced loop. A tune that plays once and goes silent can't loop
        // natively: a COUNTED loop (mode 1) is the Dart generic loop's job
        // (veto ⇒ configure_loop is not trusted for this file), on a single
        // pass of known length (loopnum 1 / fade 0) and without nsfplay ever
        // ending on its own (PLAY_ADVANCE). INFINITE (mode 2) is lifted by
        // nsfplay_configure_loop — the same call that arms it IN FLIGHT.
        nsf->SetDefaults(baseMs, 0, 1);
        if (g_force_loop_mode == 1) {
            g_force_loop_native_veto = 1;
            (*cfg)["PLAY_ADVANCE"] = 1;
            player->UpdateInfinite();
        }
    }
    player->Reset();

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    dec->player = player;
    dec->config = cfg;
    dec->nsf    = nsf;

    // Compute the real active voice count and the buffer->infobuf channel map,
    // following the native Render() ring-buffer write order:
    //   APU(5: sq1,sq2,tri,noise,dmc), FDS(1), FME7(3), MMC5(3), N106(8),
    //   VRC6(3), VRC7(9).
    using P = xgm::NSFPlayer;

    // Allocate the ring buffers FIRST: rewamp_channel_data_reset() wipes the
    // voice/chip metadata, so registration must come after it.
    {
        int total = 5;
        if (nsf->use_fds)  total += 1;
        if (nsf->use_fme7) total += 3;
        if (nsf->use_mmc5) total += 3;
        if (nsf->use_n106) total += 8;
        if (nsf->use_vrc6) total += 3;
        if (nsf->use_vrc7) total += 9;
        if (total > REWAMP_MAX_CHANNELS) total = REWAMP_MAX_CHANNELS;
        rewamp_channel_data_reset(total);
        rewamp_channel_data_set_ring_write_size(NSFPLAY_OSCILLO_SIZE);
        rewamp_channel_data_set_ring_circular(1);
    }

    // Info panel: NSF/NSFe header strings (+ NSFe ripper/text blocks).
    {
        struct { const char* v; const char* label; } kFields[] = {
            { nsf->title,     "Title" },     { nsf->artist, "Artist" },
            { nsf->copyright, "Copyright" }, { nsf->ripper, "Ripper" },
        };
        for (size_t k = 0; k < sizeof(kFields) / sizeof(kFields[0]); k++) {
            if (kFields[k].v && kFields[k].v[0])
                rewamp_track_message_append("%s: %s\n",
                                            kFields[k].label, kFields[k].v);
        }
        if (nsf->text && nsf->text[0])
            rewamp_track_message_append("\n%s\n", nsf->text);
    }

    int n = 0;
    rewamp_voices_meta_reset();

    rewamp_voices_add_chip("RP2A03", n, 5);
    static const char* const kApuNames[5] =
        { "Square 1", "Square 2", "Triangle", "Noise", "DMC" };
    dec->infoMap[n] = P::APU1_TRK0; dec->maskBit[n] = 0; n++; // square 1
    dec->infoMap[n] = P::APU1_TRK1; dec->maskBit[n] = 1; n++; // square 2
    dec->infoMap[n] = P::APU2_TRK0; dec->maskBit[n] = 2; n++; // triangle
    dec->infoMap[n] = P::APU2_TRK1; dec->maskBit[n] = 3; n++; // noise
    dec->infoMap[n] = P::APU2_TRK2; dec->maskBit[n] = 4; n++; // dmc
    for (int i = 0; i < 5; i++) rewamp_voice_set_name(i, kApuNames[i]);

    if (nsf->use_fds) {
        rewamp_voices_add_chip("FDS", n, 1);
        rewamp_voice_set_name(n, "FDS");
        dec->infoMap[n] = P::FDS_TRK0; dec->maskBit[n] = 5; n++;
    }
    if (nsf->use_fme7) {
        rewamp_voices_add_chip("5B", n, 3);
        for (int i = 0; i < 3; i++) {
            char vn[16]; snprintf(vn, sizeof(vn), "5B %d", i + 1);
            rewamp_voice_set_name(n, vn);
            dec->infoMap[n] = P::FME7_TRK0 + i; dec->maskBit[n] = 9 + i; n++;
        }
    }
    if (nsf->use_mmc5) {
        rewamp_voices_add_chip("MMC5", n, 3);
        static const char* const kMmc5[3] = { "Square 1", "Square 2", "PCM" };
        for (int i = 0; i < 3; i++) {
            rewamp_voice_set_name(n, kMmc5[i]);
            dec->infoMap[n] = P::MMC5_TRK0 + i; dec->maskBit[n] = 6 + i; n++;
        }
    }
    if (nsf->use_n106) {
        rewamp_voices_add_chip("N163", n, 8);
        for (int i = 0; i < 8; i++) {
            char vn[16]; snprintf(vn, sizeof(vn), "Ch %d", i + 1);
            rewamp_voice_set_name(n, vn);
            dec->infoMap[n] = P::N106_TRK0 + i; dec->maskBit[n] = 24 + i; n++;
        }
    }
    if (nsf->use_vrc6) {
        rewamp_voices_add_chip("VRC6", n, 3);
        static const char* const kVrc6[3] = { "Square 1", "Square 2", "Saw" };
        for (int i = 0; i < 3; i++) {
            rewamp_voice_set_name(n, kVrc6[i]);
            dec->infoMap[n] = P::VRC6_TRK0 + i; dec->maskBit[n] = 12 + i; n++;
        }
    }
    if (nsf->use_vrc7) {
        rewamp_voices_add_chip("VRC7", n, 9);
        for (int i = 0; i < 9; i++) {
            char vn[16]; snprintf(vn, sizeof(vn), "FM %d", i + 1);
            rewamp_voice_set_name(n, vn);
            dec->infoMap[n] = (i < 6) ? (P::VRC7_TRK0 + i) : (P::VRC7_TRK6 + (i - 6));
            dec->maskBit[n] = 15 + i; n++;
        }
    }
    if (n > REWAMP_MAX_CHANNELS) n = REWAMP_MAX_CHANNELS;
    dec->voiceCount = n;

    if (outFormat) {
        outFormat->channels   = NSFPLAY_CHANNELS;
        outFormat->sampleRate = NSFPLAY_RATE;
    }
    return dec;
}

// ── voice freq/vol capture ──────────────────────────────────────────────────
// This nsfplay copy already writes the oscilloscope ring buffers and advances
// m_voice_current_ptr[] natively (Modizer patches inside Render).  We only read
// ITrackInfo from infobuf[] to expose per-channel freq/volume.  We must NOT
// touch m_voice_buff[] or m_voice_current_ptr[] here — doing so corrupts the
// native ring-buffer write pointers and overflows the heap.
//
// infobuf[] enum ordering (APU1_TRK0, APU1_TRK1, APU2_TRK0=tri, APU2_TRK1=noise,
// APU2_TRK2=dmc, FDS_TRK0, …) matches the native ring-buffer channel order for
// the base APU channels.

static void nsfplay_capture_voices(RewampDecoder* dec) {
    xgm::NSFPlayer* p = dec->player;
    for (int ch = 0; ch < dec->voiceCount; ch++) {
        int trk = dec->infoMap[ch];
        xgm::IDeviceInfo* di = p->infobuf[trk].GetInfo(-1);
        xgm::ITrackInfo* ti = di ? dynamic_cast<xgm::ITrackInfo*>(di) : NULL;
        if (!ti) {
            vgm_last_note[ch] = 0;
            vgm_last_vol[ch]  = 0;
            continue;
        }
        int  vol    = ti->GetVolume();
        int  maxVol = ti->GetMaxVolume();
        bool keyOn  = ti->GetKeyStatus();
        // Only report a note while the channel is actually sounding; otherwise
        // clear it so the scope/notation don't keep a stale note after key-off.
        bool sounding = keyOn && vol > 0;
        vgm_last_note[ch] = sounding ? (unsigned int)ti->GetFreqHz() : 0;
        vgm_last_vol[ch]  = (maxVol > 0 && sounding) ? (unsigned int)(255 * vol / maxVol) : 0;
    }
}

// ── read ──────────────────────────────────────────────────────────────────────

static uint64_t nsfplay_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || !dec->player || frameCount == 0) return 0;
    if (dec->player->IsStopped() || dec->endedEarly) return 0;

    // Apply voice-mute changes from the UI: rebuild the nsfplay "MASK" config
    // from generic_mute_mask via the per-voice bit map, then Notify(-1) so
    // every device re-reads it (Modizer does the same).
    if (dec->lastMuteMask != generic_mute_mask) {
        dec->lastMuteMask = generic_mute_mask;
        int mask = 0;
        for (int v = 0; v < dec->voiceCount; v++) {
            if ((generic_mute_mask >> v) & 1) mask |= 1 << dec->maskBit[v];
        }
        (*dec->config)["MASK"] = mask;
        dec->player->Notify(-1);
    }

    // NSFPlayer::Render(b, length): length is the number of FRAMES (it writes
    // length * nch int16 values, advancing b by nch each iteration) and returns
    // the number of frames produced.
    int16_t* tmp = (int16_t*)malloc((size_t)(frameCount * NSFPLAY_CHANNELS * sizeof(int16_t)));
    if (!tmp) return 0;

    xgm::UINT32 framesRendered = dec->player->Render(tmp, (xgm::UINT32)frameCount);
    if (framesRendered == 0) { free(tmp); return 0; }

    for (xgm::UINT32 i = 0; i < framesRendered * NSFPLAY_CHANNELS; i++)
        out[i] = tmp[i] / 32768.0f;

    // Silence en sortie (|x| ≤ 8/32768, -72 dB: le filtre DC ramène une
    // sortie figée vers 0). Ne décide qu'en FONDU: avant, un silence est une
    // pause du morceau; muet ici, le morceau est fini et le fondu n'ajouterait
    // que du vide. Voix coupées (MASK) exclues: le silence y est voulu.
    for (xgm::UINT32 f = 0; f < framesRendered; f++) {
        bool quiet = true;
        for (int c = 0; c < NSFPLAY_CHANNELS; c++) {
            const int v = tmp[f * NSFPLAY_CHANNELS + c];
            if (v > 8 || v < -8) { quiet = false; break; }
        }
        dec->silentFrames = quiet ? dec->silentFrames + 1 : 0;
    }
    if (!dec->infinite && dec->lastMuteMask == 0 && dec->player->fader.IsFading() &&
        dec->silentFrames >= (uint32_t)((uint64_t)NSFPLAY_RATE * kNsfSilentEndMs / 1000))
        dec->endedEarly = true;   // ce bloc part, le suivant rend 0 = fin

    // Write mixed mono into channel 0 ring buffer (monotonic ptr, auto-detected
    // in ring_read via ptr always increasing — no wrap since RING_BUF_SAMPLES is
    // large enough for sustained playback at 44100 Hz).
    nsfplay_capture_voices(dec);
    free(tmp);
    return (uint64_t)framesRendered;
}

// ── seek ──────────────────────────────────────────────────────────────────────

static void nsfplay_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec || !dec->player) return;
    dec->player->Reset();
    dec->silentFrames = 0;
    dec->endedEarly = false;
    // Skip(samples): same frame-based unit as Render's length. Il saute des
    // échantillons de SORTIE à la vitesse en vigueur; la cible est en temps du
    // MORCEAU ⇒ ÷ vitesse (la vitesse survit au Reset: NES_CPU la garde).
    const double sp = dec->player->rewamp_speed > 0.0 ? dec->player->rewamp_speed : 1.0;
    dec->player->Skip((xgm::UINT32)((double)frameIndex / sp + 0.5));
}

/* Vitesse NATIVE (patch REWAMP de libnsfplay, nes_cpu.cpp): la routine PLAY du
 * NSF est appelée `speed` fois plus souvent, CPU et APU gardent leur horloge —
 * tempo plus rapide, hauteur conservée. Le temps du lecteur (fondu, fin)
 * avance × vitesse, donc en temps du MORCEAU. */
static int nsfplay_set_speed(RewampDecoder* dec, double speed) {
    if (!dec || !dec->player || speed < 0.2 || speed > 3.0) return 0;
    dec->player->RewampSetSpeed(speed);
    return 1;
}

// ── length ────────────────────────────────────────────────────────────────────

static uint64_t nsfplay_length(RewampDecoder* dec) {
    if (!dec || !dec->nsf || dec->infinite) return 0;   /* no end any more */
    int ms = dec->nsf->GetLength();
    if (ms <= 0) return 0;
    return (uint64_t)((double)ms / 1000.0 * NSFPLAY_RATE);
}

// ── close ─────────────────────────────────────────────────────────────────────

static void nsfplay_close(RewampDecoder* dec) {
    if (!dec) return;
    delete dec->player;
    delete dec->nsf;
    delete dec->config;
    free(dec);
}

// ── vtable ────────────────────────────────────────────────────────────────────

/* Infinite loop (mode 2), at open AND in flight (rewamp_lift_end_for_infinite,
 * "nsfplay" is in rewamp_loop_lifts_live): an NSF's driver loops by itself,
 * only the player's end has to go — PLAY_ADVANCE stops CheckTerminal from
 * starting the fade (it survives Reset/seek: UpdateInfinite rereads it).
 * Already fading = the end is under way: refused, the generic loop restarts.
 * Mode 1 vetoed itself in open(). */
static void nsfplay_configure_loop(RewampDecoder* dec, int mode, int count) {
    (void)count;
    if (!dec || !dec->player || mode != 2) return;
    if (dec->player->fader.IsFading()) { g_loop_lift_refused = 1; return; }
    (*dec->config)["PLAY_ADVANCE"] = 1;
    dec->player->UpdateInfinite();
    dec->infinite = true;
}

/* Live settings change (called under the decode lock): update the config the
 * player holds, then Notify(-1) so every device re-reads it (Modizer's
 * optNSFPLAY_UpdateParam). */
static void nsfplay_param_changed(RewampDecoder* dec, const char* key) {
    (void)key;
    if (!dec || !dec->config || !dec->player) return;
    nsfplay_apply_engine_params(dec->config);
    dec->player->Notify(-1);
}

static const RewampPluginVTable kNsfplayVTable = {
    "nsfplay",
    nsfplay_probe,
    nsfplay_open,
    nsfplay_read,
    nsfplay_seek,
    nsfplay_length,
    nsfplay_close,
    /* configure_loop        */ nsfplay_configure_loop,
    /* supportsNativeFadeout */ 0,
    "nsfplay",              /* engine_id */
    nsfplay_param_changed,  /* live settings */
    NULL, NULL, NULL, NULL, NULL, /* pattern view */
    NULL,                   /* probe_path */
    0,                      /* noPrefixProbe */
    nsfplay_set_speed,      /* vitesse native (période de PLAY) */
};

extern "C" const RewampPluginVTable* rewamp_nsfplay_plugin(void) {
    return &kNsfplayVTable;
}

#endif /* REWAMP_WITH_NSFPLAY */

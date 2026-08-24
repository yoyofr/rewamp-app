/*
 * rewamp_plugin_vgm.cpp — libvgm decoder plugin for rewamp_audio
 *
 * Supports VGM (.vgm / .vgz), S98, GYM, DRO formats via the libvgm
 * PlayerA API.  Per-channel oscilloscope data is populated as a side-effect
 * of rendering, written by the chip emulator cores into the global ring
 * buffers declared in ModizerVoicesData.h.
 *
 * Build guard: REWAMP_WITH_VGM
 */

#ifdef REWAMP_WITH_VGM

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"   /* vgmVRC7, vgm2610b, m_voice_ChipID, ... */

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* libvgm player layer */
#include "../third_party/libvgm/libvgm/player/playera.hpp"
#include "../third_party/libvgm/libvgm/player/vgmplayer.hpp"
#include <emu/EmuCores.h>
#include "../third_party/libvgm/libvgm/player/s98player.hpp"
#include "../third_party/libvgm/libvgm/player/droplayer.hpp"
#include "../third_party/libvgm/libvgm/player/gymplayer.hpp"
#include "../third_party/libvgm/libvgm/utils/DataLoader.h"
#include "../third_party/libvgm/libvgm/utils/FileLoader.h"
#include "../third_party/libvgm/libvgm/utils/MemoryLoader.h"
#include "rewamp_assets.h"   /* rewamp_load_asset() -> bundled vgm/yrw801.rom */
#include "../third_party/libvgm/libvgm/emu/SoundDevs.h"
#include "../third_party/libvgm/libvgm/emu/SoundEmu.h"   /* SndEmu_GetDevName */

#include <vector>

/* Forced-loop setting (Settings → Lecture) — see rewamp_audio.c. */
extern "C" int    g_force_loop_mode;
extern "C" int    g_force_loop_count;
extern "C" int    g_force_fadeout_enabled;
extern "C" double g_force_fadeout_seconds;
extern "C" int    g_force_loop_native_veto;

/* For vgmGetVoicesNb / vgmDataVoice_Available we define them inline here. */

static uint8_t vgm_voice_available(uint8_t type) {
    switch (type) {
        case DEVID_SN76496: case DEVID_YM2413:  case DEVID_YM2612:  case DEVID_YM2151:
        case DEVID_SEGAPCM: case DEVID_RF5C68:  case DEVID_YM2203:  case DEVID_YM2608:
        case DEVID_YM2610:  case DEVID_YM3812:  case DEVID_YM3526:  case DEVID_Y8950:
        case DEVID_YMF262:  case DEVID_YMF278B: case DEVID_YMF271:  case DEVID_YMZ280B:
        case DEVID_32X_PWM: case DEVID_AY8910:  case DEVID_GB_DMG:  case DEVID_NES_APU:
        case DEVID_YMW258:  case DEVID_uPD7759: case DEVID_MSM6258:case DEVID_MSM6295:
        /* Puces ajoutées par l'amont depuis notre ancienne base (2024-01) —
         * activées ici, avec leurs captures d'oscilloscope dans les coeurs. */
        case DEVID_K007232: case DEVID_K005289: case DEVID_MSM5205:
        case DEVID_MSM5232: case DEVID_BSMT2000:case DEVID_ICS2115:
        case DEVID_K051649: case DEVID_K054539: case DEVID_C6280:   case DEVID_C140:
        case DEVID_C219:    case DEVID_K053260: case DEVID_POKEY:   case DEVID_QSOUND:
        case DEVID_SCSP:    case DEVID_WSWAN:   case DEVID_VBOY_VSU:case DEVID_SAA1099:
        case DEVID_ES5503:  case DEVID_X1_010:  case DEVID_C352:
        case DEVID_GA20:    case DEVID_MIKEY:
            return 1;
        default:
            return 0;
    }
}

/* Set when the loaded NES file enables the FDS expansion (cfg.flags bit 0, see
 * nesintf.h). The NSFPlay FDS core writes its wave to voice slot base+5
 * (np_nes_fds.c), so the NES chip must reserve 6 voices — not the 5 of a bare
 * 2A03 — or that write lands in an UNALLOCATED m_voice_buff[] slot and SIGSEGVs
 * (byte-write to NULL) as soon as an FDS tune renders. */
static char vgmNesFds = 0;

static uint8_t vgm_voices_nb(uint8_t type) {
    switch (type) {
        case DEVID_SN76496: return 4;
        case DEVID_YM2413:  return (vgmVRC7 ? 6 : 9);
        case DEVID_YM2612:  return 6;
        case DEVID_YM2151:  return 8;
        case DEVID_SEGAPCM: return 16;
        case DEVID_RF5C68:  return 8;
        case DEVID_YM2203:  return 6;
        case DEVID_YM2608:  return 16;
        case DEVID_YM2610:  return (vgm2610b ? 16 : 14);
        case DEVID_YM3812:  return 9;
        case DEVID_YM3526:  return 9;
        case DEVID_Y8950:   return 10;
        case DEVID_YMF262:  return 18;
        case DEVID_YMF278B: return 24 + 18;
        case DEVID_YMF271:  return 12;
        case DEVID_YMZ280B: return 8;
        case DEVID_32X_PWM: return 2;
        case DEVID_AY8910:  return 4;
        case DEVID_GB_DMG:  return 4;
        case DEVID_NES_APU: return vgmNesFds ? 6 : 5;
        case DEVID_YMW258:  return 28;
        case DEVID_uPD7759: return 1;
        case DEVID_MSM6258:return 1;
        case DEVID_MSM6295:return 4;
        case DEVID_K007232: return 2;
        case DEVID_K005289: return 2;
        case DEVID_MSM5205: return 1;
        case DEVID_MSM5232: return 11;  /* 8 voies + 4 sorties groupées, cf. MSM5232_NUM_OUTPUTS */
        case DEVID_BSMT2000:return 13;  /* 12 PCM + 1 ADPCM/compressé */
        case DEVID_ICS2115: return 32;
        case DEVID_K051649: return 5;
        case DEVID_K054539: return 8;
        case DEVID_C6280:   return 6;
        case DEVID_C140:    return 24;
        case DEVID_C219:    return 16;
        case DEVID_K053260: return 4;
        case DEVID_POKEY:   return 4;
        case DEVID_QSOUND:  return 19;
        case DEVID_SCSP:    return 32;
        case DEVID_WSWAN:   return 4;
        case DEVID_VBOY_VSU:return 6;
        case DEVID_SAA1099: return 6;
        case DEVID_ES5503:  return 32;
        case DEVID_X1_010:  return 16;
        case DEVID_C352:    return 32;
        case DEVID_GA20:    return 4;
        case DEVID_MIKEY:   return 4;
        default:            return 0;
    }
}

/* ── Per-file decoder state ─────────────────────────────────────────────── */

/* One visualised device: mute mapping voice-range → libvgm device channels. */
struct VgmChipSlot {
    uint32_t devId;      /* libvgm device id (SetDeviceMuting key) */
    uint8_t  type;       /* DEVID_* (special mute cases: YM2413 rhythm, 2612 DAC) */
    int      startVoice; /* first UI voice */
    int      count;      /* UI voices */
};

struct VgmDecoder {
    PlayerA      player;
    DATA_LOADER* loader;
    int16_t*     renderBuf;       /* scratch buffer for int16 stereo render */
    uint32_t     renderBufFrames; /* size of renderBuf in stereo frames */
    bool         ended;
    uint32_t     sampleRate;
    std::vector<VgmChipSlot> chips;
    int64_t      lastMuteMask;    /* applied generic_mute_mask snapshot */
};

static const uint32_t kSampleRate    = 44100;
static const uint32_t kBufSizeSample = 512;   /* SOUND_BUFFER_SIZE_SAMPLE */

/* ── Probe ──────────────────────────────────────────────────────────────── */

static const char* const kVgmExts[] = {
    "vgm", "vgz", "s98", "gym", "dro", "dr0", NULL
};

/* Magic bytes for quick probing */
static int vgm_probe(const char* ext, const uint8_t* hdr, size_t hdrLen) {
    /* Extension match: high confidence */
    if (ext) {
        for (int i = 0; kVgmExts[i]; i++) {
            if (strcmp(ext, kVgmExts[i]) == 0) return 90;
        }
    }
    /* Magic headers as fallback */
    if (hdrLen >= 4) {
        if (hdr[0]=='V' && hdr[1]=='g' && hdr[2]=='m' && hdr[3]==' ') return 100; /* VGM */
        if (hdr[0]=='S' && hdr[1]=='N' && hdr[2]=='E' && hdr[3]=='S') return 80;  /* SNES SPC not ours */
        if (hdr[0]=='D' && hdr[1]=='R' && hdr[2]=='O') return 90;                  /* DRO */
        if (hdr[0]=='G' && hdr[1]=='Y' && hdr[2]=='M' && hdr[3]=='X') return 90;  /* GYM */
    }
    return 0;
}

/* ── Helpers ────────────────────────────────────────────────────────────── */

/* Modizer's vgmGetVoiceDetailedVoiceName: per-voice labels for the chips
 * whose voices have distinct ROLES (FM/SSG/rhythm/ADPCM…). Returns 0 when a
 * chip has no detailed naming — the generic "Voice N" default applies.
 * Relies on vgm2610b being set for the current file (first setup pass). */
static int vgm_voice_detailed_name(uint8_t type, int ch, char* out, size_t len) {
    switch (type) {
        case DEVID_SN76496: snprintf(out, len, "PSG %d", ch + 1); return 1;
        case DEVID_YM2413:
        case DEVID_YM2612:  snprintf(out, len, "FM %d", ch + 1); return 1;
        case DEVID_YM2203:
            if (ch < 3) snprintf(out, len, "FM %d", ch + 1);
            else        snprintf(out, len, "SSG %d", ch - 3 + 1);
            return 1;
        case DEVID_YM2608:
            if (ch < 6)       snprintf(out, len, "FM %d", ch + 1);
            else if (ch < 12) snprintf(out, len, "Rhythm %d", ch - 6 + 1);
            else if (ch < 13) snprintf(out, len, "ADPCM");
            else              snprintf(out, len, "SSG %d", ch - 13 + 1);
            return 1;
        case DEVID_YM2610: {
            const int fm = vgm2610b ? 6 : 4;
            if (ch < fm)          snprintf(out, len, "FM %d", ch + 1);
            else if (ch < fm + 6) snprintf(out, len, "ADPCM-A %d", ch - fm + 1);
            else if (ch < fm + 7) snprintf(out, len, "ADPCM-B");
            else                  snprintf(out, len, "SSG %d", ch - fm - 7 + 1);
            return 1;
        }
        case DEVID_MSM6258:
        case DEVID_MSM6295: snprintf(out, len, "ADPCM %d", ch + 1); return 1;
        /* Puces ajoutées avec la montée libvgm du 2026-08-21. */
        case DEVID_K007232: snprintf(out, len, "PCM %d", ch + 1);   return 1;
        case DEVID_K005289: snprintf(out, len, "Wave %d", ch + 1);  return 1;
        case DEVID_MSM5205: snprintf(out, len, "ADPCM");            return 1;
        case DEVID_BSMT2000:
            if (ch < 12) snprintf(out, len, "PCM %d", ch + 1);
            else         snprintf(out, len, "ADPCM");
            return 1;
        case DEVID_ICS2115: snprintf(out, len, "Osc %d", ch + 1);   return 1;
        case DEVID_MSM5232:
            /* Les 11 sorties du MSM5232: 2 groupes de 4 pieds d'orgue, 2 solo,
             * 1 bruit — ce sont des SORTIES, pas les 8 oscillateurs. */
            switch (ch) {
                case 0: case 1: case 2: case 3:
                    snprintf(out, len, "Grp1 %d'", 2 << ch);       return 1;
                case 4: case 5: case 6: case 7:
                    snprintf(out, len, "Grp2 %d'", 2 << (ch - 4)); return 1;
                case 8:  snprintf(out, len, "Solo 8'");  return 1;
                case 9:  snprintf(out, len, "Solo 16'"); return 1;
                default: snprintf(out, len, "Noise");    return 1;
            }
        case DEVID_uPD7759:  snprintf(out, len, "ADPCM"); return 1;
        case DEVID_C140:
        case DEVID_C219:
        case DEVID_C352:
        case DEVID_GA20:
        case DEVID_SEGAPCM:
        case DEVID_RF5C68:
        case DEVID_K054539:
        case DEVID_K053260:
        case DEVID_QSOUND:
        case DEVID_SCSP:
        case DEVID_YMW258:
        case DEVID_YMZ280B: snprintf(out, len, "PCM %d", ch + 1); return 1;
        case DEVID_YM2151:
        case DEVID_YM3812:
        case DEVID_YM3526:
        case DEVID_YMF262:
        case DEVID_YMF271:  snprintf(out, len, "FM %d", ch + 1); return 1;
        case DEVID_Y8950:
            if (ch < 9) snprintf(out, len, "FM %d", ch + 1);
            else        snprintf(out, len, "ADPCM");
            return 1;
        case DEVID_YMF278B:
            if (ch < 24) snprintf(out, len, "Wave %d", ch + 1);
            else         snprintf(out, len, "FM %d", ch - 24 + 1);
            return 1;
        case DEVID_AY8910:
        case DEVID_POKEY:
        case DEVID_SAA1099:
        case DEVID_MIKEY:   snprintf(out, len, "PSG %d", ch + 1); return 1;
        case DEVID_K051649: snprintf(out, len, "SCC %d", ch + 1); return 1;
        case DEVID_ES5503:
        case DEVID_X1_010:  snprintf(out, len, "Wave %d", ch + 1); return 1;
        case DEVID_32X_PWM: snprintf(out, len, "PWM %s", ch == 0 ? "L" : "R"); return 1;
        case DEVID_GB_DMG: {
            static const char* const gb[4] =
                { "Pulse 1", "Pulse 2", "Wave", "Noise" };
            if (ch < 4) { snprintf(out, len, "%s", gb[ch]); return 1; }
            return 0;
        }
        case DEVID_NES_APU: {
            static const char* const nes[6] =
                { "Pulse 1", "Pulse 2", "Triangle", "Noise", "DPCM", "FDS" };
            if (ch < 6) { snprintf(out, len, "%s", nes[ch]); return 1; }
            return 0;
        }
        case DEVID_VBOY_VSU:
            if (ch < 5) snprintf(out, len, "Wave %d", ch + 1);
            else        snprintf(out, len, "Noise");
            return 1;
        case DEVID_C6280:
            /* channels 5-6 can switch to noise */
            if (ch < 4) snprintf(out, len, "Wave %d", ch + 1);
            else        snprintf(out, len, "Wave/Noise %d", ch + 1);
            return 1;
        case DEVID_WSWAN: {
            static const char* const ws[4] =
                { "Wave 1", "Wave 2/Voice", "Wave 3/Sweep", "Wave 4/Noise" };
            if (ch < 4) { snprintf(out, len, "%s", ws[ch]); return 1; }
            return 0;
        }
    }
    return 0;
}

/* Set up voice slot → device-ID mapping after the file is loaded. */
static void vgm_setup_channels(VgmDecoder* dec) {
    PlayerBase* plr = dec->player.GetPlayer();
    if (!plr) return;

    std::vector<PLR_DEV_INFO> devList;
    plr->GetSongDeviceInfo(devList);

    /* Reset flag-globals for this file */
    vgmVRC7   = 0;
    vgm2610b  = 0;
    vgmNesFds = 0;

    /* First pass: detect variant flags that affect voice count */
    for (auto& pdi : devList) {
        if (pdi.type == DEVID_YM2413 && pdi.devCfg && (pdi.devCfg->flags & 1))
            vgmVRC7  = 1;
        if (pdi.type == DEVID_YM2610 && pdi.devCfg && (pdi.devCfg->flags & 1))
            vgm2610b = 1;
        /* NES with FDS enabled → the NES chip needs its 6th (FDS) voice slot. */
        if (pdi.type == DEVID_NES_APU && pdi.devCfg && (pdi.devCfg->flags & 1))
            vgmNesFds = 1;
    }

    /* Second pass: assign channel slots */
    int totalChannels = 0;   /* all channels (including non-visualised) */
    int voiceChannels = 0;   /* only channels with oscilloscope data */

    for (auto& pdi : devList) {
        if (!vgm_voice_available(pdi.type)) continue;

        int nb = (int)vgm_voices_nb(pdi.type);
        if (nb <= 0) continue;
        if (voiceChannels + nb > SOUND_MAXVOICES_BUFFER_FX) break;

        /* The chip core uses m_voice_ChipID[slot] == m_voice_current_system
         * where m_voice_current_system = curDev (render-loop index = pdi.id). */
        m_voice_ChipID[voiceChannels] = (int)pdi.id;
        totalChannels += nb;
        voiceChannels += nb;
    }

    rewamp_channel_data_reset(voiceChannels);
    /* MUST be set, and set to what reset() just allocated: PlayerA's fadeout
     * patch (playera.cpp, YOYOFR block) scales the per-voice scope buffers by
     * looping over m_genNumVoicesChannels. Left unset, it kept the PREVIOUS
     * track's voice count — a 64-channel module followed by a 6-voice VGM meant
     * m_voice_buff[j] was NULL for j >= 6, and the first faded-out loop end
     * segfaulted the producer thread. */
    m_genNumVoicesChannels = voiceChannels;
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 4 * 2);

    /* Re-apply ChipID mapping after reset (reset zeros it), and register the
     * chip groups for the mute/grouping UI. NB: m_voice_ChipID carries the
     * libvgm DEVICE id (scope-write routing for the cores) — the UI chip
     * index is derived from the registered ranges, add_chip does not touch it. */
    rewamp_voices_meta_reset();
    dec->chips.clear();
    int slot = 0;
    for (auto& pdi : devList) {
        if (!vgm_voice_available(pdi.type)) continue;
        int nb = (int)vgm_voices_nb(pdi.type);
        if (nb <= 0 || slot + nb > SOUND_MAXVOICES_BUFFER_FX) break;
        m_voice_ChipID[slot] = (int)pdi.id;

        const char* nm = SndEmu_GetDevName(pdi.type, 0x01, pdi.devCfg);
        rewamp_voices_add_chip((nm && nm[0]) ? nm : "Chip", slot, nb);
        /* Detailed per-voice labels (FM/SSG/rhythm/ADPCM…), Modizer parity. */
        for (int i = 0; i < nb; i++) {
            char vn[32];
            if (vgm_voice_detailed_name((uint8_t)pdi.type, i, vn, sizeof vn))
                rewamp_voice_set_name(slot + i, vn);
        }
        dec->chips.push_back(
            { (uint32_t)pdi.id, (uint8_t)pdi.type, slot, nb });
        slot += nb;
    }

    /* Info panel: GD3 / S98 / GYM tags as key:value pairs. */
    {
        const char* const* tags = plr->GetTags();
        for (const char* const* t = tags; t && *t; t += 2) {
            if (t[1] && t[1][0])
                rewamp_track_message_append("%s: %s\n", t[0], t[1]);
        }
    }
}

/* ── External chip ROM requests (VGMPlayer::LoadOPL4ROM etc.) ─────────────
 *
 * Some VGM files use chips that need an external wavetable/sample ROM the
 * hardware would have had installed -- currently just the YMF278B/OPL4's
 * yrw801.rom (Yamaha's stock wavetable set, the de-facto standard file the
 * whole VGM community ships/expects, e.g. Modizer's own vgm_RequestFileCallback
 * in ModizMusicPlayer.mm). Without this callback wired up (it was previously
 * SetFileReqCallback(NULL, NULL) -- disabled), VGMPlayer::LoadOPL4ROM's
 * `if (_fileReqCbFunc == NULL) return;` guard silently no-ops: OPL4 VGM files
 * still play (FM channels are unaffected), just with silent/missing
 * PCM/wavetable voices, no error surfaced anywhere.
 *
 * Loaded once from <datadir>/vgm/yrw801.rom (bundled asset, copied at app
 * startup like the C64 kernal/basic/chargen ROMs) and cached for the process
 * lifetime -- MemoryLoader_Init only stores a reference to the buffer
 * (doesn't copy), so it must outlive every DATA_LOADER built from it. */
static uint8_t* s_yrw801_rom      = NULL;
static size_t   s_yrw801_rom_size = 0;
static bool     s_yrw801_tried    = false;

static DATA_LOADER* vgm_file_req_callback(void* userParam, PlayerBase* player, const char* fileName) {
    (void)userParam; (void)player;
    if (!fileName || strcmp(fileName, "yrw801.rom") != 0) return NULL;
    if (!s_yrw801_tried) {
        s_yrw801_tried = true;
        char rel[64];
        snprintf(rel, sizeof(rel), "vgm/%s", fileName);
        uint8_t* buf = NULL; size_t size = 0;
        if (rewamp_load_asset(rel, &buf, &size) && buf && size > 0) {
            s_yrw801_rom      = buf;
            s_yrw801_rom_size = size;
        }
    }
    if (!s_yrw801_rom) return NULL;
    DATA_LOADER* dl = MemoryLoader_Init(s_yrw801_rom, (UINT32)s_yrw801_rom_size);
    if (!dl) return NULL;
    if (DataLoader_Load(dl) != 0) { DataLoader_Deinit(dl); return NULL; }
    return dl;
}

/* ── Open ───────────────────────────────────────────────────────────────── */

static RewampDecoder* vgm_open(const char* path, RewampAudioFormat* outFmt) {
    VgmDecoder* dec = new VgmDecoder();
    dec->loader      = NULL;
    dec->renderBuf   = NULL;
    dec->ended       = false;
    dec->sampleRate  = kSampleRate;

    /* Register supported player engines */
    VGMPlayer* vgmEngine = new VGMPlayer;
    dec->player.RegisterPlayerEngine(vgmEngine);
    dec->player.RegisterPlayerEngine(new S98Player);
    dec->player.RegisterPlayerEngine(new DROPlayer);
    dec->player.RegisterPlayerEngine(new GYMPlayer);

    /* Serves yrw801.rom (OPL4/YMF278B wavetable ROM) on demand; declines
     * (returns NULL) any other filename, matching "not needed for this file"
     * behavior for every other chip. */
    dec->player.SetFileReqCallback(vgm_file_req_callback, NULL);
    dec->player.SetLogCallback(NULL, NULL);

    /* Configure output: 44100 Hz, stereo, 16-bit, 512-frame buffer */
    dec->player.SetOutputSettings(kSampleRate, 2, 16, kBufSizeSample);

    /* Load the file via FileLoader */
    dec->loader = FileLoader_Init(path);
    if (!dec->loader) { delete dec; return NULL; }

    DataLoader_Load(dec->loader);

    uint8_t loadRet = dec->player.LoadFile(dec->loader);
    if (loadRet >= 0x80) {
        DataLoader_Deinit(dec->loader);
        delete dec;
        return NULL;
    }

    /* Emulator-core selection (Settings → Moteurs → libvgm; Modizer's LIBVGM
     * family). Must land BEFORE Start() (devices are instantiated there).
     * Param value = index into each Modizer choice list; 0 = default core. */
    {
        struct { const char* key; UINT8 devId; UINT32 fcc[3]; int n; } sel[] = {
            { "ym2612_core",  DEVID_YM2612,  { FCC_GPGX, FCC_NUKE, FCC_GENS }, 3 },
            { "ymf262_core",  DEVID_YMF262,  { FCC_ADLE, FCC_MAME, FCC_NUKE }, 3 },
            { "ym3812_core",  DEVID_YM3812,  { FCC_ADLE, FCC_MAME, 0 },        2 },
            { "qsound_core",  DEVID_QSOUND,  { FCC_CTR_, FCC_MAME, 0 },        2 },
            { "rf5c68_core",  DEVID_RF5C68,  { FCC_MAME, FCC_GENS, 0 },        2 },
            /* Ajoutés avec la montée libvgm du 2026-08-21. ⚠️ L'ORDRE doit
             * suivre celui des libellés de settings_screen.dart: la valeur
             * stockée est un INDEX, pas un FourCC. */
            { "gb_core",      DEVID_GB_DMG,  { FCC_SBOY, FCC_MAME, 0 },        2 },
            { "ym2413_core",  DEVID_YM2413,  { FCC_EMU_, FCC_MAME, FCC_NUKE }, 3 },
            { "ym2151_core",  DEVID_YM2151,  { FCC_MAME, FCC_NUKE, 0 },        2 },
            { "ay8910_core",  DEVID_AY8910,  { FCC_EMU_, FCC_MAME, 0 },        2 },
            { "nes_core",     DEVID_NES_APU, { FCC_NSFP, FCC_MAME, 0 },        2 },
            { "sn76496_core", DEVID_SN76496, { FCC_MAME, FCC_MAXM, 0 },        2 },
            { "saa1099_core", DEVID_SAA1099, { FCC_VBEL, FCC_MAME, 0 },        2 },
            { "c6280_core",   DEVID_C6280,   { FCC_OOTK, FCC_MAME, 0 },        2 },
        };
        for (size_t i = 0; i < sizeof(sel) / sizeof(sel[0]); i++) {
            /* 0 = library/compile default; 1..n = explicit core (fcc[v-1]). */
            int v = (int)rewamp_get_engine_param("vgm", sel[i].key, 0);
            if (v <= 0 || v > sel[i].n) continue;
            PLR_DEV_OPTS devOpts;
            PlayerBase::InitDeviceOptions(devOpts);
            devOpts.emuCore[0] = sel[i].fcc[v - 1];
            vgmEngine->SetDeviceOptions(PLR_DEV_ID(sel[i].devId, 0), devOpts);
        }
    }

    /* Native forced-loop (Settings → Lecture): PlayerA::Config has full
     * native loop-count + fade-sample support (its PLREVT_LOOP handler auto-
     * calls FadeOut() once curLoop reaches loopCount) — read the globals
     * rewamp_audio.c populates from rewamp_set_forced_loop() and apply here,
     * BEFORE Start(): config is used by the player engine from the first
     * loop it processes, too late to change once playback has begun. Left
     * untouched (PlayerA's own default: loopCount=2, fadeSmpls=0 — 2 loops
     * then a hard stop) when force-loop is off, preserving existing
     * pre-this-feature VGM playback behavior exactly.
     * See vgm_configure_loop below for why this lives in open(), not there. */
    if (g_force_loop_mode != 0) {
        PlayerA::Config cfg = dec->player.GetConfiguration();
        // loopCount is libvgm's own "total loop passes then hard stop" (its
        // default 2 = play the loop section twice) — g_force_loop_count is
        // REPEATS after the first pass ("1 boucle" == 2 total passes), same
        // +1 needed here as vgmstream's loop_count.
        cfg.loopCount = (g_force_loop_mode == 2) ? 0 : (UINT32)(g_force_loop_count + 1);
        cfg.fadeSmpls = (g_force_loop_mode == 1 && g_force_fadeout_enabled &&
                         g_force_fadeout_seconds > 0.0)
            ? (UINT32)(g_force_fadeout_seconds * kSampleRate)
            : 0;
        dec->player.SetConfiguration(cfg);

        /* Sans point de boucle, loopCount ne s'accroche à RIEN: PLREVT_LOOP
         * n'est jamais levé, le fichier joue une fois et finit. Comme la
         * vtable annonce quand même la boucle native, le repli générique
         * restait désarmé et le réglage « boucles forcées » ne faisait
         * simplement rien — un échec silencieux. Même veto que vgmstream, qui
         * le fait déjà sur !fmt->loop_flag.
         *
         * GetLoopTicks() == 0 signifie « pas de boucle » chez les quatre
         * lecteurs (VGM/S98/GYM testent leur loopOfs; DRO rend 0 en dur, le
         * format n'ayant pas la notion — donc tout .dro passe au générique,
         * ce qui est exactement ce qu'on veut). */
        const PlayerBase* pb = dec->player.GetPlayer();
        if (pb != NULL && pb->GetLoopTicks() == 0) g_force_loop_native_veto = 1;
    }

    /* Start playback (initialises chip emulators, populates device list) */
    dec->player.Start();

    /* Set up per-channel oscilloscope ring buffers */
    vgm_setup_channels(dec);

    /* Allocate scratch render buffer: 512 frames × 2 ch × 2 bytes = 2048 bytes */
    dec->renderBufFrames = kBufSizeSample;
    dec->renderBuf = (int16_t*)malloc(dec->renderBufFrames * 2 * sizeof(int16_t));
    if (!dec->renderBuf) {
        DataLoader_Deinit(dec->loader);
        delete dec;
        return NULL;
    }

    outFmt->sampleRate = (uint32_t)kSampleRate;
    outFmt->channels   = 2;
    return (RewampDecoder*)dec;
}

/* ── Read ───────────────────────────────────────────────────────────────── */

/* Apply generic_mute_mask to every visualised device via SetDeviceMuting.
 * Special cases (Modizer parity):
 *  - YM2413/VRC7 rhythm: visual ch 6/7/8 also drive the rhythm slots
 *    (BD=bit9, HH+SD=bits10+13, TOM+CYM=bits11+12).
 *  - YM2612: visual ch 5 also drives the DAC (bit 6).
 *  - YM2203/YM2608/YM2610: the SSG/AY part is a LINKED device in libvgm —
 *    its mute bits live in chnMute[1], not in the high bits of chnMute[0]
 *    (last 3 visual voices: from ch 3 on the 2203, ch 13 on the 2608/2610).
 *  - YM2610 (non-B): 4 FM voices map to slots 1,2,4,5 and ADPCM starts at
 *    bit 6, so visual ADPCM/delta channels shift up by 2.
 *  - YMF262: visual ch 6/7/8 also drive the OPL3 rhythm slots (bits 18+).
 *  - YMF278B: PCM 0-23 in chnMute[0]; the OPL3 part is a LINKED device →
 *    visual ch 24-41 land in chnMute[1], rhythm slots included.           */

/* OPL3 rhythm slots ride visual ch 6/7/8: BD=+0, SD=+1, TOM=+2, CYM=+3,
 * HH=+4, all offset by the 18 melodic channels. */
static uint32_t vgm_opl3_rhythm(uint32_t m) {
    if (m & (1u << 6)) m |= 1u << (18 + 0);                      /* BD       */
    if (m & (1u << 7)) m |= (1u << (18 + 4)) | (1u << (18 + 1)); /* HH + SD  */
    if (m & (1u << 8)) m |= (1u << (18 + 2)) | (1u << (18 + 3)); /* TOM + CYM */
    return m;
}

static void vgm_apply_mute(VgmDecoder* dec) {
    PlayerBase* plr = dec->player.GetPlayer();
    if (!plr) return;
    for (const auto& c : dec->chips) {
        PLR_MUTE_OPTS mo;
        if (plr->GetDeviceMuting(c.devId, mo) & 0x80) continue;
        uint32_t m0 = 0, m1 = 0;
        for (int i = 0; i < c.count && i < 32; i++) {
            if (!((generic_mute_mask >> (c.startVoice + i)) & 1)) continue;
            int ch = i;
            if (c.type == DEVID_YM2203) {
                if (ch < 3) m0 |= 1u << ch;               /* FM 1-3      */
                else        m1 |= 1u << (ch - 3);         /* SSG (linked) */
            } else if (c.type == DEVID_YM2608) {
                if (ch < 13) m0 |= 1u << ch;              /* FM+rhythm+ADPCM */
                else         m1 |= 1u << (ch - 13);       /* SSG (linked) */
            } else if (c.type == DEVID_YM2610) {
                if (!vgm2610b) {
                    /* 2610: 4 FM in slots 1,2,4,5; ADPCM starts at bit 6 */
                    static const int fmMap[4] = {1, 2, 4, 5};
                    ch = (ch < 4) ? fmMap[ch] : ch + 2;
                }
                if (ch < 13) m0 |= 1u << ch;              /* FM+ADPCM+delta */
                else         m1 |= 1u << (ch - 13);       /* SSG (linked) */
            } else if (c.type == DEVID_YMF278B) {
                if (ch < 24) m0 |= 1u << ch;              /* PCM          */
                else         m1 |= 1u << (ch - 24);       /* OPL3 (linked) */
            } else {
                m0 |= 1u << ch;
            }
        }
        if (c.type == DEVID_YMF262) {
            m0 = vgm_opl3_rhythm(m0);
        } else if (c.type == DEVID_YMF278B) {
            m1 = vgm_opl3_rhythm(m1);
        }
        if (c.type == DEVID_YM2413) {
            /* melodic 0-8 map 1:1; rhythm mode reuses ch 6-8 visually */
            if (m0 & (1u << 6)) m0 |= 1u << 9;              /* BD          */
            if (m0 & (1u << 7)) m0 |= (1u << 10) | (1u << 13); /* HH + SD  */
            if (m0 & (1u << 8)) m0 |= (1u << 11) | (1u << 12); /* TOM + CYM */
        } else if (c.type == DEVID_YM2612) {
            if (m0 & (1u << 5)) m0 |= 1u << 6;              /* DAC follows FM6 */
        }
        mo.chnMute[0] = m0;
        mo.chnMute[1] = m1;
        plr->SetDeviceMuting(c.devId, mo);
    }
}

static uint64_t vgm_read(RewampDecoder* rdec, float* out, uint64_t frameCount) {
    VgmDecoder* dec = (VgmDecoder*)rdec;

    /* Apply voice-mute changes from the UI. */
    if (dec->lastMuteMask != generic_mute_mask) {
        dec->lastMuteMask = generic_mute_mask;
        vgm_apply_mute(dec);
    }
    if (dec->ended) return 0;

    uint64_t framesRendered = 0;

    while (framesRendered < frameCount) {
        uint64_t remaining  = frameCount - framesRendered;
        uint32_t chunk = (uint32_t)(remaining < dec->renderBufFrames
                                    ? remaining : dec->renderBufFrames);

        uint32_t bytes = dec->player.Render(chunk * 2 * sizeof(int16_t),
                                            dec->renderBuf);
        uint32_t framesGot = bytes / (2 * sizeof(int16_t));

        /* Convert int16 stereo → float32 stereo */
        const int16_t* src = dec->renderBuf;
        float*         dst = out + framesRendered * 2;
        for (uint32_t i = 0; i < framesGot * 2; i++) {
            dst[i] = src[i] * (1.0f / 32768.0f);
        }
        framesRendered += framesGot;

        /* Detect end of file */
        if (dec->player.GetState() & PLAYSTATE_FIN) {
            dec->ended = true;
            break;
        }
        if (framesGot < chunk) {
            /* PlayerA returned less than requested — treat as end */
            dec->ended = true;
            break;
        }
    }

    return framesRendered;
}

/* ── Seek ───────────────────────────────────────────────────────────────── */

static void vgm_seek(RewampDecoder* rdec, uint64_t frameIndex) {
    VgmDecoder* dec = (VgmDecoder*)rdec;
    dec->ended = false;
    dec->player.Seek(PLAYPOS_SAMPLE, (uint32_t)frameIndex);
}

/* ── Length ─────────────────────────────────────────────────────────────── */

static uint64_t vgm_length(RewampDecoder* rdec) {
    VgmDecoder* dec = (VgmDecoder*)rdec;
    /* PLAYTIME_LOOP_INCL: include one loop iteration. Add WITH_FADE too once
     * a forced-loop fade is actually configured (vgm_open) so the reported
     * duration matches what will really play, fade included. */
    UINT8 flags = PLAYTIME_LOOP_INCL;
    if (g_force_loop_mode == 1 && g_force_fadeout_enabled) flags |= PLAYTIME_WITH_FADE;
    double totalSecs = dec->player.GetTotalTime(flags);
    if (totalSecs <= 0.0) return 0;
    return (uint64_t)(totalSecs * kSampleRate + 0.5);
}

/* configure_loop is called AFTER open() (see rewamp_plugin.h's doc comment)
 * — too late for PlayerA::SetConfiguration, which must run before Start().
 * The real work already happened in vgm_open() above by reading the
 * g_force_loop_* globals directly; this only exists so the vtable field is
 * non-NULL (rewamp_has_native_loop_support). */
static void vgm_configure_loop(RewampDecoder* rdec, int mode, int count) {
    (void)rdec; (void)mode; (void)count;
}

/* ── Close ──────────────────────────────────────────────────────────────── */

static void vgm_close(RewampDecoder* rdec) {
    VgmDecoder* dec = (VgmDecoder*)rdec;
    dec->player.Stop();
    dec->player.UnloadFile();
    if (dec->loader) {
        DataLoader_Deinit(dec->loader);
        dec->loader = NULL;
    }
    if (dec->renderBuf) {
        free(dec->renderBuf);
        dec->renderBuf = NULL;
    }
    rewamp_channel_data_reset(0);
    delete dec;
}

/* ── VTable ─────────────────────────────────────────────────────────────── */

static const RewampPluginVTable kVgmPlugin = {
    /* name                   */ "libvgm",
    /* probe                  */ vgm_probe,
    /* open                   */ vgm_open,
    /* read                   */ vgm_read,
    /* seek                   */ vgm_seek,
    /* length                 */ vgm_length,
    /* close                  */ vgm_close,
    /* configure_loop         */ vgm_configure_loop,
    /* supportsNativeFadeout  */ 1,
};

extern "C" const RewampPluginVTable* rewamp_vgm_plugin(void) {
    return &kVgmPlugin;
}

/*
 * NOTE: libvgm's source files are NOT unity-built here.  Every libvgm .c and
 * .cpp is compiled as its own translation unit by the build system (podspec
 * prepare_command / CMakeLists), exactly like Modizer's libvgm.xcodeproj:
 *   - .c  sources are C99 and must be compiled as C (implicit fn-ptr→void*
 *     conversions, narrowing initializers are invalid in C++)
 *   - .cpp player sources define file-static helpers with identical names
 *     across files (ReadLE16/ReadLE32 in vgmplayer_cmdhandler.cpp,
 *     SaveDeviceConfig in s98player.cpp + gymplayer.cpp), so they cannot be
 *     merged into one TU either.
 * This file (rewamp_plugin_vgm.cpp) is itself one such TU, holding only the
 * RewampPluginVTable glue.
 */

#endif /* REWAMP_WITH_VGM */

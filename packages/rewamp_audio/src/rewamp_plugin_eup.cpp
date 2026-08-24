// EUP plugin — FM Towns EUPHONY music (.eup, with its .fmb FM-bank and .pmb
// PCM-bank siblings) via the vendored eupmini (third_party/eupmini: the eupmini
// EUPHONY sequencer + Nuked-OPN2 (YM2612) FM + the FM Towns PCM emulator).
//
// The whole load path — parsing the 2 KB EUPHEAD, mapping tracks to channels,
// loading the .fmb/.pmb instrument banks, seeding the default FM patch — lived
// in Modizer's ModizMusicPlayer.mm (EUPPlayer_readFile), NOT in the library, so
// it is ported here. The .fmb/.pmb names come from the header (8-char fields at
// 0x6E2/0x6EA) and are looked up next to the .eup — exactly where the server's
// aux_files download puts them (like MDX's .pdx).
//
// Output model (push→pull, like gsf/mdx): the emulator renders into a global
// `eup_pcm` ring (its own pcm_struct, from audioout.hpp) as a side effect of
// player->nextTick(); read() calls nextTick() until enough samples are queued,
// then drains read_pos→write_pos. nextTick's buffer length is a tempo-derived
// sequencer step (deterministic — no wall-clock), so this is reproducible.
//
// Voice layout: FM 0-5 (YM2612), PCM 6-13 (FM Towns PCM) = 14 voices. Per-voice
// scope/notes/mute already live in the vendored cores (grep YOYOFR in
// mame/fmopn.c and eupmini/eupplayer_townsEmulator.cpp); the mute global was
// renamed eup_mutemask→generic_mute_mask in the vendored source (organya
// precedent), so the cores gate the real mix directly and the plugin wires no
// mute. Ring mask SOUND_BUFFER_SIZE_SAMPLE*2*4 = 4096.
//
// Process-global singleton (eup_pcm + the Nuked-OPN2 state) — fine, rewamp
// never runs two decoders concurrently.
#ifdef REWAMP_WITH_EUP

#include "rewamp_plugin.h"
#include "rewamp_loaded_files.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <string>

#include "../third_party/eupmini/eupmini/eupplayer.hpp"
#include "../third_party/eupmini/eupmini/eupplayer_townsEmulator.hpp"
#include "../third_party/eupmini/eupmini/audioout.hpp"   // pcm_struct + stream* consts

#define EUP_RATE   44100
#define EUP_VOICES 14   // FM 0-5, PCM 6-13

// The audio ring the emulator writes into — a Modizer-era global the vendored
// cores reference by name (eupplayer_townsEmulator.cpp's render loop). This is
// the audio SINK, not a mute/config global, so it stays here (the plugin owns
// the output buffer), unlike eup_mutemask which was folded into
// generic_mute_mask in the vendored source.
struct pcm_struct eup_pcm;

// ── ported EUPHEAD (the 2 KB .eup header; offsets verified against the spec) ──
typedef struct {
    char    title[32];              // 0x000
    char    artist[8];              // 0x020
    char    dummy[44];              // 0x028
    char    trk_name[32][16];       // 0x084
    char    short_trk_name[32][8];  // 0x254
    char    trk_mute[32];           // 0x354
    char    trk_port[32];           // 0x374
    char    trk_midi_ch[32];        // 0x394
    char    trk_key_bias[32];       // 0x3B4
    char    trk_transpose[32];      // 0x3D4
    char    trk_play_filter[32][7]; // 0x3F4
    char    instruments_name[128][4]; // 0x4D4
    char    fm_midi_ch[6];          // 0x6D4
    char    pcm_midi_ch[8];         // 0x6DA
    char    fm_file_name[8];        // 0x6E2
    char    pcm_file_name[8];       // 0x6EA
    char    reserved[260];          // 0x6F2
    char    appli_name[8];          // 0x7F6
    char    appli_version[2];       // 0x7FE
    int32_t size;                   // 0x800
    char    signature;              // 0x804
    char    first_tempo;            // 0x805
} EUPHEAD;

struct RewampDecoder {
    EUPPlayer*         player;
    EUP_TownsEmulator* dev;
    uint8_t*           eupBuf;     // whole file, kept alive: startPlaying points into it
    uint64_t           totalFrames;
    uint64_t           framePos;
    char               path[4096];
};

static const char* const kEupExts[] = { "eup", NULL };

static int eup_probe(const char* ext, const uint8_t* h, size_t n) {
    (void)h; (void)n;
    return rewamp_ext_in_list(ext, kEupExts) ? 90 : 0;
}

// Try "<dir>/<name>" in the given, lower- and upper-cased spellings (the banks
// on modland can be either case). Returns an open FILE* or NULL.
static FILE* eup_open_sibling(const std::string& dir, const std::string& name) {
    std::string variants[3] = { name, name, name };
    for (char& c : variants[1]) c = (char)tolower((unsigned char)c);
    for (char& c : variants[2]) c = (char)toupper((unsigned char)c);
    for (int i = 0; i < 3; i++) {
        std::string full = dir + variants[i];
        FILE* f = fopen(full.c_str(), "rb");
        if (f) {
            // Pour le panneau ⓘ: les banques .fmb/.pmb sont des fichiers à
            // part, et c'est ici qu'on connaît enfin leur orthographe réelle
            // (modland les publie dans les deux casses).
            rewamp_loaded_files_add(full.c_str());
            return f;
        }
        if (i > 0 && variants[i] == variants[0]) break;  // name was already caseless
    }
    return NULL;
}

// Ported from ModizMusicPlayer.mm's EUPPlayer_readFile: parse the header, wire
// tracks/devices, load the .fmb/.pmb banks, and return the whole-file buffer
// (which startPlaying indexes into, so the caller must keep it alive). NULL on
// any failure. The default FM patch and the bank byte layout are the reference
// glue's, verbatim.
static uint8_t* eup_read_file(EUPPlayer* player, EUP_TownsEmulator* device,
                              const char* path, EUPHEAD* outHeader) {
    player->stopPlaying();

    FILE* f = fopen(path, "rb");
    if (!f) { fprintf(stderr, "[eup] open: cannot fopen %s\n", path); return NULL; }
    fseek(f, 0, SEEK_END);
    long fsize = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (fsize < 2048 + 6 + 6) {
        fprintf(stderr, "[eup] open: %s too short (%ld bytes)\n", path, fsize);
        fclose(f); return NULL;
    }

    EUPHEAD hdr;
    if (fread(&hdr, 1, sizeof(EUPHEAD), f) != sizeof(EUPHEAD)) {
        fprintf(stderr, "[eup] open: %s header read failed\n", path);
        fclose(f); return NULL;
    }

    player->tempo((hdr.first_tempo + 30) & 0xFF);
    for (int trk = 0; trk < 32; trk++)
        player->mapTrack_toChannel(trk, hdr.trk_midi_ch[trk]);
    for (int n = 0; n < 6; n++)
        device->assignFmDeviceToChannel(hdr.fm_midi_ch[n], n);
    for (int n = 0; n < 8; n++)
        device->assignPcmDeviceToChannel(hdr.pcm_midi_ch[n]);

    uint8_t* buf = (uint8_t*)malloc((size_t)fsize);
    if (!buf) { fclose(f); return NULL; }
    fseek(f, 0, SEEK_SET);
    if (fread(buf, 1, (size_t)fsize, f) != (size_t)fsize) { fclose(f); free(buf); return NULL; }
    fclose(f);

    // Default FM instrument (the reference glue's fixed patch) for all 128 slots
    // — overwritten below by the .fmb bank if one is present.
    {
        uint8_t instrument[] = {
            ' ',' ',' ',' ',' ',' ',' ',' ',
            17,33,10,17,  25,10,57,0,  154,152,218,216,  15,12,7,12,
            0,5,3,5,  38,40,70,40,  20,  0xc0,
            0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        };
        for (int n = 0; n < 128; n++) device->setFmInstrumentParameter(n, instrument);
    }

    std::string dir(path);
    size_t slash = dir.rfind('/');
    dir = (slash == std::string::npos) ? std::string("") : dir.substr(0, slash + 1);

    // FMB — 48-byte FM patches after an 8-byte header. A MISSING bank is NOT
    // fatal (unlike Modizer's reference glue, which returned NULL): the default
    // patch above already fills all 128 slots, so the tune plays FM-only. This
    // matters because the banks are downloaded as aux_files siblings and can be
    // absent on the first play attempt (download race) — failing hard there
    // makes the player auto-skip the track for good instead of retrying.
    {
        char fn0[9]; memcpy(fn0, hdr.fm_file_name, 8); fn0[8] = '\0';
        std::string fn(std::string(fn0) + ".fmb");
        if (fn != ".fmb") {
            FILE* bf = eup_open_sibling(dir, fn);
            if (bf) {
                fseek(bf, 0, SEEK_END); long bs = ftell(bf); fseek(bf, 0, SEEK_SET);
                uint8_t* bank = (uint8_t*)malloc(bs > 0 ? (size_t)bs : 1);
                if (bank && bs > 0 && fread(bank, 1, (size_t)bs, bf) == (size_t)bs) {
                    for (int n = 0; n < (bs - 8) / 48; n++)
                        device->setFmInstrumentParameter(n, bank + 8 + 48 * n);
                }
                free(bank); fclose(bf);
            }
        }
    }
    // PMB — the whole bank handed to the PCM device as-is. Also non-fatal when
    // missing (the PCM voices simply stay silent — same download-race reason).
    {
        char fn0[9]; memcpy(fn0, hdr.pcm_file_name, 8); fn0[8] = '\0';
        std::string fn(std::string(fn0) + ".pmb");
        if (fn != ".pmb") {
            FILE* bf = eup_open_sibling(dir, fn);
            if (bf) {
                fseek(bf, 0, SEEK_END); long bs = ftell(bf); fseek(bf, 0, SEEK_SET);
                uint8_t* bank = (uint8_t*)malloc(bs > 0 ? (size_t)bs : 1);
                if (bank && bs > 0 && fread(bank, 1, (size_t)bs, bf) == (size_t)bs)
                    device->setPcmInstrumentParameters(bank, (size_t)bs);
                free(bank); fclose(bf);
            }
        }
    }

    if (outHeader) memcpy(outHeader, &hdr, sizeof(EUPHEAD));
    return buf;
}

// Drive the sequencer until the eup_pcm ring holds at least `wantSamples`
// int16 samples (or playback ends). Returns available samples.
static int eup_fill(EUPPlayer* player, int wantSamples) {
    for (;;) {
        int avail = (eup_pcm.read_pos <= eup_pcm.write_pos)
            ? eup_pcm.write_pos - eup_pcm.read_pos
            : streamAudioBufferSamples - eup_pcm.read_pos + eup_pcm.write_pos;
        if (avail >= wantSamples || !player->isPlaying()) return avail;
        player->nextTick();   // renders a tempo-step's worth into eup_pcm
    }
}

// Build a fresh player+device and (re)load the file into it. `outHeader` is
// optional. On success dec->eupBuf is non-NULL and the player is ready for
// startPlaying(); on failure dec->eupBuf is NULL and player/dev are torn down.
static void eup_setup_and_load(RewampDecoder* dec, EUPHEAD* outHeader) {
    memset(&eup_pcm, 0, sizeof(eup_pcm));
    eup_pcm.on = 1;
    dec->dev    = new EUP_TownsEmulator();
    dec->player = new EUPPlayer();
    dec->dev->rate(EUP_RATE);
    dec->player->outputDevice(dec->dev);
    dec->eupBuf = eup_read_file(dec->player, dec->dev, dec->path, outHeader);
    if (!dec->eupBuf) {
        delete dec->player; delete dec->dev;
        dec->player = NULL; dec->dev = NULL;
    }
}

static RewampDecoder* eup_open(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) return NULL;
    snprintf(dec->path, sizeof(dec->path), "%s", path);
    char* q = strrchr(dec->path, '?');
    if (q) *q = '\0';

    rewamp_channel_data_reset(EUP_VOICES);
    rewamp_channel_data_set_ring_write_size(SOUND_BUFFER_SIZE_SAMPLE * 2 * 4);
    rewamp_channel_data_set_ring_circular(1);

    EUPHEAD hdr;
    eup_setup_and_load(dec, &hdr);
    if (!dec->eupBuf) {
        fprintf(stderr, "[eup] open FAILED for %s (load/bank error)\n", dec->path);
        free(dec); return NULL;
    }

    m_genNumVoicesChannels = EUP_VOICES;
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("YM2612 FM", 0, 6);
    rewamp_voices_add_chip("FM Towns PCM", 6, 8);

    // The player data begins 2048 (header) + 6 bytes in — the reference glue's
    // startPlaying offset.
    dec->player->startPlaying(dec->eupBuf + 2048 + 6);

    // Measure length by ticking silently to the end (nextTick(true) advances the
    // sequencer without rendering audio; write_pos still accumulates the frames
    // that WOULD be produced). Cap at 30 min like the reference.
    uint64_t samples = 0;
    if (dec->player->isPlaying()) {
        while (dec->player->isPlaying()) {
            dec->player->nextTick(true);
            samples += (uint64_t)(eup_pcm.write_pos / 2);   // int16 → stereo frames
            eup_pcm.write_pos = 0;
            if (samples > (uint64_t)EUP_RATE * 60 * 30) break;
        }
    }
    dec->player->stopPlaying();
    if (samples > 0 && samples <= (uint64_t)EUP_RATE * 60 * 30) dec->totalFrames = samples;

    // Restart cleanly for playback from 0 (the length pass consumed the tune).
    delete dec->player; delete dec->dev; free(dec->eupBuf);
    eup_setup_and_load(dec, NULL);
    if (!dec->eupBuf) { free(dec); return NULL; }
    dec->player->startPlaying(dec->eupBuf + 2048 + 6);
    dec->framePos = 0;

    // Title/artist are Shift-JIS.
    char t[33] = {0}; memcpy(t, hdr.title, 32);
    if (t[0]) { char u[256]; rewamp_sjis_to_utf8(t, u, sizeof(u)); rewamp_track_message_append("Title: %s\n", u); }
    char a[9] = {0}; memcpy(a, hdr.artist, 8);
    if (a[0]) { char u[64]; rewamp_sjis_to_utf8(a, u, sizeof(u)); rewamp_track_message_append("Artist: %s\n", u); }
    rewamp_track_message_append("Format: EUP (FM Towns EUPHONY), YM2612 + PCM, %d Hz, stereo\n", EUP_RATE);
    if (dec->totalFrames > 0) {
        unsigned total = (unsigned)(dec->totalFrames / EUP_RATE);
        rewamp_track_message_append("Duration: %u:%02u\n", total / 60, total % 60);
    }

    if (outFormat) { outFormat->channels = 2; outFormat->sampleRate = EUP_RATE; }
    return dec;
}

static uint64_t eup_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || frameCount == 0) return 0;
    if (dec->totalFrames > 0) {
        if (dec->framePos >= dec->totalFrames) return 0;
        uint64_t remain = dec->totalFrames - dec->framePos;
        if (frameCount > remain) frameCount = remain;
    }

    const int16_t* ring = (const int16_t*)eup_pcm.buffer;
    const float scale = 1.0f / 32768.0f;
    uint64_t written = 0;
    while (written < frameCount) {
        int want = (int)((frameCount - written) * 2);   // int16 samples
        int avail = eup_fill(dec->player, want);
        if (avail <= 0) break;                           // playback ended
        int take = (avail < want) ? avail : want;
        take &= ~1;                                      // whole stereo frames
        if (take <= 0) break;
        float* dst = out + written * 2;
        for (int i = 0; i < take; i++) {
            dst[i] = ring[eup_pcm.read_pos++] * scale;
            if (eup_pcm.read_pos >= streamAudioBufferSamples) eup_pcm.read_pos = 0;
        }
        written    += take / 2;
        dec->framePos += take / 2;
    }
    return written;
}

// No native seek: rebuild the player (cheap — the file buffer + banks stay) and
// discard-render forward. Same idiom as UADE/vio2sf/PMD/MDX/FMP.
static void eup_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (!dec) return;
    if (frameIndex < dec->framePos) {
        delete dec->player; delete dec->dev; free(dec->eupBuf);
        eup_setup_and_load(dec, NULL);
        if (!dec->eupBuf) return;
        dec->player->startPlaying(dec->eupBuf + 2048 + 6);
        dec->framePos = 0;
    }
    while (dec->framePos < frameIndex && dec->player->isPlaying()) {
        int want = (int)((frameIndex - dec->framePos) * 2);
        if (want > streamAudioBufferSamples / 2) want = streamAudioBufferSamples / 2;
        int avail = eup_fill(dec->player, want);
        if (avail <= 0) break;
        int take = (avail < want ? avail : want) & ~1;
        if (take <= 0) break;
        eup_pcm.read_pos = (eup_pcm.read_pos + take) % streamAudioBufferSamples;
        dec->framePos += take / 2;
    }
}

static uint64_t eup_length(RewampDecoder* dec) {
    return dec ? dec->totalFrames : 0;
}

static void eup_close(RewampDecoder* dec) {
    if (!dec) return;
    if (dec->player) dec->player->stopPlaying();
    delete dec->player;
    delete dec->dev;
    free(dec->eupBuf);
    free(dec);
}

static const RewampPluginVTable kEupVTable = {
    "eup",
    eup_probe,
    eup_open,
    eup_read,
    eup_seek,
    eup_length,
    eup_close,
};

extern "C" const RewampPluginVTable* rewamp_eup_plugin(void) { return &kEupVTable; }

#endif /* REWAMP_WITH_EUP */

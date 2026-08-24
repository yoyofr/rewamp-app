// Furnace plugin — chiptune tracker engine (DivEngine) via the Modizer-authored
// FurnacePlayer wrapper. Handles .fur and the formats Furnace imports (.dmf/.dmp/…).
// Compiled only when REWAMP_WITH_FURNACE is defined.
#ifdef REWAMP_WITH_FURNACE

#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"   // m_voice_buff / m_voice_current_ptr / vgm_last_*
#include "ModizerConstants.h"    // SOUND_BUFFER_SIZE_SAMPLE, SOUND_MAXVOICES_BUFFER_FX

#include "FurnacePlayer.h"   // third_party/furnace/src/modizer (added to include path)

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>   // strcasecmp

// Furnace output is always stereo; pick a fixed device rate (miniaudio resamples).
static const int FURNACE_RATE = 44100;

// Per-voice oscilloscope ring size — matches rewamp_channel_data's default
// g_ring_write_size (RING_BUF_SAMPLES) so our writes line up with ring_read.
static const int FURNACE_RING = SOUND_BUFFER_SIZE_SAMPLE * 4 * 4;

struct RewampDecoder {
    FurnacePlayer* player;
    double         rate;
    int            subsong;
    int            voiceCount;  // furnace channels (capped to SOUND_MAXVOICES_BUFFER_FX)
    int16_t*       pcm;         // scratch int16 stereo buffer
    int            pcmFrames;
    int64_t        lastMuteMask; // applied generic_mute_mask snapshot
    // Pattern view (cached at open — constant per subsong).
    int            patOrders;   // getOrderCount()
    int            patRows;     // subsong patLen (same for every order)
    int            patChannels; // total channel count (NOT capped like voiceCount)
    int*           patEffRows;  // per-order EFFECTIVE rows (cut by 0B/0D/FF jumps)
};

// Furnace native ".fur" + the FamiTracker family it imports (.ftm and the
// 0CC/Dn/E-FamiTracker variants). NOT plain ".dmf": that extension is shared with
// X-Tracker (libopenmpt) — instead we claim DefleMask .dmf by its unambiguous
// header magic below, so real DefleMask files go to Furnace while X-Tracker .dmf
// (no magic match, ext not listed → score 0) stays with libopenmpt.
static const char* const kFurnaceExts[] = { "fur", "ftm", "0cc", "dnm", "eft", NULL };

static int furnace_probe(const char* ext, const uint8_t* hdr, size_t hdrSize) {
    // Header magics are decisive (uncompressed files; compressed ones rely on ext).
    if (hdr) {
        if (hdrSize >= 16 && memcmp(hdr, "-Furnace module-", 16) == 0) return 95;
        if (hdrSize >= 18 && memcmp(hdr, "FamiTracker Module", 18) == 0) return 95;
        if (hdrSize >= 21 && memcmp(hdr, "Dn-FamiTracker Module", 21) == 0) return 95;
        if (hdrSize >= 16 && memcmp(hdr, ".DelekDefleMask.", 16) == 0) return 95;
    }
    return (ext && rewamp_ext_in_list(ext, kFurnaceExts)) ? 70 : 0;
}

static RewampDecoder* furnace_open(const char* path, RewampAudioFormat* outFormat) {
    if (!path) return NULL;

    // Strip optional ?subsong=N suffix; keep the real path for fopen.
    char clean[4096];
    int subsong = 0;
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    char* q = strrchr(clean, '?');
    if (q && strncmp(q, "?subsong=", 9) == 0) { subsong = atoi(q + 9); *q = '\0'; }

    // Read the whole file into memory (FurnacePlayer::load takes a buffer).
    FILE* f = fopen(clean, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (len <= 0) { fclose(f); return NULL; }
    uint8_t* data = (uint8_t*)malloc((size_t)len);
    if (!data) { fclose(f); return NULL; }
    size_t got = fread(data, 1, (size_t)len, f);
    fclose(f);
    if (got != (size_t)len) { free(data); return NULL; }

    FurnacePlayer* player = new FurnacePlayer();
    if (!player->init(FURNACE_RATE) || !player->load(data, (size_t)len, clean)) {
        free(data);
        delete player;
        return NULL;
    }
    free(data);

    if (subsong > 0) player->selectSong(subsong);

    FurnaceSongInfo info = player->getInfo();
    int voices = info.channels;
    if (voices < 1) voices = 2;
    if (voices > SOUND_MAXVOICES_BUFFER_FX) voices = SOUND_MAXVOICES_BUFFER_FX;
    // Per-channel oscilloscope buffers must exist before the first render.
    rewamp_channel_data_reset(voices);

    // Voice metadata for the mute/grouping UI (after reset — it wipes the
    // tables): one group per Furnace system slot, channel names from the
    // engine (e.g. "FM 1", "PSG 2").
    rewamp_voices_meta_reset();
    const int sysCount = player->getSystemCount();
    if (sysCount > 0) {
        for (int s = 0; s < sysCount; s++) {
            FurnaceSystemInfo si = player->getSystemInfo(s);
            if (si.channelCount <= 0 || si.firstChannel < 0 ||
                si.firstChannel >= voices)
                continue;
            int cnt = si.channelCount;
            if (si.firstChannel + cnt > voices) cnt = voices - si.firstChannel;
            rewamp_voices_add_chip(
                (si.name && si.name[0]) ? si.name : "Chip",
                si.firstChannel, cnt);
        }
    } else {
        rewamp_voices_add_chip("Furnace", 0, voices);
    }
    for (int i = 0; i < voices; i++) {
        const char* cn = player->getChannelShortName(i);
        if (cn && cn[0]) rewamp_voice_set_name(i, cn);
    }

    // Info panel: Furnace song metadata.
    if (!info.title.empty())
        rewamp_track_message_append("Title: %s\n", info.title.c_str());
    if (!info.author.empty())
        rewamp_track_message_append("Author: %s\n", info.author.c_str());
    if (!info.systemName.empty())
        rewamp_track_message_append("System: %s\n", info.systemName.c_str());
    if (info.subsongCount > 1) {
        rewamp_track_message_append("Subsongs: %d\n", info.subsongCount);
        if (!info.subsongName.empty())
            rewamp_track_message_append("Subsong: %s\n",
                                        info.subsongName.c_str());
    }
    rewamp_track_message_append("Channels: %d\n", info.channels);
    if (!info.comment.empty())
        rewamp_track_message_append("\n%s\n", info.comment.c_str());

    player->setPlaying(true);

    RewampDecoder* dec = (RewampDecoder*)calloc(1, sizeof(*dec));
    if (!dec) { delete player; return NULL; }
    dec->player     = player;
    dec->rate       = FURNACE_RATE;
    dec->subsong    = subsong;
    dec->voiceCount = voices;
    dec->pcm        = NULL;
    dec->pcmFrames  = 0;

    // Pattern-view geometry. Nominally every order is patLen rows, but a jump
    // effect (0Dxx break-to-next, 0Bxx jump-to-order, FFxx stop) cuts the order
    // short — the cursor leaves at that row and the tail never plays. The
    // pattern timeline must use the EFFECTIVE length, otherwise the view shows
    // the dead tail instead of the (dimmed) next pattern and the scroll leaps
    // when the cursor jumps (user-visible bug on break-heavy .fur files).
    dec->patOrders = player->getOrderCount();
    if (dec->patOrders > 0) {
        dec->patEffRows = (int*)malloc((size_t)dec->patOrders * sizeof(int));
        if (!dec->patEffRows) dec->patOrders = 0;
    }
    for (int o = 0; o < dec->patOrders; o++) {
        int rows = 0, chans = 0;
        FurnacePatternNote* buf = player->getOrderPattern(o, &rows, &chans);
        if (!buf) { dec->patOrders = o; break; }   /* keep what we scanned */
        if (o == 0) { dec->patRows = rows; dec->patChannels = chans; }
        int eff = rows;
        for (int r = 0; r < rows && eff == rows; r++)
            for (int c = 0; c < chans && eff == rows; c++) {
                const FurnacePatternNote* n = &buf[r * chans + c];
                for (int e = 0; e < 4; e++) {
                    int fx = n->fx[e];
                    if (fx == 0x0B || fx == 0x0D || fx == 0xFF) { eff = r + 1; break; }
                }
            }
        dec->patEffRows[o] = eff;
        delete[] buf;
    }
    if (dec->patOrders > 0 && dec->patChannels <= 0) dec->patOrders = 0;

    outFormat->channels   = 2;
    outFormat->sampleRate = (uint32_t)FURNACE_RATE;
    return dec;
}

// Feed the per-voice oscilloscope ring + note state from Furnace's introspection
// API, mirroring Modizer. The datasource then drives rewamp_notes_capture /
// rewamp_channel_data_capture_delayed off these globals (same as the libvgm cores
// do inline). Called once per render with the just-produced frame count.
static void furnace_capture_voices(RewampDecoder* dec, int frames) {
    FurnacePlayer* pl = dec->player;
    const int nv = dec->voiceCount;

    // Furnace osc buffers run at a fixed 65536 Hz; map that window onto our frames.
    const float oscPerFrame = (float)FurnaceOscData::OSC_RATE / (float)FURNACE_RATE;
    const int   oscWindow   = (int)(frames * oscPerFrame) + 2;

    for (int j = 0; j < nv; j++) {
        signed char* buf = m_voice_buff[j];
        if (!buf) continue;
        const int64_t base = m_voice_current_ptr[j] >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT;

        FurnaceOscData osc = pl->getOscData(j);
        if (osc.valid && osc.data) {
            short lastValid = 0;
            const unsigned short baseIdx = (unsigned short)(osc.readPos - oscWindow);
            for (int i = 0; i < frames; i++) {
                int slotStart = (int)(i       * oscPerFrame);
                int slotEnd   = (int)((i + 1) * oscPerFrame);
                if (slotEnd == slotStart) slotEnd = slotStart + 1;
                // Average the valid osc slots covering this display frame
                // (-1 is Furnace's "no sample" sentinel).
                int sum = 0, count = 0;
                for (int s = slotStart; s < slotEnd; s++) {
                    short v = osc.data[(unsigned short)(baseIdx + s)];
                    if (v != -1) { sum += v; count++; }
                }
                short sample;
                if (count > 0) {
                    sample = (short)(sum / count);
                    lastValid = sample;
                } else {
                    sample = -1;
                    for (int d = slotEnd; d < slotEnd + 3 && sample == -1; d++) {
                        short v = osc.data[(unsigned short)(baseIdx + d)];
                        if (v != -1) sample = v;
                    }
                    if (sample == -1) sample = lastValid; else lastValid = sample;
                }
                buf[(int)(((base + i) % FURNACE_RING + FURNACE_RING) % FURNACE_RING)] =
                    (signed char)(sample >> 8);
            }
        } else {
            for (int i = 0; i < frames; i++)
                buf[(int)(((base + i) % FURNACE_RING + FURNACE_RING) % FURNACE_RING)] = 0;
        }
        m_voice_current_ptr[j] += (int64_t)frames << MODIZER_OSCILLO_OFFSET_FIXEDPOINT;
    }

    // Note state (Hz / volume / instrument) → rewamp_notes_capture reads these.
    // Clear on silence so released notes don't linger as ghost notes.
    for (int j = 0; j < nv; j++) {
        FurnaceChannelLiveState st = pl->getChannelLiveState(j);
        if (st.active && st.note >= 0 && st.volume > 0) {
            vgm_last_note[j]  = (unsigned int)st.freqHz;
            vgm_last_vol[j]   = (unsigned int)st.volume;
            vgm_last_instr[j] = (unsigned char)(st.instrument > 0 ? st.instrument : 0);
        } else {
            vgm_last_note[j] = 0;
            vgm_last_vol[j]  = 0;
        }
    }
}

static uint64_t furnace_read(RewampDecoder* dec, float* out, uint64_t frameCount) {
    if (!dec || !dec->player || !out || frameCount == 0) return 0;
    if (dec->player->isEndOfSong()) return 0;

    // Apply voice-mute changes from the UI (Modizer: furPlayer->setMute).
    if (dec->lastMuteMask != generic_mute_mask) {
        dec->lastMuteMask = generic_mute_mask;
        for (int ch = 0; ch < dec->voiceCount && ch < 64; ch++)
            dec->player->setMute(ch, ((generic_mute_mask >> ch) & 1) != 0);
    }

    if ((int)frameCount > dec->pcmFrames) {
        free(dec->pcm);
        dec->pcm = (int16_t*)malloc(frameCount * 2 * sizeof(int16_t));
        dec->pcmFrames = (int)frameCount;
    }
    if (!dec->pcm) return 0;

    dec->player->render(dec->pcm, (int)frameCount);

    furnace_capture_voices(dec, (int)frameCount);

    const int samples = (int)(frameCount * 2);
    const float inv = 1.0f / 32768.0f;
    for (int i = 0; i < samples; i++) out[i] = dec->pcm[i] * inv;
    return frameCount;
}

static void furnace_seek(RewampDecoder* dec, uint64_t frameIndex) {
    if (dec && dec->player) dec->player->seek((double)frameIndex / dec->rate);
}

static uint64_t furnace_length(RewampDecoder* dec) {
    if (!dec || !dec->player) return 0;
    double secs = dec->player->getTotalDuration();
    if (secs <= 0) return 0;
    return (uint64_t)(secs * dec->rate);
}

static void furnace_close(RewampDecoder* dec) {
    if (!dec) return;
    if (dec->player) { dec->player->stop(); dec->player->close(); delete dec->player; }
    free(dec->patEffRows);
    free(dec->pcm);
    free(dec);
}

// ── Tracker-pattern view ─────────────────────────────────────────────────────
// Furnace's order list maps a pattern PER CHANNEL (ord[c][order]), so there is
// no song-global "pattern index": the viewable unit IS the order. We expose
// pattern == order (identity mapping) and convert lazily per fetch — the GL
// renderer only asks for the handful of orders in its window, and the calls
// arrive under decodeLock (rewamp_audio.c) so they never race the engine.

static int furnace_pattern_song_info(RewampDecoder* dec, RewampPatternSongInfo* out) {
    if (!dec || !out || !dec->player || dec->patOrders <= 0 ||
        dec->patChannels <= 0)
        return 0;
    out->num_channels = dec->patChannels;
    out->num_orders   = dec->patOrders;
    out->num_patterns = dec->patOrders;   /* identity: pattern == order */
    out->max_fx_cols  = 4;                /* FurnacePatternNote fx[4] */
    return 1;
}

static int furnace_pattern_order(RewampDecoder* dec, int order) {
    if (!dec || order < 0 || order >= dec->patOrders) return -1;
    return order;
}

static int furnace_pattern_num_rows(RewampDecoder* dec, int pattern) {
    if (!dec || pattern < 0 || pattern >= dec->patOrders) return 0;
    /* EFFECTIVE rows (cut at the first jump effect) — what actually plays. */
    return dec->patEffRows ? dec->patEffRows[pattern] : dec->patRows;
}

static int furnace_pattern_get(RewampDecoder* dec, int pattern,
                               RewampPatternCell* out, int maxCells) {
    if (!dec || !out || !dec->player || pattern < 0 || pattern >= dec->patOrders)
        return 0;
    int rows = 0, chans = 0;
    FurnacePatternNote* src = dec->player->getOrderPattern(pattern, &rows, &chans);
    if (!src) return 0;
    int n = rows * chans;
    if (n > maxCells) n = maxCells;
    static const char* H = "0123456789ABCDEF";
    for (int i = 0; i < n; i++) {
        const FurnacePatternNote* s = &src[i];
        RewampPatternCell* c = &out[i];
        memset(c, 0, sizeof(*c));
        // Furnace pattern notes share our semitone origin (playback.cpp:
        // note = patNote - 60, calcBaseFreq → pattern 57 = A-4 = generic 57).
        if      (s->note == 253) c->note = REWAMP_NOTE_OFF;
        else if (s->note == 254) c->note = REWAMP_NOTE_FADE;   /* release */
        else if (s->note >= 0 && s->note <= 179) c->note = s->note;
        else c->note = REWAMP_NOTE_EMPTY;
        c->instrument = (s->instrument >= 0) ? s->instrument : -1;
        c->volume     = (s->volume     >= 0) ? s->volume     : -1;
        int nfx = 0;
        for (int e = 0; e < 4; e++) {
            if (s->fx[e] < 0) continue;
            /* Furnace displays the effect code as 2 hex digits. */
            c->fx[nfx][0]  = H[(s->fx[e] >> 4) & 15];
            c->fx[nfx][1]  = H[s->fx[e] & 15];
            c->fxval[nfx]  = (s->fxVal[e] >= 0) ? s->fxVal[e] : -1;
            nfx++;
        }
        c->num_fx = (uint8_t)nfx;
        for (int e = nfx; e < REWAMP_PATTERN_MAX_FX; e++) c->fxval[e] = -1;
    }
    delete[] src;
    return n;
}

static void furnace_pattern_cursor(RewampDecoder* dec, int* order, int* row) {
    /* Producer thread, under decodeLock, right after read() — reflects the
     * just-decoded position (consumer sync happens in the cursor store). */
    if (order) *order = (dec && dec->player) ? dec->player->getCurrentOrder() : -1;
    if (row)   *row   = (dec && dec->player) ? dec->player->getCurrentRow()   : -1;
}

static const RewampPluginVTable kFurnaceVTable = {
    "furnace",
    furnace_probe,
    furnace_open,
    furnace_read,
    furnace_seek,
    furnace_length,
    furnace_close,
    NULL,                    /* configure_loop */
    0,                       /* supportsNativeFadeout */
    NULL,                    /* engine_id */
    NULL,                    /* param_changed */
    furnace_pattern_song_info,  /* pattern view */
    furnace_pattern_order,
    furnace_pattern_num_rows,
    furnace_pattern_get,
    furnace_pattern_cursor,
};

extern "C" const RewampPluginVTable* rewamp_furnace_plugin(void) { return &kFurnaceVTable; }

#endif /* REWAMP_WITH_FURNACE */

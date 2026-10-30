/* libADLMIDI plugin — MIDI (and DMX MUS, XMI, HMI/HMP, GMF) rendered on an
 * emulated Yamaha OPL3 (YMF262): the Sound Blaster / AdLib sound of DOS games.
 *
 * libADLMIDI v1.6.2.1 (Wohlstand, GPL-3.0-or-later core; chip cores LGPL-2.1+
 * / BSD-3 / public domain, sequencer and WOPL reader MIT) — vendored verbatim
 * under third_party/libadlmidi. Every TU of the LIBRARY is compiled with
 * third_party/libadlmidi/rewamp/adlmidi_rename.h injected first (cmake
 * `-include`, Apple wrappers): it prefixes every top-level name the library
 * defines, because AdPlug (Nuked OPL3: OPL3_*), Furnace (esfmu: ESFM_*) and
 * pmdmini (namespace ymfm) define the same ones and the linker would merge
 * them in silence. THIS file includes only the public C API (adl_*), which
 * keeps its names. Regenerate the header on every resync:
 * scripts/gen_fm_midi_rename.py.
 *
 * Banks: the 79 embedded banks (greyzone included — the author's decision,
 * 2026-10-29), chosen by index (engine param "adlmidi"/"bank").
 *
 * Voices: one per MIDI channel the FILE uses (notes, mute, oscilloscope). The
 * used channels are found by scanning the file with tml for SMF/RMI (the
 * raw-event hook does NOT fire during adl_positionSeek — measured), all 16
 * otherwise. The oscilloscope comes from a patch of the library
 * (rewamp/adlmidi_scope.h, sites marked "REWAMP SCOPE"): the emulator hands
 * its 18 channel outputs per output frame, and the sequencer says which MIDI
 * channel each chip channel last played a note for — a release tail stays
 * with its channel until another channel takes it. Nuked OPL3 (1.8, 1.7.4)
 * and DOSBox expose their channels; the other emulators give notes only.
 *
 * Loop: native for infinite (adl_setLoopEnabled + count -1; the whole song
 * loops when the file has no loop markers), safe to arm live (measured: armed
 * after 1 s, played 2 × the length + 5 s without ending). N passes go through
 * the generic Dart loop (veto), like the PSF family.
 */
#ifdef REWAMP_WITH_ADLMIDI

#include "rewamp_plugin.h"
#include "rewamp_registry.h"
#include "rewamp_channel_data.h"
#include "rewamp_audio.h"            /* extern "C" exports — FFI linkage rule */
#include "ModizerVoicesData.h"
#include "ModizerConstants.h"

#include "adlmidi.h"
#include "../third_party/libadlmidi/rewamp/adlmidi_scope.h"
#include "tml.h"                     /* implementation lives in rewamp_tml.c */

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <new>
#include <strings.h>

extern "C" int g_force_loop_mode;
extern "C" int g_force_loop_native_veto;

#define ADL_RATE      44100
#define ADL_CHANNELS  16
#define ADL_BATCH     2048           /* frames per adl_playFormat call */
#define ADL_DRUM_CH   9
#define ADL_DRUM_INSTR_BASE 129      /* same instrument index space as FluidLite */
#define ADL_SCOPE_CHIPS 16           /* = the « chips » setting's maximum */
#define ADL_CHIP_CHANNELS 23         /* libADLMIDI NUM_OF_CHANNELS (18 + 5 rhythm) */
#define ADL_RING_SIZE (SOUND_BUFFER_SIZE_SAMPLE * 4 * 2)   /* power of 2 */
#define ADL_FP        MODIZER_OSCILLO_OFFSET_FIXEDPOINT

namespace {

/* ⚠️ Not `struct RewampDecoder`: it owns nothing non-trivial today, but the
 * rule (CLAUDE.md, ODR) is to keep every plugin's state in its own type. */
struct AdlDec {
    ADL_MIDIPlayer* dev = nullptr;
    double          gain = 2.0;
    int64_t         muteApplied = 0;
    int             chan2voice[ADL_CHANNELS];
    int             voiceCount = 0;
    uint8_t         prog[ADL_CHANNELS];
    int             noteCount[ADL_CHANNELS];
};

ADLMIDI_AudioFormat kF32 = { ADLMIDI_SampleType_F32, 4, 8 };

/* Oscilloscope state. One decoder plays at a time (the producer opens the
 * next track only after closing this one), and every hook runs on the
 * producer thread, inside adl_playFormat. */
int8_t  g_scope_owner[ADL_SCOPE_CHIPS][REWAMP_ADL_SCOPE_CHANNELS]; /* MIDI ch */
int     g_scope_chan2voice[ADL_CHANNELS];
int     g_scope_pos[ADL_SCOPE_CHIPS];   /* frames of this batch, per chip */
int32_t g_scope_acc[ADL_CHANNELS][ADL_BATCH];

void scope_reset_owners() {
    memset(g_scope_owner, -1, sizeof(g_scope_owner));
}

}  // namespace

extern "C" {
int rewamp_adl_scope_on = 0;

/* A chip renders a whole run of frames before the next chip renders the
 * same run, so each chip keeps its own position in the batch. */
void rewamp_adl_scope_frame(uint32_t chip, const int32_t* ch) {
    if (chip >= ADL_SCOPE_CHIPS) return;
    const int pos = g_scope_pos[chip]++;
    if (pos >= ADL_BATCH) return;
    const int8_t* own = g_scope_owner[chip];
    for (int i = 0; i < REWAMP_ADL_SCOPE_CHANNELS; i++) {
        if (own[i] < 0 || ch[i] == 0) continue;
        const int v = g_scope_chan2voice[(int)own[i]];
        if (v >= 0) g_scope_acc[v][pos] += ch[i];
    }
}

/* Rhythm-mode channels (18..22) sound through register channels 6, 7, 8. */
void rewamp_adl_scope_owner(size_t chipChan, size_t midCh) {
    static const int8_t kRhythmReg[5] = { 6, 7, 8, 8, 7 };
    const size_t chip = chipChan / ADL_CHIP_CHANNELS;
    const size_t cc   = chipChan % ADL_CHIP_CHANNELS;
    if (chip >= ADL_SCOPE_CHIPS || midCh >= ADL_CHANNELS) return;
    const int reg = cc < REWAMP_ADL_SCOPE_CHANNELS ? (int)cc : kRhythmReg[cc - REWAMP_ADL_SCOPE_CHANNELS];
    g_scope_owner[chip][reg] = (int8_t)midCh;
}
}  // extern "C"

namespace {

double param(const char* key, double def) {
    return rewamp_get_engine_param("adlmidi", key, def);
}

/* Settings read at open (bank, emulator, chips, 4-op, volume model need a
 * fresh synth) — plus the live ones, re-applied by adl_param_changed. */
void apply_live(AdlDec* d) {
    d->gain = param("gain", 2.0);
    adl_setSoftPanEnabled(d->dev, param("soft_pan", 1) != 0);
    adl_setHVibrato(d->dev, (int)param("deep_vibrato", -1));
    adl_setHTremolo(d->dev, (int)param("deep_tremolo", -1));
    adl_setAutoArpeggio(d->dev, param("auto_arpeggio", 0) != 0);
}

void apply_open(AdlDec* d) {
    int emu = (int)param("emulator", ADLMIDI_EMU_NUKED);
    if (emu < 0 || emu >= ADLMIDI_EMU_end || adl_switchEmulator(d->dev, emu) < 0)
        adl_switchEmulator(d->dev, ADLMIDI_EMU_DOSBOX);   /* compiled everywhere */
    int chips = (int)param("chips", 4);
    if (chips < 1) chips = 1;
    if (chips > 16) chips = 16;
    adl_setNumChips(d->dev, chips);
    int bank = (int)param("bank", 0);
    if (bank < 0 || bank >= adl_getBanksCount()) bank = 0;
    adl_setBank(d->dev, bank);
    adl_setNumFourOpsChn(d->dev, (int)param("four_op", -1));   /* -1 = auto */
    adl_setVolumeRangeModel(d->dev, (int)param("volume_model", ADLMIDI_VolumeModel_AUTO));
    adl_setScaleModulators(d->dev, param("scale_modulators", 0) != 0);
    adl_setFullRangeBrightness(d->dev, param("full_brightness", 0) != 0);
    apply_live(d);
}

/* Notes and programs per MIDI channel for the visualisers — the raw-event
 * hook sees every standard MIDI event the sequencer dispatches (producer
 * thread, same as read()). */
void on_event(void* ud, ADL_UInt8 type, ADL_UInt8 /*subtype*/, ADL_UInt8 ch,
              const ADL_UInt8* data, size_t len) {
    AdlDec* d = static_cast<AdlDec*>(ud);
    if (ch >= ADL_CHANNELS) return;
    const int v = d->chan2voice[ch];
    switch (type) {
        case 0x0C:                                   /* program change */
            if (len >= 1) d->prog[ch] = data[0] & 0x7F;
            break;
        case 0x09:                                   /* note on */
            if (v < 0 || len < 2) break;
            if (data[1] > 0) {
                d->noteCount[v]++;
                vgm_last_note[v] = (unsigned int)
                    (440.0 * pow(2.0, (data[0] - 69) / 12.0) + 0.5);
                vgm_last_vol[v]   = data[1];
                vgm_last_instr[v] = ch == ADL_DRUM_CH
                    ? ADL_DRUM_INSTR_BASE + d->prog[ch]
                    : d->prog[ch] + 1u;
                break;
            }
            /* velocity 0 = note off */
            /* fall through */
        case 0x08:                                   /* note off */
            if (v < 0) break;
            if (--d->noteCount[v] <= 0) {
                d->noteCount[v] = 0;
                vgm_last_note[v] = 0;
                vgm_last_vol[v]  = 0;
            }
            break;
        case 0x0B:                                   /* all sound / notes off */
            if (v >= 0 && len >= 1 && (data[0] == 120 || data[0] == 123)) {
                d->noteCount[v] = 0;
                vgm_last_note[v] = 0;
                vgm_last_vol[v]  = 0;
            }
            break;
        default:
            break;
    }
}

void silence_notes(AdlDec* d) {
    for (int v = 0; v < ADL_CHANNELS; v++) {
        d->noteCount[v] = 0;
        vgm_last_note[v] = 0;
        vgm_last_vol[v]  = 0;
    }
}

/* Which MIDI channels the file plays, for an SMF/RMI (tml reads both). */
int scan_channels(const char* path, int used[ADL_CHANNELS]) {
    tml_message* ev = tml_load_filename(path);
    if (!ev) return 0;
    int any = 0;
    for (tml_message* m = ev; m; m = m->next)
        if (m->type == TML_NOTE_ON && m->velocity > 0 && m->channel < ADL_CHANNELS) {
            used[m->channel] = 1;
            any = 1;
        }
    tml_free(ev);
    return any;
}

enum Kind { K_NONE, K_SMF, K_RMI, K_XMI, K_MUS, K_HMI, K_HMP, K_GMF };

Kind kind_of(const uint8_t* h, size_t n) {
    if (n >= 4 && memcmp(h, "MThd", 4) == 0) return K_SMF;
    if (n >= 12 && memcmp(h, "RIFF", 4) == 0 && memcmp(h + 8, "RMID", 4) == 0) return K_RMI;
    if (n >= 12 && memcmp(h, "FORM", 4) == 0 && memcmp(h + 8, "XDIR", 4) == 0) return K_XMI;
    if (n >= 4 && memcmp(h, "MUS\x1A", 4) == 0) return K_MUS;
    if (n >= 18 && memcmp(h, "HMI-MIDISONG061595", 18) == 0) return K_HMI;
    if (n >= 8 && memcmp(h, "HMIMIDIP", 8) == 0) return K_HMP;
    if (n >= 4 && memcmp(h, "GMF\x01", 4) == 0) return K_GMF;
    return K_NONE;
}

const char* kind_name(Kind k) {
    switch (k) {
        case K_SMF: return "Standard MIDI";
        case K_RMI: return "RIFF MIDI (RMI)";
        case K_XMI: return "Miles Sound System XMIDI (XMI)";
        case K_MUS: return "DMX MUS (id Software)";
        case K_HMI: return "HMI (Human Machine Interfaces)";
        case K_HMP: return "HMP (Human Machine Interfaces)";
        case K_GMF: return "GMF";
        default:    return "MIDI";
    }
}

const char* const kMidiExts[]  = { "mid", "midi", "kar", "rmi", nullptr };
const char* const kOwnExts[]   = { "xmi", "hmi", "hmp", "gmf", nullptr };

/* Strip a ?subsong=N suffix; return N (-1 if absent). */
int split_subsong(const char* path, char* clean, size_t cap) {
    strncpy(clean, path, cap - 1);
    clean[cap - 1] = '\0';
    char* q = strchr(clean, '?');
    int sub = -1;
    if (q) {
        const char* s = strstr(q, "subsong=");
        if (s) sub = atoi(s + 8);
        *q = '\0';
    }
    return sub;
}

int adl_probe(const char* ext, const uint8_t* hdr, size_t n) {
    const Kind k = kind_of(hdr, n);
    const bool midiExt = rewamp_ext_in_list(ext, kMidiExts);
    const bool ownExt  = rewamp_ext_in_list(ext, kOwnExts);
    switch (k) {
        /* Below FluidLite's 100 on a plain MIDI: « Synthé MIDI: auto » keeps
         * the SoundFont, « OPL3 » pins this plugin. */
        case K_SMF:
        case K_RMI: return midiExt ? 95 : 90;
        /* Formats no other plugin plays: ours, confirmed by the header. A
         * `.mus` without the DMX magic is someone else's (SID, KSS…). */
        case K_XMI: case K_MUS: case K_HMI: case K_HMP: case K_GMF:
            return 100;
        default:
            return ownExt ? 40 : (midiExt ? 30 : 0);
    }
}

/* Batch → voice rings, one ring sample per output frame. A channel peaks
 * near ±8000 (four slots of a 13-bit operator); several chip channels of one
 * MIDI channel add up, hence the clamp. */
void scope_flush(AdlDec* d, int frames) {
    const int mask = ADL_RING_SIZE - 1;
    for (int v = 0; v < d->voiceCount; v++) {
        if (!m_voice_buff[v]) continue;
        const int64_t base = m_voice_current_ptr[v] >> ADL_FP;
        const int32_t* a = g_scope_acc[v];
        for (int k = 0; k < frames; k++) {
            int32_t s8 = a[k] >> 5;
            if (s8 > 127) s8 = 127;
            if (s8 < -128) s8 = -128;
            m_voice_buff[v][(base + k) & mask] = (signed char)s8;
        }
        m_voice_current_ptr[v] += (int64_t)frames << ADL_FP;
    }
}

void adl_close_fn(RewampDecoder* rd);

RewampDecoder* adl_open_fn(const char* path, RewampAudioFormat* outFormat) {
    /* N passes: no native count here — veto, the generic Dart loop counts
     * (same as the PSF family). Infinite is native (configure_loop). */
    if (g_force_loop_mode == 1) g_force_loop_native_veto = 1;

    char clean[4096];
    const int sub = split_subsong(path, clean, sizeof(clean));

    uint8_t hdr[32] = {0};
    size_t hn = 0;
    if (FILE* f = fopen(clean, "rb")) {
        hn = fread(hdr, 1, sizeof(hdr), f);
        fclose(f);
    }
    const Kind kind = kind_of(hdr, hn);

    AdlDec* d = new (std::nothrow) AdlDec();
    if (!d) return nullptr;
    d->dev = adl_init(ADL_RATE);
    if (!d->dev) { delete d; return nullptr; }
    apply_open(d);
    adl_setRawEventHook(d->dev, on_event, d);
    if (sub >= 0) adl_selectSongNum(d->dev, sub);
    if (adl_openFile(d->dev, clean) < 0) {
        adl_close_fn(reinterpret_cast<RewampDecoder*>(d));
        return nullptr;
    }

    /* Voices: the channels the file uses (SMF/RMI), else all 16. */
    int used[ADL_CHANNELS] = {0};
    const bool scanned = (kind == K_SMF || kind == K_RMI) && scan_channels(clean, used);
    for (int c = 0; c < ADL_CHANNELS; c++) {
        d->chan2voice[c] = (!scanned || used[c]) ? d->voiceCount++ : -1;
        d->prog[c] = 0;
    }
    rewamp_channel_data_reset(d->voiceCount);
    rewamp_channel_data_set_ring_write_size(ADL_RING_SIZE);
    for (int c = 0; c < ADL_CHANNELS; c++) g_scope_chan2voice[c] = d->chan2voice[c];
    scope_reset_owners();
    rewamp_adl_scope_on = 1;
    silence_notes(d);
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("OPL3", 0, d->voiceCount);
    for (int c = 0; c < ADL_CHANNELS; c++) {
        if (d->chan2voice[c] < 0) continue;
        char nm[MODIZ_VOICE_NAME_MAX_CHAR];
        if (c == ADL_DRUM_CH) snprintf(nm, sizeof(nm), "Drums");
        else                  snprintf(nm, sizeof(nm), "Ch %d", c + 1);
        rewamp_voice_set_name(d->chan2voice[c], nm);
    }

    const double total = adl_totalTimeLength(d->dev);
    const char* title = adl_metaMusicTitle(d->dev);
    const char* copy  = adl_metaMusicCopyright(d->dev);
    if (title && title[0]) rewamp_track_tag_set(title, nullptr, nullptr);
    rewamp_track_message_append("Format: %s\n", kind_name(kind));
    if (title && title[0]) rewamp_track_message_append("Title: %s\n", title);
    if (copy && copy[0])   rewamp_track_message_append("Copyright: %s\n", copy);
    const int songs = adl_getSongsCount(d->dev);
    if (songs > 1) rewamp_track_message_append("Songs: %d\n", songs);
    {
        const int bank = (int)param("bank", 0);
        const char* const* names = adl_getBankNames();
        if (names && bank >= 0 && bank < adl_getBanksCount())
            rewamp_track_message_append("Bank: %s\n", names[bank]);
    }
    rewamp_track_message_append("Synth: Yamaha OPL3 — %s, %d chip(s)\n",
                                adl_chipEmulatorName(d->dev),
                                adl_getNumChipsObtained(d->dev));
    if (total > 0)
        rewamp_track_message_append("Duration: %u:%02u\n",
                                    (unsigned)total / 60, (unsigned)total % 60);
    {
        const double ls = adl_loopStartTime(d->dev), le = adl_loopEndTime(d->dev);
        if (ls >= 0 && le > ls)
            rewamp_track_message_append_loop(ls, le - ls, -1, -1);
    }

    if (outFormat) {
        outFormat->channels   = 2;
        outFormat->sampleRate = ADL_RATE;
    }
    return reinterpret_cast<RewampDecoder*>(d);
}

uint64_t adl_read_fn(RewampDecoder* rd, float* out, uint64_t frameCount) {
    AdlDec* d = reinterpret_cast<AdlDec*>(rd);
    if (!d || !d->dev) return 0;
    /* Mute: one MIDI channel per voice, pushed when the mask moves. */
    if (d->muteApplied != generic_mute_mask) {
        for (int c = 0; c < ADL_CHANNELS; c++) {
            const int v = d->chan2voice[c];
            if (v >= 0) adl_setChannelEnabled(d->dev, (size_t)c,
                                              ((generic_mute_mask >> v) & 1) == 0);
        }
        d->muteApplied = generic_mute_mask;
    }
    uint64_t done = 0;
    while (done < frameCount) {
        uint64_t want = frameCount - done;
        if (want > ADL_BATCH) want = ADL_BATCH;
        float* dst = out + done * 2;
        for (int v = 0; v < d->voiceCount; v++)
            memset(g_scope_acc[v], 0, sizeof(int32_t) * (size_t)want);
        memset(g_scope_pos, 0, sizeof(g_scope_pos));
        const int got = adl_playFormat(d->dev, (int)(want * 2),
                                       reinterpret_cast<ADL_UInt8*>(dst),
                                       reinterpret_cast<ADL_UInt8*>(dst + 1), &kF32);
        if (got <= 0) break;
        const uint64_t frames = (uint64_t)got / 2;
        scope_flush(d, (int)frames);
        const float g = (float)d->gain;
        for (uint64_t i = 0; i < frames * 2; i++) dst[i] *= g;
        done += frames;
        if (frames < want) break;
    }
    /* A long silent intro is not an end while events remain. */
    if (!adl_atEnd(d->dev)) rewamp_decoder_activity();
    return done;
}

void adl_seek_fn(RewampDecoder* rd, uint64_t frameIndex) {
    AdlDec* d = reinterpret_cast<AdlDec*>(rd);
    if (!d || !d->dev) return;
    adl_positionSeek(d->dev, (double)frameIndex / ADL_RATE);
    silence_notes(d);   /* the visualisers follow the sound */
    scope_reset_owners();
}

uint64_t adl_length_fn(RewampDecoder* rd) {
    AdlDec* d = reinterpret_cast<AdlDec*>(rd);
    if (!d || !d->dev) return 0;
    const double t = adl_totalTimeLength(d->dev);
    return t > 0 ? (uint64_t)(t * ADL_RATE + 0.5) : 0;
}

void adl_close_fn(RewampDecoder* rd) {
    AdlDec* d = reinterpret_cast<AdlDec*>(rd);
    if (!d) return;
    rewamp_adl_scope_on = 0;
    if (d->dev) adl_close(d->dev);
    delete d;
}

/* Mode 2 = native infinite, also replayed live by
 * rewamp_lift_end_for_infinite (the flag is read at the song's end). */
void adl_configure_loop_fn(RewampDecoder* rd, int mode, int /*count*/) {
    AdlDec* d = reinterpret_cast<AdlDec*>(rd);
    if (!d || !d->dev || mode != 2) return;
    adl_setLoopEnabled(d->dev, 1);
    adl_setLoopCount(d->dev, -1);
}

void adl_param_changed_fn(RewampDecoder* rd, const char* /*key*/) {
    AdlDec* d = reinterpret_cast<AdlDec*>(rd);
    if (d && d->dev) apply_live(d);
}

/* Native speed: the sequencer's tempo multiplier (pitch unchanged). */
int adl_set_speed_fn(RewampDecoder* rd, double speed) {
    AdlDec* d = reinterpret_cast<AdlDec*>(rd);
    if (!d || !d->dev || speed < 0.2 || speed > 3.0) return 0;
    adl_setTempo(d->dev, speed);
    return 1;
}

const RewampPluginVTable kAdlVTable = {
    "adlmidi",
    adl_probe,
    adl_open_fn,
    adl_read_fn,
    adl_seek_fn,
    adl_length_fn,
    adl_close_fn,
    adl_configure_loop_fn,
    0,                    /* supportsNativeFadeout */
    "adlmidi",            /* engine_id */
    adl_param_changed_fn, /* live settings */
    nullptr, nullptr, nullptr, nullptr, nullptr, /* pattern view */
    nullptr,              /* probe_path */
    0,                    /* noPrefixProbe */
    adl_set_speed_fn,     /* vitesse native (tempo du séquenceur) */
};

}  // namespace

extern "C" const RewampPluginVTable* rewamp_adlmidi_plugin(void) { return &kAdlVTable; }

/* Sub-songs of a multi-song XMI (0 for anything with a single song). */
extern "C" int rewamp_adlmidi_probe_subsong_count(const char* path) {
    char clean[4096];
    split_subsong(path, clean, sizeof(clean));
    /* Only an XMI holds several songs: decide on the header, never by
     * opening every file the dispatcher asks about. */
    uint8_t hdr[12] = {0};
    size_t hn = 0;
    if (FILE* f = fopen(clean, "rb")) {
        hn = fread(hdr, 1, sizeof(hdr), f);
        fclose(f);
    }
    if (kind_of(hdr, hn) != K_XMI) return 0;
    ADL_MIDIPlayer* dev = adl_init(ADL_RATE);
    if (!dev) return 0;
    int n = 0;
    if (adl_openFile(dev, clean) >= 0) n = adl_getSongsCount(dev);
    adl_close(dev);
    return n > 1 ? n : 0;
}

/* Embedded bank names, for Settings → OPL3 (index = engine param "bank"). */
extern "C" REWAMP_EXPORT int rewamp_adlmidi_bank_count(void) { return adl_getBanksCount(); }

extern "C" REWAMP_EXPORT const char* rewamp_adlmidi_bank_name(int index) {
    const char* const* names = adl_getBankNames();
    if (!names || index < 0 || index >= adl_getBanksCount()) return "";
    return names[index];
}

#endif /* REWAMP_WITH_ADLMIDI */

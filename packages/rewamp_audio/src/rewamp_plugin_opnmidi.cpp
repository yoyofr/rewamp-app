/* libOPNMIDI plugin — MIDI (and the DOS game formats its sequencer reads:
 * XMI, DMX MUS, HMI/HMP, GMF) rendered on an emulated Yamaha OPN2 (YM2612,
 * the Mega Drive / Genesis chip) or OPNA (YM2608, PC-98).
 *
 * libOPNMIDI v1.6.2 (Wohlstand, GPL-3.0-or-later core; chip cores LGPL-2.1+ /
 * GPL-2.0+ / BSD / MIT-like, sequencer and WOPN reader MIT) — vendored under
 * third_party/libopnmidi. Every TU of the LIBRARY is compiled with
 * third_party/libopnmidi/rewamp/opnmidi_rename.h injected first: libvgm
 * (Nuked OPN2: OPN2_*; MAME fm: ym2612_*), pmdmini (ymfm) and libADLMIDI (the
 * same sequencer classes: MIDIplay, FileAndMemReader…) define the same
 * names — 222 shared before renaming, 0 after. THIS file includes only the
 * public C API (opn2_*), which keeps its names. Regenerate the header on every
 * resync: scripts/gen_fm_midi_rename.py --api opn2_ --prefix rwopn_.
 *
 * Banks: the library embeds none. The seven WOPN banks of its fm_banks/ are
 * embedded by rewamp/opnmidi_banks.c (scripts/gen_opn_banks.py), chosen by
 * index (engine param "opnmidi"/"bank"); XG (MIT) is the default.
 *
 * Voices: one per MIDI channel the file uses (notes, mute, oscilloscope) —
 * same design as the libADLMIDI plugin. The oscilloscope comes from a patch of
 * the library (rewamp/opnmidi_scope.h, sites marked "REWAMP SCOPE"): MAME
 * YM2612 and Nuked OPN2 hand their 6 channel outputs per output frame; the
 * other emulators give notes only.
 *
 * Loop: native for infinite (opn2_setLoopEnabled + count -1), safe to arm
 * live; N passes go through the generic Dart loop (veto).
 */
#ifdef REWAMP_WITH_OPNMIDI

#include "rewamp_plugin.h"
#include "rewamp_registry.h"
#include "rewamp_gm_drums.h"
#include "rewamp_channel_data.h"
#include "rewamp_audio.h"            /* extern "C" exports — FFI linkage rule */
#include "ModizerVoicesData.h"
#include "ModizerConstants.h"

#include "opnmidi.h"
#include "../third_party/libopnmidi/rewamp/opnmidi_scope.h"
#include "rewamp_path_bank.h"         /* « Lire avec… » bank per file */
/* The bank file reader, for the INSTRUMENT names (the synth API gives none).
 * Its symbols carry the library's rename prefix (rewamp/opnmidi_rename.h, not
 * included whole here: it also renames names this file uses); a renamed
 * prefix fails the link, not silently. */
#define WOPN_LoadBankFromMem rwopn_WOPN_LoadBankFromMem
#define WOPN_Free            rwopn_WOPN_Free
#include "../third_party/libopnmidi/src/wopn/wopn_file.h"
#include "tml.h"                     /* implementation lives in rewamp_tml.c */

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <new>
#include <string>
#include <strings.h>

extern "C" int g_force_loop_mode;
extern "C" int g_force_loop_native_veto;

/* rewamp/opnmidi_banks.c (generated). */
extern "C" const int rewamp_opn_bank_count_v;
extern "C" const char* const rewamp_opn_bank_names_v[];
extern "C" const unsigned char* const rewamp_opn_bank_data_v[];
extern "C" const size_t rewamp_opn_bank_size_v[];

#define OPN_RATE      44100
#define OPN_CHANNELS  16
#define OPN_BATCH     2048           /* frames per opn2_playFormat call */
#define OPN_DRUM_CH   9
#define OPN_SCOPE_CHIPS 16           /* = the « chips » setting's maximum */
#define OPN_RING_SIZE (SOUND_BUFFER_SIZE_SAMPLE * 4 * 2)   /* power of 2 */
#define OPN_FP        MODIZER_OSCILLO_OFFSET_FIXEDPOINT

namespace {

/* ⚠️ Not `struct RewampDecoder`: the rule is to keep every plugin's state in
 * its own type (ODR: an implicit destructor is a weak symbol the linker
 * merges with another plugin's). */
struct OpnDec {
    OPN2_MIDIPlayer* dev = nullptr;
    double           gain = 2.0;
    int64_t          muteApplied = 0;
    int              chan2voice[OPN_CHANNELS];
    int              voiceCount = 0;
    uint8_t          prog[OPN_CHANNELS];
    int              noteCount[OPN_CHANNELS];
    /* Velocity to restore after an attack column (see on_event), 0 = none. */
    unsigned         attackVel[OPN_CHANNELS];
    std::string      bankLabel;       /* user bank file name, "" = embedded */
    bool             userBankFailed = false;
    /* Melodic instrument names of the bank in use (index = program), "" =
     * unnamed. Only what the BANK says: a program number is not a General
     * MIDI instrument for a bank written for one game. */
    std::string      instName[128];
    int              bankIndex = 0;   /* embedded bank in use */
};

OPNMIDI_AudioFormat kF32 = { OPNMIDI_SampleType_F32, 4, 8 };

/* User bank (a .wopn the user imported), set from the UI thread, read by
 * open() on the producer thread. Empty = the embedded bank of param "bank". */
std::mutex  g_bank_file_lock;
std::string g_bank_file;

std::string bank_file() {
    std::lock_guard<std::mutex> lk(g_bank_file_lock);
    return g_bank_file;
}

/* « Lire avec… »: the bank chosen for one file, above the setting. */
PathBankTable g_path_banks;

const char* base_name(const std::string& path) {
    const size_t s = path.find_last_of("/\\");
    return s == std::string::npos ? path.c_str() : path.c_str() + s + 1;
}

/* Oscilloscope state. One decoder plays at a time (the producer opens the
 * next track only after closing this one), and every hook runs on the
 * producer thread, inside opn2_playFormat. */
int8_t  g_scope_owner[OPN_SCOPE_CHIPS][REWAMP_OPN_SCOPE_CHANNELS]; /* MIDI ch */
int     g_scope_chan2voice[OPN_CHANNELS];
int     g_scope_pos[OPN_SCOPE_CHIPS];   /* frames of this batch, per chip */
int32_t g_scope_acc[OPN_CHANNELS][OPN_BATCH];

void scope_reset_owners() {
    memset(g_scope_owner, -1, sizeof(g_scope_owner));
}

}  // namespace

extern "C" {
int rewamp_opn_scope_on = 0;

/* A chip renders a whole run of frames before the next chip renders the
 * same run, so each chip keeps its own position in the batch. */
void rewamp_opn_scope_frame(uint32_t chip, const int32_t* ch) {
    if (chip >= OPN_SCOPE_CHIPS) return;
    const int pos = g_scope_pos[chip]++;
    if (pos >= OPN_BATCH) return;
    const int8_t* own = g_scope_owner[chip];
    for (int i = 0; i < REWAMP_OPN_SCOPE_CHANNELS; i++) {
        if (own[i] < 0 || ch[i] == 0) continue;
        const int v = g_scope_chan2voice[(int)own[i]];
        if (v >= 0) g_scope_acc[v][pos] += ch[i];
    }
}

void rewamp_opn_scope_owner(size_t chipChan, size_t midCh) {
    const size_t chip = chipChan / REWAMP_OPN_SCOPE_CHANNELS;
    if (chip >= OPN_SCOPE_CHIPS || midCh >= OPN_CHANNELS) return;
    g_scope_owner[chip][chipChan % REWAMP_OPN_SCOPE_CHANNELS] = (int8_t)midCh;
}
}  // extern "C"

namespace {

double param(const char* key, double def) {
    return rewamp_get_engine_param("opnmidi", key, def);
}

/* Settings read at open (bank, emulator, chips, volume model need a fresh
 * synth) — plus the live ones, re-applied by opn_param_changed. */
void apply_live(OpnDec* d) {
    d->gain = param("gain", 2.0);
    opn2_setSoftPanEnabled(d->dev, param("soft_pan", 1) != 0);
    opn2_setAutoArpeggio(d->dev, param("auto_arpeggio", 0) != 0);
}

int bank_index() {
    int bank = (int)param("bank", 0);
    return bank >= 0 && bank < rewamp_opn_bank_count_v ? bank : 0;
}

/* Names of the melodic bank MIDI bank 0 selects (else the first one). */
void read_inst_names(OpnDec* d, const void* mem, size_t size) {
    for (auto& n : d->instName) n.clear();
    if (!mem || size == 0) return;
    int err = 0;
    WOPNFile* f = WOPN_LoadBankFromMem(const_cast<void*>(mem), size, &err);
    if (!f) return;
    const WOPNBank* b = nullptr;
    for (int i = 0; i < f->banks_count_melodic; i++) {
        const WOPNBank& c = f->banks_melodic[i];
        if (c.bank_midi_msb == 0 && c.bank_midi_lsb == 0) { b = &c; break; }
    }
    if (!b && f->banks_count_melodic > 0) b = &f->banks_melodic[0];
    if (b) {
        for (int p = 0; p < 128; p++) {
            std::string n(b->ins[p].inst_name);
            while (!n.empty() && (n.back() == ' ' || n.back() == '\t')) n.pop_back();
            /* Wohlstand's banks mark entries « * Name »: the mark only
             * eats the voice name's few characters. */
            size_t s = 0;
            while (s < n.size() && (n[s] == ' ' || n[s] == '*')) s++;
            d->instName[p] = n.substr(s);
        }
    }
    WOPN_Free(f);
}

void read_inst_names_file(OpnDec* d, const std::string& file) {
    FILE* fp = fopen(file.c_str(), "rb");
    if (!fp) { read_inst_names(d, nullptr, 0); return; }
    std::string buf;
    char chunk[65536];
    size_t n;
    while ((n = fread(chunk, 1, sizeof(chunk), fp)) > 0) buf.append(chunk, n);
    fclose(fp);
    read_inst_names(d, buf.data(), buf.size());
}

bool apply_open(OpnDec* d, const char* path) {
    int emu = (int)param("emulator", OPNMIDI_EMU_MAME);
    if (emu < 0 || emu >= OPNMIDI_EMU_end || opn2_switchEmulator(d->dev, emu) < 0)
        opn2_switchEmulator(d->dev, OPNMIDI_EMU_MAME);   /* compiled everywhere */
    int chips = (int)param("chips", 4);
    if (chips < 1) chips = 1;
    if (chips > 16) chips = 16;
    opn2_setNumChips(d->dev, chips);
    int bank = bank_index();
    std::string file = bank_file();
    /* « Lire avec… »: a bank chosen for THIS file replaces the setting's. */
    PathBank pb;
    if (g_path_banks.get(path, pb)) {
        file = pb.file;
        if (pb.file.empty())
            bank = pb.index >= 0 && pb.index < rewamp_opn_bank_count_v ? pb.index : 0;
    }
    d->bankIndex = bank;
    /* A user bank replaces the embedded one; unreadable ⇒ the embedded one,
     * said in ⓘ rather than a synth with no instruments (nothing would play). */
    d->userBankFailed = false;
    d->bankLabel.clear();
    if (!file.empty() && opn2_openBankFile(d->dev, file.c_str()) == 0) {
        d->bankLabel = base_name(file);
        read_inst_names_file(d, file);
    } else {
        d->userBankFailed = !file.empty();
        if (opn2_openBankData(d->dev, rewamp_opn_bank_data_v[bank],
                              (long)rewamp_opn_bank_size_v[bank]) < 0)
            return false;
        /* The embedded banks are WOPN files too. */
        read_inst_names(d, rewamp_opn_bank_data_v[bank], rewamp_opn_bank_size_v[bank]);
    }
    opn2_setVolumeRangeModel(d->dev, (int)param("volume_model", OPNMIDI_VolumeModel_AUTO));
    opn2_setScaleModulators(d->dev, param("scale_modulators", 0) != 0);
    opn2_setFullRangeBrightness(d->dev, param("full_brightness", 0) != 0);
    apply_live(d);
    return true;
}

/* Notes and programs per MIDI channel for the visualisers — the raw-event
 * hook sees every standard MIDI event the sequencer dispatches (producer
 * thread, same as read()). */
void on_event(void* ud, OPN2_UInt8 type, OPN2_UInt8 /*subtype*/, OPN2_UInt8 ch,
              const OPN2_UInt8* data, size_t len) {
    OpnDec* d = static_cast<OpnDec*>(ud);
    if (ch >= OPN_CHANNELS) return;
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
                /* ATTACK: 255 for the column captured after this read, the
                 * velocity from the next one on. The notation and piano cut a
                 * note when its volume RISES (rewamp_notes_render.cpp): with
                 * the velocity alone, the same key struck again at the same
                 * velocity — a repeated bass note, a drum — read as ONE held
                 * note (« The Healer Stalks », voice 1). UADE's rule. */
                vgm_last_vol[v]   = 255;
                d->attackVel[v]   = data[1];
                /* Canal 10: une case par TOUCHE (rewamp_gm_drums.h). */
                vgm_last_instr[v] = ch == OPN_DRUM_CH
                    ? rewamp_drum_instr_index(data[0])
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

void silence_notes(OpnDec* d) {
    for (int v = 0; v < OPN_CHANNELS; v++) {
        d->noteCount[v] = 0;
        vgm_last_note[v] = 0;
        vgm_last_vol[v]  = 0;
        d->attackVel[v]  = 0;
    }
}

/* Which MIDI channels the file plays, for an SMF/RMI (tml reads both). The
 * raw-event hook does NOT fire during opn2_positionSeek (same sequencer as
 * libADLMIDI, measured there). */
int scan_channels(const char* path, int used[OPN_CHANNELS]) {
    tml_message* ev = tml_load_filename(path);
    if (!ev) return 0;
    int any = 0;
    for (tml_message* m = ev; m; m = m->next)
        if (m->type == TML_NOTE_ON && m->velocity > 0 && m->channel < OPN_CHANNELS) {
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

int opn_probe(const char* ext, const uint8_t* hdr, size_t n) {
    const Kind k = kind_of(hdr, n);
    const bool midiExt = rewamp_ext_in_list(ext, kMidiExts);
    const bool ownExt  = rewamp_ext_in_list(ext, kOwnExts);
    switch (k) {
        /* Below FluidLite's 100 and libADLMIDI's 95 on a plain MIDI: only
         * « Synthé MIDI: OPN2 » (a pin) selects it there. */
        case K_SMF:
        case K_RMI: return midiExt ? 94 : 89;
        /* The DOS formats were written for an OPL: libADLMIDI (100) plays
         * them; this plugin is their fallback when it is not built. */
        case K_XMI: case K_MUS: case K_HMI: case K_HMP: case K_GMF:
            return 90;
        default:
            return ownExt ? 39 : (midiExt ? 29 : 0);
    }
}

void opn_close_fn(RewampDecoder* rd);

RewampDecoder* opn_open_fn(const char* path, RewampAudioFormat* outFormat) {
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

    OpnDec* d = new (std::nothrow) OpnDec();
    if (!d) return nullptr;
    d->dev = opn2_init(OPN_RATE);
    if (!d->dev) { delete d; return nullptr; }
    if (!apply_open(d, clean)) {
        opn_close_fn(reinterpret_cast<RewampDecoder*>(d));
        return nullptr;
    }
    opn2_setRawEventHook(d->dev, on_event, d);
    if (sub >= 0) opn2_selectSongNum(d->dev, sub);
    if (opn2_openFile(d->dev, clean) < 0) {
        opn_close_fn(reinterpret_cast<RewampDecoder*>(d));
        return nullptr;
    }

    /* Voices: the channels the file uses (SMF/RMI), else all 16. */
    int used[OPN_CHANNELS] = {0};
    const bool scanned = (kind == K_SMF || kind == K_RMI) && scan_channels(clean, used);
    for (int c = 0; c < OPN_CHANNELS; c++) {
        d->chan2voice[c] = (!scanned || used[c]) ? d->voiceCount++ : -1;
        d->prog[c] = 0;
    }
    rewamp_channel_data_reset(d->voiceCount);
    rewamp_channel_data_set_ring_write_size(OPN_RING_SIZE);
    for (int c = 0; c < OPN_CHANNELS; c++) g_scope_chan2voice[c] = d->chan2voice[c];
    scope_reset_owners();
    rewamp_opn_scope_on = 1;
    silence_notes(d);
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("OPN2", 0, d->voiceCount);
    for (int c = 0; c < OPN_CHANNELS; c++) {
        if (d->chan2voice[c] < 0) continue;
        char nm[MODIZ_VOICE_NAME_MAX_CHAR];
        if (c == OPN_DRUM_CH) snprintf(nm, sizeof(nm), "Drums");
        else                  snprintf(nm, sizeof(nm), "Ch %d", c + 1);
        rewamp_voice_set_name(d->chan2voice[c], nm);
    }
    /* Same index as vgm_last_instr (program + 1); unnamed ⇒ « Inst n ». */
    for (int p = 0; p < 128; p++)
        if (!d->instName[p].empty())
            rewamp_instrument_set_name(p + 1, d->instName[p].c_str());
    rewamp_drum_register_names();   /* la batterie, touche par touche */

    const double total = opn2_totalTimeLength(d->dev);
    const char* title = opn2_metaMusicTitle(d->dev);
    const char* copy  = opn2_metaMusicCopyright(d->dev);
    if (title && title[0]) rewamp_track_tag_set(title, nullptr, nullptr);
    rewamp_track_message_append("Format: %s\n", kind_name(kind));
    if (title && title[0]) rewamp_track_message_append("Title: %s\n", title);
    if (copy && copy[0])   rewamp_track_message_append("Copyright: %s\n", copy);
    const int songs = opn2_getSongsCount(d->dev);
    if (songs > 1) rewamp_track_message_append("Songs: %d\n", songs);
    if (!d->bankLabel.empty())
        rewamp_track_message_append("Bank: %s (imported)\n", d->bankLabel.c_str());
    else
        rewamp_track_message_append("Bank: %s%s\n", rewamp_opn_bank_names_v[d->bankIndex],
                                    d->userBankFailed ? " (imported bank unreadable)" : "");
    rewamp_track_message_append("Synth: Yamaha %s — %s, %d chip(s)\n",
                                opn2_getChipType(d->dev) == OPNMIDI_ChipType_OPNA
                                    ? "OPNA (YM2608)" : "OPN2 (YM2612)",
                                opn2_chipEmulatorName(d->dev),
                                opn2_getNumChipsObtained(d->dev));
    if (total > 0)
        rewamp_track_message_append("Duration: %u:%02u\n",
                                    (unsigned)total / 60, (unsigned)total % 60);
    {
        const double ls = opn2_loopStartTime(d->dev), le = opn2_loopEndTime(d->dev);
        if (ls >= 0 && le > ls)
            rewamp_track_message_append_loop(ls, le - ls, -1, -1);
    }

    if (outFormat) {
        outFormat->channels   = 2;
        outFormat->sampleRate = OPN_RATE;
    }
    return reinterpret_cast<RewampDecoder*>(d);
}

/* Batch → voice rings, one ring sample per output frame. A channel peaks
 * near ±8192 (MAME out_fm; Nuked is brought to that scale); several chip
 * channels of one MIDI channel add up, hence the clamp. */
void scope_flush(OpnDec* d, int frames) {
    const int mask = OPN_RING_SIZE - 1;
    for (int v = 0; v < d->voiceCount; v++) {
        if (!m_voice_buff[v]) continue;
        const int64_t base = m_voice_current_ptr[v] >> OPN_FP;
        const int32_t* a = g_scope_acc[v];
        for (int k = 0; k < frames; k++) {
            int32_t s8 = a[k] >> 7;
            if (s8 > 127) s8 = 127;
            if (s8 < -128) s8 = -128;
            m_voice_buff[v][(base + k) & mask] = (signed char)s8;
        }
        m_voice_current_ptr[v] += (int64_t)frames << OPN_FP;
    }
}

uint64_t opn_read_fn(RewampDecoder* rd, float* out, uint64_t frameCount) {
    OpnDec* d = reinterpret_cast<OpnDec*>(rd);
    if (!d || !d->dev) return 0;
    /* The attack columns were captured after the previous read: back to the
     * velocity (a note released since then stays at 0). */
    for (int v = 0; v < d->voiceCount; v++) {
        if (d->attackVel[v] && vgm_last_vol[v] == 255) vgm_last_vol[v] = d->attackVel[v];
        d->attackVel[v] = 0;
    }
    /* Mute: one MIDI channel per voice, pushed when the mask moves. */
    if (d->muteApplied != generic_mute_mask) {
        for (int c = 0; c < OPN_CHANNELS; c++) {
            const int v = d->chan2voice[c];
            if (v >= 0) opn2_setChannelEnabled(d->dev, (size_t)c,
                                               ((generic_mute_mask >> v) & 1) == 0);
        }
        d->muteApplied = generic_mute_mask;
    }
    uint64_t done = 0;
    while (done < frameCount) {
        uint64_t want = frameCount - done;
        if (want > OPN_BATCH) want = OPN_BATCH;
        float* dst = out + done * 2;
        for (int v = 0; v < d->voiceCount; v++)
            memset(g_scope_acc[v], 0, sizeof(int32_t) * (size_t)want);
        memset(g_scope_pos, 0, sizeof(g_scope_pos));
        const int got = opn2_playFormat(d->dev, (int)(want * 2),
                                        reinterpret_cast<OPN2_UInt8*>(dst),
                                        reinterpret_cast<OPN2_UInt8*>(dst + 1), &kF32);
        if (got <= 0) break;
        const uint64_t frames = (uint64_t)got / 2;
        scope_flush(d, (int)frames);
        const float g = (float)d->gain;
        for (uint64_t i = 0; i < frames * 2; i++) dst[i] *= g;
        done += frames;
        if (frames < want) break;
    }
    /* A long silent intro is not an end while events remain. */
    if (!opn2_atEnd(d->dev)) rewamp_decoder_activity();
    return done;
}

void opn_seek_fn(RewampDecoder* rd, uint64_t frameIndex) {
    OpnDec* d = reinterpret_cast<OpnDec*>(rd);
    if (!d || !d->dev) return;
    opn2_positionSeek(d->dev, (double)frameIndex / OPN_RATE);
    silence_notes(d);   /* the visualisers follow the sound */
    scope_reset_owners();
}

uint64_t opn_length_fn(RewampDecoder* rd) {
    OpnDec* d = reinterpret_cast<OpnDec*>(rd);
    if (!d || !d->dev) return 0;
    const double t = opn2_totalTimeLength(d->dev);
    return t > 0 ? (uint64_t)(t * OPN_RATE + 0.5) : 0;
}

void opn_close_fn(RewampDecoder* rd) {
    OpnDec* d = reinterpret_cast<OpnDec*>(rd);
    if (!d) return;
    rewamp_opn_scope_on = 0;
    if (d->dev) opn2_close(d->dev);
    delete d;
}

/* Mode 2 = native infinite, also replayed live by
 * rewamp_lift_end_for_infinite (the flag is read at the song's end). */
void opn_configure_loop_fn(RewampDecoder* rd, int mode, int /*count*/) {
    OpnDec* d = reinterpret_cast<OpnDec*>(rd);
    if (!d || !d->dev || mode != 2) return;
    opn2_setLoopEnabled(d->dev, 1);
    opn2_setLoopCount(d->dev, -1);
}

void opn_param_changed_fn(RewampDecoder* rd, const char* /*key*/) {
    OpnDec* d = reinterpret_cast<OpnDec*>(rd);
    if (d && d->dev) apply_live(d);
}

/* Native speed: the sequencer's tempo multiplier (pitch unchanged). */
int opn_set_speed_fn(RewampDecoder* rd, double speed) {
    OpnDec* d = reinterpret_cast<OpnDec*>(rd);
    if (!d || !d->dev || speed < 0.2 || speed > 3.0) return 0;
    opn2_setTempo(d->dev, speed);
    return 1;
}

const RewampPluginVTable kOpnVTable = {
    "opnmidi",
    opn_probe,
    opn_open_fn,
    opn_read_fn,
    opn_seek_fn,
    opn_length_fn,
    opn_close_fn,
    opn_configure_loop_fn,
    0,                    /* supportsNativeFadeout */
    "opnmidi",            /* engine_id */
    opn_param_changed_fn, /* live settings */
    nullptr, nullptr, nullptr, nullptr, nullptr, /* pattern view */
    nullptr,              /* probe_path */
    0,                    /* noPrefixProbe */
    opn_set_speed_fn,     /* vitesse native (tempo du séquenceur) */
};

}  // namespace

extern "C" const RewampPluginVTable* rewamp_opnmidi_plugin(void) { return &kOpnVTable; }

/* Sub-songs of a multi-song XMI (0 for anything with a single song). */
extern "C" int rewamp_opnmidi_probe_subsong_count(const char* path) {
    char clean[4096];
    split_subsong(path, clean, sizeof(clean));
    uint8_t hdr[12] = {0};
    size_t hn = 0;
    if (FILE* f = fopen(clean, "rb")) {
        hn = fread(hdr, 1, sizeof(hdr), f);
        fclose(f);
    }
    if (kind_of(hdr, hn) != K_XMI) return 0;
    OPN2_MIDIPlayer* dev = opn2_init(OPN_RATE);
    if (!dev) return 0;
    int n = 0;
    opn2_openBankData(dev, rewamp_opn_bank_data_v[0], (long)rewamp_opn_bank_size_v[0]);
    if (opn2_openFile(dev, clean) >= 0) n = opn2_getSongsCount(dev);
    opn2_close(dev);
    return n > 1 ? n : 0;
}

/* Embedded bank names, for Settings → libOPNMIDI (index = engine param "bank"). */
extern "C" REWAMP_EXPORT int rewamp_opnmidi_bank_count(void) { return rewamp_opn_bank_count_v; }

/* A user bank file (.wopn, imported into the data dir) — "" = back to the
 * embedded bank. Applied at the next open, like the other bank settings. */
extern "C" REWAMP_EXPORT void rewamp_opnmidi_set_bank_file(const char* path) {
    std::lock_guard<std::mutex> lk(g_bank_file_lock);
    g_bank_file = path ? path : "";
}

/* « Lire avec… »: the bank of ONE file — an embedded [index], or an imported
 * [file] (index ignored); index < 0 and no file = forget [path]. Exact path,
 * without ?subsong=. Applied at its next open. */
extern "C" REWAMP_EXPORT void rewamp_opnmidi_set_path_bank(const char* path, int index,
                                                           const char* file) {
    g_path_banks.set(path, index, file);
}

extern "C" REWAMP_EXPORT void rewamp_opnmidi_clear_path_banks(void) { g_path_banks.clear(); }

extern "C" REWAMP_EXPORT const char* rewamp_opnmidi_bank_name(int index) {
    if (index < 0 || index >= rewamp_opn_bank_count_v) return "";
    return rewamp_opn_bank_names_v[index];
}

#endif /* REWAMP_WITH_OPNMIDI */

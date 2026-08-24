/* MIDI plugin: FluidLite (FluidSynth fork, SF2 SoundFont renderer, no glib)
 * driven by TinyMidiLoader (tml.h) as the sequencer.
 *
 * The SoundFont is NOT bundled: the Dart layer downloads it (server assets)
 * and points the plugin at it via rewamp_midi_set_soundfont(); fallback is
 * <datadir>/soundfonts/default.sf2. Without a readable SoundFont the probe
 * declines the file so the app can surface a clear "no soundfont" state.
 *
 * Per-voice scope: FluidLite mixes its 16 MIDI channels internally, so this
 * plugin registers no voices (stereo L/R fallback applies). Per-channel
 * capture needs a core patch — phase 2 (see midi-plan memory).
 */

#include "rewamp_plugin.h"
#include "rewamp_registry.h"
#include "rewamp_channel_data.h"
#include "rewamp_assets.h"
#include "ModizerVoicesData.h"   /* m_voice_buff / vgm_last_note / mute mask */
#include "ModizerConstants.h"
#include <math.h>

#include "fluidlite.h"

#define TML_IMPLEMENTATION
#include "tml.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MIDI_SAMPLE_RATE 44100
#define MIDI_TAIL_MS     2000   /* let releases/reverb ring out at the end */

#define MIDI_CHANNELS    16
#define MIDI_RING_SIZE   (SOUND_BUFFER_SIZE_SAMPLE * 4 * 2)   /* power of 2 */
#define MIDI_FP          MODIZER_OSCILLO_OFFSET_FIXEDPOINT

/* ── Per-channel capture state (fed by the fluid_synth.c REWAMP_VOICE_CAPTURE
 * hooks, flushed into the shared voice rings once per 64-frame block). ──── */
static float g_cap[MIDI_CHANNELS][64];
static int   g_note_count[MIDI_CHANNELS];   /* active notes per voice */

/* Compact channel→voice map: only the channels the FILE actually uses get a
 * scope voice (a 4-channel .mid shows 4 scopes, not 16). -1 = unused. The
 * mute mask / rings / notes are indexed by VOICE, hence the mapping. */
static int g_chan2voice[MIDI_CHANNELS];
static int g_voice_count = 0;

/* Hooks called from the patched fluid_synth.c (same thread as read()). */
int rewamp_fluid_channel_muted(int ch) {
    if (ch < 0 || ch >= MIDI_CHANNELS) return 0;
    int v = g_chan2voice[ch];
    return v >= 0 && ((generic_mute_mask >> v) & 1) != 0;
}

void rewamp_fluid_capture_voice(int ch, const float* dl, const float* dr,
                                int len) {
    if (ch < 0 || ch >= MIDI_CHANNELS || dl == NULL || dr == NULL) return;
    int v = g_chan2voice[ch];
    if (v < 0) return;
    if (len > 64) len = 64;
    for (int k = 0; k < len; k++) g_cap[v][k] += dl[k] + dr[k];
}

void rewamp_fluid_block_done(int len) {
    if (len > 64) len = 64;
    const int mask = MIDI_RING_SIZE - 1;
    for (int v = 0; v < g_voice_count; v++) {
        if (m_voice_buff[v]) {
            int64_t base = m_voice_current_ptr[v] >> MIDI_FP;
            for (int k = 0; k < len; k++) {
                float f = g_cap[v][k] * 96.0f;   /* ±~1.3 → full-ish scale */
                if (f > 127.0f) f = 127.0f;
                if (f < -128.0f) f = -128.0f;
                m_voice_buff[v][(base + k) & mask] = (int8_t)f;
            }
            m_voice_current_ptr[v] += (int64_t)len << MIDI_FP;
        }
        for (int k = 0; k < len; k++) g_cap[v][k] = 0.0f;
    }
}

static void midi_reset_note_state(void) {
    for (int c = 0; c < MIDI_CHANNELS; c++) {
        g_note_count[c] = 0;
        vgm_last_note[c] = 0;
        vgm_last_vol[c]  = 0;
    }
}

/* ── Engine params (Settings → Moteurs → FluidLite) ──────────────────────────
 * Read live: applied to the synth in open() and again on every settings change
 * via the param_changed hook (under the decode lock). Keys/defaults mirror the
 * user_settings.dart getters (the single source of truth). */
static void midi_apply_params(fluid_synth_t* s) {
    if (!s) return;
    double gain = rewamp_get_engine_param("midi", "gain", 0.8);
    int    poly = (int)rewamp_get_engine_param("midi", "polyphony", 128);
    int    rev  = (int)rewamp_get_engine_param("midi", "reverb", 1);
    int    cho  = (int)rewamp_get_engine_param("midi", "chorus", 1);
    /* Interpolation method: 0=none, 1=linear, 4=4th order, 7=7th order
     * (FLUID_INTERP_* — the 4th-order default matches FluidLite's own). */
    int    interp = (int)rewamp_get_engine_param("midi", "interp", 4);
    fluid_synth_set_gain(s, (float)gain);
    fluid_synth_set_polyphony(s, poly);
    fluid_synth_set_reverb_on(s, rev);
    fluid_synth_set_chorus_on(s, cho);
    fluid_synth_set_interp_method(s, -1, interp);   /* -1 = all channels */
}

static char g_sf2_path[4096] = "";

void rewamp_midi_set_soundfont(const char* path) {
    if (!path) { g_sf2_path[0] = '\0'; return; }
    strncpy(g_sf2_path, path, sizeof(g_sf2_path) - 1);
    g_sf2_path[sizeof(g_sf2_path) - 1] = '\0';
}

const char* rewamp_midi_get_soundfont(void) { return g_sf2_path; }

/* Resolve the SoundFont: explicit path first, then the datadir default. */
static const char* midi_soundfont(void) {
    if (g_sf2_path[0]) {
        FILE* f = fopen(g_sf2_path, "rb");
        if (f) { fclose(f); return g_sf2_path; }
    }
    const char* dd = rewamp_get_data_dir();
    if (dd && dd[0]) {
        static char def[4096];
        snprintf(def, sizeof(def), "%s/soundfonts/default.sf2", dd);
        FILE* f = fopen(def, "rb");
        if (f) { fclose(f); return def; }
    }
    return NULL;
}

typedef struct {
    fluid_settings_t*   settings;
    fluid_synth_t*      synth;
    tml_message*        events;      /* full list (owned) */
    tml_message*        next;        /* next event to dispatch */
    double              time_ms;     /* playback clock */
    unsigned            total_ms;    /* last event time + tail */
} MidiDec;

static const char* const kMidiExts[] = { "mid", "midi", "kar", "rmi", NULL };

static int midi_probe(const char* ext, const uint8_t* header, size_t headerSize) {
    int extMatch = rewamp_ext_in_list(ext, kMidiExts);
    int magic = headerSize >= 4 && memcmp(header, "MThd", 4) == 0;
    /* RIFF RMID wrapper: "RIFF" .... "RMID" — tml handles it. */
    if (!magic && headerSize >= 12 &&
        memcmp(header, "RIFF", 4) == 0 && memcmp(header + 8, "RMID", 4) == 0)
        magic = 1;
    if (!magic && !extMatch) return 0;
    if (midi_soundfont() == NULL) return 0;   /* nothing to render with */
    if (magic) return extMatch ? 110 : 100;
    return 60;
}

static void midi_dispatch(MidiDec* d, const tml_message* m) {
    fluid_synth_t* s = d->synth;
    switch (m->type) {
        case TML_PROGRAM_CHANGE:
            fluid_synth_program_change(s, m->channel, m->program);
            break;
        case TML_NOTE_ON:
            if (m->velocity > 0) {
                fluid_synth_noteon(s, m->channel, m->key, m->velocity);
                if (m->channel < MIDI_CHANNELS &&
                    g_chan2voice[m->channel] >= 0) {
                    int v = g_chan2voice[m->channel];
                    g_note_count[v]++;
                    vgm_last_note[v] = (unsigned int)
                        (440.0 * pow(2.0, (m->key - 69) / 12.0) + 0.5);
                    vgm_last_vol[v] = (unsigned int)m->velocity;
                }
            } else {
                fluid_synth_noteoff(s, m->channel, m->key);
                if (m->channel < MIDI_CHANNELS &&
                    g_chan2voice[m->channel] >= 0) {
                    int v = g_chan2voice[m->channel];
                    if (--g_note_count[v] <= 0) {
                        g_note_count[v] = 0;
                        vgm_last_note[v] = 0;
                        vgm_last_vol[v]  = 0;
                    }
                }
            }
            break;
        case TML_NOTE_OFF:
            fluid_synth_noteoff(s, m->channel, m->key);
            if (m->channel < MIDI_CHANNELS &&
                g_chan2voice[m->channel] >= 0) {
                int v = g_chan2voice[m->channel];
                if (--g_note_count[v] <= 0) {
                    g_note_count[v] = 0;
                    vgm_last_note[v] = 0;
                    vgm_last_vol[v]  = 0;
                }
            }
            break;
        case TML_PITCH_BEND:
            fluid_synth_pitch_bend(s, m->channel, m->pitch_bend);
            break;
        case TML_CONTROL_CHANGE:
            fluid_synth_cc(s, m->channel, m->control, m->control_value);
            if ((m->control == 120 || m->control == 123) &&
                m->channel < MIDI_CHANNELS &&
                g_chan2voice[m->channel] >= 0) { /* all sound / notes off */
                int v = g_chan2voice[m->channel];
                g_note_count[v] = 0;
                vgm_last_note[v] = 0;
                vgm_last_vol[v]  = 0;
            }
            break;
        case TML_CHANNEL_PRESSURE:
            fluid_synth_channel_pressure(s, m->channel, m->channel_pressure);
            break;
        default:
            break;   /* tempo handled by tml's absolute timestamps */
    }
}

static void midi_close(RewampDecoder* rd);

static RewampDecoder* midi_open(const char* path, RewampAudioFormat* outFormat) {
    const char* sf2 = midi_soundfont();
    if (!sf2) return NULL;

    /* Strip a ?subsong= suffix (MIDI has no subsongs, but keep fopen clean). */
    char clean[4096];
    strncpy(clean, path, sizeof(clean) - 1);
    clean[sizeof(clean) - 1] = '\0';
    char* q = strchr(clean, '?');
    if (q) *q = '\0';

    MidiDec* d = (MidiDec*)calloc(1, sizeof(MidiDec));
    if (!d) return NULL;

    d->events = tml_load_filename(clean);
    if (!d->events) { free(d); return NULL; }
    d->next = d->events;

    unsigned lastMs = 0;
    int noteCount = 0;
    for (tml_message* m = d->events; m; m = m->next) {
        if (m->time > lastMs) lastMs = m->time;
        if (m->type == TML_NOTE_ON && m->velocity > 0) noteCount++;
    }
    d->total_ms = lastMs + MIDI_TAIL_MS;

    d->settings = new_fluid_settings();
    if (!d->settings) { midi_close((RewampDecoder*)d); return NULL; }
    fluid_settings_setnum(d->settings, "synth.sample-rate", MIDI_SAMPLE_RATE);
    fluid_settings_setint(d->settings, "synth.polyphony", 128);
    /* FluidSynth's default gain (0.2) is calibrated for 100+ simultaneous
     * voices and is far too quiet next to the other plugins. */
    fluid_settings_setnum(d->settings, "synth.gain", 0.8);
    fluid_settings_setstr(d->settings, "synth.reverb.active", "yes");
    fluid_settings_setstr(d->settings, "synth.chorus.active", "yes");

    d->synth = new_fluid_synth(d->settings);
    if (!d->synth) { midi_close((RewampDecoder*)d); return NULL; }
    if (fluid_synth_sfload(d->synth, sf2, 1) == -1) {
        midi_close((RewampDecoder*)d);
        return NULL;
    }
    midi_apply_params(d->synth);   /* user gain/polyphony/reverb/chorus/interp */

    /* Scope voices = only the MIDI channels this FILE uses (has at least one
     * note-on), mapped compactly (channel→voice). Reset BEFORE first render. */
    for (int c = 0; c < MIDI_CHANNELS; c++) g_chan2voice[c] = -1;
    g_voice_count = 0;
    for (tml_message* m = d->events; m; m = m->next) {
        if (m->type == TML_NOTE_ON && m->velocity > 0 &&
            m->channel < MIDI_CHANNELS && g_chan2voice[m->channel] < 0) {
            g_chan2voice[m->channel] = 0;   /* mark used; index assigned below */
        }
    }
    for (int c = 0; c < MIDI_CHANNELS; c++)
        if (g_chan2voice[c] == 0) g_chan2voice[c] = g_voice_count++;
        else g_chan2voice[c] = -1;
    if (g_voice_count == 0) {               /* degenerate file: keep 1 voice */
        g_chan2voice[0] = 0;
        g_voice_count = 1;
    }

    rewamp_channel_data_reset(g_voice_count);
    rewamp_channel_data_set_ring_write_size(MIDI_RING_SIZE);
    memset(g_cap, 0, sizeof(g_cap));
    midi_reset_note_state();
    rewamp_voices_meta_reset();
    rewamp_voices_add_chip("MIDI", 0, g_voice_count);
    {
        /* Voice names: apply each channel's FIRST program change, read the
         * preset name, then reset the synth (playback re-applies programs
         * at their real event times). */
        int seen[MIDI_CHANNELS] = {0};
        for (tml_message* m = d->events; m; m = m->next) {
            if (m->type == TML_PROGRAM_CHANGE && m->channel < MIDI_CHANNELS &&
                !seen[m->channel]) {
                seen[m->channel] = 1;
                fluid_synth_program_change(d->synth, m->channel, m->program);
            }
        }
        for (int c = 0; c < MIDI_CHANNELS; c++) {
            int v = g_chan2voice[c];
            if (v < 0) continue;
            char nm[MODIZ_VOICE_NAME_MAX_CHAR];
            const char* pname = NULL;
            fluid_preset_t* pr = fluid_synth_get_channel_preset(d->synth, c);
            if (pr && pr->get_name) pname = pr->get_name(pr);
            if (c == 9 && (!pname || !pname[0])) pname = "Drums";
            if (pname && pname[0]) {
                snprintf(nm, sizeof(nm), "%.*s",
                         (int)sizeof(nm) - 1, pname);
            } else {
                snprintf(nm, sizeof(nm), "Ch %d", c + 1);
            }
            rewamp_voice_set_name(v, nm);
        }
        fluid_synth_system_reset(d->synth);
    }

    rewamp_track_message_append("Format: Standard MIDI\n");
    rewamp_track_message_append("Notes: %d\n", noteCount);
    rewamp_track_message_append("Duration: %u:%02u\n",
                                lastMs / 60000, (lastMs / 1000) % 60);
    {
        const char* slash = strrchr(sf2, '/');
        rewamp_track_message_append("SoundFont: %s\n", slash ? slash + 1 : sf2);
    }

    if (outFormat) {
        outFormat->channels   = 2;
        outFormat->sampleRate = MIDI_SAMPLE_RATE;
    }
    return (RewampDecoder*)d;
}

static uint64_t midi_read(RewampDecoder* rd, float* out, uint64_t frameCount) {
    MidiDec* d = (MidiDec*)rd;
    if (d->time_ms >= d->total_ms && d->next == NULL) return 0;

    uint64_t done = 0;
    while (done < frameCount) {
        /* Dispatch every event due at the current clock, then render up to
         * the next event (or the block end) in one go. */
        while (d->next && d->next->time <= (unsigned)d->time_ms) {
            midi_dispatch(d, d->next);
            d->next = d->next->next;
        }
        double untilMs = d->next ? (d->next->time - d->time_ms)
                                 : (double)(d->total_ms - d->time_ms);
        if (untilMs <= 0) untilMs = 0.1;
        uint64_t chunk = (uint64_t)(untilMs * MIDI_SAMPLE_RATE / 1000.0) + 1;
        if (chunk > frameCount - done) chunk = frameCount - done;

        fluid_synth_write_float(d->synth, (int)chunk,
                                out + done * 2, 0, 2,
                                out + done * 2, 1, 2);
        done += chunk;
        d->time_ms += (double)chunk * 1000.0 / MIDI_SAMPLE_RATE;
        if (d->time_ms >= d->total_ms && d->next == NULL) break;
    }
    return done;
}

static void midi_seek(RewampDecoder* rd, uint64_t frameIndex) {
    MidiDec* d = (MidiDec*)rd;
    double targetMs = (double)frameIndex * 1000.0 / MIDI_SAMPLE_RATE;
    if (targetMs < d->time_ms) {
        /* Rewind: silence everything and replay events from the start. */
        fluid_synth_system_reset(d->synth);
        d->next    = d->events;
        d->time_ms = 0;
        midi_reset_note_state();
    }
    /* Fast-forward: apply state-bearing events without rendering so
     * programs/controllers are correct at the target position. */
    while (d->next && d->next->time <= (unsigned)targetMs) {
        if (d->next->type != TML_NOTE_ON && d->next->type != TML_NOTE_OFF)
            midi_dispatch(d, d->next);
        d->next = d->next->next;
    }
    d->time_ms = targetMs;
}

static uint64_t midi_length(RewampDecoder* rd) {
    MidiDec* d = (MidiDec*)rd;
    return (uint64_t)d->total_ms * MIDI_SAMPLE_RATE / 1000;
}

static void midi_close(RewampDecoder* rd) {
    MidiDec* d = (MidiDec*)rd;
    if (!d) return;
    if (d->synth)    delete_fluid_synth(d->synth);
    if (d->settings) delete_fluid_settings(d->settings);
    if (d->events)   tml_free(d->events);
    free(d);
}

/* Live settings: re-apply all synth params on any Moteurs → FluidLite change
 * (called under the decode lock — safe against the producer's read()). */
static void midi_param_changed(RewampDecoder* rd, const char* key) {
    (void)key;
    MidiDec* d = (MidiDec*)rd;
    if (d) midi_apply_params(d->synth);
}

static const RewampPluginVTable g_midi_vtable = {
    "fluidlite",
    midi_probe,
    midi_open,
    midi_read,
    midi_seek,
    midi_length,
    midi_close,
    NULL,               /* configure_loop */
    0,                  /* supportsNativeFadeout */
    "midi",             /* engine_id */
    midi_param_changed, /* live settings */
};

const RewampPluginVTable* rewamp_midi_plugin(void) {
    return &g_midi_vtable;
}

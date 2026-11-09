/* Rewamp per-voice oscilloscope hooks for libOPNMIDI — same design as
 * libadlmidi/rewamp/adlmidi_scope.h.
 *
 * The library mixes every FM channel of every chip into one stereo pair, so
 * the scope needs two things the public API does not give:
 *   - each chip channel's output, per output frame (OPNChipBaseT, filled by
 *     the emulators that expose it: MAME YM2612, Nuked OPN2);
 *   - which MIDI channel a chip channel is playing for (OPNMIDIplay, at note on).
 * Implemented in src/rewamp_plugin_opnmidi.cpp. The names carry the rewamp_
 * prefix, so the rename header leaves them alone. Patched sites are marked
 * "REWAMP SCOPE" (list in REWAMP_VENDOR.txt). */
#ifndef REWAMP_OPNMIDI_SCOPE_H
#define REWAMP_OPNMIDI_SCOPE_H

#include <stddef.h>
#include <stdint.h>

#define REWAMP_OPN_SCOPE_CHANNELS 6    /* FM channels per chip */

#ifdef __cplusplus
extern "C" {
#endif

/* Non-zero while a decoder wants the capture (the emulators skip the work
 * otherwise). */
extern int rewamp_opn_scope_on;

/* One output frame of chip `chip`: `ch` = the 6 channel outputs. */
void rewamp_opn_scope_frame(uint32_t chip, const int32_t* ch);

/* libOPNMIDI chip channel `chipChan` (chip * 6 + channel) starts a note of
 * MIDI channel `midCh`. */
void rewamp_opn_scope_owner(size_t chipChan, size_t midCh);

/* MAME YM2612 core: the 6 channel outputs of its last native sample
 * (mame/mame_ym2612fm.c, REWAMP SCOPE). */
void rewamp_opn_mame2612_chout(void* chip, int32_t* out6);

#ifdef __cplusplus
}
#endif

#endif

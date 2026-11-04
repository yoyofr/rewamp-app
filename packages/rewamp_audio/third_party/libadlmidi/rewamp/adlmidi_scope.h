/* Rewamp per-voice oscilloscope hooks for libADLMIDI.
 *
 * The library mixes every OPL channel of every chip into one stereo pair, so
 * the scope needs two things the public API does not give:
 *   - each chip channel's output, per output frame (OPLChipBaseT, filled by
 *     the emulators that expose it: Nuked OPL3 1.8 / 1.7.4, DOSBox);
 *   - which MIDI channel a chip channel is playing for (MIDIplay, at note on).
 * Implemented in src/rewamp_plugin_adlmidi.cpp. The names carry the rewamp_
 * prefix, so the rename header leaves them alone. Patched sites are marked
 * "REWAMP SCOPE" (list in REWAMP_VENDOR.txt). */
#ifndef REWAMP_ADLMIDI_SCOPE_H
#define REWAMP_ADLMIDI_SCOPE_H

#include <stddef.h>
#include <stdint.h>

#define REWAMP_ADL_SCOPE_CHANNELS 18   /* OPL3 register channels per chip */

#ifdef __cplusplus
extern "C" {
#endif

/* Non-zero while a decoder wants the capture (the emulators skip the work
 * otherwise). */
extern int rewamp_adl_scope_on;

/* One output frame of chip `chip`: `ch` = the 18 channel outputs. */
void rewamp_adl_scope_frame(uint32_t chip, const int32_t* ch);

/* libADLMIDI chip channel `chipChan` (chip * 23 + channel, rhythm 18..22)
 * starts a note of MIDI channel `midCh`. */
void rewamp_adl_scope_owner(size_t chipChan, size_t midCh);

#ifdef __cplusplus
}
#endif

#endif

/*
 * ModizerConstants.h — compatibility shim for rewamp_audio
 *
 * The libvgm chip cores (third_party/libvgm/libvgm/emu/cores/) include
 * "../../../../../../src/ModizerVoicesData.h" which in turn includes this file.
 * We provide a minimal subset of constants needed by those chip cores.
 * All Modizer-specific iOS/ObjC symbols are omitted.
 */

#ifndef REWAMP_MODIZER_CONSTANTS_H
#define REWAMP_MODIZER_CONSTANTS_H

#define SOUND_BUFFER_SIZE_SAMPLE        512
#define SOUND_BUFFER_NB                 128
#define SOUND_MAXVOICES_BUFFER_FX       256
#define SOUND_MAXMOD_CHANNELS           256
#define SOUND_VOICES_MAX_ACTIVE_CHIPS   8
#define MODIZER_OSCILLO_OFFSET_FIXEDPOINT 16

/* Voice/chipset grouping metadata (generic mute + grouping framework). */
#define MODIZ_MAX_CHIPS                 SOUND_VOICES_MAX_ACTIVE_CHIPS
#define MODIZ_CHIP_NAME_MAX_CHAR        16
#define MODIZ_VOICE_NAME_MAX_CHAR       16
#define MAXSID_CHIPS                    16
#define PM_BUFFER_SIZE                  (735 * 2)

#define DEFAULT_PLAYBACK_FREQ           44100

#endif /* REWAMP_MODIZER_CONSTANTS_H */

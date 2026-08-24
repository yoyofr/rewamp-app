#pragma once
/* Generated equivalent of SAASound's CMake configure_file(src/config.h.in)
 * for the rewamp vendored build (cmake + Apple podspec don't run SAASound's
 * own CMake). Values = SAASound defaults; USE_CONFIG_FILE left off so the
 * emulator never touches a SAASound.cfg on disk in an embedded player. */

#define EXTERNAL_CLK_HZ 8000000
/* #undef SAAFREQ_FIXED_CLOCKRATE */
#define SAMPLE_RATE_HZ 44100
#define DEFAULT_OVERSAMPLE 6
#define DEFAULT_UNBOOSTED_MULTIPLIER 11.3
#define DEFAULT_BOOST 1
/* #undef DEBUGSAA */
#define DEBUG_SAA_REGISTER_LOG "debugsaa.txt"
#define DEBUG_SAA_PCM_LOG "debugsaa.pcm"

/* #undef USE_CONFIG_FILE */
/* #undef CONFIG_FILE_PATH */

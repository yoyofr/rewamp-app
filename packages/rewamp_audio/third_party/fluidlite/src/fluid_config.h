/* fluid_config.h — pre-baked for rewamp (from src/fluid_config.cmake).
 * All rewamp targets are little-endian C99 platforms; SF3 disabled (SF2 only);
 * float (32-bit) sample pipeline. */

#define DEBUG 0

/* Version number of the package */
#define VERSION "1.2.2"

/* #undef WORDS_BIGENDIAN */

/* SF3 files support, using OGG/Vorbis */
#define SF3_DISABLED 0
#define SF3_XIPH_VORBIS 1
#define SF3_STB_VORBIS 2
#define SF3_SUPPORT SF3_DISABLED

/* if defined, the synth uses float (32 bit) samples, otherwise double */
#define WITH_FLOAT

/* Standard C99 headers detection */
#define HAVE_STRING_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STDIO_H 1
#define HAVE_STDARG_H 1
#define HAVE_MATH_H 1
#define HAVE_LIMITS_H 1
#define HAVE_FCNTL_H 1

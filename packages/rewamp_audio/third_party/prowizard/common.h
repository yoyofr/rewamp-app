/* Minimal stand-in for libxmp's internal common.h — see xmp.h in this dir. */
#ifndef REWAMP_PROWIZARD_COMMON_H
#define REWAMP_PROWIZARD_COMMON_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

typedef int8_t   int8;
typedef int16_t  int16;
typedef int32_t  int32;
typedef uint8_t  uint8;
typedef uint16_t uint16;
typedef uint32_t uint32;

#ifndef ARRAY_SIZE
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#endif

#ifndef MIN
#define MIN(a, b) ((a) < (b) ? (a) : (b))
#endif
#ifndef MAX
#define MAX(a, b) ((a) > (b) ? (a) : (b))
#endif

/* Debug trace: silent (the depackers are chatty by design). */
#define D_(...) do {} while (0)

#ifdef __cplusplus
extern "C" {
#endif

/* Big-endian helpers (libxmp's misc.c), implemented in pw_shim.c. */
static inline void write8(FILE *f, uint8 b) { fputc(b, f); }

uint16 readmem16b(const uint8 *);
uint32 readmem24b(const uint8 *);
uint32 readmem32b(const uint8 *);
void   write16b(FILE *, uint16);
void   write32b(FILE *, uint32);

#ifdef __cplusplus
}
#endif

#endif /* REWAMP_PROWIZARD_COMMON_H */

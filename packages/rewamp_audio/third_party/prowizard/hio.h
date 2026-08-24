/* Minimal stand-in for libxmp's internal hio.h — see xmp.h in this dir.
 *
 * rewamp only ever feeds ProWizard a whole file already in memory, so this is
 * a MEMORY-ONLY stream. Semantics match libxmp's: a read past the end returns
 * 0 / a short count and latches an error that hio_error() reads-and-clears
 * (the depackers bail on it, and pw_wizardry() checks it after depacking).
 */
#ifndef REWAMP_PROWIZARD_HIO_H
#define REWAMP_PROWIZARD_HIO_H

#include <stddef.h>
#include "common.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
	const unsigned char *start;
	long size;
	long pos;
	int error;
} HIO_HANDLE;

/* Not part of libxmp's API: rewamp's own constructor. */
void hio_open_mem(HIO_HANDLE *, const void *, long);

uint8  hio_read8   (HIO_HANDLE *);
uint16 hio_read16b (HIO_HANDLE *);
uint32 hio_read24b (HIO_HANDLE *);
uint32 hio_read32b (HIO_HANDLE *);
size_t hio_read    (void *, size_t, size_t, HIO_HANDLE *);
int    hio_seek    (HIO_HANDLE *, long, int);
long   hio_tell    (HIO_HANDLE *);
long   hio_size    (HIO_HANDLE *);
int    hio_error   (HIO_HANDLE *);
const unsigned char *hio_get_underlying_memory(HIO_HANDLE *);

#ifdef __cplusplus
}
#endif

#endif /* REWAMP_PROWIZARD_HIO_H */

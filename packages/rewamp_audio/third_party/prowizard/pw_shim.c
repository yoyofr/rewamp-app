/* rewamp: memory-only HIO stream + the big-endian helpers the vendored
 * ProWizard depackers expect from libxmp. See xmp.h in this directory. */

#include <errno.h>

#include "common.h"
#include "hio.h"

/* ---- big-endian helpers (libxmp misc.c) ---------------------------------- */

uint16 readmem16b(const uint8 *m)
{
	return ((uint16)m[0] << 8) | m[1];
}

uint32 readmem24b(const uint8 *m)
{
	return ((uint32)m[0] << 16) | ((uint32)m[1] << 8) | m[2];
}

uint32 readmem32b(const uint8 *m)
{
	return ((uint32)m[0] << 24) | ((uint32)m[1] << 16) |
	       ((uint32)m[2] << 8) | m[3];
}

void write16b(FILE *f, uint16 w)
{
	fputc(w >> 8, f);
	fputc(w & 0xff, f);
}

void write32b(FILE *f, uint32 w)
{
	fputc(w >> 24, f);
	fputc((w >> 16) & 0xff, f);
	fputc((w >> 8) & 0xff, f);
	fputc(w & 0xff, f);
}

/* ---- memory-only HIO ----------------------------------------------------- */

void hio_open_mem(HIO_HANDLE *h, const void *mem, long size)
{
	h->start = (const unsigned char *)mem;
	h->size = size;
	h->pos = 0;
	h->error = 0;
}

size_t hio_read(void *buf, size_t size, size_t num, HIO_HANDLE *h)
{
	size_t want, avail, got;

	if (size == 0 || num == 0) {
		return 0;
	}
	want = size * num;
	avail = (h->pos < h->size) ? (size_t)(h->size - h->pos) : 0;
	if (want > avail) {
		want = avail;
		h->error = EOF;
	}
	got = want / size;
	if (got) {
		memcpy(buf, h->start + h->pos, got * size);
		h->pos += (long)(got * size);
	}
	return got;
}

uint8 hio_read8(HIO_HANDLE *h)
{
	if (h->pos >= h->size) {
		h->error = EOF;
		return 0;
	}
	return h->start[h->pos++];
}

uint16 hio_read16b(HIO_HANDLE *h)
{
	uint16 a = hio_read8(h);
	uint16 b = hio_read8(h);
	return (a << 8) | b;
}

uint32 hio_read24b(HIO_HANDLE *h)
{
	uint32 a = hio_read16b(h);
	uint32 b = hio_read8(h);
	return (a << 8) | b;
}

uint32 hio_read32b(HIO_HANDLE *h)
{
	uint32 a = hio_read16b(h);
	uint32 b = hio_read16b(h);
	return (a << 16) | b;
}

int hio_seek(HIO_HANDLE *h, long offset, int whence)
{
	long target;

	switch (whence) {
	case SEEK_SET: target = offset; break;
	case SEEK_CUR: target = h->pos + offset; break;
	case SEEK_END: target = h->size + offset; break;
	default:
		h->error = EINVAL;
		return -1;
	}
	/* Seeking past the end is legal (like fseek); reading there is not. */
	if (target < 0) {
		h->error = EINVAL;
		return -1;
	}
	h->pos = target;
	return 0;
}

long hio_tell(HIO_HANDLE *h)
{
	return h->pos;
}

long hio_size(HIO_HANDLE *h)
{
	return h->size;
}

int hio_error(HIO_HANDLE *h)
{
	int error = h->error;
	h->error = 0;
	return error;
}

const unsigned char *hio_get_underlying_memory(HIO_HANDLE *h)
{
	return h->start;
}

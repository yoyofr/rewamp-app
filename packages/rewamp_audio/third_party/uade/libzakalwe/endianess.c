#include <zakalwe/endianess.h>

#include <string.h>

void z_read_floats_be(float *f, const void *_mem, const size_t n)
{
	size_t i;
	const uint8_t *mem = _mem;
	for (i = 0; i < n; i++) {
		uint32_t x = z_read_u32_be(mem);
		memcpy(&f[i], &x, sizeof f[i]);
		mem += sizeof(f[0]);
	}
}

void z_read_floats_le(float *f, const void *_mem, const size_t n)
{
	size_t i;
	const uint8_t *mem = _mem;
	for (i = 0; i < n; i++) {
		uint32_t x = z_read_u32_le(mem);
		memcpy(&f[i], &x, sizeof f[i]);
		mem += sizeof(f[0]);
	}
}

void z_write_floats_be(void *_mem, const float *values, const size_t n)
{
	size_t i;
	uint8_t *mem = _mem;
	for (i = 0; i < n; i++) {
		uint32_t value = * (const uint32_t *) &values[i];
		z_write_u32_be((uint32_t *) mem, value);
		mem += sizeof(values[0]);
	}
}

void z_write_floats_le(void *_mem, const float *values, const size_t n)
{
	size_t i;
	uint8_t *mem = _mem;
	for (i = 0; i < n; i++) {
		uint32_t value = * (const uint32_t *) &values[i];
		z_write_u32_le((uint32_t *) mem, value);
		mem += sizeof(values[0]);
	}
}

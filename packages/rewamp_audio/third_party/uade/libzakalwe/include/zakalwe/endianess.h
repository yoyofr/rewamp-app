#ifndef _Z_ENDIANESS_H_
#define _Z_ENDIANESS_H_

#include <stdint.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * You can use __[bl]e{16,32,64} integer types to annotate endianess.
 * This used as a documentation, i.e. a hint.
 */
#define __le16
#define __be16
#define __le32
#define __be32
#define __le64
#define __be64

void z_read_floats_be(float *f, const void *mem, const size_t n);
void z_read_floats_le(float *f, const void *mem, const size_t n);

static inline int16_t z_read_s16_be(const void *_data)
{
	const uint8_t *mem = (const uint8_t *) _data;
	return (((int16_t) mem[0]) << 8) | mem[1];
}

static inline int16_t z_read_s16_le(const void *_data)
{
	const uint8_t *mem = (const uint8_t *) _data;
	return (((int16_t) mem[1]) << 8) | mem[0];
}

static inline uint16_t z_read_u16_be(const void *data)
{
	return z_read_s16_be(data);
}

static inline uint16_t z_read_u16_le(const void *data)
{
	return z_read_s16_le(data);
}

static inline int32_t z_read_s32_be(const void *_data)
{
	const uint8_t *mem = (const uint8_t *) _data;
	return (
		(((int32_t) mem[0]) << 24) |
		(((int32_t) mem[1]) << 16) |
		(((int32_t) mem[2]) << 8) |
		mem[3]);
}

static inline int32_t z_read_s32_le(const void *_data)
{
	const uint8_t *mem = (const uint8_t *) _data;
	return (
		(((int32_t) mem[3]) << 24) |
		(((int32_t) mem[2]) << 16) |
		(((int32_t) mem[1]) << 8) |
		mem[0]);
}

static inline uint32_t z_read_u32_be(const void *data)
{
	return z_read_s32_be(data);
}

static inline uint32_t z_read_u32_le(const void *data)
{
	return z_read_s32_le(data);
}

static inline int64_t z_read_s64_be(const void *_data)
{
	const uint8_t *mem = (const uint8_t *) _data;
	uint32_t lsbs = z_read_s32_be(mem + 4);
	uint32_t msbs = z_read_s32_be(mem);
	return (((int64_t) msbs) << 32) + lsbs;
}

static inline int64_t z_read_s64_le(const void *_data)
{
	const uint8_t *mem = (const uint8_t *) _data;
	uint32_t lsbs = z_read_s32_le(mem);
	uint32_t msbs = z_read_s32_le(mem + 4);
	return (((int64_t) msbs) << 32) + lsbs;
}

static inline uint64_t z_read_u64_be(const void *data)
{
	return z_read_s64_be(data);
}

static inline uint64_t z_read_u64_le(const void *data)
{
	return z_read_s64_le(data);
}

static inline void z_write_u16_be(void *data, const uint16_t value)
{
	unsigned char *mem = (unsigned char *) data;
	mem[0] = (value >> 8) & 0xff;
	mem[1] = value & 0xff;
}

static inline void z_write_u16_le(void *data, const uint16_t value)
{
	unsigned char *mem = (unsigned char *) data;
	mem[0] = value & 0xff;
	mem[1] = (value >> 8) & 0xff;
}

static inline void z_write_u32_be(void *data, const uint32_t value)
{
	unsigned char *mem = (unsigned char *) data;
	mem[0] = (value >> 24) & 0xff;
	mem[1] = (value >> 16) & 0xff;
	mem[2] = (value >> 8) & 0xff;
	mem[3] = value & 0xff;
}

static inline void z_write_u32_le(void *data, const uint32_t value)
{
	unsigned char *mem = (unsigned char *) data;
	mem[0] = value & 0xff;
	mem[1] = (value >> 8) & 0xff;
	mem[2] = (value >> 16) & 0xff;
	mem[3] = (value >> 24) & 0xff;
}

static inline void z_write_u64_be(void *data, const uint64_t value)
{
	unsigned char *mem = (unsigned char *) data;
	unsigned int i;
	/* Note, we don't have to mask away bits from MSB of value */
	for (i = 0; i < 8; i++)
		mem[i] = (value >> (56 - i * 8)) & 0xff;
}

static inline void z_write_u64_le(void *data, const uint64_t value)
{
	unsigned char *mem = (unsigned char *) data;
	unsigned int i;
	/* Note, we don't have to mask away bits from MSB of value */
	for (i = 0; i < 8; i++)
		mem[i] = (value >> (i * 8)) & 0xff;
}

static inline void z_write_s16_be(void *data, const int16_t value)
{
	z_write_u16_be(data, value);
}
static inline void z_write_s16_le(void *data, const int16_t value)
{
	z_write_u16_le(data, value);
}
static inline void z_write_s32_be(void *data, const int32_t value)
{
	z_write_u32_be(data, value);
}
static inline void z_write_s32_le(void *data, const int32_t value)
{
	z_write_u32_le(data, value);
}
static inline void z_write_s64_be(void *data, const int64_t value)
{
	z_write_u64_be(data, value);
}
static inline void z_write_s64_le(void *data, const int64_t value)
{
	z_write_u64_le(data, value);
}

void z_write_floats_be(void *mem, const float *values, const size_t n);
void z_write_floats_le(void *mem, const float *values, const size_t n);

#ifdef __cplusplus
}
#endif

#endif

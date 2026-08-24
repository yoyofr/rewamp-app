#ifndef _Z_BITFIELD_H_
#define _Z_BITFIELD_H_

#include <zakalwe/base.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

struct z_random_state;

/* bit field used for boolean vectors */
struct z_bitfield {
	size_t n;
	unsigned char bits[];
};

/*
 * dst must not be equal to src0 or src1.
 * Result would overflow if return value is higher than length of dst.
 */
size_t z_bitfield_cat(struct z_bitfield *dst,
		      const struct z_bitfield *src0,
		      const struct z_bitfield *src1);
size_t z_bitfield_cat_many(struct z_bitfield *dst,
			   const struct z_bitfield **srcs,
			   const size_t n);
void z_bitfield_clear(struct z_bitfield *bf);
struct z_bitfield *z_bitfield_clone(const struct z_bitfield *bf);
int z_bitfield_copy(struct z_bitfield *dst, const struct z_bitfield *src);
struct z_bitfield *z_bitfield_copy_or_clone(struct z_bitfield *dst,
					    const struct z_bitfield *src);
int z_bitfield_copy_slice(struct z_bitfield *dst, const size_t dst_start,
			  const struct z_bitfield *src, const size_t src_start,
			  const size_t len);
/* Must be freed with z_bitfield_free() */
struct z_bitfield *z_bitfield_create(const size_t nbits);
struct z_bitfield *z_bitfield_create_from_args(int num, ...);

/*
 * Create 'n' bitfields each with size 'nbits'.
 *
 * It is permissible to rotate pointers inside resulting struct z_bitfield **.
 * This makes it possible to implement fast ring buffers by using this
 * creation primitive.
 *
 * Must be freed with z_bitfield_free_many.
 */
struct z_bitfield **z_bitfield_create_many(const size_t n, const size_t nbits);

/*
 * Returns 1 if bitfield a equals b, otherwise 0.
 *
 * Note, bitfield can have a different size. In this case 0 is returned.
 */
int z_bitfield_equals(const struct z_bitfield *a, const struct z_bitfield *b);

void z_bitfield_free(struct z_bitfield *bf);

#define z_bitfield_free_and_null(x) do { z_bitfield_free(x); (x) = NULL; } while (0)
#define z_bitfield_free_and_poison(x) do { z_bitfield_free(x); (x) = (void *) -1; } while (0)

/* It is valid to pass s == NULL. */
void z_bitfield_free_many(struct z_bitfield **s, const size_t n);

void z_bitfield_from_probability_vector(struct z_bitfield *bf, const float *p,
					struct z_random_state *state);
void z_bitfield_from_probability_vector(struct z_bitfield *bf, const float *p,
					struct z_random_state *state);

/* This function is unsafe: no bounds checking. Returns 0 or 1. */
static inline int z_bitfield_get_unsafe(const struct z_bitfield *bf,
					const size_t i)
{
	return (bf->bits[i >> 3] >> (i & 7)) & 1;
}

/*
 * This function is unsafe: no bounds checking. It must hold that (i % 8) <= 4.
 */
static inline int z_bitfield_get_4_bits_unsafe(const struct z_bitfield *bf,
					       const size_t i)
{
	return (bf->bits[i >> 3] >> (i & 7)) & 0xf;
}

/* Returns 0 or 1. */
static inline int z_bitfield_get(const struct z_bitfield *bf, const size_t i)
{
	z_assert(i < bf->n);
	return z_bitfield_get_unsafe(bf, i);
}

/*
 * Interpret bit field as an unsigned integer so that bit position 0 is the
 * least significant bit (LSB). Increases the value by one.
 */
void z_bitfield_increase_by_one(struct z_bitfield *bf);

/*
 * For bitfields a and b, return sum (a_i - b_i)^2 for all i.
 * If length of bitfields differs, the shorter one is zero expanded implicitly.
 */
double z_bitfield_l2_metric(const struct z_bitfield *a,
			    const struct z_bitfield *b);

static inline size_t z_bitfield_len(const struct z_bitfield *a)
{
	return a->n;
}

void z_bitfield_ones(struct z_bitfield *bf);

void z_bitfield_print(const char *prefix, const struct z_bitfield *bf,
		      const char *suffix);

void z_bitfield_randomize(struct z_bitfield *bf, struct z_random_state *state);

/*
 * x must be either 0 or 1, otherwise the bitfield will be corrupted.
 * This function is unsafe: no bounds checking.
 * Use z_bitfield_set() if you want safe semantics.
 */
static inline void z_bitfield_set_unsafe(struct z_bitfield *bf, const size_t i,
					 const int x)
{
	unsigned char mask = 1 << (i & 7);
	unsigned char byte = bf->bits[i >> 3];
	byte &= ~mask;
	byte |= x << (i & 7);
	bf->bits[i >> 3] = byte;
}

/* If x is non-zero, it represents bit "1". Otherwise it represents 0. */
static inline void z_bitfield_set(struct z_bitfield *bf, const size_t i,
				  const int x)
{
	z_assert(i < bf->n);
	z_bitfield_set_unsafe(bf, i, !!x);
}

/*
 * Insert 8 bits into the bitfield. i (bit offset) must be divisible by 8.
 * Bit 0 (least significant bit) of x becomes bit 0 of the bitfield.
 * Bit 1 becomes bit 1 of the bitfield, etc.
 *
 * Returns 0 (failure) if i is too big or is not divisible by 8.
 * Otherwise returns 1 (success).
 */
int z_bitfield_set_8_bits(struct z_bitfield *bf, const size_t i,
			  const unsigned char x);

/*
 * The number of variable arguments must match the dimension of bitfield.
 * It can not know how many parameters were actually given.
 * This function is unsafe: no bounds checking.
 */
void z_bitfield_set_from_args(struct z_bitfield *bf, ...);

void z_bitfield_to_float_array(float *f, const struct z_bitfield *bf);

/* It is permitted that a == b or b == c or a == b == c. */
int z_bitfield_xor(struct z_bitfield *c, const struct z_bitfield *a,
		   const struct z_bitfield *b);

#ifdef __cplusplus
}
#endif

#endif

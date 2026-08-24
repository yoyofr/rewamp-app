#include <zakalwe/base.h>
#include <zakalwe/bitfield.h>
#include <zakalwe/math.h>
#include <zakalwe/mem.h>
#include <zakalwe/random.h>

#include <stdarg.h>
#include <stdlib.h>
#include <string.h>

/* TODO: Audit: What is bitfield size is 0? */

static inline size_t z_bitfield_size_from_bits(const size_t nbits)
{
	return (nbits + 7) >> 3;
}

static inline size_t z_bitfield_size(const struct z_bitfield *bf)
{
	return z_bitfield_size_from_bits(bf->n);
}

void z_bitfield_clear(struct z_bitfield *bf)
{
	size_t bf_size = z_bitfield_size(bf);
	memset(bf->bits, 0, bf_size);
}

size_t z_bitfield_cat(struct z_bitfield *dst,
		    const struct z_bitfield *src0,
		    const struct z_bitfield *src1)
{
	size_t size;
	if (dst == src0 || dst == src1)
		return -1;
	if (!z_add2_size_t(&size, src0->n, src1->n))
		return -1;
	if (size > dst->n)
		return -1;
	z_bitfield_copy_slice(dst, 0, src0, 0, src0->n);
	z_bitfield_copy_slice(dst, src0->n, src1, 0, src1->n);
	return size;
}

size_t z_bitfield_cat_many(struct z_bitfield *dst,
			 const struct z_bitfield **srcs,
			 const size_t n)
{
	size_t i;
	size_t size = 0;
	size_t offset = 0;
	for (i = 0; i < n; i++) {
		if (srcs[i] == dst)
			return -1;
		if (!z_add2_size_t(&size, size, srcs[i]->n))
			return -1;
	}
	if (size > dst->n)
		return -1;
	for (i = 0; i < n; i++) {
		z_bitfield_copy_slice(dst, offset, srcs[i], 0, srcs[i]->n);
		offset += srcs[i]->n;
	}
	z_assert(offset == size);
	return size;
}

struct z_bitfield *z_bitfield_clone(const struct z_bitfield *bf)
{
	size_t bf_size = z_bitfield_size(bf);
	int ret;
	struct z_bitfield *newbf = malloc(sizeof(struct z_bitfield) + bf_size);
	if (newbf == NULL)
		return NULL;
	newbf->n = bf->n;
	ret = z_bitfield_copy(newbf, bf);
	z_assert(ret);
	return newbf;
}

int z_bitfield_copy(struct z_bitfield *dst, const struct z_bitfield *src)
{
	if (src->n != dst->n)
		return 0;
	memcpy(dst->bits, src->bits, z_bitfield_size(src));
	return 1;
}

struct z_bitfield *z_bitfield_copy_or_clone(struct z_bitfield *dst,
					const struct z_bitfield *src)
{
	if (dst == src)
		return dst;
	if (z_bitfield_copy(dst, src))
		return dst;
	return z_bitfield_clone(src);
}

int z_bitfield_copy_slice(struct z_bitfield *dst, size_t dst_start,
			const struct z_bitfield *src, size_t src_start,
			size_t len)
{
	size_t i;
	if (len == 0)
		return 1;
	if (src_start >= src->n || len > src->n || (src_start + len) > src->n)
		return 0;
	if (dst_start >= dst->n || len > dst->n || (dst_start + len) > dst->n)
		return 0;
	for (i = 0; i < len; i++) {
		const int bit = z_bitfield_get_unsafe(src, src_start + i);
		z_bitfield_set_unsafe(dst, dst_start + i, bit);
	}
	return 1;
}

/* TODO: Create a unit test */
void z_bitfield_increase_by_one(struct z_bitfield *bf)
{
	size_t i;
	for (i = 0; i < bf->n; i++) {
		unsigned char bit = z_bitfield_get(bf, i) ^ 1;
		z_bitfield_set(bf, i, bit);
		/*
		 * Break loop if there is no carry bit, i.e. bit didn't flip
		 * over to zero in the xor operation.
		 */
		if (bit)
			break;
	}
}

double z_bitfield_l2_metric(const struct z_bitfield *a, const struct z_bitfield *b)
{
	const size_t min_len = Z_MIN(z_bitfield_len(a), z_bitfield_len(b));
	const size_t max_len = Z_MAX(z_bitfield_len(a), z_bitfield_len(b));
	const struct z_bitfield *longer = (
		z_bitfield_len(a) >= z_bitfield_len(b)) ? a : b;
	size_t i;
	double s = 0.0;
	for (i = 0; i < min_len; i++)
		s += z_bitfield_get(a, i) ^ z_bitfield_get(b, i);
	for (; i < max_len; i++)
		s += z_bitfield_get(longer, i);
	return s;
}

void z_bitfield_ones(struct z_bitfield *bf)
{
	size_t bf_size = z_bitfield_size(bf);
	memset(bf->bits, -1, bf_size);
}

/* The bitfield must be freed with z_bitfield_free() */
struct z_bitfield *z_bitfield_create(size_t nbits)
{
	size_t bf_size = z_bitfield_size_from_bits(nbits);
	struct z_bitfield *bf = calloc(sizeof(struct z_bitfield) + bf_size, 1);
	if (bf == NULL)
		return NULL;
	bf->n = nbits;
	return bf;
}

/* The bitfields must be freed with z_bitfield_free_many() */
struct z_bitfield **z_bitfield_create_many(size_t n, size_t nbits)
{
	struct z_bitfield *bf;
	struct z_bitfield **s = calloc(n, sizeof bf);
	size_t i;
	if (s == NULL)
		return NULL;
	for (i = 0; i < n; i++) {
		s[i] = z_bitfield_create(nbits);
		if (s[i] == NULL)
			goto out;
	}

	return s;

out:
	z_bitfield_free_many(s, n);
	return NULL;
}

int z_bitfield_equals(const struct z_bitfield *a, const struct z_bitfield *b)
{
	size_t i;
	const size_t size = z_bitfield_size_from_bits(a->n);
	size_t memcmp_bytes;
	if (a->n != b->n)
		return 0;
	if (a->n == 0)
		return 1;
	z_assert(size > 0);
	memcmp_bytes = (a->n & 0x7) ? (size - 1) : size;
	if (memcmp(a->bits, b->bits, memcmp_bytes) != 0)
		return 0;
	i = a->n & (~0x7);
	z_assert((a->n & 0x7) == 0 || i < a->n);
	for (; i < a->n; i++) {
		if (z_bitfield_get_unsafe(a, i) !=
		    z_bitfield_get_unsafe(b, i))
			return 0;
	}
	return 1;
}

void z_bitfield_free(struct z_bitfield *bf)
{
	if (bf != NULL) {
		bf->n = 0;
		free(bf);
	}
}

void z_bitfield_free_many(struct z_bitfield **s, size_t n)
{
	size_t i;
	if (s == NULL)
		return;
	for (i = 0; i < n; i++)
		z_bitfield_free_and_poison(s[i]);
	z_free_and_poison(s);
}

struct z_bitfield *z_bitfield_create_from_args(int num, ...)
{
	va_list arguments;
	struct z_bitfield *bf;
	int x;
	if (num < 1)
		return NULL;
	bf = z_bitfield_create(num);
	if (bf == NULL)
		return NULL;
	va_start(arguments, num);
	for (x = 0; x < num; x++)
		z_bitfield_set(bf, x, va_arg(arguments, int));
	va_end(arguments);
	return bf;
}

void z_bitfield_from_probability_vector(struct z_bitfield *bf, const float *p,
				      struct z_random_state *state)
{
	size_t i;
	for (i = 0; i < bf->n; i++) {
		int activation = z_random_float(state) < p[i];
		z_bitfield_set(bf, i, activation);
	}
}

void z_bitfield_print(const char *prefix, const struct z_bitfield *bf,
		  const char *suffix)
{
	size_t pos;
	if (prefix != NULL)
		printf("%s", prefix);
	for (pos = 0; pos < bf->n; pos++) {
		printf("%d ", z_bitfield_get(bf, pos));
	}
	if (suffix != NULL)
		printf("%s", suffix);
}

void z_bitfield_randomize(struct z_bitfield *bf, struct z_random_state *state)
{
	size_t i;
	for (i = 0; i < bf->n; i++) {
		int bit = z_random_float(state) < 0.5;
		z_bitfield_set(bf, i, bit);
	}
}

int z_bitfield_set_8_bits(struct z_bitfield *bf, const size_t i,
			const unsigned char x)
{
	const size_t offset = i >> 3;
	if ((i + 7) >= bf->n || (i & 7) != 0)
		return 0;
	bf->bits[offset] = x;
	return 1;
}

void z_bitfield_set_from_args(struct z_bitfield *bf, ...)
{
	va_list arguments;
	size_t i;
	va_start(arguments, bf);
	for (i = 0; i < bf->n; i++)
		z_bitfield_set(bf, i, va_arg(arguments, int));
	va_end(arguments);
}

void z_bitfield_to_float_array(float *f, const struct z_bitfield *bf)
{
	size_t i;
	for (i = 0; i < bf->n; i++)
		f[i] = z_bitfield_get(bf, i);
}

int z_bitfield_xor(struct z_bitfield *c, const struct z_bitfield *a,
		 const struct z_bitfield *b)
{
	if (z_bitfield_len(a) != z_bitfield_len(b) ||
	    z_bitfield_len(b) != z_bitfield_len(c))
		return 0;
	if (a == b) {
		z_bitfield_clear(c);
	} else {
		size_t i;
		size_t bf_size = z_bitfield_size(c);
		for (i = 0; i < bf_size; i++)
			c->bits[i] = a->bits[i] ^ b->bits[i];
	}
	return 1;
}

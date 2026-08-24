#include <zakalwe/random.h>
#include <zakalwe/base.h>
#include <zakalwe/unix-support.h>

/* Lookup table of inverse cumulative normal distribution */
#include "norm_inv_table_65536.h"

#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <stdint.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>

#define RANDOM_BUFFER 4088

struct z_random_state {
	unsigned int pos;
	unsigned int size;
	char buf[RANDOM_BUFFER];
};

float z_lookup_normal_random_table(size_t i)
{
	const size_t maxi = (sizeof(_ccul_norm_inv_table) /
			     sizeof(_ccul_norm_inv_table[0]));
	z_assert(maxi == 65536);
	z_assert(i < maxi);
	return _ccul_norm_inv_table[i];
}

float z_fast_normal_random(struct z_random_state *randstate, float u, float s)
{
	const size_t maxi = (sizeof(_ccul_norm_inv_table) /
			     sizeof(_ccul_norm_inv_table[0]));
	uint32_t ri = z_random_uint32(randstate);
	size_t i = (((uint64_t) ri) * maxi) / (1ULL << 32);
	return u + z_lookup_normal_random_table(i) * s;
}

static void fill_random_state(struct z_random_state *state)
{
	ssize_t bytes;
	const ssize_t unit = sizeof(uint32_t);
	int fd = open("/dev/urandom", O_RDONLY);
	if (fd < 0)
		z_die("Could not open /dev/urandom: %s\n",
		      strerror(errno));
	bytes = z_atomic_read(fd, state->buf, sizeof state->buf);
	if (bytes < unit)
		z_die("Could not read enough random bytes.\n");
	close(fd);
	state->pos = 0;
	state->size = bytes;
}

uint32_t z_random_uint32(struct z_random_state *state)
{
	uint32_t x;
	const unsigned int unit_size = sizeof x;
	if ((state->pos + unit_size) > state->size)
		fill_random_state(state);
	memcpy(&x, &state->buf[state->pos], unit_size);
	state->pos += unit_size;
	return x;
}

uint64_t z_random_uint64(struct z_random_state *state)
{
	uint64_t x;
	const unsigned int unit_size = sizeof x;
	if ((state->pos + unit_size) > state->size)
		fill_random_state(state);
	memcpy(&x, &state->buf[state->pos], unit_size);
	state->pos += unit_size;
	return x;
}

int z_random_bool(struct z_random_state *state, const float p)
{
	if (p <= 0)
		return 0;
	if (p >= 1)
		return 1;
	return z_random_float(state) < p;
}

double z_random_double(struct z_random_state *state)
{
	uint64_t x = z_random_uint64(state);
	uint64_t ceiling = (1ULL) << 53;
	uint64_t mask = ceiling - 1;
	/* Take 53 bits with a mask. This fits a double. */
	double d = (x & mask);
	/* Ceiling has an exact presentation as a double for the division. */
	return d / ceiling;
}

float z_random_float(struct z_random_state *state)
{
	uint32_t x = z_random_uint32(state);
	double d = x;
	double ceiling = 0x100000000ull;
	return d / ceiling;
}

void z_random_permutation(size_t *order, const size_t n,
			struct z_random_state *state)
{
	size_t i;
	z_assert(n <= ((uint32_t) -1));

	for (i = 0; i < n; i++)
		order[i] = i;

	for (i = 0; i < n; i++) {
		uint32_t x = z_random_uint32(state);
		uint64_t left = n - i;
		uint64_t ri = i + ((x * left) >> 32);
		size_t tmp;
		z_assert(ri < n);
		tmp = order[i];
		order[i] = order[ri];
		order[ri] = tmp;
	}
}

size_t z_random_size_t(struct z_random_state *state)
{
	size_t x;
	const unsigned int unit_size = sizeof x;
	if ((state->pos + unit_size) > state->size)
		fill_random_state(state);
	memcpy(&x, &state->buf[state->pos], unit_size);
	state->pos += unit_size;
	return x;
}

/* TODO: Fix this function to not be limited to upper_bound of 1ULL << 53. */
size_t z_random_range_size_t(const size_t upper_bound, struct z_random_state *state)
{
	int exponent;
	size_t msb_shifted;
	size_t mask;
	size_t r;
	const uint64_t limit = 1ULL << 53;

	z_assert(upper_bound > 0);
	z_assert(upper_bound < limit);

	exponent = ilogb((double) upper_bound);
	z_assert(exponent >= 0);

	msb_shifted = (1ULL << exponent);
	if (msb_shifted == upper_bound) {
		/* upper_bound is a power of two. Need only one try. */
		return z_random_size_t(state) & (upper_bound - 1);
	}

	/*
	 * upper_bound is not a power of two. We round up upper_bound to the
	 * nearest power of two, and create a mask from it. We try random
	 * numbers and mask them until the value is less than upper bound.
	 */
	mask = (msb_shifted << 1) - 1;
	do {
		r = z_random_size_t(state) & mask;
	} while (r >= upper_bound);

	return r;
}


size_t z_random_size_t_by_weights(const float *weights, const size_t n,
				struct z_random_state *state)
{
	float s = 0.0;
	float threshold;
	size_t i;
	z_assert(n > 0);
	for (i = 0; i < n; i++)
		s += weights[i];
	threshold = s * z_random_float(state);
	z_assert(threshold >= 0);
	z_assert(threshold <= s);
	s = 0.0;
	for (i = 0; i < n; i++) {
		s += weights[i];
		if (s > threshold)
			return i;
	}
	/* Highly improbable, but possible */
	return n - 1;
}

struct z_random_state *z_random_create_state(void)
{
	struct z_random_state *state = calloc(1, sizeof state[0]);
	if (state == NULL)
		z_log_warning("Could not allocate memory for random_state\n");
	return state;
}

void z_random_float_vector_to_boolean(unsigned char *b, float *f, size_t n,
				    struct z_random_state *state)
{
	size_t i;
	for (i = 0; i < n; i++)
		b[i] = z_random_float(state) < f[i];
}

void z_random_free_state(struct z_random_state *state)
{
	free(state);
}

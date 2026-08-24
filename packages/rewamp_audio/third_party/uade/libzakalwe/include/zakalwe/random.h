#ifndef _Z_RANDOM_H_
#define _Z_RANDOM_H_

#include <stdio.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

struct z_random_state;

float z_lookup_normal_random_table(size_t i);
/* WARNING: this function can only return 65536 different values. */
float z_fast_normal_random(struct z_random_state *randstate, float u, float s);

/*
 * Returns 0 if p <= 0. Returns 1 if p >= 1.
 * When 0 < p < 1: Returns 1 with probability p, otherwise 0.
 * Note: random state is not used when p <= 0 or p >= 1.
 */
int z_random_bool(struct z_random_state *state, const float p);

/* Returns random double x so that 0 <= x < 1. */
double z_random_double(struct z_random_state *state);

void z_random_float_vector_to_boolean(unsigned char *b, float *f, size_t n,
				      struct z_random_state *state);
/* Returns random float x so that 0 <= x < 1. */
float z_random_float(struct z_random_state *state);

/*
 * Returns random integer i so that 0 <= i < n according to non-negative weights
 * in 'weights'.
 */
size_t z_random_size_t_by_weights(const float *weights, const size_t n,
				  struct z_random_state *state);

void z_random_permutation(size_t *order, const size_t n,
			struct z_random_state *state);
size_t z_random_size_t(struct z_random_state *state);

/*
 * Returns a uniform size_t x so that 0 <= x < upper_bound.
 *
 * Calling with upper_bound == 0 or upper bound >= (1ULL << 53) is a fatal
 * error. TODO: Improve this function to allow full range for the upper_bound.
 */
size_t z_random_range_size_t(const size_t upper_bound,
			   struct z_random_state *state);

/* It is valid to pass in NULL. */
void z_random_free_state(struct z_random_state *state);

uint32_t z_random_uint32(struct z_random_state *state);
uint64_t z_random_uint64(struct z_random_state *state);

struct z_random_state *z_random_create_state(void);

#ifdef __cplusplus
}
#endif

#endif

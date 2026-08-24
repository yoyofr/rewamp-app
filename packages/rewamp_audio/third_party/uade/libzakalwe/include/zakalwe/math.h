#ifndef _Z_MATH_UTIL_H_
#define _Z_MATH_UTIL_H_

#include <zakalwe/base.h>

#include <math.h>
#include <stdio.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Clamps x into range [a, b]. */
static inline float z_clamp_f(const float x, const float a, const float b)
{
	if (x < a)
		return a;
	if (x > b)
		return b;
	return x;
}

/* Clamps x into range [a, b]. */
static inline int32_t z_clamp_i32(const int32_t x, const int32_t a,
				  const int32_t b)
{
	if (x < a)
		return a;
	if (x > b)
		return b;
	return x;
}

static inline int z_float_equal(float x, float y, float eps)
{
	return fabsf(x - y) < eps;
}

float z_logistic_function_f(float x);
float z_logistic_function_derivative_f(float x);
float z_tanh_derivative_f(float x);

static inline float z_rectified_linear_activation_f(const float x)
{
	if (x < 0.0f)
		return 0.0f;
	return x;
}

static inline float z_rectified_linear_activation_derivative_f(const float x)
{
	if (x < 0.0f)
		return 0.0f;
	return 1;
}

/* It is permitted that result == &a or result == &b. */
static inline int z_add2_size_t(size_t *result, size_t a, size_t b)
{
	size_t s = a + b;
	if (s < a || s < b) {
		*result = 0;
		return 0;
	}
	*result = s;
	return 1;
}

/* It is permitted that result == &a or result == &b. */
static inline int z_mul2_size_t(size_t *result, size_t a, size_t b)
{
	size_t limit;
	/* Make a <= b so that ((size_t) -1) * 1 is correct */
	if (a > b) {
		size_t t = a;
		a = b;
		b = t;
	}
	z_assert(a <= b);
	if (b == 0) {
		*result = 0;
		return 1;
	}
	limit = ((size_t) - 1) / b;
	if (a > limit) {
		*result = 0;
		return 0;
	}
	*result = a * b;
	return 1;
}

int z_mul3_size_t(size_t *result, size_t a, size_t b, size_t c);

#ifdef __cplusplus
}
#endif

#endif

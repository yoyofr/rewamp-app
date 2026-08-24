#include <zakalwe/math.h>

#include <math.h>

float z_logistic_function_f(float x)
{
	/* logistic function value < 4.14E-8. Return zero. */
	if (x < -17)
		return 0.0f;

	/* logistic function value > (1.0 - 4.14E-8). Avoid overflow. */
	if (x > 17)
		return 1.0f;

	return 1.0f / (1.0f + expf(-x));
}

float z_logistic_function_derivative_f(float x)
{
	float logistic = z_logistic_function_f(x);
	return logistic * (1 - logistic);
}

float z_tanh_derivative_f(float x)
{
	float tanh_value = tanhf(x);
	return 1 - tanh_value * tanh_value;
}

int z_mul3_size_t(size_t *result, size_t a, size_t b, size_t c)
{
	if (!z_mul2_size_t(result, a, b)) {
		*result = 0;
		return 0;
	}
	if (!z_mul2_size_t(result, *result, c)) {
		*result = 0;
		return 0;
	}
	return 1;
}

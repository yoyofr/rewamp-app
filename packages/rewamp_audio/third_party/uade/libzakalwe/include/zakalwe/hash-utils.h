#ifndef _Z_HASH_UTILS_H_
#define _Z_HASH_UTILS_H_
/*
 * TODO: Python's string hash.
 */

#ifdef __cplusplus
extern "C" {
#endif

/* Python hash for integers. */
static inline long long z_long_long_hash(const long long value)
{
	if (value == -1)
		return -2;
	return value;
}

#ifdef __cplusplus
}
#endif

#endif

#ifndef _Z_TIME_UTIL_H_
#define _Z_TIME_UTIL_H_

#include <stdint.h>
#include <sys/time.h>

#ifdef __cplusplus
extern "C" {
#endif

double z_timeval_delta_and_set(struct timeval *tv);

/*
 * Computes tv1 - tv0. Returns a value in microseconds.
 * Returns INT64_MIN for invalid values or overflow.
 */
int64_t z_timeval_delta(const struct timeval *tv1,
			const struct timeval *tv0);

#ifdef __cplusplus
}
#endif

#endif

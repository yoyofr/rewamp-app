#include <zakalwe/base.h>
#include <zakalwe/time.h>

#include <errno.h>
#include <stdint.h>
#include <string.h>

int64_t z_timeval_delta(const struct timeval *tv1, const struct timeval *tv0)
{
	int64_t t0 = tv0->tv_sec;
	int64_t t1 = tv1->tv_sec;
	int usec0 = tv0->tv_usec;
	int usec1 = tv1->tv_usec;
	const int64_t max_secs = INT64_MAX / 1000000 - 1;
	if (t0 < 0 || t1 < 0)
		return INT64_MIN;
	if (t0 >= max_secs || t1 >= max_secs)
		return INT64_MIN;
	if (usec0 < 0 || usec0 >= 1000000)
		return INT64_MIN;
	if (usec1 < 0 || usec1 >= 1000000)
		return INT64_MIN;
	return (t1 - t0) * 1000000 + usec1 - usec0;
}

double z_timeval_delta_and_set(struct timeval *tv0)
{
	struct timeval tv1;
	double delta;

	if (gettimeofday(&tv1, NULL)) {
		z_log_warning("gettimeofday() failed: %s\n", strerror(errno));
		return 0.0;
	}

	if (tv0 == NULL)
		return ((double) tv1.tv_sec) + 0.000001 * tv1.tv_usec;

	delta = ((double) tv1.tv_sec) - tv0->tv_sec;
	delta += 0.000001 * (((double) tv1.tv_usec) - tv0->tv_usec);
	*tv0 = tv1;
	return delta;
}

#include <zakalwe/base.h>
#include <zakalwe/map.h>
#include <zakalwe/time.h>

#include <pthread.h>
#include <sys/time.h>

/* TODO: Do _z_every_n_secs separately for different identifiers. */

Z_SCALAR_MAP_PROTOTYPE(log_last_time_map, void *, struct timeval)

static pthread_mutex_t log_mutex = PTHREAD_MUTEX_INITIALIZER;
/* Hold permanent log state in log_last_time_map. Protected with log_mutex. */
static struct log_last_time_map log_last_time_map;

int _z_every_n_secs(const int secs, const void *p)
{
	int ret = 0;
	struct timeval log_new_time;
	struct timeval log_last_time;
	int64_t elapsed;

	z_assert(!gettimeofday(&log_new_time, NULL));

	z_assert(!pthread_mutex_lock(&log_mutex));

	log_last_time = log_last_time_map_get_default(
		&log_last_time_map, p, (struct timeval) {.tv_usec = 0});

	elapsed = z_timeval_delta(&log_new_time, &log_last_time) / 1000000;
	if (elapsed >= secs) {
		// Note: failing the set() does not matter much.
		log_last_time_map_set(&log_last_time_map, (void *) p,
				      log_new_time);
		ret = 1;
	}

	z_assert(!pthread_mutex_unlock(&log_mutex));
	return ret;
}

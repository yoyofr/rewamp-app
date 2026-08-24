#ifndef _Z_THREAD_UTIL_H_
#define _Z_THREAD_UTIL_H_

#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

struct task_runner;
struct task_runner_queue;

enum task_runner_mode {
	TASK_RUNNER_DEFAULT = 0,
	TASK_RUNNER_SEPARATE_CORES = 1,
	TASK_RUNNER_MAXIMUM_UTILIZATION = 2,
};

/* If num_threads == 0, use the number of cores available. */
struct task_runner *task_runner_create(size_t num_threads,
				       enum task_runner_mode mode);

void task_runner_free(struct task_runner *tr);
unsigned int task_runner_get_num_threads(const struct task_runner *tr);
unsigned int task_runner_get_num_cpu_threads(enum task_runner_mode mode);

/*
 * Same as task_runner_run_async, but does not return until all the tasks have
 * been computed. Returns the number of completed tasks through
 * size_t *completed.
 */
int task_runner_run_sync(size_t *completed, struct task_runner *tr, void *data,
			 size_t num_items,
			 int (*run)(void *data, size_t i, size_t num_items,
				    void *run_ctx),
			 void *run_ctx);

/*
 * Parameters of done():
 * - 'success' parameter is 0 if task_runner was not able to call run() properly
 *   for all tasks. Otherwise, the parameter is 1. This parameter must be
 *   tested in reliable code.
 *
 * - 'completed' parameter counts how many times run() was called.
 *   All calls of run are counted, even those that return 0.
 *
 * NOTES on run() function:
 * - run() function may call task_runner_run_async to issue new tasks to be
 *   computed. task_runner_run_sync may not be called.
 *
 * - if run() returns zero, task runner execution is discontinued as soon
 *   as possible. Specifically, if task number i returns 0, task j > i can
 *   still be executed due to parallelism. Returning zero is only informational
 *   to discontinue execution.
 *
 * NOTES on done() function:
 * - done() is always called, even if the task_runner_run_async() returns 0.
 *
 * - done() function may call task_runner_run_async to issue new tasks to be
 *   computed. task_runner_run_sync may not be called.
 *
 * - Other threads may already execute a run() function for a new queue while
 *   done() is being called to finish a previous queue.
 */
int task_runner_run_async(
	struct task_runner *tr, void *data, size_t num_items,
	int (*run)(void *data, size_t i, size_t num_items, void *run_ctx),
	void *run_ctx,
	void (*done)(int success, void *data, size_t completed,
		     size_t num_items, void *done_ctx),
	void *done_ctx);

#ifdef __cplusplus
}
#endif

#endif

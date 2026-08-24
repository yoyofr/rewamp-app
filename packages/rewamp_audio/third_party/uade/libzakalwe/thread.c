#include <zakalwe/next/thread.h>

#include <zakalwe/file.h>
#include <zakalwe/input.h>
#include <zakalwe/mem.h>
#include <zakalwe/base.h>

#include <assert.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

struct thread {
	int initialized;
	pthread_t thread;
};

struct task_runner_queue {
	struct task_runner_queue *next;
	void *data;
	size_t i;
	size_t num_items;
	int (*run)(void *data, size_t i, size_t num_items, void *run_ctx);
	void *run_ctx;
	void (*done)(int success, void *data, size_t completed,
		     size_t num_items, void *done_ctx);
	void *done_ctx;

	/*
	 * This is used as a per thread indicator to wait for a new queue.
	 * queue_id == tr->queue_id when a thread executes the
	 * current tr->queue. When the thread finishes executing items from
	 * tr->queue, it increments this by one and waits that tr->queue_id
	 * is also incremented by one.
	 */
	size_t queue_id;
};

struct task_runner {
	size_t num_threads;
	struct thread *threads;

	/* This is only used once for cleaning up the task queue */
	int terminate_now;

	/* This is used to abort tasks in a queue */
	int cancel_now;

	int cond_initialized;
	/*
	 * queue_mutex must be held while broadcasting this condition.
	 * queue_mutex must be held and passed when waiting for this condition.
	 * This condition must be broadcasted when queue is changed.
	 */
	pthread_cond_t cond;

	/*
	 * NOTE: queue_mutex and list_mutex must be locked in the order:
	 * 1. queue_mutex
	 * 2. list_mutex
	 */
	int list_mutex_initialized;
	/* list_mutex controls mutation of active_queues and free_queues */
	pthread_mutex_t list_mutex;

	int queue_mutex_initialized;
	/* queue_mutex controls access to queue */
	pthread_mutex_t queue_mutex;

	size_t num_threads_finished;
	size_t queue_id;

	struct task_runner_queue *active_queues;
	struct task_runner_queue *free_queues;

	struct task_runner_queue *queue;
};

struct task_runner_completed_status {
	size_t completed;
	pthread_mutex_t done_signaling_mutex;
};

struct ptuple {
	unsigned int processor_id;
	unsigned int core_id;
	unsigned int thread_id;
};

struct processors {
	unsigned int n;
	unsigned int n_alloc;
	struct ptuple *ptuples;
};

static int cond_broadcast(pthread_cond_t *cond)
{
	int thread_errno = pthread_cond_broadcast(cond);
	if (thread_errno)
		z_log_warning("cond_broadcast error: %s\n",
			    strerror(thread_errno));
	return thread_errno;
}

static int cond_destroy(pthread_cond_t *cond)
{
	int thread_errno = pthread_cond_destroy(cond);
	if (thread_errno)
		z_log_warning("cond_destroy error: %s\n", strerror(thread_errno));
	return thread_errno;
}

static int cond_init(pthread_cond_t *cond, const pthread_condattr_t *attr)
{
	int thread_errno = pthread_cond_init(cond, attr);
	if (thread_errno)
		z_log_warning("cond_init error: %s\n", strerror(thread_errno));
	return thread_errno;
}

static int cond_wait(pthread_cond_t *cond, pthread_mutex_t *mutex)
{
	int thread_errno = pthread_cond_wait(cond, mutex);
	if (thread_errno)
		z_log_warning("cond_wait error: %s\n", strerror(thread_errno));
	return thread_errno;
}

static int mutex_destroy(pthread_mutex_t *mutex)
{
	int thread_errno = pthread_mutex_destroy(mutex);
	if (thread_errno)
		z_log_warning("mutex_destroy error: %s\n",
			    strerror(thread_errno));
	return thread_errno;
}

static int mutex_init(pthread_mutex_t *mutex, const pthread_mutexattr_t *attr)
{
	int thread_errno = pthread_mutex_init(mutex, attr);
	if (thread_errno)
		z_log_warning("mutex_init error: %s\n", strerror(thread_errno));
	return thread_errno;
}

static int mutex_lock(pthread_mutex_t *mutex)
{
	int thread_errno = pthread_mutex_lock(mutex);
	if (thread_errno)
		z_log_warning("mutex_lock error: %s\n", strerror(thread_errno));
	return thread_errno;
}

static int mutex_unlock(pthread_mutex_t *mutex)
{
	int thread_errno = pthread_mutex_unlock(mutex);
	if (thread_errno)
		z_log_warning("mutex_unlock error: %s\n", strerror(thread_errno));
	return thread_errno;
}

static void free_processors(struct processors *processors)
{
	if (!processors)
		return;
	processors->n = -1;
	processors->n_alloc = -1;
	z_free_and_poison(processors->ptuples);
	free(processors);
}

static struct processors *read_processors(void)
{
	FILE *f = fopen("/proc/cpuinfo", "r");
	char line[256];
	char f1[64];
	char f2[64];
	char f3[64];
	char f4[64];
	int ret;
	int cur_core_id = -1;
	int is_int;
	struct processors *processors = calloc(1, sizeof processors[0]);

	if (f == NULL)
		goto error;
	if (processors == NULL)
		goto error;

	processors->n = 0;
	processors->n_alloc = 1;
	processors->ptuples = malloc(
		processors->n_alloc * sizeof processors->ptuples[0]);
	if (processors->ptuples == NULL)
		goto error;

	while (1) {
		if (!z_fgets(line, sizeof line, f))
			break;
		ret = sscanf(line, "%63s%63s%63s%63s", f1, f2, f3, f4);
		if (ret < 3)
			continue;
		if (strcmp(f1, "processor") == 0 &&
		    strcmp(f2, ":") == 0) {
			int processor_id = z_strtoll(&is_int, f3, 10);
			if (!is_int ||
			    processor_id < 0 || processor_id > 65535) {
				z_log_warning("Invalid processor id %s\n", f3);
				goto error;
			}
			/*
			 * We expect a sequence of processor ids:
			 * 0, 1, ..., n-1.
			 */
			if (((unsigned int) processor_id) != processors->n) {
				z_log_warning("Malformed /proc/cpuinfo: "
					    "processor numbers not in order. "
					    "%d follows %u\n",
					    processor_id, processors->n);
				goto error;
			}
			cur_core_id = -1;
			processors->n++;
			continue;
		}

		if (ret == 4 &&
		    strcmp(f1, "core") == 0 &&
		    strcmp(f2, "id") == 0 &&
		    strcmp(f3, ":") == 0) {
			int core_id = z_strtoll(&is_int, f4, 10);
			if (!is_int || core_id < 0) {
				z_log_warning("Invalid core id %s\n", f4);
				goto error;
			}
			if (processors->n == 0) {
				z_log_warning("Malformed /proc/cpuinfo: core id "
					    "comes before any processor id\n");
				goto error;
			}
			if (cur_core_id != -1) {
				z_log_warning("Malformed /proc/cpuinfo: two core "
					    "ids without a processor id in "
					    "between.");
				goto error;
			}
			if (processors->n >= processors->n_alloc) {
				struct ptuple *ptuples;
				processors->n_alloc = 2 * (processors->n + 1);
				ptuples = realloc(processors->ptuples,
						  processors->n_alloc * sizeof processors->ptuples[0]);
				if (ptuples == NULL)
					goto error;
				processors->ptuples = ptuples;
				ptuples = NULL;
			}
			assert(processors->n < processors->n_alloc);
			processors->ptuples[processors->n].core_id = core_id;
			cur_core_id = core_id;
		}
	}

	if (cur_core_id < 0) {
		z_log_warning("Malformed /proc/cpuinfo: no core id followed the "
			    "last processor id\n");
		goto error;
	}
	if (processors->n == 0) {
		z_log_warning("Malformed /proc/cpuinfo: 0 processors found\n");
		goto error;
	}

	z_atomic_fclose(f);
	return processors;

error:
	if (f)
		z_atomic_fclose(f);
	free_processors(processors);
	return NULL;
}

static int pick_processors(struct task_runner *tr,
			   size_t num_threads,
			   const struct processors *processors,
			   enum task_runner_mode mode)
{
	processors = processors;
	if (mode == TASK_RUNNER_DEFAULT) {
		if (num_threads == 0)
			num_threads = processors->n;
		tr->num_threads = num_threads;
	} else if (mode == TASK_RUNNER_SEPARATE_CORES) {
		z_log_warning("TASK_RUNNER_SEPARATE_CORES not implemented\n");
		return 0;
	} else if (mode == TASK_RUNNER_MAXIMUM_UTILIZATION) {
		z_log_warning("TASK_RUNNER_MAXIMUM_UTILIZATION not "
			    "implemented\n");
		return 0;
	} else {
		z_log_warning("Invalid task_runner mode %d\n", mode);
		return 0;
	}
	return 1;
}

static void set_queue(struct task_runner_queue *queue,
		      void *data, size_t num_items,
		      int (*run)(void *data, size_t i, size_t num_items,
				 void *run_ctx),
		      void *run_ctx,
		      void (*done)(int success, void *data, size_t completed,
				   size_t num_items, void *done_ctx),
		      void *done_ctx)
{
	queue->data = data;
	queue->i = 0;
	queue->num_items = num_items;
	queue->run = run;
	queue->run_ctx = run_ctx;
	queue->done = done;
	queue->done_ctx = done_ctx;
}

static struct task_runner_queue *pop_list_head(
	struct task_runner_queue **list_head)
{
	struct task_runner_queue *queue = *list_head;
	if (queue == NULL)
		return NULL;
	*list_head = queue->next;
	queue->next = NULL;
	return queue;
}

static void append_to_list(struct task_runner_queue **list_head,
			   struct task_runner_queue *queue)
{
	struct task_runner_queue *current = *list_head;
	/* Make sure queue has no follower */
	queue->next = NULL;
	if (current == NULL) {
		*list_head = queue;
	} else {
		while (current->next != NULL)
			current = current->next;
		current->next = queue;
	}
}

static int should_run_a_new_task(const struct task_runner_queue *queue)
{
	return queue->i < queue->num_items;
}

static void get_item_from_a_queue(struct task_runner_queue *action,
				  struct task_runner *tr)
{
	while (1) {
		if (should_run_a_new_task(tr->queue) && !tr->cancel_now) {
			action->data = tr->queue->data;
			action->i = tr->queue->i;
			tr->queue->i++;
			action->num_items = tr->queue->num_items;
			action->run = tr->queue->run;
			action->run_ctx = tr->queue->run_ctx;
			break;
		}

		if (action->queue_id != tr->queue_id)
			break;
		action->queue_id++;

		tr->num_threads_finished++;
		assert(tr->num_threads_finished <= tr->num_threads);

		if (tr->num_threads_finished == tr->num_threads) {
			/*
			 * All the items in the queue have been processed, and
			 * all the threads have come to get_action() to
			 * get more items.
			 *
			 * Free the queue's writer lock to indicate that the
			 * queue is completed and can be re-used.
			 */
			size_t completed = tr->queue->i;
			if (tr->queue->done != NULL) {
				action->data = tr->queue->data;
				action->done = tr->queue->done;
				action->done_ctx = tr->queue->done_ctx;
				action->i = completed;
				action->num_items = tr->queue->num_items;
			}
			tr->cancel_now = 0;
			tr->num_threads_finished = 0;
			tr->queue_id++;
			mutex_lock(&tr->list_mutex);

			/* Move queue to free queues and get a new queue */
			append_to_list(&tr->free_queues, tr->queue);
			tr->queue = pop_list_head(&tr->active_queues);

			mutex_unlock(&tr->list_mutex);
			if (tr->queue != NULL) {
				/*
				 * A new queue is broadcasted to other threads
				 * to start its execution. This thread
				 * may possibly call done() for the queue that
				 * was just finished.
				 */
				cond_broadcast(&tr->cond);
				if (action->done == NULL) {
					/*
					 * No need to call done(). Loop again
					 * to get an item from the new queue.
					 */
					continue;
				}
			}
		}
		break;
	}
}

/* queue_mutex must be locked before calling this */
static int get_action(struct task_runner_queue *action, struct task_runner *tr)
{
	action->done = NULL;
	action->run = NULL;

	while (!tr->terminate_now) {
		if (tr->queue != NULL) {
			get_item_from_a_queue(action, tr);
			if (action->done != NULL || action->run != NULL ||
			    tr->terminate_now)
				break;
		}
		cond_wait(&tr->cond, &tr->queue_mutex);
	}
	return tr->terminate_now;
}

/* This function is called when a new thread is created for running tasks */
static void *runner(void *_struct_task_runner)
{
	struct task_runner *tr = _struct_task_runner;
	struct task_runner_queue action = {
		.done = NULL,
		.run = NULL,
	};

	while (1) {
		int terminate_now;
		mutex_lock(&tr->queue_mutex);
		terminate_now = get_action(&action, tr);
		mutex_unlock(&tr->queue_mutex);

		if (terminate_now)
			break;

		/*
		 * Test if runner() state machine is broken.
		 * Either done() or run() should be non-NULL.
		 */
		z_assert((action.done != NULL) ^ (action.run != NULL));

		if (action.run != NULL) {
			if (!action.run(action.data, action.i, action.num_items,
					action.run_ctx)) {
				mutex_lock(&tr->queue_mutex);
				tr->cancel_now = 1;
				cond_broadcast(&tr->cond);
				mutex_unlock(&tr->queue_mutex);
			}
		} else {
			action.done(1, action.data, action.i, action.num_items,
				    action.done_ctx);
		}
	}
	return NULL;
}

static void clean_up_threads(struct task_runner *tr)
{
	unsigned int i;
	void *retval;
	int thread_errno;

	if (tr->queue_mutex_initialized) {
		/* We need to signal the threads to end, if any */
		mutex_lock(&tr->queue_mutex);
		tr->terminate_now = 1;
		cond_broadcast(&tr->cond);
		mutex_unlock(&tr->queue_mutex);
	}

	for (i = 0; i < tr->num_threads; i++) {
		if (!tr->threads[i].initialized)
			continue;
		thread_errno = pthread_join(tr->threads[i].thread, &retval);
		if (thread_errno) {
			z_log_warning("pthread_join returns an error: %s\n",
				    strerror(thread_errno));
		} else if (retval != NULL) {
			z_log_warning("Thread %u returns non-NULL value.\n", i);
		}
		/* Clear thread state. Set to not initialized. */
		memset(&tr->threads[i], 0, sizeof(tr->threads[i]));
	}
}

static struct task_runner_queue *create_queue(void)
{
	struct task_runner_queue *queue = calloc(1, sizeof queue[0]);
	return queue;
}

struct task_runner *task_runner_create(size_t num_threads,
				       enum task_runner_mode mode)
{
	struct task_runner *tr = calloc(1, sizeof tr[0]);
	struct processors *processors = read_processors();
	unsigned int i;

	if (tr == NULL || processors == NULL)
		goto error;

	if (!pick_processors(tr, num_threads, processors, mode))
		goto error;
	assert(tr->num_threads > 0);
	num_threads = tr->num_threads;

	free_processors(processors);
	processors = NULL;

	tr->threads = calloc(tr->num_threads, sizeof tr->threads[0]);
	if (tr->threads == NULL) {
		z_log_warning("Unable to allocate memory for threads\n");
		goto error;
	}

	if (mutex_init(&tr->list_mutex, NULL)) {
		z_log_warning("Unable to initialize list_mutex\n");
		goto error;
	}
	tr->list_mutex_initialized = 1;

	if (cond_init(&tr->cond, NULL)) {
		z_log_warning("Unable to initialize tr->cond\n");
		goto error;
	}
	tr->cond_initialized = 1;
	if (mutex_init(&tr->queue_mutex, NULL)) {
		z_log_warning("Unable to initialize tr->queue_mutex\n");
		goto error;
	}
	tr->queue_mutex_initialized = 1;

	tr->free_queues = create_queue();
	if (tr->free_queues == NULL) {
		z_log_warning("Unable to allocate memory for queue\n");
		goto error;
	}

	for (i = 0; i < tr->num_threads; i++) {
		int thread_errno = pthread_create(
			&tr->threads[i].thread, NULL, runner, tr);
		if (thread_errno) {
			z_log_warning("Unable to create a thread: %s\n",
				    strerror(thread_errno));
			goto error;
		}
		tr->threads[i].initialized = 1;
	}
	return tr;

error:
	task_runner_free(tr);
	free_processors(processors);
	return NULL;
}

static void free_list_nodes(struct task_runner_queue **list_head)
{
	struct task_runner_queue *queue = *list_head;
	*list_head = NULL;
	while (queue != NULL) {
		struct task_runner_queue *next = queue->next;
		z_free_and_null(queue);
		queue = next;
	}
}

static void clean_up_queues(struct task_runner *tr)
{
	free_list_nodes(&tr->free_queues);
	free_list_nodes(&tr->active_queues);
	z_free_and_null(tr->queue);
}

void task_runner_free(struct task_runner *tr)
{
	if (tr == NULL)
		return;
	/*
	 * clean_up_threads() must be done first as it stops all the threads
	 * that are using datastructures.
	 */
	clean_up_threads(tr);
	z_free_and_null(tr->threads);
	clean_up_queues(tr);
	if (tr->list_mutex_initialized)
		mutex_destroy(&tr->list_mutex);
	if (tr->cond_initialized)
		cond_destroy(&tr->cond);
	if (tr->queue_mutex_initialized)
		mutex_destroy(&tr->queue_mutex);
	memset(tr, 0, sizeof tr[0]);
	z_free_and_null(tr);
}

unsigned int task_runner_get_num_threads(const struct task_runner *tr)
{
	return tr->num_threads;
}

unsigned int task_runner_get_num_cpu_threads(enum task_runner_mode mode)
{
	struct processors *processors = read_processors();
	struct task_runner tr = {.num_threads = 0};
	int ret;
	if (processors == NULL)
		return 0;
	ret = pick_processors(&tr, 0, processors, mode);
	free_processors(processors);
	if (!ret)
		return 0;
	return tr.num_threads;
}

/*
 * list_mutex must be locked before calling this.
 * The returned queue is disconnected from all lists, so it must be either
 * freed or attached to a list.
 */
static struct task_runner_queue *get_queue(struct task_runner *tr)
{
	struct task_runner_queue *queue = pop_list_head(&tr->free_queues);
	if (queue == NULL)
		queue = create_queue();
	return queue;
}

/*
 * If 0 is returned, done() is called before returning 0 and success
 * parameter passed to done() is set to 0.
 */
int task_runner_run_async(
	struct task_runner *tr, void *data, size_t num_items,
	int (*run)(void *data, size_t i, size_t num_items, void *run_ctx),
	void *run_ctx,
	void (*done)(int success, void *data, size_t completed,
		     size_t num_items, void *done_ctx),
	void *done_ctx)
{
	struct task_runner_queue *queue;
	mutex_lock(&tr->list_mutex);
	queue = get_queue(tr);
	if (queue == NULL) {
		mutex_unlock(&tr->list_mutex);
		if (done != NULL)
			done(0, data, 0, num_items, done_ctx);
		return 0;
	}
	set_queue(queue, data, num_items, run, run_ctx, done, done_ctx);
	append_to_list(&tr->active_queues, queue);
	mutex_unlock(&tr->list_mutex);

	mutex_lock(&tr->queue_mutex);
	/* If no queue is being processed, start processing this one */
	if (tr->queue == NULL) {
		mutex_lock(&tr->list_mutex);
		tr->queue = pop_list_head(&tr->active_queues);
		mutex_unlock(&tr->list_mutex);
	}
	/* Notify all threads holding the lock that there is new tasks to run */
	cond_broadcast(&tr->cond);
	mutex_unlock(&tr->queue_mutex);

	return 1;
}

/*
 * This function is used to get the number of completed tasks for
 * task_runner_run_sync(). It is called when the synchronous tasks have all been
 * executed.
 */
static void run_sync_done(int success, void *data, size_t completed,
			  size_t num_items,
			  void *_struct_task_runner_completed_status)
{
	struct task_runner_completed_status *status =
		_struct_task_runner_completed_status;
	(void) success;
	(void) data;
	(void) num_items;
	status->completed = completed;
	mutex_unlock(&status->done_signaling_mutex);
}

/*
 * task_runner_run_sync guarantees that computation has completed when the
 * function returns. It does not guarantee ordering between calls.
 */
int task_runner_run_sync(size_t *completed, struct task_runner *tr, void *data,
			 size_t num_items,
			 int (*run)(void *data, size_t i, size_t num_items,
				    void *run_ctx),
			 void *run_ctx)
{
	struct task_runner_completed_status status = {
		.completed = 0,
	};
	*completed = 0;
	if (mutex_init(&status.done_signaling_mutex, NULL))
		return 0;
	mutex_lock(&status.done_signaling_mutex);
	if (!task_runner_run_async(tr, data, num_items, run, run_ctx,
				   run_sync_done, &status)) {
		/* mutex has already been unlocked in run_sync_done */
		mutex_destroy(&status.done_signaling_mutex);
		return 0;
	}

	mutex_lock(&status.done_signaling_mutex);
	mutex_unlock(&status.done_signaling_mutex);

	mutex_destroy(&status.done_signaling_mutex);
	*completed = status.completed;
	return 1;
}

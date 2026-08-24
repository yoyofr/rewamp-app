#ifndef _Z_MEM_UTIL_H_
#define _Z_MEM_UTIL_H_

#include <zakalwe/config.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

#define z_calloc_target(name) ((typeof((name)[0]) *) calloc(1, sizeof((name)[0])))
#define z_clone_items(items, nmemb, size) ((typeof((items)[0]) *) z_internal_clone_items((items), (nmemb), (size)))
#define z_clone_items_or_die(items, nmemb, size) ((typeof((items)[0]) *) z_internal_clone_items_or_die((items), (nmemb), (size)))
#define z_free_and_null(x) do { free(x); (x) = NULL; } while (0)
#define z_free_and_poison(x) do { free(x); (x) = (void *) -1; } while (0)
#define z_malloc_target(name) ((typeof((name)[0]) *) malloc(sizeof((name)[0])))

void *z_calloc_or_die(size_t nmemb, size_t size);
void *z_internal_clone_items(const void *items, size_t nmemb, size_t size);
void *z_internal_clone_items_or_die(const void *items, size_t nmemb, size_t size);
void *z_malloc_or_die(size_t size);

/* src and dst may overlap. */
void *z_copy_items(void *dst, const void *src, const size_t nmemb,
	           const size_t size);

static inline void *z_ptr_add(void *_ptr, const size_t bytes)
{
	unsigned char *ptr = (unsigned char *) _ptr;
	return ptr + bytes;
}

#ifdef _Z_NEED_REALLOCARRAY
/*
 * The naming of this function comes from OpenBSD. We don't provide this if the
 * operating system provides it (i.e. OpenBSD).
 */
void *reallocarray(void *ptr, size_t nmemb, size_t size);
#endif

void *z_reallocarray_or_die(void *ptr, size_t nmemb, size_t size);
int z_zero_items(void *ptr, const size_t nmemb, const size_t size);

/* May only be used for pointers. */
#define z_zero_target(name) ((typeof((name)[0]) *) memset(name, 0, sizeof((name)[0])))

#ifdef __cplusplus
}
#endif

#endif

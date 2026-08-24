#include <zakalwe/math.h>
#include <zakalwe/mem.h>
#include <zakalwe/base.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void *z_calloc_or_die(size_t nmemb, size_t size)
{
	void *mem = calloc(nmemb, size);
	if (mem == NULL && nmemb != 0 && size != 0)
		z_die("Can not allocate zeroed memory: nmemb %zu size %zu\n",
		      nmemb, size);
	return mem;
}

void *z_internal_clone_items(const void *items, size_t nmemb, size_t size)
{
	void *new_items = reallocarray(NULL, nmemb, size);
	if (new_items == NULL)
		return NULL;
	/* reallocarray() verified that the multiplication won't overflow */
	memcpy(new_items, items, nmemb * size);
	return new_items;
}

void *z_internal_clone_items_or_die(const void *items, size_t nmemb, size_t size)
{
	void *cloned_items = z_internal_clone_items(items, nmemb, size);
	if (cloned_items == NULL && nmemb != 0 && size != 0)
		z_die("Can not clone items: items %p nmemb %zu size %zu\n",
		      items, nmemb, size);
	return cloned_items;
}

void *z_malloc_or_die(size_t size)
{
	void *mem = malloc(size);
	if (mem == NULL && size != 0)
		z_die("malloc_or_die can not allocate memory: size %zu\n",
		      size);
	return mem;
}

void *z_copy_items(void *dst, const void *src, const size_t nmemb,
		   const size_t size)
{
	size_t total_size;
	if (!z_mul2_size_t(&total_size, nmemb, size))
		return NULL;
	return memmove(dst, src, total_size);
}

#ifdef _Z_NEED_REALLOCARRAY
void *reallocarray(void *ptr, size_t nmemb, size_t size)
{
	size_t total_size;
	if (!z_mul2_size_t(&total_size, nmemb, size))
		return NULL;
	return realloc(ptr, total_size);
}
#endif

void *z_reallocarray_or_die(void *ptr, size_t nmemb, size_t size)
{
	void *mem = reallocarray(ptr, nmemb, size);
	if (mem == NULL && nmemb != 0 && size != 0)
		z_die("Can not reallocate memory: ptr %p nmemb %zu size %zu\n",
		      ptr, nmemb, size);
	return mem;
}

int z_zero_items(void *ptr, const size_t nmemb, const size_t size)
{
	size_t total_size;
	if (!z_mul2_size_t(&total_size, nmemb, size))
		return 0;
	memset(ptr, 0, total_size);
	return 1;
}

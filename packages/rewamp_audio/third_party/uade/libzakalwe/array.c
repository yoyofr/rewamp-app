#include <zakalwe/array.h>
#include <zakalwe/base.h>
#include <zakalwe/math.h>
#include <zakalwe/mem.h>

/* This may only be called when the array is full. */
int _z_array_reserve(size_t *num_items, size_t *num_items_allocated,
		      void **items, const size_t item_size,
		      const size_t increase)
{
	size_t new_num_items;
	size_t new_num_items_allocated;
	void *new_items;
	if (!z_add2_size_t(&new_num_items, *num_items, increase))
		return 0;
	if (new_num_items <= *num_items_allocated)
		return 1;
	if (!z_mul2_size_t(&new_num_items_allocated, *num_items_allocated, 2))
		return 0;
	new_num_items_allocated = Z_MAX(new_num_items_allocated, new_num_items);
	z_assert(new_num_items_allocated > 0);

	new_items = reallocarray(*items, new_num_items_allocated, item_size);
	if (new_items == NULL)
		return 0;
	*items = new_items;
	*num_items_allocated = new_num_items_allocated;
	z_assert(*num_items < *num_items_allocated);
	return 1;
}

int _z_array_realloc(const size_t new_num_items_allocated,
		      size_t *num_items_allocated,
		      void **items,
		      const size_t item_size)
{
	void *new_items = reallocarray(*items, new_num_items_allocated,
				       item_size);
	if (new_items == NULL)
		return 0;
	*num_items_allocated = new_num_items_allocated;
	*items = new_items;
	return 1;
}

int _z_array_allocate(const size_t new_num_items,
		       size_t *num_items,
		       size_t *num_items_allocated,
		       void **items,
		       const size_t item_size)
{
	if (new_num_items <= *num_items) {
		*num_items = new_num_items;
		if (*num_items < (*num_items_allocated / 4)) {
			if (!_z_array_realloc(
				    *num_items_allocated / 2,
				    num_items_allocated,
				    items,
				    item_size)) {
				return 0;
			}
		}
		return 1;
	}
	if (new_num_items > *num_items_allocated) {
		if (!_z_array_realloc(new_num_items,
				       num_items_allocated,
				       items,
				       item_size)) {
			return 0;
		}
	}
	z_assert(new_num_items > *num_items);
	z_zero_items(z_ptr_add(*items, *num_items * item_size),
		     new_num_items - *num_items,
		     item_size);
	*num_items = new_num_items;
	return 1;
}

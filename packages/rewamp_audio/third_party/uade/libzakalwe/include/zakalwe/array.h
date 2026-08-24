#ifndef _Z_ARRAY_H_
#define _Z_ARRAY_H_

#include <zakalwe/base.h>
#include <zakalwe/math.h>
#include <zakalwe/mem.h>
#include <zakalwe/random.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

static inline void *z_array_util_double_if_needed(void *ptr,
						  const size_t num_members,
						  size_t *num_allocated,
						  const size_t size)
{
	size_t new_num_allocated;
	if (num_members < *num_allocated)
		return ptr;
	if (!z_mul2_size_t(&new_num_allocated, *num_allocated, 2))
		return NULL;
	new_num_allocated = Z_MAX(new_num_allocated, 1);
	ptr = reallocarray(ptr, new_num_allocated, size);
	if (ptr != NULL)
		*num_allocated = new_num_allocated;
	return ptr;
}

int _z_array_allocate(const size_t new_num_items,
		       size_t *num_items, size_t *num_items_allocated,
		       void **items, const size_t item_size);
int _z_array_realloc(const size_t new_num_items_allocated,
		      size_t *num_items_allocated,
		      void **items,
		      const size_t item_size);
int _z_array_reserve(size_t *num_items, size_t *num_items_allocated,
		      void **items, const size_t item_size,
		      const size_t increase);

/* Note: a zero initialized array is guaranteed to be a valid empty array. */
#define Z_EMPTY_ARRAY {.num_items_allocated = 0}

#define _Z_ARRAY_PROTOTYPE(name, type) \
struct name { \
	size_t num_items; \
	size_t num_items_allocated; \
	type *items; \
}; \
 \
struct name##_iter { \
	const struct name *array; \
	size_t i; /* You may access this. */ \
	type value; /* You may access this. */ \
	int reverse; \
}; \
 \
static inline void name##_deinit(struct name *array) \
{ \
	free(array->items); \
	memset(array, 0, sizeof(array[0])); \
} \
 \
static inline void name##_free(struct name *array) \
{ \
	if (array == NULL) \
		return; \
	name##_deinit(array); \
	free(array); \
} \
 \
static inline type name##_get(const struct name *array, const size_t i) \
{ \
	z_assert(i < array->num_items); \
	return array->items[i]; \
} \
 \
/* Follow python naming: choice. */ \
static inline type name##_choice(size_t *pos, const struct name *array, \
				 struct z_random_state *rs)		\
{ \
	const size_t i = z_random_range_size_t(array->num_items, rs); \
	if (pos != NULL) \
		*pos = i; \
	return name##_get(array, i); \
} \
 \
static inline type name##_get_unsafe(const struct name *array, const size_t i) \
{ \
	return array->items[i]; \
} \
 \
static inline type *name##_get_ptr(const struct name *array, const size_t i) \
{ \
	z_assert(i < array->num_items); \
	return &array->items[i]; \
} \
 \
static inline const type *name##_get_const_ptr(const struct name *array, \
					       const size_t i)           \
{ \
	z_assert(i < array->num_items); \
	return (const type *) &array->items[i]; \
} \
 \
static inline type *name##_get_ptr_unsafe(const struct name *array, \
					  const size_t i)	    \
{ \
	return &array->items[i]; \
} \
 \
/*
 * Zero initialization is a valid initialization for the array struct.
 * If you zero initialize the struct, you don't need to call init.
 * Note: deinit() must be called always.
 */ \
static inline void name##_init(struct name *array)	\
{ \
	memset(array, 0, sizeof(array[0])); \
} \
 \
static inline int name##_init2(struct name *array, const size_t len) \
{ \
	memset(array, 0, sizeof(array[0])); \
	array->items = (type *) calloc(len, sizeof(array->items[0]));	\
	if (array->items == NULL) \
		return 0; \
	array->num_items = len; \
	array->num_items_allocated = len; \
	return 1; \
} \
\
static inline struct name *name##_clone(const struct name *array) \
{ \
	struct name *new_array = z_calloc_target(new_array); \
	const size_t len = array->num_items; \
	const size_t bytes = len * sizeof(array->items[0]); \
	if (new_array == NULL) \
		return NULL; \
	if (len == 0) { \
		/* If len == 0, we don't need to allocate new_array->items. */ \
		return new_array; \
	} \
	new_array->items = (type *) malloc(bytes); \
	if (new_array->items == NULL) \
		return NULL; \
	memcpy(new_array->items, array->items, bytes); \
	new_array->num_items = len; \
	new_array->num_items_allocated = len; \
	return new_array; \
} \
 \
static inline struct name *name##_create(void) \
{ \
	struct name *array = z_calloc_target(array); \
	if (array == NULL) \
		return NULL; \
	name##_init(array); \
	return array; \
} \
 \
/*
 * Like init(), but creates an array with length len and the elements are zero
 * initialized.
 */ \
static inline struct name *name##_create2(const size_t len) \
{ \
	struct name *array = z_calloc_target(array); \
	if (array == NULL) \
		return NULL; \
	if (!name##_init2(array, len)) { \
		free(array); \
		return NULL; \
	} \
	return array; \
} \
 \
static inline size_t name##_len(const struct name *array) \
{ \
	return array->num_items; \
} \
 \
static inline void name##_begin(struct name##_iter *iter, \
				const struct name *array) \
{ \
	iter->array = array; \
	iter->i = 0; \
	iter->reverse = 0; \
} \
 \
static inline void name##_begin_last(struct name##_iter *iter, \
				     const struct name *array) \
{ \
	iter->array = array; \
	iter->i = name##_len(array) - 1; \
	iter->reverse = 1; \
} \
 \
static inline int name##_end(struct name##_iter *iter) \
{ \
	/* Note: this check also covers the case when i == (size_t) -1. */ \
	if (iter->i >= name##_len(iter->array)) \
		return 0; \
	iter->value = name##_get(iter->array, iter->i); \
	return 1; \
} \
 \
static inline void name##_next(struct name##_iter *iter) \
{ \
	if (iter->reverse) { \
		iter->i--; \
	} else { \
		iter->i++; \
	} \
} \
 \
static inline void name##_call(struct name *array, void (*func)(type item)) \
{ \
	size_t i; \
	for (i = 0; i < name##_len(array); i++) \
		func(name##_get_unsafe(array, i)); \
} \
 \
static inline int name##_compare_len(const struct name *array0, \
				     const struct name *array1) \
{ \
	const size_t len0 = name##_len(array0); \
	const size_t len1 = name##_len(array1); \
	if (len0 < len1) { \
		return -1; \
	} else if (len0 > len1) { \
		return 1; \
	} else { \
		return 0; \
	} \
} \
 \
static inline type name##_get_last(const struct name *array) \
{ \
	size_t len = name##_len(array); \
	z_assert(len > 0); \
	return name##_get_unsafe(array, len - 1); \
} \
 \
/* Note: Preserves the order of values in the array. */ \
static inline type name##_pop(struct name *array, const size_t pos) \
{ \
	/* Overflow check. */ \
	type ret = name##_get(array, pos); \
	size_t i; \
	for (i = pos; i < (array->num_items - 1); i++) { \
		array->items[i] = array->items[i + 1]; \
	} \
	array->num_items--; \
	if (array->num_items < (array->num_items_allocated / 4)) { \
		if (!_z_array_realloc(array->num_items_allocated / 2,	\
					&array->num_items_allocated, \
					(void **) &array->items, \
				         sizeof(array->items[0]))) { \
			z_log_warning("array shrinking failed.\n"); \
		} \
	} \
	return ret; \
} \
 \
/*
 * Remove element at pos, and inserts the last element of the array on its
 * place.
 */ \
static inline type name##_pop_fast(struct name *array, const size_t pos) \
{ \
	/* Overflow check. */ \
	type ret = name##_get(array, pos); \
	array->items[pos] = name##_get_unsafe(array, name##_len(array) - 1); \
	array->num_items--; \
	if (array->num_items < (array->num_items_allocated / 4)) { \
		if (!_z_array_realloc(array->num_items_allocated / 2, \
					&array->num_items_allocated, \
					(void **) &array->items, \
				         sizeof(array->items[0]))) { \
			z_log_warning("array shrinking failed.\n"); \
		} \
	} \
	return ret; \
} \
 \
/*
 * Removes the last element and returns it.
 */ \
static inline type name##_pop_last(struct name *array) \
{ \
	type ret; \
	z_assert(array->num_items > 0); \
	ret = name##_get_unsafe(array, array->num_items - 1); \
	array->num_items--; \
	if (array->num_items < (array->num_items_allocated / 4)) { \
		if (!_z_array_realloc(array->num_items_allocated / 2, \
					&array->num_items_allocated, \
					(void **) &array->items, \
				         sizeof(array->items[0]))) { \
			z_log_warning("array shrinking failed.\n"); \
		} \
	} \
	return ret; \
} \
 \
static inline void name##_reverse(struct name *array) \
{ \
	const size_t len = name##_len(array); \
	size_t i = 0; \
	size_t j; \
	if (len <= 1) \
		return; \
	j = len - 1; \
	for (; i < j; ) { \
		type left = name##_get_unsafe(array, i); \
		array->items[i] = name##_get_unsafe(array, j); \
		array->items[j] = left; \
		i++; \
		j--; \
	} \
} \
 \
static inline void name##_set(const struct name *array, const size_t i, \
			      type value) \
{ \
	z_assert(i < array->num_items); \
	array->items[i] = value; \
} \
 \
static inline void name##_set_unsafe(const struct name *array, const size_t i, \
				    type value) \
{ \
	array->items[i] = value; \
} \
 \
static inline void name##_shuffle(struct name *array, struct z_random_state *rs) \
{ \
	size_t i; \
	const size_t len = name##_len(array); \
	for (i = 0; i < len; i++) { \
		const size_t pos = z_random_range_size_t(len - i, rs); \
		type value0 = name##_get(array, i); \
		type valuepos = name##_get(array, i + pos); \
		name##_set(array, i, valuepos); \
		name##_set(array, i + pos, value0); \
	} \
} \
 \
/*
 * Rotate array right by one position. array[i] = array[(i + len - 1) % len],
 * where len is the length of the array.
 */ \
static inline void name##_rotate_right(struct name *array) \
{ \
	const size_t len = name##_len(array); \
	type last; \
	size_t i; \
	if (len == 0) \
		return; \
	last = name##_get_unsafe(array, len - 1); \
	for (i = len - 1; i > 0; i--) {	\
		name##_set_unsafe(array, i, name##_get_unsafe(array, i - 1)); \
	} \
	name##_set_unsafe(array, 0, last); \
} \
 \
/*
 * When the size of array increases, new elements are zero initialized in
 * memory.
 */ \
static inline int name##_truncate(struct name *array, const size_t num_items) \
{ \
	return _z_array_allocate(num_items, \
				  &array->num_items,			\
				  &array->num_items_allocated,		\
				  (void **) &array->items,		\
				  sizeof(array->items[0]));		\
} \
 \
static inline int name##_copy(struct name *dst, const struct name *src) \
{ \
	size_t i; \
	const size_t len = name##_len(src); \
	if (!name##_truncate(dst, len)) \
		return 0; \
	for (i = 0; i < len; i++) \
		name##_set_unsafe(dst, i, name##_get_unsafe(src, i)); \
	return 1; \
} \
 \
static inline int name##_append(struct name *array, type value) \
{ \
	if (array->num_items >= array->num_items_allocated && \
	    !_z_array_reserve(&array->num_items, \
			       &array->num_items_allocated,  \
			       (void **) &array->items,		\
			       sizeof(array->items[0]), \
			       1)) {			\
		return 0; \
	} \
	name##_set_unsafe(array, array->num_items, value); \
	array->num_items++; \
	return 1; \
} \
 \
/*
 * Inserts the given value (value) before the value at the given index (pos).
 * If pos >= array_len(array), inserts the value at the end, i.e. appends.
 * This is similar to python list's insert, but pos < 0 is not supported
 * because pos is an unsigned value.
 */	\
static inline int name##_insert(struct name *array, const size_t pos, \
				type value) \
{ \
	type *dst; \
	type *src; \
	const size_t len = name##_len(array); \
	size_t size; \
	if (array->num_items >= array->num_items_allocated && \
	    !_z_array_reserve(&array->num_items, \
			       &array->num_items_allocated,  \
			       (void **) &array->items,		\
			       sizeof(array->items[0]), \
			       1)) {			\
		return 0; \
	} \
	array->num_items++; \
	if (pos >= len) { \
		/* Insert at the end. Note: also the case when len == 0. */ \
		name##_set_unsafe(array, len, value); \
		return 1; \
	} \
	src = name##_get_ptr(array, pos); \
	dst = src + 1; \
	size = (len - pos) * sizeof(src[0]); \
	memmove(dst, src, size); \
	name##_set_unsafe(array, pos, value); \
	return 1; \
} \
 \
static inline int name##_extend(struct name *dst, const struct name *src) \
{ \
	const size_t src_len = name##_len(src); \
	size_t i; \
	if (!_z_array_reserve(&dst->num_items,\
			       &dst->num_items_allocated, \
			       (void **) &dst->items, \
			       sizeof(dst->items[0]), \
			       src_len)) {	      \
		return 0; \
	} \
	for (i = 0; i < src_len; i++) { \
		type value = name##_get_unsafe(src, i); \
		name##_set_unsafe(dst, dst->num_items + i, value); \
	} \
	dst->num_items += src_len; \
	return 1; \
} \
 \

/* END OF _Z_ARRAY_PROTOTYPE() */

#define _Z_ARRAY_SCALAR_OPERATOR(name, type) \
static inline size_t name##_count(struct name *array, const type value) \
{ \
	size_t i; \
	size_t count = 0; \
	for (i = 0; i < name##_len(array); i++) { \
		if (name##_get_unsafe(array, i) == value) { \
			count++; \
		} \
	} \
	return count; \
} \
 \
/* Note: it is valid that start_pos >= array length. */ \
static inline size_t name##_find(const struct name *array, const type value, \
				 const size_t start_pos) \
{ \
	size_t i; \
	for (i = start_pos; i < name##_len(array); i++) { \
		if (name##_get_unsafe(array, i) == value) \
			return i; \
	} \
	return -1; \
} \
 \
static inline size_t name##_replace(struct name *array, const type old_value, \
				    type new_value) \
{ \
	size_t i; \
	size_t num_replaced = 0; \
	for (i = 0; i < name##_len(array); i++) { \
		if (name##_get_unsafe(array, i) == old_value) { \
			array->items[i] = new_value; \
			num_replaced++; \
		} \
	} \
	return num_replaced; \
} \
 \
static inline void name##_sort(struct name *array, \
			       int (*compare)(const type *a, const type *b)) \
{ \
	qsort(array->items, array->num_items, sizeof(array->items[0]), \
	      (int (*)(const void *a, const void *b)) compare); \
} \
 \


#define _Z_ARRAY_COMPARE_FUNCTION(name, type, compare_f) \
static inline size_t name##_count(struct name *array, const type value) \
{ \
	size_t i; \
	size_t count = 0; \
        int (*compare)(const type *a, const type *b) = compare_f; \
	for (i = 0; i < name##_len(array); i++) { \
		if (!compare(name##_get_ptr_unsafe(array, i), &value)) \
			count++; \
	} \
	return count; \
} \
 \
/* Note: it is valid that start_pos >= array length. */ \
static inline size_t name##_find(const struct name *array, const type value, \
	                         const size_t start_pos) \
{ \
	size_t i; \
        int (*compare)(const type *a, const type *b) = compare_f; \
	for (i = start_pos; i < name##_len(array); i++) { \
		if (!compare(name##_get_ptr_unsafe(array, i), &value)) \
			return i; \
	} \
	return -1; \
} \
 \
static inline size_t name##_replace(struct name *array, const type old_value, \
				    type new_value) \
{ \
	size_t i; \
	size_t num_replaced = 0; \
        int (*compare)(const type *a, const type *b) = compare_f; \
	for (i = 0; i < name##_len(array); i++) { \
		if (!compare(name##_get_ptr_unsafe(array, i), &old_value)) { \
			array->items[i] = new_value; \
			num_replaced++; \
		} \
	} \
	return num_replaced; \
} \
 \
static inline void name##_sort(struct name *array) \
{ \
        int (*compare)(const type *a, const type *b) = compare_f; \
	qsort(array->items, array->num_items, sizeof(array->items[0]), \
	      (int (*)(const void *a, const void *b)) compare); \
} \
 \


#define Z_ARRAY_PROTOTYPE(name, type) \
_Z_ARRAY_PROTOTYPE(name, type) \
_Z_ARRAY_SCALAR_OPERATOR(name, type)


/*
 * Use ARRAY_COMPARE_PROTOTYPE if the type is a struct (not struct *) or you
 * want a complex comparison for count, find, replace methods. Note, you may
 * pass compare_f as NULL, but then you can not use count, find, replace or
 * sort.
 */
#define Z_ARRAY_COMPARE_PROTOTYPE(name, type, compare_f) \
_Z_ARRAY_PROTOTYPE(name, type) \
_Z_ARRAY_COMPARE_FUNCTION(name, type, compare_f)


#define _Z_PAIR_ARRAY_PROTOTYPE(name, type0, type1) \
 \
struct _z_pair_##name { \
        type0 value0; \
        type1 value1; \
}; \
 \
struct name { \
	size_t num_items; \
	size_t num_items_allocated; \
	struct _z_pair_##name *items; \
}; \
 \
static inline void name##_deinit(struct name *array) \
{ \
	free(array->items); \
	memset(array, 0, sizeof(array[0])); \
} \
 \
static inline void name##_free(struct name *array) \
{ \
	if (array == NULL) \
		return; \
	name##_deinit(array); \
	free(array); \
} \
 \
static inline type0 name##_get0(const struct name *array, const size_t i) \
{ \
	z_assert(i < array->num_items); \
	return array->items[i].value0; \
} \
 \
static inline type0 name##_get0_unsafe(const struct name *array, \
				       const size_t i)		 \
{ \
	return array->items[i].value0; \
} \
 \
static inline type1 name##_get1(const struct name *array, const size_t i) \
{ \
	z_assert(i < array->num_items); \
	return array->items[i].value1; \
} \
 \
static inline type1 name##_get1_unsafe(const struct name *array, \
				       const size_t i)		 \
{ \
	return array->items[i].value1; \
} \
 \
static inline size_t name##_len(const struct name *array) \
{ \
	return array->num_items; \
} \
 \
/* Note: it is valid that start_pos >= array length. */ \
static inline size_t name##_find0(const struct name *array, const type0 value, \
				  const size_t start_pos) \
{ \
	size_t i; \
	for (i = start_pos; i < name##_len(array); i++) { \
		if (name##_get0_unsafe(array, i) == value) \
			return i; \
	} \
	return -1; \
} \
 \
/* Note: it is valid that start_pos >= array length. */ \
static inline size_t name##_find1(const struct name *array, const type1 value, \
				  const size_t start_pos) \
{ \
	size_t i; \
	for (i = start_pos; i < name##_len(array); i++) { \
		if (name##_get1_unsafe(array, i) == value) \
			return i; \
	} \
	return -1; \
} \
 \
/*
 * Zero initialization is a valid initialization for the array struct.
 * If you zero initialize the struct, you don't need to call init.
 * Note: deinit() must be called always.
 */ \
static inline void name##_init(struct name *array) \
{ \
	memset(array, 0, sizeof(array[0])); \
} \
\
static inline struct name *name##_create(void) \
{ \
	struct name *array = z_calloc_target(array); \
	if (array == NULL) \
		return NULL; \
	name##_init(array); \
	return array; \
} \
 \
static inline void name##_set(const struct name *array, const size_t i, \
			      type0 value0, type1 value1) \
{ \
	z_assert(i < array->num_items); \
	array->items[i].value0 = value0; \
	array->items[i].value1 = value1; \
} \
 \
static inline void name##_set0(const struct name *array, const size_t i, \
			       type0 value0) \
{ \
	z_assert(i < array->num_items); \
	array->items[i].value0 = value0; \
} \
 \
static inline void name##_set1(const struct name *array, const size_t i, \
			      type1 value1) \
{ \
	z_assert(i < array->num_items); \
	array->items[i].value1 = value1; \
} \
 \
static inline void name##_set_unsafe(const struct name *array, const size_t i, \
				     type0 value0, type1 value1) \
{ \
	array->items[i].value0 = value0; \
	array->items[i].value1 = value1; \
} \
 \
/*
 * When the size of array increases, new elements are zero initialized in
 * memory.
 */ \
static inline int name##_truncate(struct name *array, const size_t num_items) \
{ \
	return _z_array_allocate(num_items, \
				  &array->num_items,			\
				  &array->num_items_allocated,		\
				  (void **) &array->items,		\
				  sizeof(array->items[0]));		\
} \
 \
static inline int name##_append(struct name *array, type0 value0, \
				type1 value1)			  \
{ \
	if (array->num_items >= array->num_items_allocated && \
	    !_z_array_reserve(&array->num_items, \
			       &array->num_items_allocated,  \
			       (void **) &array->items,		\
			       sizeof(array->items[0]), \
			       1)) {			\
		return 0; \
	} \
	name##_set_unsafe(array, array->num_items, value0, value1); \
	array->num_items++; \
	return 1; \
} \
 \
static inline int name##_extend(struct name *dst, const struct name *src) \
{ \
	const size_t src_len = name##_len(src); \
	size_t i; \
	if (!_z_array_reserve(&dst->num_items,\
			       &dst->num_items_allocated, \
			       (void **) &dst->items, \
			       sizeof(dst->items[0]), \
			       src_len)) {	      \
		return 0; \
	} \
	for (i = 0; i < src_len; i++) { \
		type0 value0 = name##_get0_unsafe(src, i); \
		type1 value1 = name##_get1_unsafe(src, i); \
		name##_set_unsafe(dst, dst->num_items + i, value0, value1); \
	} \
	dst->num_items += src_len; \
	return 1; \
} \
 \

/* END OF _Z_PAIR_ARRAY_PROTOTYPE() */

#define Z_PAIR_ARRAY_PROTOTYPE(name, type0, type1) \
_Z_PAIR_ARRAY_PROTOTYPE(name, type0, type1)


/*
 * array_for_each(array_type, array, iter) can be used like this:
 *
 * struct array_type *array;
 * struct array_type_iter iter;
 *
 * z_array_for_each(array_type, array, &iter) {
 *         f(iter.value);
 * }
 *
 * where
 *
 *     array_type is the struct name of the array,
 *     array is the pointer to array, and
 *     iter is the pointer to struct name##_iter.
 *
 * Alternatively, you can directly use the iterators if you want to embed the
 * iteration state into your own datastructure:
 *
 * for (array_type_begin(&iter, array);
 *      array_type_end(&iter);
 *      array_type_next(&iter)) {
 *         f(iter.value);
 * }
 */
#define z_array_for_each(name, array, iter)   \
	for (name##_begin((iter), (array)); \
	     name##_end(iter);              \
	     name##_next(iter))

/*
 * Same as array_for_each() but iterates the array in reverse order.
 * Similarly, you can use the iterators directly:
 *
 * for (array_type_begin_last(&iter, array);
 *      array_type_end(&iter);
 *      array_type_next(&iter)) {
 *         f(iter.value);
 * }
 */
#define z_array_for_each_reverse(name, array, iter)  \
	for (name##_begin_last((iter), (array));   \
	     name##_end(iter);                     \
	     name##_next(iter))

#ifdef __cplusplus
}
#endif

#endif

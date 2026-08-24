#ifndef _Z_MAP_H_
#define _Z_MAP_H_

#include <zakalwe/array.h>
#include <zakalwe/base.h>
#include <zakalwe/mem.h>
#include <zakalwe/tree.h>
#include <stddef.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * name: The struct name for the map. E.g. 'foo' implies that 'struct foo' is
 *       the type for the map.
 * key_type: Type for keys.
 * value_type: Type for values.
 * compare: Comparison function for key_type with the following prototype:
 *              int compare(key_type a, key_type b)
 *          Should return value < 0 when a < b, 0 when a == b and value > 0 when
 *          a > b. This is similar to the compare function for qsort(), but
 *          type-safe.
 */
#define Z_MAP_PROTOTYPE(name, key_type, value_type, compare) \
 \
struct _z_map_node_##name { \
	key_type key; \
	value_type value; \
	RB_ENTRY(_z_map_node_##name) node; \
}; \
 \
static inline int _z_compare_nodes_##name(struct _z_map_node_##name *a, \
					   struct _z_map_node_##name *b) \
{ \
	return compare(a->key, b->key); \
} \
 \
RB_HEAD(_z_tree_##name, _z_map_node_##name); \
 \
Z_ARRAY_PROTOTYPE(_z_map_node_array_##name, struct _z_map_node_##name *); \
 \
struct name { \
	struct _z_tree_##name tree; \
	size_t len; \
	struct _z_map_node_array_##name free_nodes; \
	void (*cleanup_key)(key_type key); \
	void (*cleanup_value)(value_type value); \
}; \
 \
struct name##_iter { \
	struct _z_map_node_##name *next; \
	struct _z_map_node_##name *nextnext; \
	key_type key; \
	value_type value; \
	int reverse; \
}; \
 \
RB_PROTOTYPE(_z_tree_##name, _z_map_node_##name, node, \
             _z_compare_nodes_##name)			 \
 \
static inline struct _z_map_node_##name *name##_internal_get( \
	const struct name *map, const key_type key) \
{ \
	struct _z_map_node_##name key_node = {.key = (key_type) key}; \
	return RB_FIND(_z_tree_##name, \
		       (struct _z_tree_##name *) &map->tree, &key_node); \
} \
 \
static inline void name##_begin(struct name##_iter *iter, \
				const struct name *map) \
{ \
	struct _z_tree_##name *tree = (struct _z_tree_##name *) &map->tree; \
	iter->next = RB_MIN(_z_tree_##name, tree); \
	iter->reverse = 0; \
} \
 \
static inline void name##_begin_last(struct name##_iter *iter, \
				     const struct name *map)   \
{ \
	struct _z_tree_##name *tree = (struct _z_tree_##name *) &map->tree; \
	iter->next = RB_MAX(_z_tree_##name, tree); \
	iter->reverse = 1; \
} \
 \
static inline int name##_end(struct name##_iter *iter) \
{ \
	if (iter->next == NULL) \
		return 0; \
	if (iter->reverse) { \
		iter->nextnext = _z_tree_##name##_RB_PREV(iter->next); \
	} else { \
		iter->nextnext = _z_tree_##name##_RB_NEXT(iter->next); \
	} \
	iter->key = iter->next->key; \
	iter->value = iter->next->value; \
	return 1; \
} \
 \
static inline void name##_next(struct name##_iter *iter) \
{ \
	iter->next = iter->nextnext; \
} \
 \
static inline struct _z_map_node_##name *name##_internal_alloc( \
	struct name *map)					 \
{ \
	struct _z_map_node_##name *node; \
	if (_z_map_node_array_##name##_len(&map->free_nodes) > 0) { \
		return _z_map_node_array_##name##_pop_last(&map->free_nodes); \
	} \
	return z_calloc_target(node); \
} \
 \
static inline void name##_init(struct name *map) \
{ \
	RB_INIT(&map->tree); \
	_z_map_node_array_##name##_init(&map->free_nodes); \
} \
 \
static inline struct name *name##_create(void) \
{ \
	struct name *map = z_calloc_target(map); \
	if (map == NULL) \
		return NULL; \
	name##_init(map); \
	return map; \
} \
 \
static inline void name##_append_to_free_nodes( \
	struct name *map, struct _z_map_node_##name *node) \
{ \
	/*
	 * If we can't append the node into free_nodes list,
	 * we just free it.
	*/ \
	if (!_z_map_node_array_##name##_append(&map->free_nodes, node)) \
		free(node); \
} \
 \
static inline void name##_cleanup_node( \
	struct _z_map_node_##name *node, \
	void (*cleanup_key)(key_type key), \
	void (*cleanup_value)(value_type value)) \
{ \
	if (cleanup_key != NULL) \
		cleanup_key(node->key); \
	if (cleanup_value != NULL) \
		cleanup_value(node->value); \
} \
 \
static inline void name##_cleanup_keys(struct name *map, \
				       void (*cleanup_key)(key_type key)) \
{ \
	map->cleanup_key = cleanup_key; \
} \
 \
static inline void name##_cleanup_values( \
	struct name *map, \
	void (*cleanup_value)(value_type value)) \
{ \
	map->cleanup_value = cleanup_value; \
} \
 \
static inline void name##_pop_current(struct name *map, \
				      struct name##_iter *iter) \
{ \
	struct _z_map_node_##name *node = iter->next; \
	z_assert(node != NULL); \
	z_assert(RB_REMOVE(_z_tree_##name, &map->tree, node) == node); \
	name##_cleanup_node(node, map->cleanup_key, map->cleanup_value); \
	z_zero_target(node); \
	free(node); \
} \
 \
/* Remove all nodes from the map. */ \
static inline void name##_clear(struct name *map) \
{ \
	struct name##_iter iter; \
	for (name##_begin(&iter, map); \
	     name##_end(&iter); \
	     name##_next(&iter)) { \
		name##_pop_current(map, &iter); \
	} \
} \
 \
static inline void name##_deinit(struct name *map) \
{ \
	size_t i; \
	name##_clear(map); \
	for (i = 0; i < _z_map_node_array_##name##_len(&map->free_nodes); i++) \
		free(_z_map_node_array_##name##_get(&map->free_nodes, i)); \
 \
	_z_map_node_array_##name##_deinit(&map->free_nodes); \
 \
	z_zero_target(map);			\
} \
 \
/* It is permitted that map == NULL. */ \
static inline void name##_free(struct name *map) \
{ \
	if (map != NULL) {			\
		name##_deinit(map);		\
		free(map);			\
	}					\
} \
 \
static inline value_type name##_get(const struct name *map, \
				    const key_type key) \
{ \
	const struct _z_map_node_##name *node = name##_internal_get(map, key); \
	z_assert(node != NULL); \
	return node->value; \
} \
 \
static inline value_type name##_get_default( \
	const struct name *map, const key_type key, value_type def) \
{ \
	const struct _z_map_node_##name *node = name##_internal_get(map, key); \
	if (node == NULL) \
		return def; \
	return node->value; \
} \
 \
static inline int name##_get_2(value_type *value, const struct name *map, \
			       const key_type key) \
{ \
	const struct _z_map_node_##name *node = name##_internal_get(map, key); \
	if (node == NULL) \
		return 0; \
	*value = node->value; \
	return 1; \
} \
 \
static inline int name##_has(const struct name *map, const key_type key) \
{ \
	return name##_internal_get(map, key) != NULL; \
} \
 \
static inline size_t name##_len(const struct name *map) \
{ \
	return map->len; \
} \
 \
static inline value_type name##_pop(struct name *map, key_type key) \
{ \
	struct _z_map_node_##name *node = name##_internal_get(map, key); \
	value_type value; \
	z_assert(node != NULL); \
	value = node->value; \
	z_assert(RB_REMOVE(_z_tree_##name, &map->tree, node) == node); \
	name##_cleanup_node(node, map->cleanup_key, map->cleanup_value); \
	z_zero_target(node); \
	name##_append_to_free_nodes(map, node); \
	return value; \
} \
 \
static inline int name##_pop_2(value_type *value, struct name *map, \
			       const key_type key) \
{ \
	struct _z_map_node_##name *node = name##_internal_get(map, key); \
	if (node == NULL) \
		return 0; \
	*value = node->value; \
	z_assert(RB_REMOVE(_z_tree_##name, &map->tree, node) == node); \
	name##_cleanup_node(node, map->cleanup_key, map->cleanup_value); \
	z_zero_target(node); \
	name##_append_to_free_nodes(map, node); \
	return 1; \
} \
 \
/*
 * The set function takes ownership of the key and the value. I.e. you may have
 * to allocate memory and duplicate them before setting a key-value.
 */ \
static inline int name##_set(struct name *map, key_type key, value_type value) \
{ \
	struct _z_map_node_##name *node = name##_internal_get(map, key); \
	if (node != NULL) { \
		/*
		 * map takes ownership of key variable, so we must free it,
		 * if necessary.
		 */ \
		if (map->cleanup_key != NULL) { \
			z_assert(key != node->key); \
			map->cleanup_key(key); \
		} \
		if (map->cleanup_value != NULL) \
			map->cleanup_value(node->value); \
		/* Overwrites the value, i.e. memory may be leaked. */ \
		node->value = value; \
		return 1; \
	} \
	node = name##_internal_alloc(map); \
	if (node == NULL) \
		return 0; \
	node->key = key; \
	node->value = value; \
	z_assert(RB_INSERT(_z_tree_##name, &map->tree, node) == NULL); \
	map->len++; \
	return 1; \
} \
 \
static inline int name##_set_2(struct name *map, key_type key, \
			       value_type value, \
			       int *did_replace, value_type *replaced_value) \
{ \
	struct _z_map_node_##name *node = name##_internal_get(map, key); \
	if (did_replace != NULL) \
		*did_replace = (node != NULL);	\
	if (node != NULL) { \
		/*
		 * map takes ownership of key variable, so we must free it,
		 * if necessary.
		 */ \
		if (map->cleanup_key != NULL) { \
			z_assert(key != node->key); \
			map->cleanup_key(key); \
		} \
		if (map->cleanup_value != NULL) \
			map->cleanup_value(node->value); \
		/* Note: *replaced_value must not be used if it was cleaned */ \
		*replaced_value = node->value; \
		node->value = value; \
		return 1; \
	} \
	node = name##_internal_alloc(map); \
	if (node == NULL) \
		return 0; \
	node->key = key; \
	node->value = value; \
	z_assert(RB_INSERT(_z_tree_##name, &map->tree, node) == NULL); \
	map->len++; \
	return 1; \
} \
 \
RB_GENERATE(_z_tree_##name, _z_map_node_##name, node, _z_compare_nodes_##name) \

/*
 * z_map_for_each() can be used like this:
 *
 * struct map_type *map;
 * struct map_type_iter iter;
 *
 * z_map_for_each(map_type, map, &iter) {
 *         f(iter.key, iter.value);
 * }
 *
 * where
 *
 *     name is the struct name of the map,
 *     map is the pointer to map, and
 *     iter is the pointer to struct name##_iter.
 *
 * Alternatively, you can directly use the iterators if you want to embed the
 * iteration state into your own datastructure:
 *
 * for (map_type_begin(&iter, map);
 *      map_type_end(&iter);
 *      map_type_next(&iter)) {
 *         f(iter.key, iter.value);
 * }
 */
#define z_map_for_each(name, map, iter)     \
	for (name##_begin((iter), (map)); \
	     name##_end(iter);            \
	     name##_next(iter))

/*
 * Same as z_map_for_each() but iterates the map in reverse order.
 * Similarly, you can use the iterators directly:
 *
 * for (map_type_begin_last(&iter, map);
 *      map_type_end(&iter);
 *      map_type_next(&iter)) {
 *         f(iter.key, iter.value);
 * }
 */
#define z_map_for_each_reverse(name, map, iter)  \
	for (name##_begin_last((iter), (map)); \
	     name##_end(iter);                 \
	     name##_next(iter))


/* END OF Z_MAP_PROTOTYPE() */

/*
 * You can initialize a map or a scalar map with EMPTY_MAP on the stack.
 * You must deallocate the (scalar) map by using the deinit function. Example:
 *
 * Z_MAP_PROTOTYPE(map, char *, int, compare)
 *
 * void f(void) {
 *   struct map m = EMPTY_MAP;
 *   use(&m);
 *   map_deinit(&m);
 * }
 *
 * Note: This is a hack. We exploit the fact the RB_INIT defined by tree.h
 * only sets the root pointer to NULL, thus zero initialization is ok.
 */
#define Z_EMPTY_MAP {.len = 0}


/*
 * Same as Z_MAP_PROTOTYPE, but keys are always comparable scalar types:
 * integers, floats or pointer types. You don't need to define a compare
 * function.
 */
#define Z_SCALAR_MAP_PROTOTYPE(name, key_type, value_type) \
 \
static inline int _z_scalar_key_compare_##name(const key_type a, \
						const key_type b) \
{ \
	if (a < b) \
		return -1; \
	if (b < a) \
		return 1; \
	return 0; \
} \
 \
Z_MAP_PROTOTYPE(name, key_type, value_type, _z_scalar_key_compare_##name)

/* END OF Z_SCALAR_MAP_PROTOTYPE */

#ifdef __cplusplus
}
#endif

#endif

#ifndef _Z_DIGRAPH_H_
#define _Z_DIGRAPH_H_

#include <zakalwe/base.h>
#include <zakalwe/tree.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * struct digraph_opaque_{edge|node} pointer is used to point to the user
 * specified edge/node structure without the internal implementation knowing
 * anything about the contents except the offset digraph_{edge|node}
 * inside it. This is done for type-safety. There is no actual definition
 * for this struct.
 */
struct digraph_opaque_edge;
struct digraph_opaque_node;

struct digraph {
	size_t num_allocated;
	/*
	 * Pointer to user-specified node structure. This is not a pointer to
	 * struct digraph_node.
	 */
	struct digraph_opaque_node **nodes;
	size_t edge_offset;
	size_t node_offset;
	size_t num_nodes;
	size_t num_edges;
};

struct digraph_edge {
	size_t src;
	size_t dst;
	RB_ENTRY(digraph_edge) out_edge;
	RB_ENTRY(digraph_edge) in_edge;
};

RB_HEAD(digraph_in_edges, digraph_edge);
RB_HEAD(digraph_out_edges, digraph_edge);

struct digraph_node {
	struct digraph_out_edges out_edges;
	struct digraph_in_edges in_edges;
	size_t index;
	size_t num_in_edges;
	size_t num_out_edges;
};

struct digraph_opaque_reclaim {
	/* free_edge must be a no-op if edge == NULL. */
	void (*free_edge)(struct digraph_opaque_edge *edge, void *edge_data);
	void *edge_data;
	/* free_node must be a no-op if edge == NULL. */
	void (*free_node)(struct digraph_opaque_node *node, void *node_data);
	void *node_data;
};

struct digraph_node_iterator {
	size_t index;
	const struct digraph *digraph;
};

struct digraph_edge_iterator {
	struct digraph_edge *cur;
	struct digraph_edge *next;
};

int digraph_compare_in_edge(struct digraph_edge *a, struct digraph_edge *b);
int digraph_compare_out_edge(struct digraph_edge *a, struct digraph_edge *b);
int digraph_internal_alloc(size_t *alloc_index, struct digraph *digraph,
			   const size_t num_nodes);
void *digraph_internal_create(const size_t num_allocated,
			      const size_t edge_offset,
			      const size_t node_offset);
void digraph_internal_free(struct digraph *digraph,
			   const struct digraph_opaque_reclaim *reclaim);

/* in edge iterator functions */
void digraph_internal_in_edge_iterator(struct digraph_edge_iterator *iterator,
				       struct digraph_node *node);
int digraph_internal_in_edge_iterator_cur(
	struct digraph_edge **edge, struct digraph_edge_iterator *iterator);
void digraph_internal_in_edge_iterator_next(
	struct digraph_edge_iterator *iterator);

/* node iterator functions */
void digraph_internal_node_iterator(struct digraph_node_iterator *iterator,
				    struct digraph *digraph);
int digraph_internal_node_iterator_cur(
	struct digraph_opaque_node **node,
	struct digraph_node_iterator *iterator);
void digraph_internal_node_iterator_next(
	struct digraph_node_iterator *iterator);

/* out edge iterator functions */
void digraph_internal_out_edge_iterator(struct digraph_edge_iterator *iterator,
					struct digraph_node *node);
int digraph_internal_out_edge_iterator_cur(
	struct digraph_edge **edge, struct digraph_edge_iterator *iterator);
void digraph_internal_out_edge_iterator_next(
	struct digraph_edge_iterator *iterator);

struct digraph_edge *digraph_internal_remove_edge(
	struct digraph *digraph,
	struct digraph_node *src_node,
	struct digraph_node *dst_node);
int digraph_internal_remove_node(
	struct digraph *digraph,
	const size_t index,
	const struct digraph_opaque_reclaim *reclaim);
int digraph_internal_remove_node_edges(
	struct digraph *digraph,
	const size_t index,
	const struct digraph_opaque_reclaim *reclaim);
int digraph_internal_rename_node(
	struct digraph *digraph, const size_t old_index,
	const size_t new_index);
int digraph_internal_set_edge(struct digraph *digraph,
			      const size_t src_index,
			      const size_t dst_index,
			      struct digraph_opaque_edge *edge);
int digraph_internal_set_node(struct digraph *digraph,
			      const size_t index,
			      struct digraph_opaque_node *node);

RB_PROTOTYPE(digraph_in_edges, digraph_edge, in_edge, compare_in_edge);
RB_PROTOTYPE(digraph_out_edges, digraph_edge, out_edge, compare_out_edge);

/* *_set_node Returns 0 if node index already exists in the graph. */
#define DIGRAPH_PROTOTYPE(digraph_struct_name, edge_struct_name, edge_field_name, node_struct_name, node_field_name) \
struct digraph_struct_name { \
	struct digraph digraph; \
}; \
 \
struct digraph_struct_name##_reclaim { \
	/* free_edge must be a no-op if edge == NULL. */ \
	void (*free_edge)(struct edge_struct_name *edge, void *edge_data); \
	void *edge_data; \
	/* free_node must be a no-op if edge == NULL. */ \
	void (*free_node)(struct node_struct_name *node, void *node_data); \
	void *node_data; \
}; \
 \
static inline struct digraph_opaque_edge * \
digraph_struct_name##_digraph_cast_to_opaque_edge( \
	struct edge_struct_name *edge) \
{ \
	return (struct digraph_opaque_edge *) edge; \
} \
 \
static inline struct digraph_opaque_node * \
digraph_struct_name##_digraph_cast_to_opaque_node( \
	struct node_struct_name *node) \
{ \
	return (struct digraph_opaque_node *) node; \
} \
 \
static inline const struct digraph_opaque_reclaim * \
digraph_struct_name##_digraph_const_cast_to_opaque_reclaim( \
	const struct digraph_struct_name##_reclaim *reclaim) \
{ \
	return (const struct digraph_opaque_reclaim *) reclaim; \
} \
 \
static inline struct node_struct_name * \
digraph_struct_name##_digraph_cast_to_user_node( \
	struct digraph_opaque_node *node) \
{ \
	return (struct node_struct_name *) node; \
} \
 \
static inline struct edge_struct_name * \
digraph_struct_name##_digraph_internal_to_user_edge( \
	const struct digraph_edge *edge) \
{ \
	if (edge == NULL) \
		return NULL; \
	return z_container_of(edge, struct edge_struct_name, \
			      edge_field_name);		     \
} \
 \
static inline int digraph_struct_name##_digraph_alloc( \
	size_t *alloc_index, struct digraph_struct_name *digraph, \
	const size_t num_nodes) \
{ \
	return digraph_internal_alloc(alloc_index, &digraph->digraph, \
				      num_nodes); \
} \
 \
static inline struct digraph_struct_name * \
digraph_struct_name##_digraph_create(const size_t num_allocated) \
{ \
	const size_t edge_offset = offsetof(struct edge_struct_name, \
					    edge_field_name); \
	const size_t node_offset = offsetof(struct node_struct_name, \
					    node_field_name); \
	return digraph_internal_create(num_allocated, edge_offset, \
				       node_offset); \
} \
 \
static inline void digraph_struct_name##_digraph_free( \
	struct digraph_struct_name *digraph, \
	const struct digraph_struct_name##_reclaim *reclaim) \
{ \
	if (digraph == NULL) \
		return; \
	digraph_internal_free( \
		&digraph->digraph, \
		digraph_struct_name##_digraph_const_cast_to_opaque_reclaim(reclaim)); \
} \
 \
static inline struct node_struct_name * \
digraph_struct_name##_digraph_get_node( \
	const struct digraph_struct_name *digraph, const size_t index) \
{ \
	if (index >= digraph->digraph.num_allocated) \
		return NULL; \
	return digraph_struct_name##_digraph_cast_to_user_node( \
		digraph->digraph.nodes[index]); \
} \
 \
static inline struct edge_struct_name * \
digraph_struct_name##_digraph_get_edge( \
	const struct digraph_struct_name *digraph, \
	const size_t src_index,	\
	const size_t dst_index) \
{ \
	struct digraph_edge key = {.dst = dst_index}; \
	struct node_struct_name *src_node = ( \
		digraph_struct_name##_digraph_get_node(digraph, src_index)); \
	struct digraph_edge *edge; \
	if (src_node == NULL) \
		return NULL; \
	edge = RB_FIND(digraph_out_edges, \
		       &src_node->node_field_name.out_edges, \
		       &key); \
	return digraph_struct_name##_digraph_internal_to_user_edge(edge); \
} \
 \
static inline void digraph_struct_name##_digraph_in_edge_iterator( \
	struct digraph_edge_iterator *iterator, \
	struct node_struct_name *node) \
{ \
	digraph_internal_in_edge_iterator(iterator, &node->node_field_name); \
} \
 \
static inline int digraph_struct_name##_digraph_in_edge_iterator_cur( \
	struct edge_struct_name **edge, \
	struct digraph_edge_iterator *iterator) \
{ \
	struct digraph_edge *internal_edge; \
	int ret = digraph_internal_in_edge_iterator_cur( \
		&internal_edge, iterator); \
	*edge = digraph_struct_name##_digraph_internal_to_user_edge( \
		internal_edge); \
	return ret; \
} \
 \
static inline void digraph_struct_name##_digraph_in_edge_iterator_next( \
	struct digraph_edge_iterator *iterator) \
{ \
	digraph_internal_in_edge_iterator_next(iterator); \
} \
 \
static inline void digraph_struct_name##_digraph_node_iterator( \
	struct digraph_node_iterator *iterator, \
	struct digraph_struct_name *digraph) \
{ \
	digraph_internal_node_iterator(iterator, &digraph->digraph); \
} \
 \
static inline int digraph_struct_name##_digraph_node_iterator_cur( \
	struct node_struct_name **node, \
	struct digraph_node_iterator *iterator) \
{ \
	struct digraph_opaque_node *opaque_node; \
	int ret = digraph_internal_node_iterator_cur(&opaque_node, iterator); \
	*node = digraph_struct_name##_digraph_cast_to_user_node(opaque_node); \
	return ret; \
} \
 \
static inline void digraph_struct_name##_digraph_node_iterator_next( \
	struct digraph_node_iterator *iterator) \
{ \
	digraph_internal_node_iterator_next(iterator); \
} \
 \
static inline size_t digraph_struct_name##_digraph_num_allocated( \
	const struct digraph_struct_name *digraph) \
{ \
	return digraph->digraph.num_allocated; \
} \
 \
static inline size_t digraph_struct_name##_digraph_num_edges( \
	const struct digraph_struct_name *digraph) \
{ \
	(void) digraph; \
	abort(); \
} \
 \
static inline size_t digraph_struct_name##_digraph_num_nodes( \
	const struct digraph_struct_name *digraph) \
{ \
	return digraph->digraph.num_nodes; \
} \
 \
static inline void digraph_struct_name##_digraph_out_edge_iterator( \
	struct digraph_edge_iterator *iterator, \
	struct node_struct_name *node) \
{ \
	digraph_internal_out_edge_iterator(iterator, &node->node_field_name); \
} \
 \
static inline int digraph_struct_name##_digraph_out_edge_iterator_cur( \
	struct edge_struct_name **edge, \
	struct digraph_edge_iterator *iterator) \
{ \
	struct digraph_edge *internal_edge; \
	int ret = digraph_internal_out_edge_iterator_cur( \
		&internal_edge, iterator); \
	*edge = digraph_struct_name##_digraph_internal_to_user_edge( \
		internal_edge); \
	return ret; \
} \
 \
static inline void digraph_struct_name##_digraph_out_edge_iterator_next( \
	struct digraph_edge_iterator *iterator) \
{ \
	digraph_internal_out_edge_iterator_next(iterator); \
} \
 \
static inline void digraph_struct_name##_digraph_reclaim_free_edge( \
	struct edge_struct_name *edge, void *data) \
{ \
	(void) data; \
	free(edge); \
} \
 \
static inline void digraph_struct_name##_digraph_reclaim_free_node( \
	struct node_struct_name *node, void *data) \
{ \
	(void) data; \
	free(node); \
} \
 \
static inline struct edge_struct_name * \
digraph_struct_name##_digraph_remove_edge( \
	struct digraph_struct_name *digraph, \
	struct node_struct_name *src_node, \
	const size_t dst_index) \
{ \
	struct digraph_edge *edge; \
	struct node_struct_name *dst_node; \
	dst_node = digraph_struct_name##_digraph_get_node(digraph, dst_index); \
	if (dst_node == NULL) \
		return NULL; \
	edge = digraph_internal_remove_edge(&digraph->digraph, \
					    &src_node->node_field_name, \
					    &dst_node->node_field_name); \
	return digraph_struct_name##_digraph_internal_to_user_edge(edge); \
} \
 \
static inline int digraph_struct_name##_digraph_remove_node( \
	struct digraph_struct_name *digraph, \
	const size_t index, \
	const struct digraph_struct_name##_reclaim *reclaim) \
{ \
	return digraph_internal_remove_node( \
		&digraph->digraph, index, \
		digraph_struct_name##_digraph_const_cast_to_opaque_reclaim(reclaim)); \
} \
 \
static inline int digraph_struct_name##_digraph_remove_node_edges( \
	struct digraph_struct_name *digraph, \
	const size_t index, \
	const struct digraph_struct_name##_reclaim *reclaim) \
{ \
	return digraph_internal_remove_node_edges( \
		&digraph->digraph, \
		index, \
		digraph_struct_name##_digraph_const_cast_to_opaque_reclaim(reclaim)); \
} \
 \
static inline int digraph_struct_name##_digraph_rename_node( \
	struct digraph_struct_name *digraph, \
	const size_t old_index, \
	const size_t new_index) \
{ \
	return digraph_internal_rename_node( \
		&digraph->digraph, old_index, new_index); \
} \
 \
static inline int digraph_struct_name##_digraph_set_edge( \
	struct digraph_struct_name *digraph, \
	const size_t src_index, \
	const size_t dst_index, \
	struct edge_struct_name *edge) \
{ \
	return digraph_internal_set_edge( \
		&digraph->digraph, src_index, dst_index, \
		digraph_struct_name##_digraph_cast_to_opaque_edge(edge)); \
} \
 \
static inline int digraph_struct_name##_digraph_set_node( \
	struct digraph_struct_name *digraph, \
	const size_t index, \
	struct node_struct_name *node) \
{ \
	return digraph_internal_set_node( \
		&digraph->digraph, index, \
		digraph_struct_name##_digraph_cast_to_opaque_node(node)); \
} \
 \

/* End of custom function prototypes */

/* Define digraph accessors */

/* digraph_alloc: alloc_index can be a NULL ptr. */
#define digraph_alloc(digraph_struct_name, alloc_index, digraph, num_nodes) digraph_struct_name##_digraph_alloc((alloc_index), (digraph), (num_nodes))
#define digraph_create(digraph_struct_name, num_allocated) digraph_struct_name##_digraph_create(num_allocated)
#define digraph_free(digraph_struct_name, digraph, reclaim) digraph_struct_name##_digraph_free((digraph), (reclaim));
#define digraph_get_edge(digraph_struct_name, digraph, src_index, dst_index) digraph_struct_name##_digraph_get_edge((digraph), (src_index), (dst_index))
#define digraph_get_node(digraph_struct_name, digraph, index) digraph_struct_name##_digraph_get_node((digraph), (index))
#define digraph_num_allocated(digraph_struct_name, digraph) digraph_struct_name##_digraph_num_allocated(digraph)
#define digraph_num_edges(digraph_struct_name, digraph) digraph_struct_name##_digraph_num_edges(digraph)
#define digraph_num_nodes(digraph_struct_name, digraph) digraph_struct_name##_digraph_num_nodes(digraph)
#define digraph_remove_edge(digraph_struct_name, digraph, src_index, dst_index) digraph_struct_name##_digraph_remove_edge((digraph), (src_index), (dst_index))
#define digraph_remove_node(digraph_struct_name, digraph, index, reclaim) digraph_struct_name##_digraph_remove_node((digraph), (index), (reclaim))
#define digraph_remove_node_edges(digraph_struct_name, digraph, index, reclaim) digraph_struct_name##_digraph_remove_node_edges((digraph), (index), (reclaim))
#define digraph_rename_node(digraph_struct_name, digraph, old_index, new_index) digraph_struct_name##_digraph_rename_node((digraph), (old_index), (new_index))
#define digraph_set_edge(digraph_struct_name, digraph, src_index, dst_index, edge) digraph_struct_name##_digraph_set_edge((digraph), (src_index), (dst_index), (edge))
#define digraph_set_node(digraph_struct_name, digraph, index, node) digraph_struct_name##_digraph_set_node((digraph), (index), (node))

#define digraph_reclaim_free_initializer(digraph_struct_name) ((struct digraph_struct_name##_reclaim) { \
	.free_edge = digraph_struct_name##_digraph_reclaim_free_edge, \
	.free_node = digraph_struct_name##_digraph_reclaim_free_node, \
	})

#define digraph_for_each_node(digraph_struct_name, digraph, iterator, node) \
	for (digraph_struct_name##_digraph_node_iterator( \
		(iterator), (digraph)); \
	     digraph_struct_name##_digraph_node_iterator_cur( \
		&(node), (iterator)); \
	     digraph_struct_name##_digraph_node_iterator_next(iterator))

/*
 * You are permitted to remove the current edge from the graph while iterating.
 */
#define digraph_for_each_out_edge(digraph_struct_name, node, iterator, edge) \
	for (digraph_struct_name##_digraph_out_edge_iterator( \
		(iterator), (node)); \
	     digraph_struct_name##_digraph_out_edge_iterator_cur( \
		&(edge), (iterator)); \
	     digraph_struct_name##_digraph_out_edge_iterator_next(iterator))

#define digraph_for_each_in_edge(digraph_struct_name, node, iterator, edge) \
	for (digraph_struct_name##_digraph_in_edge_iterator( \
		(iterator), (node)); \
	     digraph_struct_name##_digraph_in_edge_iterator_cur( \
		&(edge), (iterator)); \
	     digraph_struct_name##_digraph_in_edge_iterator_next(iterator))

#ifdef __cplusplus
}
#endif

#endif  /* _Z_DIGRAPH_H_ */

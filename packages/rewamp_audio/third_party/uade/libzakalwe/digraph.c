#include <zakalwe/next/digraph.h>
#include <zakalwe/math.h>
#include <zakalwe/mem.h>
#include <stdlib.h>
#include <string.h>

int digraph_compare_in_edge(struct digraph_edge *a, struct digraph_edge *b)
{
	if (a->src < b->src)
		return -1;
	else if (b->src < a->src)
		return 1;
	return 0;
}

int digraph_compare_out_edge(struct digraph_edge *a, struct digraph_edge *b)
{
	if (a->dst < b->dst)
		return -1;
	else if (b->dst < a->dst)
		return 1;
	return 0;
}

RB_GENERATE(digraph_in_edges, digraph_edge, in_edge, digraph_compare_in_edge);
RB_GENERATE(digraph_out_edges, digraph_edge, out_edge,
	    digraph_compare_out_edge);

#define ITERATE_OUT_EDGES(edge, iterator, node) \
	for (digraph_internal_out_edge_iterator((iterator), (node)); \
	     digraph_internal_out_edge_iterator_cur(&(edge), (iterator)); \
	     digraph_internal_out_edge_iterator_next(iterator))

#define ITERATE_IN_EDGES(edge, iterator, node) \
	for (digraph_internal_in_edge_iterator((iterator), (node)); \
	     digraph_internal_in_edge_iterator_cur(&(edge), (iterator)); \
	     digraph_internal_in_edge_iterator_next(iterator))


static inline struct digraph_edge *opaque_edge_to_internal(
	const struct digraph *digraph,
	const struct digraph_opaque_edge *edge)
{
	return (struct digraph_edge *) (((char *) edge) + digraph->edge_offset);
}

static inline struct digraph_opaque_edge *internal_edge_to_opaque(
	const struct digraph *digraph,
	const struct digraph_edge *edge)
{
	return (struct digraph_opaque_edge *) (((char *) edge) -
					       digraph->edge_offset);
}

static inline struct digraph_node *opaque_node_to_internal(
	const struct digraph *digraph,
	const struct digraph_opaque_node *node)
{
	return (struct digraph_node *) (((char *) node) + digraph->node_offset);
}

static struct digraph_opaque_node *get_opaque_node(
	const struct digraph *digraph, const size_t index)
{
	if (index >= digraph->num_allocated)
		return NULL;
	return digraph->nodes[index];
}

static struct digraph_node *get_internal_node(const struct digraph *digraph,
					      const size_t index)
{
	struct digraph_opaque_node *node = get_opaque_node(digraph, index);
	if (node == NULL)
		return NULL;
	return opaque_node_to_internal(digraph, node);
}

static void set_node(struct digraph *digraph, const size_t index,
		     struct digraph_opaque_node *node)
{
	z_assert(index < digraph->num_allocated);
	digraph->nodes[index] = node;
}

static inline int valid_index(struct digraph *digraph, const size_t index)
{
	return index < digraph->num_allocated;
}

static void __attribute__((unused)) fprint_edge(FILE *f,
						const char *prefix,
						const struct digraph_edge *edge,
						const char *suffix)
{
	fprintf(f, "%s(%zu, %zu)%s", prefix, edge->src, edge->dst, suffix);
}

int digraph_internal_alloc(size_t *alloc_index, struct digraph *digraph,
			   const size_t num_nodes)
{
	size_t num_allocated;
	struct digraph_opaque_node **nodes;

	if (alloc_index != NULL)
		*alloc_index = 0;

	if (!z_add2_size_t(&num_allocated, digraph->num_allocated,
			   num_nodes))
		return 0;

	nodes = reallocarray(digraph->nodes, num_allocated,
			     sizeof digraph->nodes[0]);
	if (nodes == NULL)
		return 0;
	digraph->nodes = nodes;

	/* Zero all the new node pointers. */
	z_assert((num_nodes + digraph->num_allocated) == num_allocated);
	z_zero_items(&digraph->nodes[digraph->num_allocated], num_nodes,
		     sizeof digraph->nodes[0]);

	if (alloc_index != NULL)
		*alloc_index = digraph->num_allocated;

	digraph->num_allocated = num_allocated;
	return 1;
}

void *digraph_internal_create(const size_t num_allocated,
			      const size_t edge_offset,
			      const size_t node_offset)
{
	struct digraph *digraph = calloc(1, sizeof digraph[0]);
	if (digraph == NULL)
		goto error;
	digraph->edge_offset = edge_offset;
	digraph->node_offset = node_offset;
	if (!digraph_internal_alloc(NULL, digraph, num_allocated))
		goto error;
	return digraph;

error:
	if (digraph != NULL) {
		z_free_and_null(digraph->nodes);
		z_free_and_null(digraph);
	}
	return NULL;
}

void digraph_internal_free(struct digraph *digraph,
			   const struct digraph_opaque_reclaim *reclaim)
{
	size_t i;
	for (i = 0; i < digraph->num_allocated; i++) {
		if (get_opaque_node(digraph, i) != NULL)
			digraph_internal_remove_node(digraph, i, reclaim);
	}
	z_assert(digraph->num_nodes == 0);
	z_assert(digraph->num_edges == 0);
	z_free_and_null(digraph->nodes);
	memset(digraph, -1, sizeof digraph[0]);
	z_free_and_null(digraph);
}

void digraph_internal_in_edge_iterator(
	struct digraph_edge_iterator *iterator, struct digraph_node *node)
{
	*iterator = (struct digraph_edge_iterator) {
		.cur = RB_MIN(digraph_in_edges, &node->in_edges),
	};
}

int digraph_internal_in_edge_iterator_cur(
	struct digraph_edge **edge, struct digraph_edge_iterator *iterator)
{
	*edge = iterator->cur;
	if (*edge == NULL)
		return 0;
	iterator->next = RB_NEXT(digraph_in_edges, -1, iterator->cur);
	return 1;
}

void digraph_internal_in_edge_iterator_next(
	struct digraph_edge_iterator *iterator)
{
	iterator->cur = iterator->next;
}

void digraph_internal_node_iterator(struct digraph_node_iterator *iterator,
				    struct digraph *digraph)
{
	*iterator = (struct digraph_node_iterator) {
		.index = 0,
		.digraph = digraph,
	};
}

int digraph_internal_node_iterator_cur(
	struct digraph_opaque_node **node,
	struct digraph_node_iterator *iterator)
{
	while (iterator->index < iterator->digraph->num_allocated) {
		struct digraph_opaque_node *cur_node;
		cur_node = get_opaque_node(iterator->digraph, iterator->index);
		if (cur_node != NULL) {
			*node = cur_node;
			return 1;
		}
		iterator->index++;
	}
	*node = NULL;
	return 0;
}

void digraph_internal_node_iterator_next(struct digraph_node_iterator *iterator)
{
	iterator->index++;
}

static int insert_edge(struct digraph_node *src_node,
		       struct digraph_node *dst_node,
		       struct digraph_edge *edge)
{
	struct digraph_edge *old_edge;
	if (RB_INSERT(digraph_out_edges, &src_node->out_edges, edge) != NULL)
		return 0;
	/*
	 * The same edge structure is inserted into outgoing edges of the
	 * source node and incoming edges of the destination node.
	 */
	old_edge = RB_INSERT(digraph_in_edges, &dst_node->in_edges, edge);
	z_assert(old_edge == NULL);
	return 1;
}

static void reclaim_edge(const struct digraph *digraph,
			 struct digraph_opaque_edge *edge,
			 const struct digraph_opaque_reclaim *reclaim)
{
	struct digraph_edge *internal_edge;
	internal_edge = opaque_edge_to_internal(digraph, edge);
	memset(internal_edge, -1, sizeof internal_edge[0]);  /* Poison */
	if (reclaim->free_edge != NULL)
		reclaim->free_edge(edge, reclaim->edge_data);
}

static void reclaim_node(struct digraph *digraph,
				struct digraph_opaque_node *node,
				const struct digraph_opaque_reclaim *reclaim)
{
	struct digraph_node *internal_node;
	internal_node = opaque_node_to_internal(digraph, node);
	memset(internal_node, -1, sizeof internal_node[0]);  /* Poison */
	if (reclaim->free_node != NULL)
		reclaim->free_node(node, reclaim->node_data);
}

static struct digraph_edge *find_in_edge(struct digraph_in_edges *tree,
					 const size_t src)
{
	struct digraph_edge key = {.src = src};
	return RB_FIND(digraph_in_edges, tree, &key);
}

static struct digraph_edge *remove_in_edge(struct digraph_in_edges *tree,
					   const size_t src)
{
	struct digraph_edge *edge = find_in_edge(tree, src);
	struct digraph_edge *removed_edge;
	if (edge == NULL)
		return NULL;
	removed_edge = RB_REMOVE(digraph_in_edges, tree, edge);
	z_assert(removed_edge == edge);
	return edge;
}

static struct digraph_edge *find_out_edge(struct digraph_out_edges *tree,
					 const size_t dst)
{
	struct digraph_edge key = {.dst = dst};
	return RB_FIND(digraph_out_edges, tree, &key);
}

static struct digraph_edge *remove_out_edge(struct digraph_out_edges *tree,
					    const size_t dst)
{
	struct digraph_edge *edge = find_out_edge(tree, dst);
	struct digraph_edge *removed_edge;
	if (edge == NULL)
		return NULL;
	removed_edge = RB_REMOVE(digraph_out_edges, tree, edge);
	z_assert(removed_edge == edge);
	return edge;
}

static int insert_in_edge(struct digraph_in_edges *tree,
			  struct digraph_edge *edge)
{
	struct digraph_edge *existing_edge;
	existing_edge = RB_INSERT(digraph_in_edges, tree, edge);
	return existing_edge == NULL;
}

static int insert_out_edge(struct digraph_out_edges *tree,
			   struct digraph_edge *edge)
{
	struct digraph_edge *existing_edge;
	existing_edge = RB_INSERT(digraph_out_edges, tree, edge);
	return existing_edge == NULL;
}

struct digraph_edge *digraph_internal_remove_edge(
	struct digraph *digraph,
	struct digraph_node *src_node,
	struct digraph_node *dst_node)
{
	struct digraph_edge *out_edge;
	struct digraph_edge *in_edge;
	out_edge = remove_out_edge(&src_node->out_edges, dst_node->index);
	if (out_edge == NULL)
		return NULL;
	in_edge = RB_REMOVE(digraph_in_edges, &dst_node->in_edges, out_edge);
	z_assert(in_edge == out_edge);
	src_node->num_out_edges--;
	dst_node->num_in_edges--;
	digraph->num_edges--;
	return out_edge;
}

static void digraph_internal_remove_in_edges(
	struct digraph *digraph,
	struct digraph_node *dst_node,
	const struct digraph_opaque_reclaim *reclaim)
{
	struct digraph_edge *edge;
	struct digraph_edge *next_edge;
	struct digraph_edge *removed_edge;
	struct digraph_in_edges *in_edges = &dst_node->in_edges;
	struct digraph_node *src_node;
	size_t num_edges = 0;

	RB_FOREACH_SAFE(edge, digraph_in_edges, in_edges, next_edge) {
		removed_edge = RB_REMOVE(digraph_in_edges, in_edges, edge);
		z_assert(removed_edge == edge);

		/* Remove associated outgoing edge on the source side. */
		src_node = get_internal_node(digraph, edge->src);
		z_assert(src_node != NULL);
		removed_edge = RB_REMOVE(digraph_out_edges,
					 &src_node->out_edges, edge);
		z_assert(removed_edge == edge);

		reclaim_edge(digraph, internal_edge_to_opaque(digraph, edge),
			     reclaim);

		z_assert(src_node->num_out_edges > 0);
		src_node->num_out_edges--;
		num_edges++;
	}

	z_assert(dst_node->num_in_edges == num_edges);
	dst_node->num_in_edges = 0;
	z_assert(digraph->num_edges >= num_edges);
	digraph->num_edges -= num_edges;
}

static void digraph_internal_remove_out_edges(
	struct digraph *digraph,
	struct digraph_node *src_node,
	const struct digraph_opaque_reclaim *reclaim)
{
	struct digraph_edge *edge;
	struct digraph_edge *next_edge;
	struct digraph_edge *removed_edge;
	struct digraph_out_edges *out_edges = &src_node->out_edges;
	struct digraph_node *dst_node;
	size_t num_edges = 0;

	RB_FOREACH_SAFE(edge, digraph_out_edges, out_edges, next_edge) {
		removed_edge = RB_REMOVE(digraph_out_edges, out_edges, edge);
		z_assert(removed_edge == edge);

		/* Remove associated incoming edge on the destination side. */
		dst_node = get_internal_node(digraph, edge->dst);
		z_assert(dst_node != NULL);
		removed_edge = RB_REMOVE(digraph_in_edges,
					 &dst_node->in_edges, edge);
		z_assert(removed_edge == edge);

		reclaim_edge(digraph, internal_edge_to_opaque(digraph, edge),
			     reclaim);

		z_assert(dst_node->num_in_edges > 0);
		dst_node->num_in_edges--;
		num_edges++;
	}

	z_assert(src_node->num_out_edges == num_edges);
	src_node->num_out_edges = 0;
	z_assert(digraph->num_edges >= num_edges);
	digraph->num_edges -= num_edges;
}

int digraph_internal_remove_node_edges(
	struct digraph *digraph,
	const size_t index,
	const struct digraph_opaque_reclaim *reclaim)
{
	struct digraph_node *node = get_internal_node(digraph, index);
	if (node == NULL)
		return 0;
	digraph_internal_remove_out_edges(digraph, node, reclaim);
	z_assert(node->num_out_edges == 0);
	digraph_internal_remove_in_edges(digraph, node, reclaim);
	z_assert(node->num_in_edges == 0);
	return 1;
}

int digraph_internal_remove_node(struct digraph *digraph,
				 const size_t index,
				 const struct digraph_opaque_reclaim *reclaim)
{
	struct digraph_opaque_node *node = get_opaque_node(digraph, index);
	if (node == NULL)
		return 0;
	digraph_internal_remove_node_edges(digraph, index, reclaim);
	set_node(digraph, index, NULL);
	digraph->num_nodes--;
	reclaim_node(digraph, node, reclaim);
	return 1;
}

void digraph_internal_out_edge_iterator(
	struct digraph_edge_iterator *iterator, struct digraph_node *node)
{
	*iterator = (struct digraph_edge_iterator) {
		.cur = RB_MIN(digraph_out_edges, &node->out_edges),
	};
}

int digraph_internal_out_edge_iterator_cur(
	struct digraph_edge **edge, struct digraph_edge_iterator *iterator)
{
	*edge = iterator->cur;
	if (*edge == NULL)
		return 0;
	iterator->next = RB_NEXT(digraph_out_edges, -1, iterator->cur);
	return 1;
}

void digraph_internal_out_edge_iterator_next(
	struct digraph_edge_iterator *iterator)
{
	iterator->cur = iterator->next;
}

int digraph_internal_rename_node(struct digraph *digraph,
				 const size_t old_index,
				 const size_t new_index)
{
	struct digraph_node *node = get_internal_node(digraph, old_index);
	struct digraph_edge_iterator iterator;
	struct digraph_edge *edge;
	int ret;
	if (node == NULL)
		return 0;
	if (!valid_index(digraph, new_index))
		return 0;
	if (old_index == new_index)
		return 1;
	if (get_opaque_node(digraph, new_index) != NULL)
		return 0;

	/*
	 * Alias the new_index with the old_index so that we can move edges to
	 * it.
	 */
	set_node(digraph, new_index, get_opaque_node(digraph, old_index));

	/*
	 * Note, we don't have to re-order the node->out_edges tree because only
	 * the src index changes in each edge. node->out_edges tree is ordered
	 * by the dst index. However, the dst side's in_edges tree needs to
	 * be re-ordered.
	 */
	ITERATE_OUT_EDGES(edge, &iterator, node) {
		struct digraph_node *dst_node;
		struct digraph_edge *in_edge;
		z_assert(edge->src == old_index);
		dst_node = get_internal_node(digraph, edge->dst);
		z_assert(dst_node != NULL);
		in_edge = remove_in_edge(&dst_node->in_edges, edge->src);
		z_assert(in_edge == edge);
		/* Change the src index and re-insert back. */
		edge->src = new_index;
		ret = insert_in_edge(&dst_node->in_edges, edge);
		z_assert(ret);
	}
	/*
	 * Note, we don't have to re-order the node->in_edges tree because only
	 * the dst index changes in each edge. node->in_edges tree is ordered
	 * by the src index. However, the src side's out_edges tree needs to
	 * be re-ordered.
	 */
	ITERATE_IN_EDGES(edge, &iterator, node) {
		struct digraph_node *src_node;
		struct digraph_edge *out_edge;
		z_assert(edge->dst == old_index);
		src_node = get_internal_node(digraph, edge->src);
		z_assert(src_node != NULL);
		out_edge = remove_out_edge(&src_node->out_edges, edge->dst);
		z_assert(out_edge == edge);
		/* Change the dst index and re-insert back. */
		edge->dst = new_index;
		ret = insert_out_edge(&src_node->out_edges, edge);
		z_assert(ret);
	}

	/*
	 * Delete the old index from node table so that the new_index is not an
	 * alias.
	 */
	set_node(digraph, old_index, NULL);

	return 1;
}

int digraph_internal_set_edge(struct digraph *digraph,
			      const size_t src_index,
			      const size_t dst_index,
			      struct digraph_opaque_edge *edge)
{
	struct digraph_node *src_node = get_internal_node(digraph, src_index);
	struct digraph_node *dst_node = get_internal_node(digraph, dst_index);
	struct digraph_edge *internal_edge = opaque_edge_to_internal(digraph,
								     edge);
	if (src_node == NULL || dst_node == NULL)
		return 0;
	internal_edge->src = src_index;
	internal_edge->dst = dst_index;
	if (!insert_edge(src_node, dst_node, internal_edge))
		return 0;
	src_node->num_out_edges++;
	dst_node->num_in_edges++;
	digraph->num_edges++;
	return 1;
}

int digraph_internal_set_node(struct digraph *digraph,
			      const size_t index,
			      struct digraph_opaque_node *node)
{
	struct digraph_node *internal_node;
	internal_node = opaque_node_to_internal(digraph, node);
	if (!valid_index(digraph, index))
		return 0;
	if (get_internal_node(digraph, index) != NULL)
		return 0;
	*internal_node = (struct digraph_node) {.index = index};
	RB_INIT(&internal_node->in_edges);
	RB_INIT(&internal_node->out_edges);
	set_node(digraph, index, node);
	digraph->num_nodes++;
	return 1;
}

#ifndef _Z_HASH64_H_
#define _Z_HASH64_H_

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

struct hash64_bucket;

struct hash64 {
	size_t num_buckets;
	struct hash64_bucket *buckets;
	size_t num_items;
};

struct hash64 *hash64_create(size_t num_buckets);
void hash64_free(struct hash64 *ht);

/*
 * Returns 1 on success.
 * Returns 0 if the item already exists in ht or no memory is available.
 */
int hash64_insert(struct hash64 *ht,
		  const uint64_t hash_value,
		  void *item,
		  const void *opaque,
		  int (*compare)(const void *a, const void *b,
				 const void *opaque));

static inline size_t hash64_len(const struct hash64 *ht)
{
	return ht->num_items;
}

void *hash64_lookup(const struct hash64 *ht,
		    const uint64_t hash_value,
		    const void *item,
		    const void *opaque,
		    int (*compare)(const void *a, const void *b,
				   const void *opaque));

size_t hash64_max_chain_len(const struct hash64 *ht);

void *hash64_remove(struct hash64 *ht,
		    const uint64_t hash_value,
		    const void *item,
		    const void *opaque,
		    int (*compare)(const void *a, const void *b,
				   const void *opaque));

void *hash64_remove_pointer(struct hash64 *ht,
			    const uint64_t hash_value,
			    void *item);

#ifdef __cplusplus
}
#endif

#endif  /* CCUL_HASH64_H_ */

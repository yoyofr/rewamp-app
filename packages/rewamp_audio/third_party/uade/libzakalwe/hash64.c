#include <zakalwe/base.h>
#include <zakalwe/next/hash64.h>
#include <stdlib.h>
#include <string.h>

struct hash64_bucket {
	uint64_t hash_value;
	/*
	 * item == NULL means an unused node. We may have unused items anywhere
	 * in the chain.
	 */
	void *item;
	struct hash64_bucket *next;
};

struct hash64 *hash64_create(size_t num_buckets)
{
	struct hash64 *ht;
	if (num_buckets == 0)
		return NULL;
	ht = calloc(1, sizeof ht[0]);
	if (ht == NULL)
		return NULL;
	ht->num_buckets = num_buckets;
	ht->buckets = calloc(ht->num_buckets, sizeof ht->buckets[0]);
	if (ht->buckets == NULL) {
		free(ht);
		return NULL;
	}
	return ht;
}

static void free_hash_chain(struct hash64_bucket *bucket)
{
	struct hash64_bucket *next;
	if (bucket == NULL)
		return;
	/* Note, the first bucket in the chain must not be freed. */
	bucket = bucket->next;
	while (bucket != NULL) {
		next = bucket->next;
		memset(bucket, 0, sizeof bucket[0]);
		free(bucket);
		bucket = next;
	}
}

void hash64_free(struct hash64 *ht)
{
	size_t i;
	for (i = 0; i < ht->num_buckets; i++)
		free_hash_chain(&ht->buckets[i]);
	free(ht->buckets);
	memset(ht, 0, sizeof ht[0]);
	free(ht);
}

static struct hash64_bucket *pick_bucket(const struct hash64 *ht,
					 const uint64_t hash_value)
{
	return &ht->buckets[hash_value % ht->num_buckets];
}

int hash64_insert(struct hash64 *ht,
		  const uint64_t hash_value,
		  void *item,
		  const void *opaque,
		  int (*compare)(const void *a, const void *b,
				 const void *opaque))
{
	struct hash64_bucket *bucket = pick_bucket(ht, hash_value);
	struct hash64_bucket *unused_bucket = NULL;
	z_assert(item != NULL);
	while (1) {
		if (bucket->item == NULL) {
			/* Re-use the first empty bucket. */
			if (unused_bucket == NULL)
				unused_bucket = bucket;
		} else {
			if (bucket->hash_value == hash_value &&
			    compare(bucket->item, item, opaque) == 0) {
				return 0;
			}
		}
		if (bucket->next == NULL)
			break;
		bucket = bucket->next;
	}

	if (unused_bucket == NULL) {
		/* Did not find an empty slot. Create a new slot. */
		z_assert(bucket->next == NULL);
		bucket->next = calloc(1, sizeof bucket->next[0]);
		if (bucket->next == NULL)
			return 0;
		unused_bucket = bucket->next;
	}

	z_assert(unused_bucket->item == NULL);
	unused_bucket->hash_value = hash_value;
	unused_bucket->item = item;

	ht->num_items++;
	return 1;
}

static struct hash64_bucket *find_bucket_with_item(
	const struct hash64 *ht,
	const uint64_t hash_value,
	const void *item,
	const void *opaque,
	int (*compare)(const void *a, const void *b,
		       const void *opaque))
{
	struct hash64_bucket *bucket = pick_bucket(ht, hash_value);

	for (; bucket != NULL; bucket = bucket->next) {
		if (bucket->item != NULL) {
			if (bucket->hash_value == hash_value &&
			    compare(bucket->item, item, opaque) == 0) {
				return bucket;
			}
		}
	}

	return NULL;
}

void *hash64_lookup(const struct hash64 *ht,
		    const uint64_t hash_value,
		    const void *item,
		    const void *opaque,
		    int (*compare)(const void *a, const void *b,
				   const void *opaque))
{
	struct hash64_bucket *bucket;
	z_assert(item != NULL);
	bucket = find_bucket_with_item(ht, hash_value, item, opaque, compare);
	if (bucket == NULL)
		return NULL;
	return bucket->item;
}

static size_t bucket_chain_len(struct hash64_bucket *bucket)
{
	size_t len = 1;
	while (bucket != NULL) {
		len++;
		bucket = bucket->next;
	}
	return len;
}

size_t hash64_max_chain_len(const struct hash64 *ht)
{
	size_t i;
	size_t max_len = 0;
	for (i = 0; i < ht->num_buckets; i++) {
		struct hash64_bucket *bucket = &ht->buckets[i];
		max_len = Z_MAX(max_len, bucket_chain_len(bucket));
	}
	return max_len;
}

void *hash64_remove(struct hash64 *ht,
		    const uint64_t hash_value,
		    const void *item,
		    const void *opaque,
		    int (*compare)(const void *a, const void *b,
				   const void *opaque))
{
	struct hash64_bucket *bucket;
	void *found_item;
	z_assert(item != NULL);
	bucket = find_bucket_with_item(ht, hash_value, item, opaque, compare);
	if (bucket == NULL)
		return NULL;
	found_item = bucket->item;
	bucket->hash_value = 0;
	bucket->item = NULL;
	ht->num_items--;
	return found_item;
}

void *hash64_remove_pointer(struct hash64 *ht,
			    const uint64_t hash_value,
			    void *item)
{
	struct hash64_bucket *bucket = pick_bucket(ht, hash_value);
	z_assert(item != NULL);
	for (; bucket != NULL; bucket = bucket->next) {
		if (bucket->item != NULL && bucket->item == item)
			break;
	}
	if (bucket == NULL)
		return NULL;
	z_assert(bucket->item == item);
	bucket->hash_value = 0;
	bucket->item = NULL;
	ht->num_items--;
	return item;
}

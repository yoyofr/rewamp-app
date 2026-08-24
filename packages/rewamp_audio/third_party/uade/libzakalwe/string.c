#include <zakalwe/string.h>
#include <string.h>

struct z_string *z_string_create(void)
{
	struct z_string *zs;
	zs = calloc(1, sizeof(*zs));
	if (zs == NULL)
		return zs;
	zs->capacity = 1;
	zs->s = malloc(zs->capacity);
	if (zs->s == NULL) {
		free(zs);
		zs = NULL;
		return zs;
	}
	zs->s[zs->len] = 0;
	return zs;
}

void z_string_free(struct z_string *zs)
{
	if (zs == NULL)
		return;
	/* There is always one char capacity */
	zs->s[0] = 0;
	free(zs->s);
	zs->s = NULL;
	zs->len = 0;
	zs->capacity = 0;
	free(zs);
}

static int _z_string_alloc(struct z_string *zs, const size_t new_len)
{
	size_t new_capacity = new_len + 1;
	if (new_capacity <= zs->capacity)
		return 1;
	if (new_capacity < (2 * zs->capacity))
		new_capacity = 2 * zs->capacity;
	char *s = realloc(zs->s, new_capacity);
	if (s == NULL)
		return 0;
	zs->s = s;
	zs->capacity = new_capacity;
	return 1;
}

int z_string_cat_c_str(struct z_string *zs, const char *src)
{
	const size_t src_len = strlen(src);
	const size_t new_len = zs->len + src_len;
	if (!_z_string_alloc(zs, new_len))
		return 0;
	memcpy(zs->s + zs->len, src, src_len);
	zs->len = new_len;
	zs->s[zs->len] = 0;
	return 1;
}

char *z_str_a_cat2(const char *sa, const char *sb)
{
	size_t la = strlen(sa);
	size_t lb = strlen(sb);
	char *dst = malloc(la + lb + 1);
	if (dst == NULL)
		return NULL;
	memcpy(dst, sa, la);
	memcpy(dst + la, sb, lb);
	dst[la + lb] = 0;
	return dst;
}

char *z_str_a_cat3(const char *sa, const char *sb, const char *sc)
{
	size_t la = strlen(sa);
	size_t lb = strlen(sb);
	size_t lc = strlen(sc);
	char *dst = malloc(la + lb + lc + 1);
	if (dst == NULL)
		return NULL;
	memcpy(dst, sa, la);
	memcpy(dst + la, sb, lb);
	memcpy(dst + la + lb, sc, lc);
	dst[la + lb + lc] = 0;
	return dst;
}

#ifdef _Z_NEED_STRL

size_t strlcpy(char *dst, const char *src, size_t size)
{
	size_t slen = strlen(src);
	if (slen < size) {
		strcpy(dst, src);
	} else if (size > 0) {
		strncpy(dst, src, size - 1);
		dst[size - 1] = 0;
	}
	return slen;
}

size_t strlcat(char *dst, const char *src, size_t size)
{
	size_t dlen = strlen(dst);

	if (dlen >= size) {
		/* This actually means a bug. */
		return strlen(src) + dlen;
	}

	return dlen + strlcpy(dst + dlen, src, size - dlen);
}

#endif

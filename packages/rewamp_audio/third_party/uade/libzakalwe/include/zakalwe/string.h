#ifndef _Z_STRING_UTIL_H_
#define _Z_STRING_UTIL_H_

#include <zakalwe/base.h>
#include <zakalwe/config.h>

#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

struct z_string {
	size_t len;
	size_t capacity;
	/*
	 * s is always zero terminated. It is zero terminated even when no
	 * no zeros were inserted into the string.
	 */
	char *s;
};

/* Returns zero on failure. Otherwise non-zero. */
int z_string_cat_c_str(struct z_string *zs, const char *s);
struct z_string *z_string_create(void);
void z_string_free(struct z_string *zs);

/* TODO: Add safe_snprintf, safe_fprintf that check for out of bounds. */

char *z_str_a_cat2(const char *sa, const char *sb);
char *z_str_a_cat3(const char *sa, const char *sb, const char *sc);

static inline char *z_strdup_or_die(const char *s)
{
	char *t = strdup(s);
	z_assert(t != NULL);
	return t;
}

#define z_snprintf_or_die(target, targetsize, fmt, args...) do { \
               int _z_ret = snprintf((target), (targetsize), fmt, ## args); \
               z_assert(_z_ret >= 0); \
	       z_assert((targetsize) == 0 || \
			((size_t) _z_ret) < (targetsize)); \
       } while(0)

#ifdef _Z_NEED_STRL
size_t strlcat(char *dst, const char *src, size_t size);
size_t strlcpy(char *dst, const char *src, size_t size);
#endif

#ifdef __cplusplus
}
#endif

#endif

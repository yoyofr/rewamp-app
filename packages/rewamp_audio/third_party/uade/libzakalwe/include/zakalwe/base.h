#ifndef _Z_BASE_H_
#define _Z_BASE_H_

#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

#include "compiler.h"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * aborts() if condition is false. z_* assert functions are always effective
 * regardless whether NDEBUG is defined or not.
 */
#define z_assert(cond) do { if (!(cond)) { fprintf(stderr, "%s: Assertion failed at %s:%d: %s\n", __FILE__, __func__, __LINE__,# cond); abort(); } } while(0)

#define z_assert_eq(a, b) z_assert((a) == (b))
/* aborts() if condition is false. */
#define z_assert_false(cond) z_assert(!(cond))
/* aborts() if expression is NULL. */
#define z_assert_not_null(expr) do { if ((expr) == NULL) { fprintf(stderr, "%s: Assertion failed at %s:%d: %s\n", __FILE__, __func__, __LINE__,# expr); abort(); } } while(0)

/* z_container_of() macro was copied from the Linux kernel. */
#define z_container_of(ptr, type, member) ({                             \
        const typeof( ((type *)0)->member ) *__member_ptr = (ptr);     \
        (type *) (((char *) __member_ptr) - offsetof(type, member));})

#define z_die(fmt, args...) do { fprintf(stderr, "abort(): %s %s:%d: " fmt, __FILE__, __func__, __LINE__, ## args); abort(); } while(0)

#define z_log_info(fmt, args...) do { fprintf(stderr, "info: %s %s:%d: " fmt, __FILE__, __func__, __LINE__, ## args); } while(0)

#define z_log_error(fmt, args...) do { fprintf(stderr, "error: %s %s:%d: " fmt, __FILE__, __func__, __LINE__, ## args); } while(0)

#define z_log_fatal(fmt, args...) do { fprintf(stderr, "fatal error: %s %s:%d: " fmt, __FILE__, __func__, __LINE__, ## args); abort(); } while(0)

#define z_log_warning(fmt, args...) do { fprintf(stderr, "warning: %s %s:%d: " fmt, __FILE__, __func__, __LINE__, ## args); } while(0)

#define z_log_info_every_n_secs(secs, fmt, args...) do { if (_z_every_n_secs((secs), (fmt))) { fprintf(stderr, "info: %s %s:%d: " fmt, __FILE__, __func__, __LINE__, ## args); } } while (0)

#define z_log_warning_every_n_secs(secs, fmt, args...) do { if (_z_every_n_secs((secs), (fmt))) { fprintf(stderr, "warning: %s %s:%d: " fmt, __FILE__, __func__, __LINE__, ## args); } } while (0)

#define z_log_error_every_n_secs(secs, fmt, args...) do { if (_z_every_n_secs((secs), (fmt))) { fprintf(stderr, "error: %s %s:%d: " fmt, __FILE__, __func__, __LINE__, ## args); } } while (0)

#define Z_MAX(a, b) (((a) >= (b)) ? (a) : (b))
#define Z_MIN(a, b) (((a) <= (b)) ? (a) : (b))

int _z_every_n_secs(const int secs, const void *p);

#ifdef __cplusplus
}
#endif

#endif  /* _Z_BASE_H_ */

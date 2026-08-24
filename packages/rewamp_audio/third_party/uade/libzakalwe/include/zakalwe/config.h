#ifndef _Z_CONFIG_H_
#define _Z_CONFIG_H_

#define _Z_NEED_REALLOCARRAY 1
/* #define _Z_NEED_STRL 1 */

#endif
#define _Z_SYSCALL_SELECT 1

/* rewamp: all our targets (macOS/iOS/Android) have mkdtemp — avoid the
   glibc-only random_r fallback in file.c. */
#ifndef _Z_HAS_MKDTEMP
#define _Z_HAS_MKDTEMP 1
#endif

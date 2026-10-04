#ifndef _Z_CONFIG_H_
#define _Z_CONFIG_H_

#define _Z_NEED_REALLOCARRAY 1
/* #define _Z_NEED_STRL 1 */
/* rewamp: l'UCRT n'a ni strlcpy ni strlcat — zakalwe les fournit (string.c). */
#ifdef _WIN32
#define _Z_NEED_STRL 1
#endif

#endif
/* rewamp: Windows n'a pas select() sur des descripteurs CRT. */
#ifndef _WIN32
#define _Z_SYSCALL_SELECT 1
#endif

/* rewamp: all our targets (macOS/iOS/Android) have mkdtemp — avoid the
   glibc-only random_r fallback in file.c. */
#ifndef _Z_HAS_MKDTEMP
#define _Z_HAS_MKDTEMP 1
#endif

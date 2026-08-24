#ifndef _Z_COMPILER_H_
#define _Z_COMPILER_H_

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Compiler specific definitions redefined to be portable and hopefully easier
 * to remember.
 */

#define z_attribute_packed __attribute__((packed))
#define z_no_return __attribute__((noreturn))
#define z_unused __attribute__((unused))

#ifdef __cplusplus
}
#endif

#endif

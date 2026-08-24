#ifndef _Z_INPUT_UTIL_H_
#define _Z_INPUT_UTIL_H_

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

char *z_fgets(char *s, const int size, FILE *stream);
double z_strtod(int *success, const char *s);
long long z_strtoll(int *success, const char *s, int base);
size_t z_strtosizet(int *success, const char *s, int base);

#ifdef __cplusplus
}
#endif

#endif

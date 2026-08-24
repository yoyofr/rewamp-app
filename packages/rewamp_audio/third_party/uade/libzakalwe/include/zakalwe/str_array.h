/*
 * str_array is an array of dynamically char * elements where each element
 * must be freed with free() after use.
 *
 * str_array_free_all() frees all elements and the array itself.
 *
 * str_array_free_elements() frees all dynamically allocated char * elements,
 * but not the array itself.
 */

#ifndef _Z_STRING_ARRAY_H_
#define _Z_STRING_ARRAY_H_

#include <zakalwe/array.h>

#ifdef __cplusplus
extern "C" {
#endif

Z_ARRAY_PROTOTYPE(str_array, char *);

void str_array_free_all(struct str_array *array);
void str_array_free_elements(struct str_array *array);

#ifdef __cplusplus
}
#endif

#endif

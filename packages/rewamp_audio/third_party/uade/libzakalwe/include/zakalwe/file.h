#ifndef _Z_FILE_UTIL_H_
#define _Z_FILE_UTIL_H_

#include <stdio.h>
#include <zakalwe/str_array.h>

#ifdef __cplusplus
extern "C" {
#endif

int z_atomic_fclose(FILE *f);
size_t z_atomic_fread(void *ptr, size_t size, size_t nmemb, FILE *stream);
size_t z_atomic_fwrite(const void *ptr, size_t size, size_t nmemb,
		       FILE *stream);

size_t z_file_get_size(int *success, const char *path);

/* Reads full contents of a file. */
void *z_file_read(size_t *size, const char *path);

struct str_array *z_list_dir(const char *path);

/*
 * Create a temporary directory. If base_dir == NULL, the directory is created
 * under the default temporary directory. If base_dir != NULL, the directory is
 * created under the given directory.
 *
 * The directory name returned must be freed with free().
 */
char *z_mkdtemp(const char *base_dir);

/*
 * Removes directory and its content recursively.
 * Returns 1 on success, otherwise 0.
 */
int z_rmdir_recursively(const char *dir);

#ifdef __cplusplus
}
#endif

#endif

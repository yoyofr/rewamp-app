#define _XOPEN_SOURCE 500

#include <zakalwe/config.h>

#include <zakalwe/base.h>
#include <zakalwe/file.h>
#include <zakalwe/string.h>

#include <ftw.h>

#include <dirent.h>
#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>

int z_atomic_fclose(FILE *f)
{
	int ret;
	do {
		ret = fclose(f);
	} while (ret != 0 && errno == EINTR);
	return ret;
}

size_t z_atomic_fread(void *_ptr, size_t size, size_t nmemb, FILE *stream)
{
	uint8_t *ptr = _ptr;
	size_t readmemb = 0;
	size_t ret;

	while (readmemb < nmemb) {
		ret = fread(ptr, size, nmemb - readmemb, stream);
		if (ret == 0 && (feof(stream) || ferror(stream)))
			break;
		readmemb += ret;
		ptr += size * ret;
	}

	z_assert(readmemb <= nmemb);
	return readmemb;
}

size_t z_atomic_fwrite(const void *_ptr, size_t size, size_t nmemb,
		       FILE *stream)
{
	const uint8_t *ptr = _ptr;
	size_t offset = 0;
	size_t writememb = 0;
	size_t ret;

	while (writememb < nmemb) {
		ret = fwrite(&ptr[offset], size, nmemb - writememb, stream);
		if (ret == 0 && ferror(stream))
			break;
		writememb += ret;
		offset += size * ret;
	}

	z_assert(writememb <= nmemb);
	return writememb;
}

static size_t get_size(int *success, FILE *f)
{
	long pos;
	if (fseek(f, 0, SEEK_END))
		goto error;
	pos = ftell(f);
	if (pos < 0)
		goto error;
	*success = 1;
	return pos;

error:
	*success = 0;
	return 0;
}

size_t z_file_get_size(int *success, const char *path)
{
	size_t size;
	int internal_success;
	FILE *f = fopen(path, "rb");
	if (f == NULL)
		goto error;
	size = get_size(&internal_success, f);

	z_atomic_fclose(f);
	f = NULL;

	if (!internal_success)
		goto error;
	if (success != NULL)
		*success = 1;
	return size;

error:
	if (f != NULL)
		z_atomic_fclose(f);
	if (success != NULL)
		*success = 0;
	return 0;
}

void *z_file_read(size_t *size, const char *path)
{
	int success;
	size_t num_bytes;
	void *data = NULL;
	FILE *f = fopen(path, "rb");
	*size = 0;
	if (f == NULL)
		goto error;

	num_bytes = get_size(&success, f);
	if (!success)
		goto error;
	/* get_size() changes the file position. */
	if (fseek(f, 0, SEEK_SET))
		goto error;

	data = malloc(num_bytes);
	if (data == NULL)
		goto error;

	if (z_atomic_fread(data, 1, num_bytes, f) != num_bytes)
		goto error;

	z_atomic_fclose(f);

	*size = num_bytes;
	return data;

error:
	if (f != NULL)
		z_atomic_fclose(f);
	if (data != NULL)
		free(data);
	return NULL;
}

struct str_array *z_list_dir(const char *path)
{
	DIR *dirp = opendir(path);
	struct str_array *names = str_array_create();
	if (dirp == NULL || names == NULL)
		goto error;

	while (1) {
		struct dirent *de = readdir(dirp);
		if (de == NULL)
			break;
		if (strcmp(de->d_name, ".") == 0 ||
		    strcmp(de->d_name, "..") == 0) {
			continue;
		}
		char *s = strdup(de->d_name);
		if (s == NULL)
			goto error;
		if (!str_array_append(names, s)) {
			free(s);
			goto error;
		}
	}

	closedir(dirp);
	return names;

error:
	str_array_free_all(names);
	if (dirp != NULL)
		closedir(dirp);

	return NULL;
}

#ifndef _Z_HAS_MKDTEMP
static char *mkdtemp_replacement(const char *tmpdir)
{
	/*
	 * A predictable sequence is OK if it finds a unique dir name
	 * eventually
	 */
	unsigned int seed = 0xdeadbeef;
	struct timeval tv;
	gettimeofday(&tv, NULL);
	seed ^= (unsigned int) tv.tv_usec ^ (unsigned int) tv.tv_sec;
	char statebuf[32];
	z_zero_target(statebuf);
	struct random_data buf = {};

	if (initstate_r(seed, statebuf, sizeof(statebuf), &buf))
		return NULL;

	char *newdir = malloc(PATH_MAX);
	if (newdir == NULL)
		return NULL;

	while (1)
	{
		int32_t x;
		if (random_r(&buf, &x))
			goto error;

		int ret = snprintf(newdir, PATH_MAX, "%s/tmp.%x", tmpdir, x);
		if (ret < 0 || ret >= PATH_MAX)
			goto error;

		printf("%s\n", newdir);
		z_assert(0);
		ret = mkdir(newdir, 0700);
		if (ret < 0) {
			if (errno == EEXIST)
				continue;
			goto error;
		}
		break;
	}

	return newdir;

error:
	if (newdir != NULL)
		free(newdir);
	return NULL;
}
#endif

char *z_mkdtemp(const char *tmpdir)
{
	char *newdir;
	if (tmpdir == NULL) {
		tmpdir = getenv("TMPDIR");
		if (tmpdir == NULL || strlen(tmpdir) == 0) {
			tmpdir = "/tmp";
		}
	}
#ifdef _Z_HAS_MKDTEMP
	newdir = z_str_a_cat2(tmpdir, "/tmp.XXXXXX");
	if (newdir == NULL)
		return NULL;
	if (mkdtemp(newdir) == NULL)
		z_free_and_null(newdir);
#else
	newdir = mkdtemp_replacement(tmpdir);
#endif
	return newdir;
}

static int dir_entry_fn(const char *fpath, const struct stat *sb,
			int typeflag, struct FTW *ftwbuf)
{
	(void) typeflag;
	(void) ftwbuf;
	switch (sb->st_mode & S_IFMT) {
	case S_IFDIR:
		if (rmdir(fpath))
			return 1;
		break;
	default:
		if (unlink(fpath))
			return 1;
		break;
	}
	return 0;
}

int z_rmdir_recursively(const char *dir)
{
	size_t i;
	int is_root = 1;
	const size_t len = strlen(dir);
	if (len == 0)
		return 0;

	/*
	 * Catch the trivial case that root ("/") is accidentally being
	 * removed. This will obviously fail, but the files will get deleted
	 * inside the root anyway, and we want to avoid that.
	 */
	for (i = 0; i < len; i++) {
		if (dir[i] != '/') {
			is_root = 0;
			break;
		}
	}
	if (is_root)
		return 0;

	if (rmdir(dir) == 0)
		return 1;

	if (errno != ENOTEMPTY)
		return 0;

	return nftw(dir, dir_entry_fn, 4, FTW_DEPTH) == 0;
}

/* rewamp: ProWizard front-end — see rewamp_prowizard.h. */

#include "rewamp_prowizard.h"

#include "common.h"
#include "hio.h"
#include "prowiz.h"

#if defined(_WIN32)
#define REWAMP_PW_NO_MEMSTREAM 1
#endif

int rewamp_prowizard_detect(const void *data, size_t len, const char **fmtName)
{
	HIO_HANDLE h;
	const struct pw_format *fmt;

	if (data == NULL || len < MIN_FILE_LENGHT) {
		return 0;
	}
	hio_open_mem(&h, data, (long)len);
	fmt = pw_check(&h, NULL);
	if (fmt == NULL) {
		return 0;
	}
	if (fmtName != NULL) {
		*fmtName = fmt->name;
	}
	return 1;
}

int rewamp_prowizard_convert(const void *data, size_t len,
                             void **out, size_t *outLen,
                             const char **fmtName)
{
	HIO_HANDLE h;
	FILE *f;
	const char *name = NULL;
	int rc;

	if (out == NULL || outLen == NULL) {
		return 0;
	}
	*out = NULL;
	*outLen = 0;

	if (data == NULL || len < MIN_FILE_LENGHT) {
		return 0;
	}
	hio_open_mem(&h, data, (long)len);

#ifdef REWAMP_PW_NO_MEMSTREAM
	/* No open_memstream: convert through a temporary file, then slurp it. */
	f = tmpfile();
	if (f == NULL) {
		return 0;
	}
	rc = pw_wizardry(&h, f, &name);
	if (rc == 0) {
		long size;
		if (fseek(f, 0, SEEK_END) == 0 && (size = ftell(f)) > 0 &&
		    fseek(f, 0, SEEK_SET) == 0) {
			void *buf = malloc((size_t)size);
			if (buf != NULL && fread(buf, 1, (size_t)size, f) == (size_t)size) {
				*out = buf;
				*outLen = (size_t)size;
			} else {
				free(buf);
				rc = -1;
			}
		} else {
			rc = -1;
		}
	}
	fclose(f);
#else
	{
		char *buf = NULL;
		size_t size = 0;

		f = open_memstream(&buf, &size);
		if (f == NULL) {
			return 0;
		}
		rc = pw_wizardry(&h, f, &name);
		fclose(f);		/* flushes buf/size */
		if (rc == 0 && buf != NULL && size > 0) {
			*out = buf;
			*outLen = size;
		} else {
			free(buf);
			rc = -1;
		}
	}
#endif

	if (rc != 0 || *out == NULL) {
		return 0;
	}
	if (fmtName != NULL) {
		*fmtName = name;
	}
	return 1;
}

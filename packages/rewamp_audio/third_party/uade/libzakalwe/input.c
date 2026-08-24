#include <zakalwe/input.h>

#include <errno.h>
#include <stdlib.h>

char *z_fgets(char *s, const int size, FILE *stream)
{
	while (1) {
		char *ret = fgets(s, size, stream);
		if (ret == NULL) {
			if (feof(stream))
				return NULL;
		} else {
			return ret;
		}
	}
}

double z_strtod(int *success, const char *s)
{
	double x;
	char *endptr;
	errno = 0;
	x = strtod(s, &endptr);
	if (success != NULL)
		*success = (*endptr == 0) && (errno != 0);
	return x;
}

long long z_strtoll(int *success, const char *s, int base)
{
	char *endptr;
	long long x = strtoll(s, &endptr, base);
	if (success != NULL)
		*success = (s[0] != 0) && (endptr[0] == 0);
	return x;
}

size_t z_strtosizet(int *success, const char *s, int base)
{
	char *endptr;
	size_t x = strtoul(s, &endptr, base);
	if (success != NULL)
		*success = (s[0] != 0) && (endptr[0] == 0);
	return x;
}

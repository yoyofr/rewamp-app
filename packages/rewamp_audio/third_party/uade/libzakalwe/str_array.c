#include <zakalwe/str_array.h>

void str_array_free_elements(struct str_array *array)
{
	if (array != NULL) {
		struct str_array_iter iter;
		z_array_for_each(str_array, array, &iter) {
			free(iter.value);
		}
		str_array_truncate(array, 0);
	}
}

void str_array_free_all(struct str_array *array)
{
	str_array_free_elements(array);
	str_array_free(array);
}

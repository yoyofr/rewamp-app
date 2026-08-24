/* memgzio.c — rewamp stub (see memgzio.h). Never exercised by GSF. */
#include "memgzio.h"

gzFile memgzopen(char* memory, int available, const char* mode) {
    (void)memory; (void)available; (void)mode; return 0;
}
int memgzread(gzFile file, voidp buf, unsigned len) {
    (void)file; (void)buf; (void)len; return -1;
}
int memgzwrite(gzFile file, const voidp buf, unsigned len) {
    (void)file; (void)buf; (void)len; return -1;
}
int memgzclose(gzFile file) { (void)file; return -1; }
long memtell(gzFile file) { (void)file; return 0; }

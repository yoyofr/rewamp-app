/* memgzio.h — rewamp stub.
 * Upstream memgzio provides in-memory .gz reading using zlib INTERNALS
 * (zutil.h/inflate.h). GSF/minigsf never use it — the GSF loader in Util.cpp
 * decompresses via the standard zlib uncompress(); memgz* is only referenced by
 * the (disabled) plain-.gz file path. So we stub the four entry points against
 * public <zlib.h> only. */
#ifndef REWAMP_MEMGZIO_STUB_H
#define REWAMP_MEMGZIO_STUB_H

#include <zlib.h>

#ifdef __cplusplus
extern "C" {
#endif

gzFile memgzopen(char* memory, int available, const char* mode);
int    memgzread(gzFile file, voidp buf, unsigned len);
int    memgzwrite(gzFile file, const voidp buf, unsigned len);
int    memgzclose(gzFile file);
long   memtell(gzFile file);

#ifdef __cplusplus
}
#endif

#endif

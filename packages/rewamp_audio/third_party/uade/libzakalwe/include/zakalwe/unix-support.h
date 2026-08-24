#ifndef _Z_UNIX_SUPPORT_H_
#define _Z_UNIX_SUPPORT_H_

#include <stdio.h>
#include <unistd.h>

#ifdef __cplusplus
extern "C" {
#endif

ssize_t z_atomic_read(int fd, const void *buf, size_t count);

#ifdef __cplusplus
}
#endif

#endif

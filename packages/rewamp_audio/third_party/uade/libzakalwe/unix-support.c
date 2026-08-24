/* TODO: Use epoll() */

#include <zakalwe/config.h>
#include <zakalwe/unix-support.h>

#include <errno.h>

#ifdef _Z_SYSCALL_SELECT
#include <sys/select.h>
#endif

#include <unistd.h>

/* Same as read(), but restarts read after EINTR and EAGAIN. */
ssize_t z_atomic_read(int fd, const void *buf, size_t count)
{
        char *b = (char *) buf;
        ssize_t bytes_read = 0;
        ssize_t ret;
	const size_t max_count = ((size_t) -1) / 2;
	if (count > max_count) {
		errno = EINVAL;
		return -1;
	}
        while (bytes_read < ((ssize_t) count)) {
                ret = read(fd, &b[bytes_read], count - bytes_read);
                if (ret < 0) {
                        if (errno == EINTR)
                                continue;
                        if (errno == EAGAIN) {
#ifdef _Z_SYSCALL_SELECT
                                fd_set s;
                                FD_ZERO(&s);
                                FD_SET(fd, &s);
                                select(fd + 1, &s, NULL, NULL, NULL);
#endif
                                continue;
                        }
			if (bytes_read == 0)
				return -1;
			break;
                } else if (ret == 0) {
			break;
                }
                bytes_read += ret;
        }
        return bytes_read;
}

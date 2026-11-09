#include <uade/unixatomic.h>
#include <uade/sysincludes.h>

#include <errno.h>
#include <stdint.h>
#include <assert.h>
#include <unistd.h>

#ifdef __EMSCRIPTEN__
/* rewamp (web): Emscripten n'a pas de socketpair(), et ses tubes vivent dans
   le FS JavaScript du fil principal: un read() BLOQUANT d'un pthread y
   attendrait un fil qui l'attend. Le frontal et le fil uadecore se parlent
   donc par un canal EN MÉMOIRE, mutex + condvar, avec la sémantique d'un
   socketpair SOCK_STREAM: deux extrémités, un sens par tampon, lecture
   partielle autorisée, EOF quand l'autre extrémité est fermée. Les
   descripteurs sont FICTIFS (UADE_MC_FD_BASE + 2*paire + extrémité) et ne
   passent que par les trois fonctions ci-dessous — unixatomic.c est le seul
   endroit où l'IPC d'UADE touche un descripteur. */
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

#define UADE_MC_FD_BASE 0x40000000
#define UADE_MC_PAIRS   4
#define UADE_MC_CAP     (1 << 20)

struct uade_mc_dir {
	uint8_t *buf;
	size_t r, len;
};
struct uade_mc_pair {
	int used;
	int open[2];             /* extrémité encore ouverte */
	struct uade_mc_dir d[2]; /* d[e] = ce que l'extrémité e LIT */
};

static pthread_mutex_t uade_mc_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t  uade_mc_cond = PTHREAD_COND_INITIALIZER;
static struct uade_mc_pair uade_mc[UADE_MC_PAIRS];

static struct uade_mc_pair *uade_mc_get(int fd, int *end)
{
	if (fd < UADE_MC_FD_BASE || fd >= UADE_MC_FD_BASE + 2 * UADE_MC_PAIRS)
		return NULL;
	*end = (fd - UADE_MC_FD_BASE) & 1;
	return &uade_mc[(fd - UADE_MC_FD_BASE) >> 1];
}

int uade_memchan_pair(int fds[2])
{
	pthread_mutex_lock(&uade_mc_lock);
	for (int i = 0; i < UADE_MC_PAIRS; i++) {
		struct uade_mc_pair *p = &uade_mc[i];
		if (p->used) continue;
		memset(p, 0, sizeof *p);
		p->d[0].buf = malloc(UADE_MC_CAP);
		p->d[1].buf = malloc(UADE_MC_CAP);
		if (!p->d[0].buf || !p->d[1].buf) {
			free(p->d[0].buf); free(p->d[1].buf);
			break;
		}
		p->used = 1;
		p->open[0] = p->open[1] = 1;
		fds[0] = UADE_MC_FD_BASE + 2 * i;
		fds[1] = UADE_MC_FD_BASE + 2 * i + 1;
		pthread_mutex_unlock(&uade_mc_lock);
		return 0;
	}
	pthread_mutex_unlock(&uade_mc_lock);
	errno = EMFILE;
	return -1;
}

static ssize_t uade_mc_read(struct uade_mc_pair *p, int e, char *b, size_t n)
{
	struct uade_mc_dir *d = &p->d[e];
	pthread_mutex_lock(&uade_mc_lock);
	while (d->len == 0 && p->open[1 - e] && p->open[e])
		pthread_cond_wait(&uade_mc_cond, &uade_mc_lock);
	size_t k = 0;
	while (k < n && d->len > 0) {
		b[k++] = d->buf[d->r];
		d->r = (d->r + 1) % UADE_MC_CAP;
		d->len--;
	}
	pthread_cond_broadcast(&uade_mc_cond);
	pthread_mutex_unlock(&uade_mc_lock);
	return (ssize_t)k;   /* 0 = EOF: l'autre extrémité est fermée */
}

static ssize_t uade_mc_write(struct uade_mc_pair *p, int e, const char *b, size_t n)
{
	struct uade_mc_dir *d = &p->d[1 - e];
	pthread_mutex_lock(&uade_mc_lock);
	while (d->len == UADE_MC_CAP && p->open[1 - e] && p->open[e])
		pthread_cond_wait(&uade_mc_cond, &uade_mc_lock);
	if (!p->open[1 - e] || !p->open[e]) {
		pthread_mutex_unlock(&uade_mc_lock);
		errno = EPIPE;
		return -1;
	}
	size_t k = 0;
	while (k < n && d->len < UADE_MC_CAP) {
		d->buf[(d->r + d->len) % UADE_MC_CAP] = (uint8_t)b[k++];
		d->len++;
	}
	pthread_cond_broadcast(&uade_mc_cond);
	pthread_mutex_unlock(&uade_mc_lock);
	return (ssize_t)k;
}

static int uade_mc_close(struct uade_mc_pair *p, int e)
{
	pthread_mutex_lock(&uade_mc_lock);
	p->open[e] = 0;
	if (!p->open[1 - e]) {
		free(p->d[0].buf); free(p->d[1].buf);
		memset(p, 0, sizeof *p);
	}
	pthread_cond_broadcast(&uade_mc_cond);
	pthread_mutex_unlock(&uade_mc_lock);
	return 0;
}
#endif /* __EMSCRIPTEN__ */

int uade_atomic_close(int fd)
{
	/*
	 * Note: uade_atomic_close() is actually useless. There are marginal
	 * platforms only where repeating on close() on EINTR is relevant.
	 */
#ifdef __EMSCRIPTEN__
	{ int e; struct uade_mc_pair *p = uade_mc_get(fd, &e);
	  if (p) return uade_mc_close(p, e); }
#endif
	close(fd);
	return 0;
}


int uade_atomic_dup2(int oldfd, int newfd)
{
  while (1) {
    if (dup2(oldfd, newfd) < 0) {
      if (errno == EINTR)
	continue;
      return -1;
    }
    break;
  }
  return newfd;
}

ssize_t uade_atomic_read(int fd, const void *buf, size_t count)
{
  char *b = (char *) buf;
  ssize_t bytes_read = 0;
  ssize_t ret;
#ifdef __EMSCRIPTEN__
  int mc_e; struct uade_mc_pair *mc_p = uade_mc_get(fd, &mc_e);
#endif
  while (bytes_read < count) {
#ifdef __EMSCRIPTEN__
    ret = mc_p ? uade_mc_read(mc_p, mc_e, &b[bytes_read], count - bytes_read)
               : read(fd, &b[bytes_read], count - bytes_read);
#else
    ret = read(fd, &b[bytes_read], count - bytes_read);
#endif
    if (ret < 0) {
      if (errno == EINTR)
        continue;
#ifndef _WIN32  /* rewamp: tubes CRT BLOQUANTS sous Windows, jamais EAGAIN */
      if (errno == EAGAIN) {
	fd_set s;
	FD_ZERO(&s);
	FD_SET(fd, &s);
	if (select(fd + 1, &s, NULL, NULL, NULL) == 0)
	  fprintf(stderr, "atomic_read: very strange. infinite select() returned 0. report this!\n");
	continue;
      }
#endif
      return -1;
    } else if (ret == 0) {
      return 0;
    }
    bytes_read += ret;
  }
  return bytes_read;
}

ssize_t uade_atomic_write(int fd, const void *buf, size_t count)
{
  char *b = (char *) buf;
  ssize_t bytes_written = 0;
  ssize_t ret;
#ifdef __EMSCRIPTEN__
  int mc_e; struct uade_mc_pair *mc_p = uade_mc_get(fd, &mc_e);
#endif
  while (bytes_written < count) {
#ifdef __EMSCRIPTEN__
    ret = mc_p ? uade_mc_write(mc_p, mc_e, &b[bytes_written], count - bytes_written)
               : write(fd, &b[bytes_written], count - bytes_written);
#else
    ret = write(fd, &b[bytes_written], count - bytes_written);
#endif
    if (ret < 0) {
      if (errno == EINTR)
        continue;
#ifndef _WIN32
      if (errno == EAGAIN) {
	fd_set s;
	FD_ZERO(&s);
	FD_SET(fd, &s);
	if (select(fd + 1, NULL, &s, NULL, NULL) == 0)
	  fprintf(stderr, "atomic_write: very strange. infinite select() returned 0. report this!\n");
	continue;
      }
#endif
      return -1;
    }
    bytes_written += ret;
  }
  return bytes_written;
}

#include <uade/ossupport.h>

/* rewamp: run uadecore in a pthread instead of fork+exec (iOS has no subprocess).
   Harness hardcodes it; the real build sets -DUADE_IN_PROCESS. */
#define UADE_IN_PROCESS 1

/* UNIX support tools

   Copyright 2000-2011 (C) Heikki Orsila <heikki.orsila@iki.fi>
   
   This module is licensed under the GNU LGPL.
*/

#include <uade/uadeipc.h>
#include <uade/unixatomic.h>

#include <assert.h>
#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <libgen.h>
#include <limits.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

int uade_filesize(size_t *size, const char *pathname)
{
	struct stat st;
	if (stat(pathname, &st))
		return -1;
	if (size)
		*size = st.st_size;
	return 0;
}

static int uade_amiga_scandir(char *real, char *dirname, char *fake, int ml)
{
	DIR *dir;
	struct dirent *direntry;
	if (!(dir = opendir(dirname))) {
		uade_warning("Can't open dir (%s) (amiga scandir)\n", dirname);
		return 0;
	}
	while ((direntry = readdir(dir))) {
		if (!strcmp(fake, direntry->d_name)) {
			if (((int) strlcpy(real, direntry->d_name, ml)) >= ml) {
				uade_warning("uade: %s does not fit real",
					     direntry->d_name);
				closedir(dir);
				return 0;
			}
			break;
		}
	}
	if (direntry) {
		closedir(dir);
		return 1;
	}
	rewinddir(dir);
	while ((direntry = readdir(dir))) {
		if (!strcasecmp(fake, direntry->d_name)) {
			if (((int) strlcpy(real, direntry->d_name, ml)) >= ml) {
				fprintf(stderr, "uade: %s does not fit real", direntry->d_name);
				closedir(dir);
				return 0;
			}
			break;
		}
	}
	closedir(dir);
	return direntry != NULL;
}

char *uade_dirname(char *dst, char *src, size_t maxlen)
{
	char *srctemp = strdup(src);
	if (srctemp == NULL)
		return NULL;
	strlcpy(dst, dirname(srctemp), maxlen);
	free(srctemp);
	return dst;
}


/* Find file in amiga namespace */
int uade_find_amiga_file(char *realname, size_t maxlen, const char *aname,
			 const char *playerdir, const char *moduledir)
{
	char *separator;
	char *ptr;
	char copy[PATH_MAX];
	char dirname[PATH_MAX];
	char fake[PATH_MAX];
	char real[PATH_MAX];
	int len;
	DIR *dir;
	FILE *file;
	size_t strip_offset;

	if (strlcpy(copy, aname, sizeof(copy)) >= sizeof(copy)) {
		uade_warning("error: amiga tried to open a very long "
			     "filename.\nPlease REPORT THIS!\n");
		return -1;
	}

#ifdef UADE_IN_PROCESS
#include "rewamp_loaded_files.h"
#endif

#ifdef UADE_IN_PROCESS
	/* rewamp: macOS/iOS sandbox + TCC forbid opendir() on a path's ancestor
	   directories (e.g. "/Users/"), which makes the case-insensitive component
	   walk below fail even when the requested file exists at an exact path
	   (multifile formats: TFMX .mdat/.smpl, sampled songs, …). open() of an
	   exact path is still permitted, so resolve the file directly without any
	   opendir(): try the literal name, then the name relative to the module's
	   directory, and use the first one that is a readable regular file. */
	{
		struct stat _rw_st;
		char _rw_cand[PATH_MAX];
		const char *_rw_try[2];
		int _rw_n = 0;
		_rw_try[_rw_n++] = aname;
		if (aname[0] != '/' && moduledir != NULL && moduledir[0]) {
			snprintf(_rw_cand, sizeof(_rw_cand), "%s/%s", moduledir, aname);
			_rw_try[_rw_n++] = _rw_cand;
		}
		for (int _rw_i = 0; _rw_i < _rw_n; _rw_i++) {
			if (stat(_rw_try[_rw_i], &_rw_st) == 0 && S_ISREG(_rw_st.st_mode)) {
				FILE *_rw_f = fopen(_rw_try[_rw_i], "rb");
				if (_rw_f != NULL) {
					fclose(_rw_f);
					strlcpy(realname, _rw_try[_rw_i], maxlen);
					/* rewamp: pour le panneau ⓘ. C'est ICI que passent TOUS les
					   fichiers que le 68k ouvre — le module et ses compagnons
					   (smpl.NOM d'un TFMX, banques d'échantillons) — donc c'est
					   le seul endroit qui les connaisse vraiment. */
					rewamp_loaded_files_add(realname);
					return 0;
				}
			}
		}

		/* rewamp: SUFFIX-convention companion. Amiga multifile formats use the
		   PREFIX convention ("mdat.NAME" + "smpl.NAME"), and the eagleplayer
		   derives the companion by swapping the prefix token. When the user
		   opens a SUFFIX-form module instead ("NAME.mdat" + "NAME.smpl", e.g. a
		   local file not from modland), the player requests "smpl.NAME.mdat",
		   which doesn't exist. Remap "TOK.STEM.EXT" -> "STEM.TOK" (the sample
		   sibling of the suffix-form module) and try it next to the module. */
		{
			const char *base = strrchr(aname, '/');
			base = base ? base + 1 : aname;
			const char *dot1 = strchr(base, '.');
			if (dot1 != NULL && dot1 > base) {
				const char *rest = dot1 + 1;          /* "STEM.EXT" */
				const char *dotN = strrchr(rest, '.');
				if (dotN != NULL && dotN > rest) {
					size_t toklen  = (size_t)(dot1 - base);
					size_t stemlen = (size_t)(dotN - rest);
					char _rw_comp[PATH_MAX];
					/* "<moduledir>/STEM.TOK" */
					int wrote = snprintf(_rw_comp, sizeof(_rw_comp),
						"%s/%.*s.%.*s",
						(moduledir && moduledir[0]) ? moduledir : ".",
						(int)stemlen, rest, (int)toklen, base);
					if (wrote > 0 && (size_t)wrote < sizeof(_rw_comp) &&
					    stat(_rw_comp, &_rw_st) == 0 && S_ISREG(_rw_st.st_mode)) {
						FILE *_rw_f = fopen(_rw_comp, "rb");
						if (_rw_f != NULL) {
							fclose(_rw_f);
							strlcpy(realname, _rw_comp, maxlen);
							rewamp_loaded_files_add(realname);
							return 0;
						}
					}
				}
			}
		}

		/* rewamp: nom de module à PLUSIEURS points — le compagnon se nomme sur
		   le DÉBUT du nom, pas sur tout.

		   Les players dérivent le fichier d'échantillons en échangeant la
		   DERNIÈRE extension. Ça tient tant que le nom n'a qu'un point. Sur
		   modland, l'Infogrames « north & south.national.dum » a pour banque
		   « north & south.ins » — le player demande donc
		   « north & south.national.ins », puis « north & south.nationa.ins »
		   (sa seconde tentative retire un caractère), et échoue: « score died ».

		   Corrigé ICI plutôt que dans le player: `players/Infogrames` est un
		   binaire 68k de l'arbre de données UADE dont nous n'avons pas la
		   source (`amigasrc/` ne contient que le score), le patcher demanderait
		   de le désassembler et serait perdu à la prochaine resynchro amont —
		   alors que cette fonction est le SEUL entonnoir par où passent tous
		   les fichiers que le 68k ouvre. Et le correctif couvre toute la classe
		   du problème, pas seulement Infogrames.

		   On RACCOURCIT le radical point par point, du plus spécifique au plus
		   court, en gardant l'extension demandée. Uniquement en dernier
		   recours (les chemins exacts ont déjà échoué), uniquement vers un
		   nom PLUS COURT, et seulement à côté du module. */
		{
			const char *base = strrchr(aname, '/');
			base = base ? base + 1 : aname;
			const char *ext = strrchr(base, '.');
			if (ext != NULL && ext > base) {
				const char *dir = (moduledir && moduledir[0]) ? moduledir : ".";
				/* Chaque point du radical, du plus À DROITE au plus à gauche:
				   « a.b.c.ins » essaie « a.b.ins » puis « a.ins ». */
				for (const char *cut = ext; cut > base; cut--) {
					if (*cut != '.' || cut == ext)
						continue;
					char _rw_short[PATH_MAX];
					int wrote = snprintf(_rw_short, sizeof(_rw_short),
						"%s/%.*s%s", dir, (int)(cut - base), base, ext);
					if (wrote <= 0 || (size_t)wrote >= sizeof(_rw_short))
						continue;
					if (stat(_rw_short, &_rw_st) != 0 ||
					    !S_ISREG(_rw_st.st_mode))
						continue;
					FILE *_rw_f = fopen(_rw_short, "rb");
					if (_rw_f == NULL)
						continue;
					fclose(_rw_f);
					strlcpy(realname, _rw_short, maxlen);
					rewamp_loaded_files_add(realname);
					return 0;
				}
			}
		}
	}
#endif

	ptr = copy;
	if ((separator = strchr(ptr, (int) ':'))) {
		len = (int) (separator - ptr);
		memcpy(dirname, ptr, len);
		dirname[len] = 0;
		if (!strcasecmp(dirname, "ENV")) {
			snprintf(dirname, sizeof(dirname), "%s/ENV/", playerdir);
		} else if (!strcasecmp(dirname, "S")) {
			snprintf(dirname, sizeof(dirname), "%s/S/", playerdir);
		} else if (!strcasecmp(dirname, "Instruments") && moduledir != NULL) {
			// ScottJohnston player loads samples from Instruments: volume
			//
			// REWAMP: the directory name is resolved CASE-INSENSITIVELY.
			// Upstream hardcodes lowercase "instruments/", which only ever
			// worked because the machines it was tested on had a
			// case-insensitive filesystem. modland ships SMUS samples under
			// "Instruments/" (capital I) and that is the name our downloader
			// writes, so on Linux and Android the opendir() below failed and
			// the tune played with no instruments at all.
			//
			// uade_amiga_scandir() is the very helper this file already uses
			// for every other path component, for exactly this reason; the
			// lowercase spelling stays as the fallback so a tree that really
			// has "instruments/" keeps working.
			char _rw_real[PATH_MAX];
			char _rw_base[PATH_MAX];
			snprintf(_rw_base, sizeof(_rw_base), "%s/", moduledir);
			if (uade_amiga_scandir(_rw_real, _rw_base, "Instruments",
					       sizeof(_rw_real))) {
				snprintf(dirname, sizeof(dirname), "%s/%s/",
					 moduledir, _rw_real);
			} else {
				snprintf(dirname, sizeof(dirname),
					 "%s/instruments/", moduledir);
			}
		} else {
			uade_warning("open_amiga_file: unknown amiga volume "
				     "(%s)\n", aname);
			return -1;
		}
		if (!(dir = opendir(dirname))) {
			uade_warning("Can't open dir (%s) (volume parsing)\n",
				     dirname);
			return -1;
		}
		closedir(dir);
		ptr = separator + 1;
	} else {
		if (*ptr == '/') {
			/* absolute path */
			strlcpy(dirname, "/", sizeof(dirname));
			ptr++;
		} else {
			/* relative path */
			strlcpy(dirname, "./", sizeof(dirname));
		}
	}

	while ((separator = strchr(ptr, (int) '/'))) {
		len = (int) (separator - ptr);
		if (!len) {
			ptr++;
			continue;
		}
		memcpy(fake, ptr, len);
		fake[len] = 0;
		if (uade_amiga_scandir(real, dirname, fake, sizeof(real))) {
			/* found matching entry */
			if (strlcat(dirname, real, sizeof(dirname)) >= sizeof(dirname)) {
				uade_warning("Too long dir path (%s + %s)\n",
					     dirname, real);
				return -1;
			}
			if (strlcat(dirname, "/", sizeof(dirname)) >= sizeof(dirname)) {
				uade_warning("Too long dir path (%s + %s)\n",
					     dirname, "/");
				return -1;
			}
		} else {
			/* didn't find entry */
			return -1;
		}
		ptr = separator + 1;
	}

	if (!(dir = opendir(dirname))) {
		uade_warning("Can't open dir (%s) after scanning\n", dirname);
		return -1;
	}
	closedir(dir);

	if (uade_amiga_scandir(real, dirname, ptr, sizeof(real))) {
		/* found matching entry */
		if (strlcat(dirname, real, sizeof(dirname)) >= sizeof(dirname)) {
			uade_warning("Too long dir path (%s + %s)\n",
				     dirname, real);
			return -1;
		}
	} else {
		/* didn't find entry */
		return -1;
	}

	file = fopen(dirname, "rb");
	if (file == NULL) {
		uade_warning("Couldn't open file (%s) induced by (%s)\n",
			     dirname, aname);
		return -1;
	}
	fclose(file);

	/* Strip leading "./" from the real path name when copying */
	strip_offset = (strncmp(dirname, "./", 2) == 0) ? 2 : 0;

	strlcpy(realname, dirname + strip_offset, maxlen);

	return 0;
}

#ifdef UADE_IN_PROCESS
#include <pthread.h>
extern int uadecore_main(int argc, char **argv);
static pthread_t uadecore_thread;
static int       uadecore_thread_active;
static int       uadecore_thread_fd;

static void *uadecore_thread_entry(void *arg)
{
	char in[16], out[16];
	(void) arg;
	snprintf(in,  sizeof in,  "%d", uadecore_thread_fd);
	snprintf(out, sizeof out, "%d", uadecore_thread_fd);
	char *argv[] = {"uadecore", "-i", in, "-o", out, NULL};
	uadecore_main(5, argv);
	return NULL;
}
#endif

void uade_arch_kill_and_wait_uadecore(struct uade_ipc *ipc, pid_t *uadepid)
{
	if (*uadepid == 0)
		return;

	uade_atomic_close(ipc->in_fd);
	uade_atomic_close(ipc->out_fd);

#ifdef UADE_IN_PROCESS
	/* Closing our side gives the uadecore thread EOF → it returns. */
	if (uadecore_thread_active) {
		pthread_join(uadecore_thread, NULL);
		uadecore_thread_active = 0;
	}
#else
	/*
	 * Wait until one of two happens:
	 * 1. uadepid is successfully handled (waitpid() returns uadepid)
	 * 2. someone else has processed uadepid (waitpid() returns -1)
	 */
	while (waitpid(*uadepid, NULL, 0) == -1 && errno == EINTR);
#endif

	*uadepid = 0;
}

int uade_arch_spawn(struct uade_ipc *ipc, pid_t *uadepid, const char *uadename,
		    const int *keep_fds)
{
	int fds[2];
	char input[32], output[32];

	if (socketpair(AF_UNIX, SOCK_STREAM, 0, fds)) {
		uade_warning("Can not create socketpair: %s\n",
			     strerror(errno));
		return -1;
	}

#ifdef UADE_IN_PROCESS
	(void) uadename; (void) keep_fds;
	uadecore_thread_fd = fds[1];
	uadecore_thread_active = 1;
	if (pthread_create(&uadecore_thread, NULL, uadecore_thread_entry, NULL)) {
		uade_warning("Can not create uadecore thread: %s\n", strerror(errno));
		uadecore_thread_active = 0;
		return -1;
	}
	*uadepid = 1; /* non-zero: frontend treats uadecore as running */
	/* fds[1] is shared with the thread — do NOT close it here. */
	uade_set_peer(ipc, 1, fds[0], fds[0]);
	return 0;
#else
	*uadepid = fork();
	if (*uadepid < 0) {
		fprintf(stderr, "Fork failed: %s\n", strerror(errno));
		return -1;
	}

	/* The child (*uadepid == 0) will execute uadecore */
	if (*uadepid == 0) {
		int fd;
		int maxfds;
		sigset_t sigset;

		/* Unblock SIGTERM in the child, we might need it */
		sigemptyset(&sigset);
		sigaddset(&sigset, SIGTERM);
		sigprocmask(SIG_UNBLOCK, &sigset, NULL);

		if ((maxfds = sysconf(_SC_OPEN_MAX)) < 0) {
			maxfds = 1024;
			fprintf(stderr, "Getting max fds failed. Using %d.\n",
				maxfds);
		}

		/*
		 * Close everything else but stdin, stdout, stderr, and
		 * in/out fds
		 */
		for (fd = 3; fd < maxfds; fd++) {
			int close_fd = (fd != fds[1]);
			for (int i = 0; keep_fds != NULL && keep_fds[i] >= 0;
			     i++) {
				if (keep_fds[i] == fd) {
					close_fd = 0;
					break;
				}
			}
			if (close_fd) {
				uade_atomic_close(fd);
			}
		}

		/* give in/out fds as command line parameters to uadecore */
		snprintf(input, sizeof input, "%d", fds[1]);
		snprintf(output, sizeof output, "%d", fds[1]);

		execlp(uadename, uadename, "-i", input, "-o", output, NULL);
		uade_die("uade execlp (%s) failed: %s\n",
			 uadename, strerror(errno));
	}

	/* Close fds that the uadecore uses */
	if (uade_atomic_close(fds[1]) < 0) {
		fprintf(stderr, "Could not close uadecore fds: %s\n",
			strerror(errno));
		kill (*uadepid, SIGKILL);
		return -1;
	}

	uade_set_peer(ipc, 1, fds[0], fds[0]);
	return 0;
#endif
}
#include <limits.h>
#include <stdlib.h>

char *canonicalize_file_name(const char *path)
{
	char *s = malloc(PATH_MAX);
	if (s == NULL)
		return NULL;

	if (realpath(path, s) == NULL) {
		free(s);
		return NULL;
	}

	return s;
}


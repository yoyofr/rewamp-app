/* <unistd.h> pour MSVC — voir README.md de ce dossier.
 *
 * Ne couvre que ce que les arbres vendorés de ce dépôt demandent réellement:
 * les descripteurs bas niveau (que l'UCRT a, sous un autre nom), `ssize_t`,
 * les constantes d'accès de `access()` et les trois STD*_FILENO.
 *
 * ⚠️ Rien ici ne SIMULE un appel que Windows n'a pas. `fork`, `pipe`,
 * `symlink` et compagnie sont volontairement ABSENTS: un moteur qui les
 * réclame doit être traité à son niveau, pas rendu compilable pour planter
 * ensuite. */
#ifndef REWAMP_WIN_COMPAT_UNISTD_H
#define REWAMP_WIN_COMPAT_UNISTD_H

#include <io.h>
#include <process.h>
#include <direct.h>
#include <stdlib.h>

/* `ssize_t` n'est pas un type de l'UCRT. MSVC fournit `SSIZE_T` dans
 * <BaseTsd.h>, mais l'inclure tirerait windows.h; la définition directe suffit
 * et vaut pour les deux modèles de données. */
#ifndef _SSIZE_T_DEFINED
#define _SSIZE_T_DEFINED
#ifdef _WIN64
typedef __int64 ssize_t;
#else
typedef int ssize_t;
#endif
#endif

/* Les modes de `access()`. L'UCRT les connaît en valeurs mais ne nomme que
 * les `_A_*`; X_OK n'existe pas sous Windows et vaut R_OK, comme le fait
 * l'implémentation de MSVC elle-même. */
#ifndef F_OK
#define F_OK 0
#endif
#ifndef X_OK
#define X_OK 4
#endif
#ifndef W_OK
#define W_OK 2
#endif
#ifndef R_OK
#define R_OK 4
#endif

#ifndef STDIN_FILENO
#define STDIN_FILENO  0
#endif
#ifndef STDOUT_FILENO
#define STDOUT_FILENO 1
#endif
#ifndef STDERR_FILENO
#define STDERR_FILENO 2
#endif

/* L'UCRT porte ces fonctions sous un nom préfixé. `_CRT_NONSTDC_NO_DEPRECATE`
 * (posé par windows/CMakeLists.txt) rend déjà les noms POSIX disponibles pour
 * la plupart; ces alias couvrent ceux qu'il ne couvre pas. */
#ifndef rewamp_win_compat_no_aliases
#define ftruncate(fd, len) _chsize_s((fd), (len))
#define getpid()           _getpid()
#endif

#endif /* REWAMP_WIN_COMPAT_UNISTD_H */

/* <strings.h> pour MSVC — voir README.md de ce dossier.
 *
 * L'en-tête POSIX ne porte que les comparaisons insensibles à la casse et
 * ffs(). L'UCRT a les deux premières sous un nom préfixé. */
#ifndef REWAMP_WIN_COMPAT_STRINGS_H
#define REWAMP_WIN_COMPAT_STRINGS_H

#include <string.h>

#ifndef strcasecmp
#define strcasecmp  _stricmp
#endif
#ifndef strncasecmp
#define strncasecmp _strnicmp
#endif

#endif /* REWAMP_WIN_COMPAT_STRINGS_H */

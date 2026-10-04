/* Fonctions POSIX que MSVC a sous un AUTRE nom — FORCE-INCLUS (/FI) par
 * `rewamp_win_compat()`, voir README.md de ce dossier.
 *
 * À distinguer de ce que fait `_CRT_NONSTDC_NO_DEPRECATE` (posé dans
 * windows/CMakeLists.txt): ce define-là rend disponibles les noms POSIX que
 * l'UCRT porte VRAIMENT (`strdup`, `read`, `close`…). Les noms ci-dessous
 * n'existent sous AUCUNE forme non préfixée, quel que soit le define — il faut
 * les aliaser.
 *
 * ⚠️ Des macros et non des fonctions: les appelants sont du C et du C++ dans
 * des arbres vendorés qu'on resynchronise, et une macro ne demande pas que la
 * déclaration soit visible au bon endroit. Gardées une par une, donc sans
 * effet si l'arbre a déjà son propre alias. */
#ifndef REWAMP_WIN_POSIX_FNS_H
#define REWAMP_WIN_POSIX_FNS_H

#if defined(_MSC_VER)

#include <string.h>
#include <stdio.h>

/* Comparaisons insensibles à la casse: jamais présentes sous ce nom chez
 * MSVC. C'est l'absence la plus fréquente dans ce dépôt (libgme, adplug, sc68,
 * mdxplay…). */
#ifndef strcasecmp
#define strcasecmp  _stricmp
#endif
#ifndef strncasecmp
#define strncasecmp _strnicmp
#endif
#ifndef wcscasecmp
#define wcscasecmp  _wcsicmp
#endif

/* `strtok_r` est POSIX; l'équivalent MSVC prend le MÊME troisième argument
 * (un `char**` de contexte), donc l'alias est exact. */
#ifndef strtok_r
#define strtok_r    strtok_s
#endif

#endif /* _MSC_VER */
#endif /* REWAMP_WIN_POSIX_FNS_H */

/* Typedefs POSIX que MSVC n'a pas — FORCE-INCLUS (/FI) dans les cibles qui en
 * ont besoin, voir README.md de ce dossier.
 *
 * Pourquoi un force-include et pas un `#include` dans les sources: ces noms
 * (`u_char` et sa famille) viennent de <sys/types.h> sur les BSD et la glibc,
 * donc les arbres qui s'en servent ne les incluent de NULLE PART — ils les
 * attendent du système. Les ajouter source par source voudrait dire toucher
 * une dizaine de fichiers par moteur, dans des arbres qu'on resynchronise.
 *
 * ⚠️ Posé en TÊTE de chaque TU de la cible, donc AVANT windows.h. C'est
 * nécessaire — les déclarations qui utilisent `u_char` sont dans les en-têtes
 * du moteur — et sans risque: ces noms-là n'existent dans aucun en-tête
 * Windows, et chaque typedef est gardé. */
#ifndef REWAMP_POSIX_TYPES_H
#define REWAMP_POSIX_TYPES_H

#if defined(_MSC_VER)

#ifndef REWAMP_HAVE_U_CHAR
#define REWAMP_HAVE_U_CHAR
typedef unsigned char  u_char;
typedef unsigned short u_short;
typedef unsigned int   u_int;
typedef unsigned long  u_long;
#endif

/* `ssize_t` est aussi déclaré par notre <unistd.h> de compat; la garde
 * `_SSIZE_T_DEFINED` est la même que celle de MSVC, donc les trois sources
 * possibles coexistent. */
#ifndef _SSIZE_T_DEFINED
#define _SSIZE_T_DEFINED
#ifdef _WIN64
typedef __int64 ssize_t;
#else
typedef int ssize_t;
#endif
#endif

/* `off_t`: MSVC l'a, dans <sys/types.h>, que `psftag.c` (gsf) n'inclut pas — il
 * l'attend du systeme comme `u_char`. On INCLUT donc l'en-tete du CRT au lieu
 * de declarer le type nous-memes.
 *
 * ⚠️ Ne JAMAIS poser `_OFF_T_DEFINED` pour le declarer soi-meme, meme avec le
 * bon type. Ce nom est le VERROU INTERNE du CRT: le definir empeche
 * <corecrt.h> de declarer `_off_t`, dont depend `st_size` dans
 * `struct _stat64i32` — donc `struct stat` entiere. Mesure le 2026-10-02:
 * 825 erreurs `C3646: 'st_size'` + 825 `C4430` reparties sur NEUF cibles, et
 * aucune ne nomme off_t. Le piege est general: un nom en `_X_DEFINED` ou
 * `_CRT_*` appartient au CRT, pas a nous.
 *
 * (`ssize_t` ci-dessus est l'exception verifiee: `_SSIZE_T_DEFINED` n'est
 * utilise par AUCUN en-tete du CRT de MSVC, qui ne declare pas ce type du
 * tout.) */
#include <sys/types.h>

/* PATH_MAX: Windows a MAX_PATH (260) dans windows.h, mais les arbres vendorés
 * s'en servent pour DIMENSIONNER des tampons de chemin, et un chemin Windows
 * peut dépasser 260 caractères depuis Windows 10. On prend la borne longue. */
#ifndef PATH_MAX
#define PATH_MAX 1024
#endif

#endif /* _MSC_VER */
#endif /* REWAMP_POSIX_TYPES_H */

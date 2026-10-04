/* psgplay sous MSVC — FORCE-INCLUS (/FI) sur la SEULE cible rewamp_psgplay
 * (rewamp_add_psgplay, cmake/rewamp.cmake). psgplay est écrit en C GNU (macros
 * du noyau Linux); ce fichier ne couvre que ce qui se règle SANS toucher à
 * l'arbre. Le reste (expressions-instructions, macros variadiques nommées,
 * terminaisons `;` des *_BITFIELD) est corrigé dans l'arbre vendoré lui-même,
 * voir docs/BUILD_WINDOWS.md §6.4. */
#ifndef REWAMP_PSGPLAY_MSVC_H
#define REWAMP_PSGPLAY_MSVC_H

#if defined(_MSC_VER) && !defined(__clang__)

/* ⚠️ Le piège SILENCIEUX: chaque `*_BITFIELD` choisit l'ordre de ses champs
 * par `#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__`. MSVC ne définit aucun des
 * trois noms, le préprocesseur les vaut 0, `0 == 0` est vrai et la branche
 * GROS-boutiste est prise: tous les registres des puces (YM2149, MFP, DMA)
 * auraient leurs champs de bits inversés, sans une erreur. x64 et ARM64 sous
 * Windows sont petit-boutistes. */
#define __ORDER_LITTLE_ENDIAN__ 1234
#define __ORDER_BIG_ENDIAN__    4321
#define __BYTE_ORDER__          __ORDER_LITTLE_ENDIAN__

/* Attributs GNU: tous NEUTRES dans le code compilé côté hôte — mesuré:
 *   format, noreturn, __error__  : diagnostics seulement;
 *   __packed__                   : seulement sur des structs TOS (system-
 *                                  variable.h, xbra.h) que l'hôte n'instancie
 *                                  jamais — il n'en lit que les ADRESSES;
 *   __mode__                     : défini (`__mode(x)`), jamais employé;
 *   __scalar_storage_order__     : structs du désassembleur et des outils ELF,
 *                                  qu'aucune source compilée n'inclut;
 *   section, __interrupt__       : côté 68k (toslibc/asm), jamais inclus.
 * ⚠️ Un NOUVEL usage de __packed__ ou de __scalar_storage_order__ dans une
 * source compilée invaliderait ce raccourci: refaire ce relevé à chaque
 * resynchro de psgplay. */
#define __attribute__(x)

/* Orthographe GNU des mots-clés standard (mfp-map.h, …). */
#define __volatile__ volatile

#endif /* _MSC_VER && !__clang__ */
#endif /* REWAMP_PSGPLAY_MSVC_H */

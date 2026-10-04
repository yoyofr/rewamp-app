/* Intrinsèques GCC/clang que MSVC n'a pas — FORCE-INCLUS (/FI) par
 * `rewamp_win_compat()`, voir README.md de ce dossier.
 *
 * Ces `__builtin_*` ne sont pas des appels de bibliothèque: ce sont des
 * intrinsèques du compilateur, donc l'éditeur de liens ne les rattrape pas et
 * l'échec est une erreur de COMPILATION (« identificateur introuvable »).
 * MSVC a des équivalents, sous d'autres noms et avec des conventions
 * différentes — c'est là que se cachent les pièges, notés ligne par ligne.
 *
 * ⚠️ On ne définit QUE ce que les arbres de ce dépôt réclament. Un
 * `__builtin_*` manquant se verra à la compilation, ce qui est exactement le
 * bon moment; une émulation « au cas où » ne se vérifierait jamais. */
#ifndef REWAMP_WIN_BUILTINS_H
#define REWAMP_WIN_BUILTINS_H

#if defined(_MSC_VER) && !defined(__clang__)

#include <intrin.h>

/* Indices de branche: MSVC n'a pas d'équivalent et n'en a pas besoin — ce sont
 * des indications d'OPTIMISATION, sans effet sémantique. On rend l'expression
 * telle quelle. ⚠️ `(void)(exp)` serait faux: la valeur est UTILISÉE (`if
 * (__builtin_expect(x, 0))`). */
#ifndef __builtin_expect
#define __builtin_expect(expr, expected) (expr)
#endif

/* `__builtin_unreachable` annonce au compilateur qu'un point est inatteignable.
 * `__assume(0)` est l'exact équivalent MSVC. */
#ifndef __builtin_unreachable
#define __builtin_unreachable() __assume(0)
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* ⚠️ `__builtin_ctz(0)` est un comportement INDÉFINI chez GCC, et
 * `_BitScanForward` rend 0 sans toucher à l'index. On rend 32 dans ce cas —
 * la valeur que donnent les implémentations qui définissent le cas — plutôt
 * que de laisser un index non initialisé, qui serait une lecture indéterminée
 * là où l'amont ne voit qu'un entier. */
static __forceinline int rewamp_builtin_ctz(unsigned int x)
{
    unsigned long i;
    if (!_BitScanForward(&i, (unsigned long)x)) return 32;
    return (int)i;
}

static __forceinline int rewamp_builtin_clz(unsigned int x)
{
    unsigned long i;
    if (!_BitScanReverse(&i, (unsigned long)x)) return 32;
    return (int)(31 - i);
}

#ifdef __cplusplus
}
#endif

#ifndef __builtin_ctz
#define __builtin_ctz(x) rewamp_builtin_ctz((unsigned int)(x))
#endif
#ifndef __builtin_clz
#define __builtin_clz(x) rewamp_builtin_clz((unsigned int)(x))
#endif
/* `__popcnt` est une instruction SSE4.2. Tout x86-64 que cette app vise la
 * porte, et MSVC l'émet sans drapeau particulier. */
#ifndef __builtin_popcount
#define __builtin_popcount(x) ((int)__popcnt((unsigned int)(x)))
#endif

/* ── Variantes 64 bits ───────────────────────────────────────────────────────
 * melonDS (vio2sf) passe par `__builtin_ctzll` dans NonStupidBitfield.h, qui
 * est un en-tete INCLUS PARTOUT: la meme erreur ressortait sur une trentaine
 * de TU, ce qui donne l'impression d'un probleme diffus alors qu'il n'y a
 * qu'un site.
 *
 * ⚠️ `_BitScanForward64`/`_BitScanReverse64` et `__popcnt64` n'existent QU'EN
 * x64 — en x86 32 bits il faudrait les composer sur deux moities. On ne le
 * fait pas: cette app est 64 bits, et une emulation jamais compilee serait une
 * dette qui se decouvrirait au pire moment. */
#if defined(_M_X64) || defined(_M_ARM64)

#ifdef __cplusplus
extern "C" {
#endif

/* Meme convention que la version 32 bits: 64 pour une entree nulle, la ou
 * GCC laisse le resultat indefini et `_BitScan*` ne touche pas a l'index. */
static __forceinline int rewamp_builtin_ctzll(unsigned long long x)
{
    unsigned long i;
    if (!_BitScanForward64(&i, x)) return 64;
    return (int)i;
}

static __forceinline int rewamp_builtin_clzll(unsigned long long x)
{
    unsigned long i;
    if (!_BitScanReverse64(&i, x)) return 64;
    return (int)(63 - i);
}

#ifdef __cplusplus
}
#endif

#ifndef __builtin_ctzll
#define __builtin_ctzll(x) rewamp_builtin_ctzll((unsigned long long)(x))
#endif
#ifndef __builtin_clzll
#define __builtin_clzll(x) rewamp_builtin_clzll((unsigned long long)(x))
#endif
#ifndef __builtin_popcountll
#define __builtin_popcountll(x) ((int)__popcnt64((unsigned long long)(x)))
#endif

#endif /* x64 */

#endif /* _MSC_VER && !__clang__ */
#endif /* REWAMP_WIN_BUILTINS_H */

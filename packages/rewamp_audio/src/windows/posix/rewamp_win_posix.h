/* Ce que le COEUR du moteur attend de POSIX et que l'UCRT n'a pas —
 * FORCE-INCLUS (/FI) dans la cible `rewamp_audio` seulement, voir pthread.h de
 * ce dossier pour le pourquoi du périmètre.
 *
 * Pas de <windows.h> ici: les corps sont dans rewamp_win_posix.c. */
#ifndef REWAMP_WIN_POSIX_H
#define REWAMP_WIN_POSIX_H

#if defined(_MSC_VER)

#include <time.h>

/* ── Horloge ───────────────────────────────────────────────────────────────
 * L'UCRT a `struct timespec` et `timespec_get(TIME_UTC)`, mais ni horloge
 * MONOTONE ni nanosleep. Le moteur s'en sert pour mesurer des écarts (tête de
 * lecture lissée, télémétrie) et pour l'attente du producteur: une horloge
 * murale y ferait sauter la tête de lecture à chaque recalage NTP. */
#ifndef CLOCK_REALTIME
#define CLOCK_REALTIME  0
#endif
#ifndef CLOCK_MONOTONIC
#define CLOCK_MONOTONIC 1
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* CLOCK_MONOTONIC → QueryPerformanceCounter; CLOCK_REALTIME → timespec_get.
 * Toute autre horloge rend -1. */
int clock_gettime(int clock_id, struct timespec* ts);

/* ⚠️ Arrondi AU-DESSUS à la milliseconde, et soumis à la granularité du
 * minuteur système (jusqu'à ~15,6 ms par défaut): une attente de 10 ms peut
 * en durer 16. Les appelants dorment quand il n'y a RIEN à faire (anneau
 * plein, 200 ms d'avance), jamais pour cadencer. `rem` n'est pas rempli. */
int nanosleep(const struct timespec* req, struct timespec* rem);

#ifdef __cplusplus
}
#endif

/* ── Prédicats de `st_mode` ────────────────────────────────────────────────
 * L'UCRT a les masques (`_S_IFMT`, `_S_IFREG`, `_S_IFDIR`) mais pas ces
 * macros. ⚠️ En C un `S_ISREG` absent n'est PAS une erreur de compilation:
 * c'est une fonction implicite, donc un externe non résolu au LIEN, loin de la
 * ligne fautive. <sys/stat.h> n'est pas inclus ici exprès: les masques ne sont
 * lus qu'à l'EXPANSION, là où l'appelant a déjà son `struct stat`. */
#ifndef S_ISREG
#define S_ISREG(m) (((m) & _S_IFMT) == _S_IFREG)
#endif
#ifndef S_ISDIR
#define S_ISDIR(m) (((m) & _S_IFMT) == _S_IFDIR)
#endif

#endif /* _MSC_VER */
#endif /* REWAMP_WIN_POSIX_H */

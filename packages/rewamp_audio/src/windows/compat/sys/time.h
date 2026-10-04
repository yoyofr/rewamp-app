/* <sys/time.h> pour MSVC — voir ../README.md.
 *
 * `struct timeval` existe déjà sous Windows (winsock2.h), et c'est le piège:
 * la redéclarer provoque un conflit dès qu'une autre TU tire winsock. On prend
 * donc celle du système, et on n'ajoute que `gettimeofday`, qui manque.
 *
 * ⚠️ Les appelants de ce dépôt ne s'en servent que pour MESURER un écart
 * (mdxplay/pcm8.c, uade), jamais pour lire une date absolue à la seconde
 * près — d'où une implémentation sur `GetSystemTimeAsFileTime`, monotone à
 * l'échelle qui nous intéresse et sans dépendance à winmm. */
#ifndef REWAMP_WIN_COMPAT_SYS_TIME_H
#define REWAMP_WIN_COMPAT_SYS_TIME_H

#include <time.h>
/* ⚠️ winsock2.h AVANT windows.h, toujours: l'ordre inverse fait tirer le
 * winsock 1.1 de windef.h et les deux se contredisent (« redefinition of
 * fd_set »). winsock2.h porte `struct timeval`; windows.h porte FILETIME et
 * GetSystemTimeAsFileTime. */
#include <winsock2.h>
#include <windows.h>

#ifndef _TIMEZONE_DEFINED
#define _TIMEZONE_DEFINED
struct timezone {
    int tz_minuteswest;
    int tz_dsttime;
};
#endif

#ifdef __cplusplus
extern "C" {
#endif

static __inline int rewamp_win_gettimeofday(struct timeval *tv, struct timezone *tz)
{
    /* 100 ns depuis 1601-01-01; 11644473600 s séparent cette époque d'Unix. */
    FILETIME ft;
    unsigned __int64 t;
    (void)tz;
    if (tv == 0) return -1;
    GetSystemTimeAsFileTime(&ft);
    t  = ((unsigned __int64)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
    t /= 10;                                /* → microsecondes */
    t -= (unsigned __int64)11644473600000000ULL;
    tv->tv_sec  = (long)(t / 1000000ULL);
    tv->tv_usec = (long)(t % 1000000ULL);
    return 0;
}

#ifdef __cplusplus
}
#endif

#define gettimeofday(tv, tz) rewamp_win_gettimeofday((tv), (tz))

#endif /* REWAMP_WIN_COMPAT_SYS_TIME_H */

/* UADE sous MSVC — FORCE-INCLUS (/FI) sur la SEULE cible rewamp_uade
 * (rewamp_add_uade, cmake/rewamp.cmake). Ne couvre que ce qui se règle SANS
 * toucher à l'arbre; le reste est corrigé dans l'arbre vendoré, voir
 * docs/BUILD_WINDOWS.md §6.3. */
#ifndef REWAMP_UADE_MSVC_H
#define REWAMP_UADE_MSVC_H

#if defined(_MSC_VER) && !defined(__clang__)

/* Attributs GNU — relevé du 2026-10-04 sur les sources compilées:
 *   format, noreturn, unused, __unused__ : diagnostics seulement;
 *   packed : cinq structs d'échange (uadeipc.h, write_audio_ext.h), que
 *            l'arbre entoure désormais de `#pragma pack(push, 1)` sous MSVC —
 *            même disposition que GCC.
 * ⚠️ Un NOUVEL attribut qui porte du sens (packed, aligned…) dans une source
 * compilée invaliderait ce raccourci: refaire ce relevé à chaque resynchro. */
#define __attribute__(x)

/* `pid_t` n'existe pas sous Windows. Chez nous il n'y a pas de processus fils
 * (UADE_IN_PROCESS: uadecore est un FIL); ossupport.c n'y range qu'un drapeau
 * « en marche » (1 / 0). */
typedef int pid_t;

/* htonl/ntohl/htons/ntohs viennent de <winsock2.h> (lié par ws2_32), inclus
 * par les TROIS fichiers qui s'en servent (uade.c, uadeipc.c, uadestate.c, via
 * uade/sysincludes.h) — PAS ici: windows.h dans toutes les TU heurte le `BOOL`
 * des en-têtes AmigaOS du score (audiodevice.c) et la macro `exit` de
 * uade_inprocess.h. Des macros maison ont été essayées aussi: elles cassent
 * les PROTOTYPES de winsock2.h dans les TU qui l'incluent (notre
 * <sys/time.h>).
 *
 * WIN32_LEAN_AND_MEAN, lui, est posé ici sans rien inclure: tout windows.h
 * tiré ensuite (notre <dirent.h>) n'entraîne plus le winsock 1.1, donc
 * l'ordre windows.h/winsock2.h ne peut plus faire se contredire les deux
 * (« redéfinition de fd_set »). */
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

/* Bits de mode POSIX de open()/mkdir() (songdb.c, uadeconf.c). L'UCRT n'a que
 * les `_S_I*` du propriétaire — Windows n'a pas de groupe ni d'« autres ». */
#include <sys/stat.h>
#ifndef S_IRUSR
#define S_IRUSR _S_IREAD
#define S_IWUSR _S_IWRITE
#define S_IXUSR _S_IEXEC
#endif

/* Macros de type de fichier et lstat (ossupport.c, unixwalkdir.c). Windows n'a
 * pas de liens symboliques au sens POSIX pour ce code: lstat() = stat(), et
 * S_ISLNK est toujours faux. */
#ifndef S_ISREG
#define S_ISREG(m) (((m) & _S_IFMT) == _S_IFREG)
#endif
#ifndef S_ISDIR
#define S_ISDIR(m) (((m) & _S_IFMT) == _S_IFDIR)
#endif
#ifndef S_ISLNK
#define S_ISLNK(m) 0
#endif
#define lstat(p, st) stat((p), (st))

/* ⚠️ strsep() et memmem() rendent des POINTEURS: sans déclaration, MSVC les
 * supposait « extern int » (C4013) et aurait tronqué le résultat à 32 bits —
 * mesuré au premier build complet. Implémentations complètes, mêmes
 * sémantiques que la glibc. */
#include <string.h>
static __inline char *rewamp_strsep(char **stringp, const char *delim)
{
    char *s = *stringp, *end;
    if (s == NULL)
        return NULL;
    end = s + strcspn(s, delim);
    if (*end) {
        *end = '\0';
        *stringp = end + 1;
    } else {
        *stringp = NULL;
    }
    return s;
}
#define strsep(sp, d) rewamp_strsep((sp), (d))

static __inline void *rewamp_memmem(const void *hay, size_t haylen,
                                    const void *needle, size_t nlen)
{
    const unsigned char *h = (const unsigned char *)hay;
    size_t i;
    if (nlen == 0)
        return (void *)hay;
    if (haylen < nlen)
        return NULL;
    for (i = 0; i + nlen <= haylen; i++)
        if (h[i] == *(const unsigned char *)needle && memcmp(h + i, needle, nlen) == 0)
            return (void *)(h + i);
    return NULL;
}
#define memmem(h, hl, n, nl) rewamp_memmem((h), (hl), (n), (nl))

/* strlcpy/strlcat: absents de l'UCRT, DÉFINIS par libzakalwe/string.c
 * (`_Z_NEED_STRL`, posé sous _WIN32 dans zakalwe/config.h). Déclarés ici parce
 * que la moitié d'UADE (ossupport.c, eagleplayer.c…) les appelle sans inclure
 * l'en-tête de zakalwe — la glibc récente et la libc d'Apple les déclarent
 * d'elles-mêmes dans <string.h>. */
#include <stddef.h>
size_t strlcpy(char *dst, const char *src, size_t size);
size_t strlcat(char *dst, const char *src, size_t size);

#endif /* _MSC_VER && !__clang__ */
#endif /* REWAMP_UADE_MSVC_H */

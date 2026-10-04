/* <dirent.h> pour MSVC — voir README.md de ce dossier.
 *
 * Deux appelants dans ce dépôt: `mdxmain.c`, qui balaie le dossier d'un
 * `.mdx` pour retrouver son `.pdx` SANS tenir compte de la casse, et le
 * résolveur de fichiers d'UADE (`uade_amiga_scandir`, ossupport.c): un passage
 * exact, puis — après `rewinddir` — un passage insensible à la casse. Sur
 * Windows ces balayages sont redondants — le système de fichiers est déjà
 * insensible à la casse — mais le code doit compiler, et un shim est plus
 * honnête qu'un `#ifdef` qui retirerait la recherche de compagnon.
 *
 * Couvre `opendir`/`readdir`/`rewinddir`/`closedir` et le seul champ utilisé,
 * `d_name`. `seekdir`, `telldir`, `d_type` et `d_ino` sont volontairement
 * ABSENTS: personne ne les demande, et les fournir à moitié vaut moins que de
 * ne pas les fournir (cf. README).
 *
 * Version ANSI (_findfirst, pas _wfindfirst) exprès: l'appelant manipule des
 * `char*` et compare avec `strcasecmp`. Depuis le 2026-10-03 le manifeste du
 * runner pose `activeCodePage=UTF-8`: la page « ANSI » du processus EST
 * l'UTF-8, donc un nom hors de l'ancienne page 1252 est retrouvé aussi. */
#ifndef REWAMP_WIN_COMPAT_DIRENT_H
#define REWAMP_WIN_COMPAT_DIRENT_H

/* ⚠️ PAS de <windows.h> ici: cet en-tête entre dans chaque TU de l'émulateur
 * d'UADE (par son sysdeps.h), et windows.h y heurte les types que ce code
 * définit lui-même (`BOOL`, …). La recherche passe donc par
 * `_findfirst`/`_findnext` de la CRT (<io.h>), qui font la même chose que
 * FindFirstFileA/FindNextFileA sans tirer l'API Win32. */
#include <io.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

struct dirent {
    char d_name[_MAX_PATH];
};

typedef struct REWAMP_DIR {
    intptr_t                handle;   /* -1 = épuisé */
    struct _finddata64i32_t find;
    int                     pending;  /* la 1re entrée vient de _findfirst */
    struct dirent           entry;
    char                    pattern[_MAX_PATH];   /* « dossier\* », pour rewinddir */
} DIR;

#ifdef __cplusplus
extern "C" {
#endif

static __inline DIR *opendir(const char *name)
{
    DIR *d;
    size_t n;
    char pattern[_MAX_PATH];

    if (!name || !*name) return 0;
    n = strlen(name);
    /* +3 pour "\\*" et le nul; on REFUSE plutôt que de tronquer en silence. */
    if (n + 3 > sizeof(pattern)) return 0;

    memcpy(pattern, name, n);
    if (n && name[n - 1] != '\\' && name[n - 1] != '/') pattern[n++] = '\\';
    pattern[n++] = '*';
    pattern[n]   = '\0';

    d = (DIR *)calloc(1, sizeof(*d));
    if (!d) return 0;

    memcpy(d->pattern, pattern, n + 1);
    d->handle = _findfirst64i32(pattern, &d->find);
    if (d->handle == -1) { free(d); return 0; }
    d->pending = 1;
    return d;
}

static __inline struct dirent *readdir(DIR *d)
{
    if (!d || d->handle == -1) return 0;
    if (d->pending) {
        d->pending = 0;
    } else if (_findnext64i32(d->handle, &d->find) != 0) {
        return 0;
    }
    strncpy(d->entry.d_name, d->find.name, sizeof(d->entry.d_name) - 1);
    d->entry.d_name[sizeof(d->entry.d_name) - 1] = '\0';
    return &d->entry;
}

/* Recommence au début: on referme la recherche et on la relance sur le même
 * motif. Si le dossier a disparu entre-temps, le DIR reste épuisé (readdir
 * rend 0), comme un dossier vide. */
static __inline void rewinddir(DIR *d)
{
    if (!d) return;
    if (d->handle != -1) _findclose(d->handle);
    d->handle  = _findfirst64i32(d->pattern, &d->find);
    d->pending = (d->handle != -1);
}

static __inline int closedir(DIR *d)
{
    if (!d) return -1;
    if (d->handle != -1) _findclose(d->handle);
    free(d);
    return 0;
}

#ifdef __cplusplus
}
#endif

#endif /* REWAMP_WIN_COMPAT_DIRENT_H */
/* <pthread.h> pour MSVC — le sous-ensemble que le COEUR du moteur utilise.
 *
 * À distinguer de ../compat/, qui sert les arbres VENDORÉS: ce dossier-ci
 * n'est sur le chemin d'include que de la cible `rewamp_audio` elle-même
 * (windows/CMakeLists.txt). Un `pthread.h` visible des 39 cibles vendorées
 * changerait le comportement de celles qui testent sa présence.
 *
 * ⚠️ Cet en-tête n'inclut PAS <windows.h>, exprès: il entre dans chaque TU du
 * moteur par rewamp_datasource.h, greffons compris, et windows.h y apporterait
 * ses macros (`ERROR`, `small`, `interface`, `near`…) au milieu de code
 * vendoré. Les types sont donc OPAQUES et les fonctions vivent dans
 * rewamp_win_posix.c, seul fichier à voir l'API Win32.
 *
 * Ce qui est couvert, et rien d'autre: mutex NON récursif (SRWLOCK), variable
 * de condition (CONDITION_VARIABLE), création, jointure et identité d'un fil. Pas
 * d'attributs, pas de valeur de retour de fil (`pthread_join(t, NULL)` est le
 * seul usage du dépôt), pas d'annulation. Un symbole absent est un symbole que
 * personne n'a demandé — même règle que ../compat/README.md. */
#ifndef REWAMP_WIN_POSIX_PTHREAD_H
#define REWAMP_WIN_POSIX_PTHREAD_H

#ifdef __cplusplus
extern "C" {
#endif

/* SRWLOCK et CONDITION_VARIABLE tiennent chacun dans UN pointeur, et leur
 * initialiseur statique est le zéro — rewamp_win_posix.c le vérifie par un
 * static_assert, pas par confiance. */
typedef struct { void* opaque; } pthread_mutex_t;
typedef struct { void* opaque; } pthread_cond_t;
/* `handle` sert à la JOINTURE (rempli par pthread_create seulement), `id` à
 * l'IDENTITÉ: pthread_self() ne peut pas rendre un handle joignable, donc il
 * ne remplit que `id`, et pthread_equal ne compare que lui. `{}` = aucun fil. */
typedef struct { void* handle; unsigned long id; } pthread_t;
typedef struct { int unused; } pthread_attr_t;
typedef struct { int unused; } pthread_mutexattr_t;
typedef struct { int unused; } pthread_condattr_t;

#define PTHREAD_MUTEX_INITIALIZER { 0 }
#define PTHREAD_COND_INITIALIZER  { 0 }

int pthread_mutex_init(pthread_mutex_t* m, const pthread_mutexattr_t* attr);
int pthread_mutex_destroy(pthread_mutex_t* m);
int pthread_mutex_lock(pthread_mutex_t* m);
int pthread_mutex_trylock(pthread_mutex_t* m);   /* 0 = pris, EBUSY sinon */
int pthread_mutex_unlock(pthread_mutex_t* m);

int pthread_cond_init(pthread_cond_t* c, const pthread_condattr_t* attr);
int pthread_cond_destroy(pthread_cond_t* c);
int pthread_cond_wait(pthread_cond_t* c, pthread_mutex_t* m);
int pthread_cond_signal(pthread_cond_t* c);
int pthread_cond_broadcast(pthread_cond_t* c);

/* `attr` doit être NULL: aucun attribut n'est honoré, et en accepter un en
 * silence ferait croire qu'une taille de pile ou une priorité a été posée. */
int pthread_create(pthread_t* t, const pthread_attr_t* attr,
                   void* (*start)(void*), void* arg);
/* `retval` doit être NULL: la valeur de retour du fil n'est pas conservée. */
int pthread_join(pthread_t t, void** retval);

/* Identité du fil courant — pour COMPARER (pthread_equal), pas pour joindre. */
pthread_t pthread_self(void);
int pthread_equal(pthread_t a, pthread_t b);   /* non nul = même fil */

#ifdef __cplusplus
}
#endif

#endif /* REWAMP_WIN_POSIX_PTHREAD_H */

/* Corps de pthread.h et rewamp_win_posix.h (ce dossier) — le SEUL fichier du
 * coeur à voir l'API Win32, pour que <windows.h> n'entre dans aucune autre TU.
 */
#include "pthread.h"
#include "rewamp_win_posix.h"

#include <windows.h>
#include <process.h>   /* _beginthreadex */
#include <errno.h>
#include <stdlib.h>

/* Les types opaques de pthread.h recouvrent ces deux objets; s'ils cessaient
 * de tenir dans un pointeur, ou si leur initialiseur n'était plus le zéro, les
 * `PTHREAD_*_INITIALIZER` deviendraient faux sans un mot. */
_Static_assert(sizeof(SRWLOCK) == sizeof(pthread_mutex_t),
               "pthread_mutex_t doit recouvrir SRWLOCK");
_Static_assert(sizeof(CONDITION_VARIABLE) == sizeof(pthread_cond_t),
               "pthread_cond_t doit recouvrir CONDITION_VARIABLE");

/* ── mutex ─────────────────────────────────────────────────────────────── */

int pthread_mutex_init(pthread_mutex_t* m, const pthread_mutexattr_t* attr) {
    (void)attr;
    InitializeSRWLock((PSRWLOCK)m);
    return 0;
}

/* Un SRWLOCK ne possède aucune ressource noyau: rien à libérer. */
int pthread_mutex_destroy(pthread_mutex_t* m) { (void)m; return 0; }

int pthread_mutex_lock(pthread_mutex_t* m) {
    AcquireSRWLockExclusive((PSRWLOCK)m);
    return 0;
}

int pthread_mutex_trylock(pthread_mutex_t* m) {
    return TryAcquireSRWLockExclusive((PSRWLOCK)m) ? 0 : EBUSY;
}

int pthread_mutex_unlock(pthread_mutex_t* m) {
    ReleaseSRWLockExclusive((PSRWLOCK)m);
    return 0;
}

/* ── variable de condition ─────────────────────────────────────────────── */

int pthread_cond_init(pthread_cond_t* c, const pthread_condattr_t* attr) {
    (void)attr;
    InitializeConditionVariable((PCONDITION_VARIABLE)c);
    return 0;
}

int pthread_cond_destroy(pthread_cond_t* c) { (void)c; return 0; }

int pthread_cond_wait(pthread_cond_t* c, pthread_mutex_t* m) {
    return SleepConditionVariableSRW((PCONDITION_VARIABLE)c, (PSRWLOCK)m,
                                     INFINITE, 0) ? 0 : EINVAL;
}

int pthread_cond_signal(pthread_cond_t* c) {
    WakeConditionVariable((PCONDITION_VARIABLE)c);
    return 0;
}

int pthread_cond_broadcast(pthread_cond_t* c) {
    WakeAllConditionVariable((PCONDITION_VARIABLE)c);
    return 0;
}

/* ── fils ──────────────────────────────────────────────────────────────── */

typedef struct {
    void* (*start)(void*);
    void*  arg;
} RewampThreadStart;

/* `_beginthreadex` attend `unsigned __stdcall (void*)`; un fil POSIX est
 * `void* (void*)`. Le trampoline porte la différence de signature. */
static unsigned __stdcall rewamp_thread_trampoline(void* p) {
    RewampThreadStart s = *(RewampThreadStart*)p;
    free(p);
    (void)s.start(s.arg);
    return 0;
}

int pthread_create(pthread_t* t, const pthread_attr_t* attr,
                   void* (*start)(void*), void* arg) {
    RewampThreadStart* s;
    uintptr_t h;
    unsigned tid = 0;
    if (t == NULL || start == NULL) return EINVAL;
    if (attr != NULL) return EINVAL;   /* voir pthread.h: aucun attribut honoré */
    s = (RewampThreadStart*)malloc(sizeof(*s));
    if (s == NULL) return EAGAIN;
    s->start = start;
    s->arg   = arg;
    /* `_beginthreadex` et pas `CreateThread`: le fil appelle le CRT (malloc,
     * stdio des décodeurs), qui veut son état par fil initialisé. */
    h = _beginthreadex(NULL, 0, rewamp_thread_trampoline, s, 0, &tid);
    if (h == 0) { free(s); return EAGAIN; }
    t->handle = (void*)h;
    t->id     = (unsigned long)tid;
    return 0;
}

pthread_t pthread_self(void) {
    pthread_t t;
    t.handle = NULL;
    t.id     = (unsigned long)GetCurrentThreadId();
    return t;
}

int pthread_equal(pthread_t a, pthread_t b) { return a.id == b.id; }

int pthread_join(pthread_t t, void** retval) {
    if (retval != NULL) return EINVAL;   /* voir pthread.h */
    if (t.handle == NULL) return ESRCH;
    if (WaitForSingleObject((HANDLE)t.handle, INFINITE) != WAIT_OBJECT_0)
        return EINVAL;
    CloseHandle((HANDLE)t.handle);
    return 0;
}

/* ── horloge ───────────────────────────────────────────────────────────── */

int clock_gettime(int clock_id, struct timespec* ts) {
    if (ts == NULL) return -1;
    if (clock_id == CLOCK_MONOTONIC) {
        /* La fréquence est fixe depuis le démarrage du système. */
        static LARGE_INTEGER freq;
        LARGE_INTEGER now;
        if (freq.QuadPart == 0) QueryPerformanceFrequency(&freq);
        QueryPerformanceCounter(&now);
        ts->tv_sec  = (time_t)(now.QuadPart / freq.QuadPart);
        ts->tv_nsec = (long)(((now.QuadPart % freq.QuadPart) * 1000000000LL)
                             / freq.QuadPart);
        return 0;
    }
    if (clock_id == CLOCK_REALTIME)
        return timespec_get(ts, TIME_UTC) == TIME_UTC ? 0 : -1;
    return -1;
}

int nanosleep(const struct timespec* req, struct timespec* rem) {
    long long ms;
    (void)rem;
    if (req == NULL || req->tv_sec < 0 || req->tv_nsec < 0) return -1;
    ms = (long long)req->tv_sec * 1000 + (req->tv_nsec + 999999) / 1000000;
    Sleep((DWORD)ms);
    return 0;
}

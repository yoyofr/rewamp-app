/*
 * rewamp: in-process uadecore shutdown.
 *
 * uadecore is a standalone process — it calls exit() on disconnect (normal
 * shutdown) and on errors. Run in a pthread (UADE_IN_PROCESS), exit() would kill
 * the whole app. Force-included into every uadecore translation unit, this
 * redirects exit() to uadecore_exit(), which longjmp()s back to uadecore_main(),
 * so the thread unwinds and returns cleanly.
 *
 * <stdlib.h> is pulled in FIRST so its real `void exit(int)` declaration is seen
 * before we shadow exit with the macro (the include guard makes later
 * <stdlib.h> includes no-ops, so the macro only rewrites call sites).
 */
#ifndef UADE_INPROCESS_H
#define UADE_INPROCESS_H

#ifdef UADE_IN_PROCESS

#include <stdlib.h>
#include <setjmp.h>

#ifdef __cplusplus
extern "C" {
#endif
extern jmp_buf uadecore_exit_jmp;
void uadecore_exit(int code);
#ifdef __cplusplus
}
#endif

#define exit(code) uadecore_exit(code)

#endif /* UADE_IN_PROCESS */
#endif /* UADE_INPROCESS_H */

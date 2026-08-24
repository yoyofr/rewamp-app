/* rewamp: ProWizard front-end.
 *
 * Detects a packed Amiga module BY CONTENT and converts it to a standard
 * Protracker MOD in memory, so the normal MOD chain (UADE / libopenmpt) can
 * play it. Nothing here emulates anything.
 *
 * Use it as a LAST RESORT only (a file no plugin claims, or one whose player
 * failed): the detection is heuristic and can false-positive on healthy files.
 */
#ifndef REWAMP_PROWIZARD_H
#define REWAMP_PROWIZARD_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Returns 1 on success, 0 when no format matched or conversion failed.
 * On success *out is a malloc'd Protracker MOD of *outLen bytes (caller frees)
 * and, if fmtName != NULL, *fmtName points at a static format name. */
int rewamp_prowizard_convert(const void *data, size_t len,
                             void **out, size_t *outLen,
                             const char **fmtName);

/* Detection only — no conversion. Returns 1 and (optionally) the format name. */
int rewamp_prowizard_detect(const void *data, size_t len, const char **fmtName);

#ifdef __cplusplus
}
#endif

#endif /* REWAMP_PROWIZARD_H */

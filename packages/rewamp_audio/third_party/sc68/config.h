/* Pre-baked config.h for the vendored sc68 (rewamp).
 *
 * sc68 is autotools-based; Modizer never generated a real config.h — its
 * global HAVE_CONFIG_H accidentally resolved "config.h" to LIBARCHIVE's
 * (first on its include path), which happened to define the generic HAVE_*
 * feature macros sc68 needs. rewamp bakes an explicit one instead.
 *
 * MUST stay scoped to the sc68 TUs only (cmake: the rewamp_sc68 target's
 * PRIVATE include dirs; Apple: per-file include scoping in the app Podfiles)
 * — "config.h" is the most collision-prone header name in the whole pod
 * (libarchive/liblzma each have their own).
 */
#ifndef REWAMP_SC68_CONFIG_H
#define REWAMP_SC68_CONFIG_H

#define PACKAGE_NAME    "libsc68"
#define PACKAGE_VERSION "3.0.0-modizer"
#define PACKAGE_STRING  PACKAGE_NAME " " PACKAGE_VERSION
#define PACKAGE_URL     "http://sc68.atari.org"

/* Standard headers — present on every rewamp target (Apple/bionic/glibc). */
#define HAVE_ASSERT_H    1
#define HAVE_LIMITS_H    1
#define HAVE_STDINT_H    1
#define HAVE_STDLIB_H    1
#define HAVE_STRING_H    1
#define HAVE_SYS_TYPES_H 1
#define HAVE_UNISTD_H    1
#define HAVE_FCNTL_H     1
#define HAVE_LIBGEN_H    1

/* Library features. */
#define HAVE_GETENV   1
#define HAVE_USLEEP   1
#define HAVE_FILENO   1
#define HAVE_BASENAME 1
#define HAVE_FSYNC    1

/* zlib: gz-compressed .sc68 + the gunzip of the BUILT-IN replay blobs
 * (replay.inc.h) — system zlib on every target. NOTE: gzip68.c/ice68.c gate
 * on FILE68_Z/FILE68_UNICE68, NOT on HAVE_ZLIB_H — file68_features.h defines
 * them but is included by NOTHING in those TUs; upstream autotools emits
 * them into the generated config.h, so this one must too (without FILE68_Z
 * the built-in replays fail to gunzip and every external-replay .sc68 is
 * silent with "inflated size of built-in replay differs -1"). */
#define HAVE_ZLIB_H     1
#define FILE68_Z        1
#define FILE68_UNICE68  1

/* Built-in gzip-embedded 68k replays (file68/src/replay.inc.h) — the
 * rsc68://replay/ fallback when no loose file exists under the user path.
 * Modizer does NOT define this and therefore NEEDS its Resources/sc68/Replay
 * files; with it the app runs with zero sc68 runtime assets. */
#define USE_REPLAY68 1

/* No libao (audio out — miniaudio's job), no curl (no remote VFS). */

#endif /* REWAMP_SC68_CONFIG_H */

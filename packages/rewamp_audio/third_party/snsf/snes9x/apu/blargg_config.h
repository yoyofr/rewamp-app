// snes_spc 0.9.0 user configuration file. Don't replace when updating library.

// snes_spc 0.9.0
#ifndef BLARGG_CONFIG_H
#define BLARGG_CONFIG_H

// Uncomment to disable debugging checks
//#define NDEBUG 1

// Uncomment to enable platform-specific (and possibly non-portable) optimizations
//#define BLARGG_NONPORTABLE 1

// Uncomment if automatic byte-order determination doesn't work
//#define BLARGG_BIG_ENDIAN 1

// Uncomment if you get errors in the bool section of blargg_common.h
//#define BLARGG_COMPILER_HAS_BOOL 1

// Use standard config.h if present
//
// rewamp: DISABLED on purpose. This engine has no autotools config.h of its own,
// but HAVE_CONFIG_H is defined POD-WIDE by the libarchive/liblzma block in both
// Apple podspecs — so this include would silently resolve to LIBARCHIVE's
// config.h (its root is on the pod-wide header path). Same class of bug as
// sc68's, which really did pick up libarchive's config.h through include order.
// Neutralized in-source rather than by build flags so it cannot regress.
#if 0
#ifdef HAVE_CONFIG_H
	#include "config.h"
#endif
#endif

#endif

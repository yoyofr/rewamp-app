// rewamp_assets — generic internal data-directory for playback libraries.
//
// Some decoder libraries need auxiliary data files that cannot be embedded in
// the binary (e.g. libsidplayfp's C64 kernal/basic/chargen ROMs, future
// soundfonts, DSP tables, ...).  The Dart layer copies the app's bundled
// assets into a writable directory at startup and registers its path here via
// rewamp_set_data_dir().  Plugins then load what they need with
// rewamp_load_asset("c64/kernal.c64", ...).
#ifndef REWAMP_ASSETS_H
#define REWAMP_ASSETS_H

#include <stddef.h>
#include <stdint.h>

// rewamp_set_data_dir est un export FFI, déclaré REWAMP_EXPORT dans
// rewamp_audio.h. MSVC refuse qu'un dllexport arrive APRÈS une déclaration nue
// (C2375): un TU qui incluait cet en-tête avant rewamp_audio.h ne compilait
// pas (rewamp_plugin_uade.cpp). On tire donc la déclaration exportée d'ici.
#include "rewamp_audio.h"

#ifdef __cplusplus
extern "C" {
#endif

// Set the root directory under which plugin assets live. `path` is copied.
// Passing NULL or "" clears it. Safe to call before rewamp_init().
// (Déclaration exportée: rewamp_audio.h.)

// Return the current data dir (never NULL; "" when unset).
const char* rewamp_get_data_dir(void);

// Load an asset at `relPath` (relative to the data dir) fully into memory.
// On success returns 1, sets *outBuf to a malloc'd buffer (caller frees) and
// *outSize to its length. On failure returns 0 and leaves outputs untouched.
int rewamp_load_asset(const char* relPath, uint8_t** outBuf, size_t* outSize);

#ifdef __cplusplus
}
#endif

#endif // REWAMP_ASSETS_H

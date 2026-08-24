#ifndef REWAMP_REGISTRY_H
#define REWAMP_REGISTRY_H

#include "rewamp_plugin.h"
#include "rewamp_audio.h"  /* REWAMP_EXPORT */

#ifdef __cplusplus
extern "C" {
#endif

// Register a plugin. The vtable must remain valid for the program lifetime
// (plugins expose a static const vtable). Returns 0 on success, -1 if full.
int rewamp_register_plugin(const RewampPluginVTable* vt);

// Register all plugins compiled into this build (gated by REWAMP_WITH_* flags).
// Called once during engine init.
void rewamp_register_builtin_plugins(void);

// Select the best plugin for `path`: filters by extension, then confirms by
// reading the file header, picking the highest probe confidence.
// Returns NULL if no plugin matches (caller should fall back to miniaudio).
const RewampPluginVTable* rewamp_registry_select(const char* path);

// Rank ALL plugins claiming `path` (probe > 0) by descending confidence into
// `out` (up to `maxOut`). A preferred-plugin override, when set and claiming
// the file, is placed first. Returns the number of candidates. Lets the loader
// cascade to the next-best plugin when the winner's open() fails (e.g. a
// converted/packed Amiga .mod that libopenmpt rejects but UADE plays).
int rewamp_registry_select_ranked(const char* path,
                                  const RewampPluginVTable** out, int maxOut);

// Number of registered plugins (for diagnostics).
int rewamp_registry_count(void);

// Override: for files with extension `ext` (lowercase, no dot), always prefer
// the plugin named `plugin_name` if it can handle the file (probe > 0).
// Pass plugin_name = NULL to clear the override for that extension.
// Up to REWAMP_MAX_OVERRIDES extensions can be overridden simultaneously.
REWAMP_EXPORT void rewamp_registry_set_preferred_plugin(const char* ext, const char* plugin_name);

#ifdef __cplusplus
}
#endif

#endif /* REWAMP_REGISTRY_H */

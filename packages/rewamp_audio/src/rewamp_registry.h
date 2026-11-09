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

// « Lire avec… »: force `plugin_name` for the file at `path` (its exact
// clean path, no ?subsong=), first in the ranking if it claims the file.
// NULL / "" clears. Up to 32 paths (Dart sets what it is about to play).
REWAMP_EXPORT void rewamp_registry_set_path_plugin(const char* path, const char* plugin_name);
REWAMP_EXPORT void rewamp_registry_clear_path_plugins(void);

// « Lire avec… »: an OPTION of `plugin_name` for the file at `path` (exact
// clean path) — "fluidlite": SoundFont path; "mt32": model "1" (MT-32) /
// "2" (CM-32L). NULL / "" value clears. Read by that plugin's open() above its setting
// (`rewamp_registry_path_option`: 1 and the value in `out` when set).
REWAMP_EXPORT void rewamp_registry_set_path_option(const char* path, const char* plugin_name,
                                                   const char* value);
REWAMP_EXPORT void rewamp_registry_clear_path_options(void);
int rewamp_registry_path_option(const char* path, const char* plugin_name,
                                char* out, size_t outSize);

// Plugins able to play `path`, DEFAULT order (no per-file override), names
// separated by '\n'; the first is the one that plays it by default.
REWAMP_EXPORT const char* rewamp_registry_candidates(const char* path);

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

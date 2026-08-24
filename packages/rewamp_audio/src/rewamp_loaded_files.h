/* rewamp_loaded_files — the files a decode ACTUALLY opened, with their sizes.
 *
 * Why it exists: many formats do not fit in one file. A `.minipsf` needs its
 * `.psflib`, a `mdat.NAME` its `smpl.NAME`, a `.mdx` its `.pdx`, an `.eup` its
 * `.fmb`/`.pmb` banks, a Quartet `.4v` its `SMP.set`. The ⓘ panel used to guess
 * the companions from the file NAME — same stem, either naming convention —
 * which is wrong in both directions: it misses a companion that does not share
 * the stem (a `.psflib` is usually named after the game, not the tune), and it
 * can pick up a neighbour that merely looks related.
 *
 * Only the plugin knows. So each loader that opens a file registers it here,
 * and the UI reads the list instead of deriving it.
 *
 * Threading: written on the DECODE side (the producer thread, or whatever
 * thread `open()` runs on) and read from Dart. The list only changes while a
 * file is being opened — long before the UI can ask about it — so a mutex
 * would protect nothing a reader could observe; the count is published last so
 * a reader never sees a half-written entry.
 */
#ifndef REWAMP_LOADED_FILES_H
#define REWAMP_LOADED_FILES_H

#ifdef __cplusplus
extern "C" {
#endif

/* Forget everything. Called by rewamp_load_file() before the plugin opens. */
void rewamp_loaded_files_reset(void);

/* Register one file. Ignores NULL/empty, a path already present, and a file
 * it cannot stat — a loader may probe several candidate names before finding
 * the right one, and only the ones that exist should be listed. */
void rewamp_loaded_files_add(const char* path);

/* `[{"name":"mdat.monkey island","size":52014}, …]`, or `[]`.
 * The buffer is static and valid until the next reset/add. */
const char* rewamp_loaded_files_json(void);

#ifdef __cplusplus
}
#endif

#endif /* REWAMP_LOADED_FILES_H */

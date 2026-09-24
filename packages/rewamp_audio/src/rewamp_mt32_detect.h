#ifndef REWAMP_MT32_DETECT_H
#define REWAMP_MT32_DETECT_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Le FICHIER porte du sysex Roland de modèle 0x16 (famille MT-32). */
int rewamp_mt32_file_has_sysex(const char* path, uint64_t fileSize);

/* Le DOSSIER du morceau porte une banque MT-32 (*.syx, ou sys*.mid de sysex
 * seuls) — verdict mémorisé par dossier + mtime. */
int rewamp_mt32_dir_has_bank(const char* songPath);

/* Le morceau est rangé sous un dossier qui NOMME la famille (MT32, MT-32,
 * CM-32L, LAPC-1), le sien ou celui au-dessus. */
int rewamp_mt32_in_mt32_folder(const char* songPath);

/* Les trois réunies: « ce fichier vise le MT-32 ». */
int rewamp_midi_targets_mt32(const char* path, uint64_t fileSize);

#ifdef __cplusplus
}
#endif

#endif /* REWAMP_MT32_DETECT_H */

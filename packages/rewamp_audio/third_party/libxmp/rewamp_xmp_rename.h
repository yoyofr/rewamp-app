/* rewamp: libxmp symbol renames (force-included on EVERY libxmp TU).
 *
 * libxmp exports ~68 globals that are NOT prefixed xmp_/libxmp_ — the hio_*
 * stream family, the big/little-endian read/write endian helpers, MD5*, the MMD
 * (OctaMED) helpers, the memio m* family. rewamp already links several of
 * those names from OTHER vendored trees:
 *
 *   - third_party/prowizard IS libxmp's own ProWizard set, vendored with a
 *     hand-written hio shim (hio_read/hio_seek/readmem32b/write16b/...),
 *   - uade brings its own MD5Init/MD5Update/MD5Final,
 *   - winsinc_integral already exists elsewhere in the binary.
 *
 * Two archives defining the same symbol do not always fail the link: the
 * linker resolves each undefined symbol from whichever archive it reaches
 * first, so ProWizard could silently end up calling libxmp's hio_read with
 * its own (differently laid out) HIO_HANDLE. Rename rather than find out.
 *
 * Generated from `nm` on a standalone libxmp build — regenerate with
 * scripts/sync_libxmp.sh if the upstream symbol set changes.
 */
#ifndef REWAMP_XMP_RENAME_H
#define REWAMP_XMP_RENAME_H

/* libxmp trace CHAQUE étape de chargement quand DEBUG est défini — et
 * CocoaPods définit DEBUG=1 en configuration Debug. Le registre sonde chaque
 * greffon sur chaque fichier, donc un simple changement de piste noyait la
 * console sous des centaines de lignes (« bad module name; not ST »…). Le
 * greffon n'a aucun moyen de les filtrer: c'est un printf direct. */
#undef DEBUG

#define format_list rwxmp_format_list
#define format_loaders rwxmp_format_loaders
#define hio_close rwxmp_hio_close
#define hio_eof rwxmp_hio_eof
#define hio_error rwxmp_hio_error
#define hio_get_underlying_memory rwxmp_hio_get_underlying_memory
#define hio_open rwxmp_hio_open
#define hio_open_callbacks rwxmp_hio_open_callbacks
#define hio_open_const_mem rwxmp_hio_open_const_mem
#define hio_open_file rwxmp_hio_open_file
#define hio_open_file2 rwxmp_hio_open_file2
#define hio_read rwxmp_hio_read
#define hio_read16b rwxmp_hio_read16b
#define hio_read16l rwxmp_hio_read16l
#define hio_read24b rwxmp_hio_read24b
#define hio_read24l rwxmp_hio_read24l
#define hio_read32b rwxmp_hio_read32b
#define hio_read32l rwxmp_hio_read32l
#define hio_read8 rwxmp_hio_read8
#define hio_read8s rwxmp_hio_read8s
#define hio_reopen_file rwxmp_hio_reopen_file
#define hio_reopen_mem rwxmp_hio_reopen_mem
#define hio_seek rwxmp_hio_seek
#define hio_size rwxmp_hio_size
#define hio_tell rwxmp_hio_tell
#define itsex_decompress16 rwxmp_itsex_decompress16
#define itsex_decompress8 rwxmp_itsex_decompress8
#define mclose rwxmp_mclose
#define mcopen rwxmp_mcopen
#define MD5Final rwxmp_MD5Final
#define MD5Init rwxmp_MD5Init
#define MD5Update rwxmp_MD5Update
#define med_load_external_instrument rwxmp_med_load_external_instrument
#define meof rwxmp_meof
#define mgetc rwxmp_mgetc
#define mmd_alloc_tables rwxmp_mmd_alloc_tables
#define mmd_convert_tempo rwxmp_mmd_convert_tempo
#define mmd_info_text rwxmp_mmd_info_text
#define mmd_load_instrument rwxmp_mmd_load_instrument
#define mmd_num_oct rwxmp_mmd_num_oct
#define mmd_set_bpm rwxmp_mmd_set_bpm
#define mmd_tracker_version rwxmp_mmd_tracker_version
#define mmd_xlat_fx rwxmp_mmd_xlat_fx
#define mod_magic rwxmp_mod_magic
#define mopen rwxmp_mopen
#define mq rwxmp_mq
#define mread rwxmp_mread
#define mseek rwxmp_mseek
#define mtell rwxmp_mtell
#define read16b rwxmp_read16b
#define read16l rwxmp_read16l
#define read24b rwxmp_read24b
#define read24l rwxmp_read24l
#define read32b rwxmp_read32b
#define read32l rwxmp_read32l
#define read8 rwxmp_read8
#define read8s rwxmp_read8s
#define readmem16b rwxmp_readmem16b
#define readmem16l rwxmp_readmem16l
#define readmem24b rwxmp_readmem24b
#define readmem24l rwxmp_readmem24l
#define readmem32b rwxmp_readmem32b
#define readmem32l rwxmp_readmem32l
#define winsinc_integral rwxmp_winsinc_integral
#define write16b rwxmp_write16b
#define write16l rwxmp_write16l
#define write32b rwxmp_write32b
#define write32l rwxmp_write32l

#endif /* REWAMP_XMP_RENAME_H */

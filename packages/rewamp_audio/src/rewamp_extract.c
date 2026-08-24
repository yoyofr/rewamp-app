// Archive extraction via libarchive — handles 7z, zip, tar, lha, gz, bz2, xz, rar.
// Compiled only when REWAMP_WITH_ARCHIVE is defined (enabled alongside libgme).
#ifdef REWAMP_WITH_ARCHIVE

#include "rewamp_audio.h"

#include <archive.h>
#include <archive_entry.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#  include <direct.h>
#  define MKDIR(p) _mkdir(p)
#else
#  include <sys/stat.h>
#  define MKDIR(p) mkdir(p, 0755)
#endif

static int copy_data(struct archive* ar, struct archive* aw) {
    const void* buf;
    size_t      size;
    int64_t     offset;
    for (;;) {
        int r = archive_read_data_block(ar, &buf, &size, &offset);
        if (r == ARCHIVE_EOF) return ARCHIVE_OK;
        if (r < ARCHIVE_OK)  return r;
        if (archive_write_data_block(aw, buf, size, offset) < ARCHIVE_OK)
            return ARCHIVE_FAILED;
    }
}

// Creates all directories in [path] up to (not including) the final component.
static void ensure_parents(const char* path) {
    char tmp[4096];
    strncpy(tmp, path, sizeof(tmp) - 1);
    tmp[sizeof(tmp) - 1] = '\0';
    // Walk forward creating each intermediate directory.
    for (char* p = tmp + 1; *p; p++) {
        if (*p == '/') {
            *p = '\0';
            MKDIR(tmp);  // ignore error — dir may already exist
            *p = '/';
        }
    }
}

// Last extraction error string — written by rewamp_extract_archive, read by accessor.
static char s_extract_error[512] = "";

const char* rewamp_extract_last_error(void) { return s_extract_error; }

int rewamp_extract_archive(const char* archive_path, const char* dest_dir) {
    s_extract_error[0] = '\0';
    if (!archive_path || !dest_dir) { snprintf(s_extract_error, sizeof(s_extract_error), "null args"); return -1; }

    struct archive* a = archive_read_new();
    if (!a) { snprintf(s_extract_error, sizeof(s_extract_error), "archive_read_new failed"); return -1; }
    archive_read_support_format_all(a);
    archive_read_support_filter_all(a);

    struct archive* ext = archive_write_disk_new();
    if (!ext) { archive_read_free(a); snprintf(s_extract_error, sizeof(s_extract_error), "archive_write_disk_new failed"); return -1; }
    archive_write_disk_set_options(ext,
        ARCHIVE_EXTRACT_TIME | ARCHIVE_EXTRACT_PERM | ARCHIVE_EXTRACT_ACL);
    archive_write_disk_set_standard_lookup(ext);

    int rc = 0;
    int r2 = archive_read_open_filename(a, archive_path, 65536);
    if (r2 != ARCHIVE_OK) {
        snprintf(s_extract_error, sizeof(s_extract_error), "open failed (%d): %s",
                 r2, archive_error_string(a) ? archive_error_string(a) : "?");
        rc = r2; // preserve actual error code for caller
        goto cleanup;
    }

    struct archive_entry* entry;
    int extracted = 0;
    for (;;) {
        int r = archive_read_next_header(a, &entry);
        if (r == ARCHIVE_EOF)  break;
        if (r < ARCHIVE_OK) {
            snprintf(s_extract_error, sizeof(s_extract_error),
                     "read_next_header (%d): %s", r,
                     archive_error_string(a) ? archive_error_string(a) : "?");
            rc = r;
            break;
        }

        const char* raw = archive_entry_pathname(entry);
        if (!raw || raw[0] == '\0') { archive_read_data_skip(a); continue; }

        // Normalise separators to '/'.
        char rel[4096];
        strncpy(rel, raw, sizeof(rel) - 1);
        rel[sizeof(rel) - 1] = '\0';
        for (char* q = rel; *q; q++) if (*q == '\\') *q = '/';

        // Strip any leading slashes (convert absolute → relative).
        const char* relp = rel;
        while (*relp == '/') relp++;

        // Reject path traversal — only a literal ".." path *component* is unsafe,
        // not any "type with '..'.psf" filename, so match component boundaries.
        int traversal = 0;
        for (const char* c = relp; c; ) {
            if (c[0] == '.' && c[1] == '.' && (c[2] == '/' || c[2] == '\0')) {
                traversal = 1; break;
            }
            const char* slash = strchr(c, '/');
            c = slash ? slash + 1 : NULL;
        }
        if (traversal) { archive_read_data_skip(a); continue; }

        // Skip pure directory entries (path ends with '/') and . / ..
        const char* base = strrchr(relp, '/');
        base = base ? base + 1 : relp;
        if (base[0] == '\0'
                || (base[0] == '.' && (base[1] == '\0' || (base[1] == '.' && base[2] == '\0')))) {
            archive_read_data_skip(a);
            continue;
        }

        // Build full dest path preserving subdirectory structure.
        char dest[4096];
        snprintf(dest, sizeof(dest), "%s/%s", dest_dir, relp);

        // Create parent directories as needed.
        ensure_parents(dest);

        archive_entry_set_pathname(entry, dest);

        r = archive_write_header(ext, entry);
        if (r < ARCHIVE_OK) {
            archive_read_data_skip(a);
            continue;
        }
        if (archive_entry_size(entry) > 0)
            copy_data(a, ext);
        archive_write_finish_entry(ext);
        extracted++;
    }

    // Opened + iterated OK but nothing came out → report it.
    if (rc == 0 && extracted == 0) {
        snprintf(s_extract_error, sizeof(s_extract_error),
                 "no entries extracted");
        rc = -2;
    }

cleanup:
    archive_read_close(a);
    archive_read_free(a);
    archive_write_close(ext);
    archive_write_free(ext);
    return rc;
}

#else /* REWAMP_WITH_ARCHIVE not set */

int rewamp_extract_archive(const char* archive_path, const char* dest_dir) {
    (void)archive_path;
    (void)dest_dir;
    return -1;
}
const char* rewamp_extract_last_error(void) { return "libarchive not compiled in"; }

#endif /* REWAMP_WITH_ARCHIVE */

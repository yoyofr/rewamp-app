#include "rewamp_loaded_files.h"

#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

/* A tune's file count is small and bounded in practice: a module plus its
 * sample bank, a PSF plus a lib plus a lib2, an EUP plus two banks. Sixteen is
 * far above anything observed and keeps the whole thing a static array — no
 * allocation on the decode path. */
#define RW_LF_MAX   16
#define RW_LF_PATH  1024

typedef struct {
    char     path[RW_LF_PATH];
    long long size;
} rw_lf_entry;

static rw_lf_entry s_files[RW_LF_MAX];
static int         s_count = 0;
static char        s_json[RW_LF_MAX * (RW_LF_PATH + 64)];

void rewamp_loaded_files_reset(void) {
    s_count  = 0;
    s_json[0] = '\0';
}

/* The last path component — what the panel shows. Kept whole in the list so a
 * future caller can still resolve it; only the JSON is trimmed. */
static const char* rw_lf_basename(const char* path) {
    const char* slash = strrchr(path, '/');
#ifdef _WIN32
    const char* bslash = strrchr(path, '\\');
    if (bslash != NULL && (slash == NULL || bslash > slash)) slash = bslash;
#endif
    return slash != NULL ? slash + 1 : path;
}

void rewamp_loaded_files_add(const char* path) {
    if (path == NULL || path[0] == '\0') return;
    if (s_count >= RW_LF_MAX) return;
    if (strlen(path) >= RW_LF_PATH) return;

    for (int i = 0; i < s_count; i++) {
        if (strcmp(s_files[i].path, path) == 0) return;
    }

    /* A loader may try several candidate names before finding the right one.
     * Only what exists gets listed, so a miss leaves no trace. */
    struct stat st;
    if (stat(path, &st) != 0) return;
#ifdef S_ISREG
    if (!S_ISREG(st.st_mode)) return;
#endif

    rw_lf_entry* e = &s_files[s_count];
    snprintf(e->path, sizeof(e->path), "%s", path);
    e->size = (long long)st.st_size;
    /* Published LAST: a reader never sees a half-written entry. */
    s_count += 1;
}

/* Minimal JSON string escaping — a file name can hold a quote or a backslash. */
static void rw_lf_append_escaped(char* out, size_t cap, size_t* len,
                                 const char* s) {
    for (; *s != '\0' && *len + 2 < cap; s++) {
        if (*s == '"' || *s == '\\') out[(*len)++] = '\\';
        else if ((unsigned char)*s < 0x20) { out[(*len)++] = ' '; continue; }
        out[(*len)++] = *s;
    }
}

const char* rewamp_loaded_files_json(void) {
    size_t len = 0;
    const size_t cap = sizeof(s_json);
    s_json[len++] = '[';
    for (int i = 0; i < s_count && len + 128 < cap; i++) {
        if (i > 0) s_json[len++] = ',';
        len += (size_t)snprintf(s_json + len, cap - len, "{\"name\":\"");
        rw_lf_append_escaped(s_json, cap, &len, rw_lf_basename(s_files[i].path));
        len += (size_t)snprintf(s_json + len, cap - len,
                                "\",\"size\":%lld}", s_files[i].size);
    }
    if (len + 2 < cap) s_json[len++] = ']';
    s_json[len] = '\0';
    return s_json;
}

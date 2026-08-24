#include "rewamp_assets.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char g_data_dir[4096] = "";

// Exported for FFI even when the target hides symbols by default.
__attribute__((visibility("default"))) __attribute__((used))
void rewamp_set_data_dir(const char* path) {
    if (path == NULL) {
        g_data_dir[0] = '\0';
        return;
    }
    strncpy(g_data_dir, path, sizeof(g_data_dir) - 1);
    g_data_dir[sizeof(g_data_dir) - 1] = '\0';
}

const char* rewamp_get_data_dir(void) {
    return g_data_dir;
}

int rewamp_load_asset(const char* relPath, uint8_t** outBuf, size_t* outSize) {
    if (relPath == NULL || outBuf == NULL || outSize == NULL) return 0;
    if (g_data_dir[0] == '\0') return 0;

    char full[4096];
    // Join data dir + "/" + relPath, tolerating a trailing slash on the dir.
    size_t dl = strlen(g_data_dir);
    int hasSlash = (dl > 0 && g_data_dir[dl - 1] == '/');
    snprintf(full, sizeof(full), "%s%s%s",
             g_data_dir, hasSlash ? "" : "/", relPath);

    FILE* f = fopen(full, "rb");
    if (!f) return 0;

    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return 0; }
    long sz = ftell(f);
    if (sz < 0) { fclose(f); return 0; }
    rewind(f);

    uint8_t* buf = (uint8_t*)malloc((size_t)sz);
    if (!buf) { fclose(f); return 0; }

    size_t rd = fread(buf, 1, (size_t)sz, f);
    fclose(f);
    if (rd != (size_t)sz) { free(buf); return 0; }

    *outBuf = buf;
    *outSize = (size_t)sz;
    return 1;
}

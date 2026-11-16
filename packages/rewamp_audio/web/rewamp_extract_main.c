/* Module de dépliage web (rewamp_extract.wasm, voir CMakeLists.txt), appelé par
 * site/extract-worker.js dans un Worker jetable.
 *
 * rewamp_extract_to_js() déplie VERS JS au lieu du disque: chaque entrée arrive
 * dans UN tampon JS alloué à sa taille exacte (js_begin), rempli bloc par bloc
 * (js_block), puis rendu tel quel (transféré, sans copie). Déplier vers MEMFS
 * (rewamp_extract_archive) faisait grandir chaque fichier par réallocations
 * successives (×1,125 au-delà d'1 Mo: une copie ENTIÈRE à chaque pas) puis le
 * recopiait en le lisant — des centaines de Mo de tampons morts par album.
 * Chrome les ramasse; Safari garde le pic de sa zone de tampons (Gigacage)
 * pour toujours: 1,5 Go mesurés après un seul album PSF2 de 295 Mo.
 *
 * Mêmes règles de chemin que le natif (rewamp_extract_safe_relpath). */
#include <archive.h>
#include <archive_entry.h>
#include <emscripten.h>
#include <stdio.h>

const char* rewamp_extract_safe_relpath(const char* raw, char* out, size_t n);

// Taille annoncée < 0 = inconnue: JS fait grandir son tampon, puis le recoupe.
EM_JS(void, js_begin, (const char* rel, double size), { Module.onBegin(UTF8ToString(rel), size); });
// Vue prise ICI: avec threads + croissance, emcc protège HEAPU8 contre une mémoire qui a grandi.
EM_JS(void, js_block, (const void* p, double len, double off), { Module.onBlock(HEAPU8.subarray(p, p + len), off); });
EM_JS(void, js_end, (void), { Module.onEnd(); });

static char s_err[512] = "";
EMSCRIPTEN_KEEPALIVE const char* rewamp_extract_js_last_error(void) { return s_err; }

EMSCRIPTEN_KEEPALIVE int rewamp_extract_to_js(const char* archive_path) {
    s_err[0] = '\0';
    struct archive* a = archive_read_new();
    if (!a) { snprintf(s_err, sizeof(s_err), "archive_read_new failed"); return -1; }
    archive_read_support_format_all(a);
    archive_read_support_filter_all(a);

    int rc = archive_read_open_filename(a, archive_path, 65536);
    if (rc != ARCHIVE_OK) {
        snprintf(s_err, sizeof(s_err), "open failed (%d): %s", rc, archive_error_string(a) ? archive_error_string(a) : "?");
        archive_read_free(a);
        return rc;
    }
    rc = 0;
    int extracted = 0;
    struct archive_entry* entry;
    for (;;) {
        int r = archive_read_next_header(a, &entry);
        if (r == ARCHIVE_EOF) break;
        if (r < ARCHIVE_OK) {
            snprintf(s_err, sizeof(s_err), "read_next_header (%d): %s", r, archive_error_string(a) ? archive_error_string(a) : "?");
            rc = r;
            break;
        }
        char rel[4096];
        const char* relp = rewamp_extract_safe_relpath(archive_entry_pathname(entry), rel, sizeof(rel));
        // Un dossier, un lien ou une entrée spéciale ne donne pas de fichier.
        if (!relp || archive_entry_filetype(entry) != AE_IFREG) { archive_read_data_skip(a); continue; }

        js_begin(relp, archive_entry_size_is_set(entry) ? (double)archive_entry_size(entry) : -1.0);
        const void* buf; size_t size; int64_t off;
        for (;;) {
            r = archive_read_data_block(a, &buf, &size, &off);
            if (r == ARCHIVE_EOF) break;
            if (r < ARCHIVE_OK) break;   // entrée abîmée: on garde ce qui est venu, comme le natif
            js_block(buf, (double)size, (double)off);
        }
        js_end();
        extracted++;
    }
    if (rc == 0 && extracted == 0) { snprintf(s_err, sizeof(s_err), "no entries extracted"); rc = -2; }
    archive_read_close(a);
    archive_read_free(a);
    return rc;
}

/* Emscripten exige un main() pour un module compilé avec -pthread. */
int main(void) { return 0; }

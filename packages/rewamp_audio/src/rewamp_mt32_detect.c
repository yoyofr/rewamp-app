/* « Ce MIDI a-t-il été écrit pour un MT-32 ? » — la question, et ses trois
 * réponses possibles, PARTAGÉES par les deux greffons MIDI.
 *
 * Le greffon MT-32 s'en sert pour marquer 104 au probe (« ce fichier est
 * pour moi »), et le greffon FluidLite pour savoir qu'il doit ADAPTER les
 * numéros de programme quand aucune ROM Roland n'est disponible. Les deux
 * doivent répondre PAREIL: une détection recopiée dans chacun dériverait, et
 * l'utilisateur verrait l'avertissement sur des fichiers qui partent quand
 * même au MT-32, ou l'inverse.
 *
 * ⚠️ Ces fonctions ne regardent PAS si des ROMs sont présentes — c'est une
 * question distincte, que chaque appelant pose à sa façon (le greffon MT-32
 * refuse de jouer sans ROM, FluidLite convertit justement dans ce cas).
 */
#include <dirent.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/stat.h>
#include <time.h>

#include "rewamp_mt32_detect.h"

/* F0 41 <dev> 16 — Roland, model id 0x16 = MT-32 family. */
int rewamp_mt32_file_has_sysex(const char* path, uint64_t fileSize) {
    if (fileSize < 8 || fileSize > (4u << 20)) return 0;
    FILE* f = fopen(path, "rb");
    if (!f) return 0;
    unsigned char* buf = (unsigned char*)malloc((size_t)fileSize);
    int found = 0;
    if (buf) {
        size_t got = fread(buf, 1, (size_t)fileSize, f);
        /* In a Standard MIDI File a sysex event is F0 <VLQ length> <data>:
         * the Roland header 41 <dev> 16 comes AFTER the length, which takes
         * TWO bytes as soon as the message exceeds 127 bytes — a timbre
         * upload always does. The first version matched F0 41 back to back
         * and so never recognised a single real file. */
        for (size_t i = 0; i + 5 < got && !found; i++) {
            if (buf[i] != 0xF0) continue;
            size_t k = i + 1;
            int n = 0;
            while (k < got && (buf[k] & 0x80) && n < 3) { k++; n++; }   /* VLQ continuation bytes */
            k++;                                                        /* last VLQ byte */
            if (k + 2 < got && buf[k] == 0x41 && buf[k + 2] == 0x16) found = 1;
        }
        free(buf);
    }
    fclose(f);
    return found;
}

/* Does the song's FOLDER carry an MT-32 bank — a raw dump (*.syx) or a
 * sysex-only MIDI (sys*.mid) holding Roland MT-32 sysex (model 0x16; a GS
 * bank is model 0x42 and does not count)? Then its tunes were written for
 * the MT-32 even when they carry no sysex of their own (Ultima VII: all of
 * it lives in sysexmain.mid), and auto mode must pick this engine. The probe
 * runs once per file of a folder, so the verdict is kept per directory and
 * dropped when the directory changes (its mtime moves on add/remove). */
struct BankDirCache { char dir[1024]; time_t mtime; int has; };
static struct BankDirCache g_bank_dir_cache[16];
static int          g_bank_dir_next = 0;
static pthread_mutex_t g_bank_dir_mutex = PTHREAD_MUTEX_INITIALIZER;

static int mt32_syx_is_mt32(const char* path) {
    struct stat st;
    if (stat(path, &st) != 0 || st.st_size < 8 || st.st_size > (1 << 20)) return 0;
    FILE* f = fopen(path, "rb");
    if (!f) return 0;
    unsigned char buf[4096];
    size_t got = fread(buf, 1, sizeof(buf), f);
    fclose(f);
    for (size_t i = 0; i + 3 < got; i++)
        if (buf[i] == 0xF0 && buf[i + 1] == 0x41 && buf[i + 3] == 0x16) return 1;
    return 0;
}

int rewamp_mt32_dir_has_bank(const char* songPath) {
    char dir[1024];
    const char* slash = strrchr(songPath, '/');
    if (!slash || (size_t)(slash - songPath) >= sizeof(dir)) return 0;
    memcpy(dir, songPath, (size_t)(slash - songPath));
    dir[slash - songPath] = '\0';
    const char* songBase = slash + 1;
    struct stat dst;
    if (stat(dir, &dst) != 0) return 0;
    pthread_mutex_lock(&g_bank_dir_mutex);
    for (int i = 0; i < (int)(sizeof(g_bank_dir_cache) / sizeof(g_bank_dir_cache[0])); i++) {
        struct BankDirCache* c = &g_bank_dir_cache[i];
        if (c->dir[0] && strcmp(c->dir, dir) == 0 && c->mtime == dst.st_mtime) {
            int has = c->has;
            pthread_mutex_unlock(&g_bank_dir_mutex);
            return has;
        }
    }
    int has = 0;
    DIR* dd = opendir(dir);
    if (dd) {
        struct dirent* e;
        while (!has && (e = readdir(dd)) != NULL) {
            const char* nm = e->d_name;
            if (nm[0] == '.' || strcmp(nm, songBase) == 0) continue;
            const char* dot = strrchr(nm, '.');
            if (!dot) continue;
            char path[2048];
            snprintf(path, sizeof(path), "%s/%s", dir, nm);
            if (strcasecmp(dot, ".syx") == 0) {
                has = mt32_syx_is_mt32(path);
            } else if ((strcasecmp(dot, ".mid") == 0 || strcasecmp(dot, ".midi") == 0) &&
                       strncasecmp(nm, "sys", 3) == 0) {
                struct stat st;
                if (stat(path, &st) == 0)
                    has = rewamp_mt32_file_has_sysex(path, (uint64_t)st.st_size);
            }
        }
        closedir(dd);
    }
    {
        struct BankDirCache* c = &g_bank_dir_cache[g_bank_dir_next];
        g_bank_dir_next = (g_bank_dir_next + 1) %
                          (int)(sizeof(g_bank_dir_cache) / sizeof(g_bank_dir_cache[0]));
        snprintf(c->dir, sizeof(c->dir), "%s", dir);
        c->mtime = dst.st_mtime;
        c->has = has;
    }
    pthread_mutex_unlock(&g_bank_dir_mutex);
    return has;
}

/* Is the song filed under a folder that NAMES the MT-32 family (its own
 * folder or the one above: "MT32/", "MT-32/Single Tracks/", "CM-32L/",
 * "LAPC-1/")? Game-MIDI collections sort each game by target device, and an
 * XMIDI conversion carries no sysex at all — the custom timbres lived in the
 * game's timbre library, never in the .xmi (Dark Sun: 70 .xmi, 0 sysex) — so
 * the folder is the ONLY thing that says "written for the MT-32". GS / GM /
 * Sound Canvas folders do not match. */
static int mt32_name_is_mt32_folder(const char* seg, size_t len) {
    char low[64];
    size_t k = 0;
    for (size_t i = 0; i < len && k < sizeof(low) - 1; i++) {
        char c = seg[i];
        if (c == '-' || c == '_' || c == ' ') continue;        /* MT-32, MT_32, MT 32 */
        low[k++] = (char)((c >= 'A' && c <= 'Z') ? c + 32 : c);
    }
    low[k] = '\0';
    return strcmp(low, "mt32") == 0 || strcmp(low, "cm32l") == 0 ||
           strcmp(low, "lapc1") == 0 || strcmp(low, "rolandmt32") == 0 ||
           strcmp(low, "mt32version") == 0;
}

int rewamp_mt32_in_mt32_folder(const char* songPath) {
    const char* end = strrchr(songPath, '/');
    for (int level = 0; end && end > songPath && level < 2; level++) {
        const char* start = end - 1;
        while (start > songPath && *start != '/') start--;
        const char* seg = (*start == '/') ? start + 1 : start;
        if (mt32_name_is_mt32_folder(seg, (size_t)(end - seg))) return 1;
        end = (*start == '/') ? start : NULL;
    }
    return 0;
}


/* Les trois signaux réunis, dans l'ordre du moins cher au plus cher: le
 * sysex du fichier lui-même, puis la banque voisine (un listing de dossier,
 * mémorisé), puis le nom du dossier. */
int rewamp_midi_targets_mt32(const char* path, uint64_t fileSize) {
    if (!path || !path[0]) return 0;
    if (rewamp_mt32_file_has_sysex(path, fileSize)) return 1;
    if (rewamp_mt32_dir_has_bank(path)) return 1;
    if (rewamp_mt32_in_mt32_folder(path)) return 1;
    return 0;
}

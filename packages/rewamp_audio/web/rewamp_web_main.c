/* Point d'entrée du module wasm. La page n'appelle que l'API publique du moteur
 * (rewamp_audio.h, exportée par REWAMP_EXPORT); ce fichier n'ajoute que:
 *   - main(), exigé par Emscripten pour un module avec pthreads;
 *   - web_bench(), qui décode un fichier hors temps réel et mesure (tools/bench.mjs).
 */
#include <emscripten/emscripten.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../src/rewamp_audio.h"
#include "../src/rewamp_channel_data.h"
#include "../src/rewamp_registry.h"

int main(void) { return 0; }

/* Décode `seconds` d'audio aussi vite que possible par le registre seul (sans
 * rewamp_init ni sortie audio) et rend le facteur temps réel. */
EMSCRIPTEN_KEEPALIVE double web_bench(const char* path, double seconds) {
    static int ready;
    if (!ready) { rewamp_register_builtin_plugins(); rewamp_channel_data_init(); ready = 1; }
    /* Comme rewamp_load_file: le moteur se choisit sur le chemin NU, l'open()
     * reçoit le chemin d'origine (avec ?subsong=N). */
    char clean[4096];
    strncpy(clean, path, sizeof clean - 1); clean[sizeof clean - 1] = 0;
    { char* q = strchr(clean, '?'); if (q) *q = 0; }
    const RewampPluginVTable* c[8];
    const int n = rewamp_registry_select_ranked(clean, c, 8);
    const RewampPluginVTable* vt = NULL;
    RewampDecoder* dec = NULL;
    RewampAudioFormat fmt;
    for (int i = 0; i < n && !dec; i++) {
        memset(&fmt, 0, sizeof fmt);
        dec = c[i]->open(path, &fmt);
        if (dec) vt = c[i];
    }
    if (!dec) { printf("bench: aucun moteur pour %s\n", path); return -1; }
    const int ch = fmt.channels ? (int)fmt.channels : 2;
    const int rate = fmt.sampleRate ? (int)fmt.sampleRate : 44100;
    float* buf = malloc(sizeof(float) * 1024 * ch);
    const uint64_t want = (uint64_t)(seconds * rate);
    uint64_t got = 0;
    double sq = 0; /* RMS: un décodeur qui « tourne » vite peut rendre du silence */
    const double t0 = emscripten_get_now();
    while (got < want) {
        const uint64_t r = vt->read(dec, buf, 1024);
        if (r == 0) break;
        for (uint64_t k = 0; k < r * ch; k++) sq += (double)buf[k] * buf[k];
        got += r;
    }
    const double ms = emscripten_get_now() - t0;
    free(buf);
    vt->close(dec);
    const double audio_ms = got * 1000.0 / rate;
    const char* base = strrchr(path, '/');
    const double rms = got ? sqrt(sq / (double)(got * ch)) : 0;
    printf("bench: %-14s %-40s %6.1fs audio en %7.1f ms = %6.1fx temps réel, RMS %.3f\n",
           vt->name, base ? base + 1 : path, audio_ms / 1000, ms,
           ms > 0 ? audio_ms / ms : 0, rms);
    return ms > 0 ? audio_ms / ms : 0;
}

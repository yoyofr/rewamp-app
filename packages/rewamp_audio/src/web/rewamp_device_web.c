/* Sortie audio web: pompe pthread → anneau en mémoire wasm → AudioWorklet.
 * Le contrat et le pourquoi sont dans rewamp_device_web.h. */
#include "rewamp_device_web.h"

#include <emscripten/emscripten.h>
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* Capacité: ce que l'AudioWorklet a d'avance. Le producteur du moteur garde
 * déjà 200 ms de décodage d'avance, la pompe ne fait que le graphe miniaudio
 * (mélange, fondus), donc pas besoin de plus que de quoi traverser un retard
 * d'ordonnancement d'un Worker: 4096 trames = 93 ms à 44,1 kHz. C'est aussi la
 * latence d'une pause ou d'un mute, en plus du fondu de 12 ms. */
#ifndef REWAMP_WEB_RING_FRAMES
#define REWAMP_WEB_RING_FRAMES 4096
#endif
/* Taille d'un rendu de la pompe: le « période » du périphérique (la position du
 * consommateur avance par ce pas, les visualiseurs la lisent). 512 = 11,6 ms. */
#ifndef REWAMP_WEB_CHUNK_FRAMES
#define REWAMP_WEB_CHUNK_FRAMES 512
#endif

enum { H_WRITE, H_READ, H_CAP, H_CH, H_RATE, H_STARTED, H_UNDERRUNS, H_DATA, H_COUNT };

static int32_t*            g_hdr;        /* en-tête + données, un seul bloc */
static float*              g_data;
static pthread_t           g_thread;
static int                 g_thread_ok;
static volatile int        g_quit;
static ma_device_data_proc g_cb;

static void* pump_main(void* arg) {
    (void)arg;
    const uint32_t cap = (uint32_t)g_hdr[H_CAP];
    const uint32_t ch  = (uint32_t)g_hdr[H_CH];
    float* tmp = (float*)malloc(sizeof(float) * REWAMP_WEB_CHUNK_FRAMES * ch);
    while (!g_quit) {
        if (!__atomic_load_n(&g_hdr[H_STARTED], __ATOMIC_ACQUIRE)) {
            /* Suspendu: rien à rendre. Attente réveillée par resume. */
            __builtin_wasm_memory_atomic_wait32(&g_hdr[H_STARTED], 0, 100 * 1000000LL);
            continue;
        }
        const uint32_t w = (uint32_t)__atomic_load_n(&g_hdr[H_WRITE], __ATOMIC_ACQUIRE);
        const int32_t  r = __atomic_load_n(&g_hdr[H_READ], __ATOMIC_ACQUIRE);
        const uint32_t used = w - (uint32_t)r;
        if (cap - used < REWAMP_WEB_CHUNK_FRAMES) {
            /* Plein: attendre que l'AudioWorklet avance `read` (il notifie).
             * Délai borné: Atomics.notify depuis un AudioWorklet n'est pas
             * garanti partout, et un réveil manqué ne doit coûter qu'un pas. */
            __builtin_wasm_memory_atomic_wait32(&g_hdr[H_READ], r, 3 * 1000000LL);
            continue;
        }
        g_cb(NULL, tmp, NULL, REWAMP_WEB_CHUNK_FRAMES);
        /* Copie dans l'anneau, en deux morceaux au besoin. */
        const uint32_t at   = w & (cap - 1);
        const uint32_t head = (cap - at < REWAMP_WEB_CHUNK_FRAMES) ? cap - at : REWAMP_WEB_CHUNK_FRAMES;
        memcpy(g_data + at * ch, tmp, sizeof(float) * head * ch);
        if (head < REWAMP_WEB_CHUNK_FRAMES)
            memcpy(g_data, tmp + head * ch,
                   sizeof(float) * (REWAMP_WEB_CHUNK_FRAMES - head) * ch);
        __atomic_store_n(&g_hdr[H_WRITE], (int32_t)(w + REWAMP_WEB_CHUNK_FRAMES),
                         __ATOMIC_RELEASE);
    }
    free(tmp);
    return NULL;
}

ma_result rewamp_web_device_start(ma_device_data_proc callback) {
    if (g_thread_ok) { g_cb = callback; return rewamp_web_device_resume(); }
    const size_t hdr_bytes = 64;   /* > H_COUNT*4, aligné pour les float */
    const size_t bytes = hdr_bytes + sizeof(float) * REWAMP_WEB_RING_FRAMES * 2;
    g_hdr = (int32_t*)calloc(1, bytes);
    if (!g_hdr) return MA_OUT_OF_MEMORY;
    g_data = (float*)((char*)g_hdr + hdr_bytes);
    g_hdr[H_CAP]  = REWAMP_WEB_RING_FRAMES;
    g_hdr[H_CH]   = 2;
    g_hdr[H_RATE] = 44100;
    g_hdr[H_DATA] = (int32_t)hdr_bytes;
    g_hdr[H_STARTED] = 1;
    g_cb = callback;
    g_quit = 0;
    if (pthread_create(&g_thread, NULL, pump_main, NULL) != 0) {
        free(g_hdr); g_hdr = NULL; g_data = NULL;
        return MA_ERROR;
    }
    g_thread_ok = 1;
    return MA_SUCCESS;
}

void rewamp_web_device_stop(void) {
    if (!g_hdr) return;
    __atomic_store_n(&g_hdr[H_STARTED], 0, __ATOMIC_RELEASE);
}

ma_result rewamp_web_device_resume(void) {
    if (!g_hdr) return MA_INVALID_OPERATION;
    __atomic_store_n(&g_hdr[H_STARTED], 1, __ATOMIC_RELEASE);
    __builtin_wasm_memory_atomic_notify(&g_hdr[H_STARTED], 1);
    return MA_SUCCESS;
}

int rewamp_web_device_is_started(void) {
    return g_hdr && __atomic_load_n(&g_hdr[H_STARTED], __ATOMIC_ACQUIRE);
}

void rewamp_web_device_uninit(void) {
    if (!g_thread_ok) return;
    g_quit = 1;
    rewamp_web_device_resume();                      /* réveille l'attente « suspendu » */
    __builtin_wasm_memory_atomic_notify(&g_hdr[H_READ], 1);
    pthread_join(g_thread, NULL);
    g_thread_ok = 0;
    /* L'en-tête n'est PAS libéré: l'AudioWorklet peut encore le lire jusqu'à
     * ce que la page le ferme; un start suivant en refait un neuf. */
    g_hdr = NULL; g_data = NULL;
}

int rewamp_web_device_period_frames(void)   { return REWAMP_WEB_CHUNK_FRAMES; }
int rewamp_web_device_capacity_frames(void) { return REWAMP_WEB_RING_FRAMES; }

EMSCRIPTEN_KEEPALIVE int rewamp_web_audio_ring(void) { return (int)(intptr_t)g_hdr; }

/* Harnais mécanique du relais gapless: rewamp_datasource.c réel, décodeurs
 * factices, PAS de device — on appelle ds_read via ma_data_source_read
 * comme le ferait le rappel audio. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "rewamp_datasource.h"

/* ── stubs des captures/globals ── */
unsigned int generic_mute_mask = 0;
int64_t g_loop_fadeout_start_frame = -1;
int64_t g_loop_fadeout_total_frames = 0;
void rewamp_notes_capture(int64_t p) { (void)p; }
void rewamp_notes_reset(int n) { (void)n; }
void rewamp_notes_set_rate(int r) { (void)r; }
void rewamp_notes_set_played(int64_t p) { (void)p; }
void rewamp_channel_data_capture_delayed(int64_t s, int n) { (void)s; (void)n; }
void rewamp_channel_data_set_delayed(int on) { (void)on; }
void rewamp_channel_data_set_consumer_pos(int64_t p) { (void)p; }
int  rewamp_channel_count(void) { return 0; }
int  rewamp_channel_count_raw(void) { return 0; }
void rewamp_pattern_cursor_capture(int64_t p, int o, int r) { (void)p;(void)o;(void)r; }
void rewamp_pattern_cursor_reset(void) {}
void rewamp_pattern_cursor_set_played(int64_t p) { (void)p; }
void rewamp_waveform_write(const float* p, uint64_t n, int c) { (void)p;(void)n;(void)c; }
double rewamp_get_lookahead_seconds(void) { return 0; }

extern double g_crossfade_seconds;
extern double g_track_end_seconds;

/* ── décodeur factice: N frames d'une valeur constante ── */
typedef struct { int64_t left; float value; int64_t total; } FakeDec;
static uint64_t fake_read(RewampDecoder* d, float* out, uint64_t frames) {
    FakeDec* f = (FakeDec*)d;
    int64_t n = (int64_t)frames < f->left ? (int64_t)frames : f->left;
    for (int64_t i = 0; i < n * 2; i++) out[i] = f->value;
    f->left -= n;
    return (uint64_t)n;
}
static void fake_seek(RewampDecoder* d, uint64_t frame) {
    FakeDec* f = (FakeDec*)d;
    f->left = f->total - (int64_t)frame;
    if (f->left < 0) f->left = 0;
}
static uint64_t fake_length(RewampDecoder* d) { return (uint64_t)((FakeDec*)d)->total; }
static int fake_closed = 0;
static void fake_close(RewampDecoder* d) { fake_closed++; free(d); }
static int fake_probe(const char* e, const uint8_t* h, size_t n) { (void)e;(void)h;(void)n; return 0; }
static RewampDecoder* fake_open(const char* p, RewampAudioFormat* f) { (void)p;(void)f; return NULL; }
static const RewampPluginVTable kFakeVt = {
    "fake", fake_probe, fake_open, fake_read, fake_seek, fake_length, fake_close,
};

/* ── le "prochain" que rewamp_audio.c fournirait ── */
static int g_staged = 0;
static float g_next_value = 0;
static int64_t g_next_frames = 0;
static uint32_t g_next_rate = 44100;
int rewamp_next_staged(void) { return g_staged; }
int rewamp_handoff_open_next(const RewampPluginVTable** vt, RewampDecoder** dec,
                             RewampAudioFormat* fmt) {
    if (!g_staged) return 0;
    g_staged = 0;
    FakeDec* f = calloc(1, sizeof *f);
    f->left = f->total = g_next_frames;
    f->value = g_next_value;
    *vt = &kFakeVt; *dec = (RewampDecoder*)f;
    fmt->channels = 2; fmt->sampleRate = g_next_rate;
    return 1;
}
int64_t rewamp_handoff_serial(void);

static int fails = 0;
#define CHECK(cond, msg) do { \
    if (cond) printf("  OK  %s\n", msg); else { printf("  ECHEC %s\n", msg); fails++; } } while (0)

int main(void) {
    /* piste A: 10000 frames a 0.25 ; piste B: 8000 frames a 0.75 */
    FakeDec* a = calloc(1, sizeof *a);
    a->left = a->total = 10000; a->value = 0.25f;
    RewampAudioFormat fmt = { .channels = 2, .sampleRate = 44100 };
    RewampDataSource ds;
    memset(&ds, 0, sizeof ds);
    if (rewamp_data_source_init(&ds, &kFakeVt, (RewampDecoder*)a, fmt) != MA_SUCCESS)
        { printf("init ds FAIL\n"); return 1; }

    g_staged = 1; g_next_value = 0.75f; g_next_frames = 8000; g_next_rate = 44100;

    /* consommer comme le rappel audio: blocs de 512 frames, en laissant au
     * producteur le temps de remplir (lead 0.2 s = 8820 frames). */
    float buf[512 * 2];
    int64_t nA = 0, nB = 0, nSil = 0, boundary_at = -1, first_b_frame = -1;
    int64_t consumed = 0;
    int64_t serial0 = rewamp_handoff_serial();
    usleep(300000);  /* preremplissage du producteur */
    for (int it = 0; it < 3000 && consumed < 17000; it++) {
        ma_uint64 got = 0;
        ma_result r = ma_data_source_read_pcm_frames(&ds.base, buf, 512, &got);
        for (ma_uint64 i = 0; i < got; i++) {
            float v = buf[i * 2];
            if (v > 0.5f) { nB++; if (first_b_frame < 0) first_b_frame = nA + nB - 1 + nSil; }
            else if (v > 0.1f) nA++;
            else nSil++;
        }
        consumed += (int64_t)got;
        if (boundary_at < 0 && rewamp_handoff_serial() != serial0)
            boundary_at = consumed;
        if (r == MA_AT_END) break;
        usleep(11000);  /* cadence du device: 512 frames = 11.6 ms */
    }
    printf("== relais meme format == (A=%lld B=%lld silence=%lld firstB=%lld boundary=%lld closed=%d)\n",
           (long long)nA, (long long)nB, (long long)nSil, (long long)first_b_frame, (long long)boundary_at, fake_closed);
    CHECK(nA == 10000 && nB == consumed - nA - nSil, "les 10000 frames de A puis B, rien d'autre");
    CHECK(nSil == 0, "ZERO frame de silence entre les deux (gapless)");
    CHECK(first_b_frame == 10000, "la piste B commence EXACTEMENT a la frame 10000");
    CHECK(boundary_at >= 10000 && boundary_at <= 10000 + 512, "serial bascule quand le CONSOMMATEUR franchit la frontiere");
    CHECK(fake_closed == 1, "le decodeur A a ete ferme (sequentiel)");

    /* position relative a la piste apres franchissement */
    ma_uint64 cur = 0;
    ma_data_source_get_cursor_in_pcm_frames(&ds.base, &cur);
    CHECK(cur == (ma_uint64)(consumed - 10000), "cursor relatif a la piste B apres la frontiere");

    /* fin de B sans nouveau staged -> MA_AT_END */
    int64_t total = consumed;
    for (int it = 0; it < 3000; it++) {
        ma_uint64 got = 0;
        ma_result r = ma_data_source_read_pcm_frames(&ds.base, buf, 512, &got);
        total += (int64_t)got;
        if (r == MA_AT_END) break;
        usleep(11000);
    }
    CHECK(total == 18000, "18000 frames au total (10000 + 8000), fin propre");

    rewamp_data_source_uninit(&ds);
    CHECK(fake_closed == 2, "le decodeur B ferme par uninit");

    /* ── cas 2: taux DIFFERENT (48 k) -> le resampler producteur relaie ── */
    printf("== taux different: relais via resampler ==\n");
    fake_closed = 0;
    FakeDec* a2 = calloc(1, sizeof *a2);
    a2->left = a2->total = 5000; a2->value = 0.25f;
    memset(&ds, 0, sizeof ds);
    rewamp_data_source_init(&ds, &kFakeVt, (RewampDecoder*)a2, fmt);
    g_staged = 1; g_next_value = 0.75f; g_next_frames = 48000; g_next_rate = 48000;
    int64_t s0 = rewamp_handoff_serial();
    usleep(300000);
    total = 0;
    int64_t nB2 = 0;
    for (int it = 0; it < 3000; it++) {
        ma_uint64 got = 0;
        ma_result r = ma_data_source_read_pcm_frames(&ds.base, buf, 512, &got);
        for (ma_uint64 i = 0; i < got; i++) if (buf[i * 2] > 0.5f) nB2++;
        total += (int64_t)got;
        if (r == MA_AT_END) break;
        usleep(11000);
    }
    /* 48000 frames a 48 kHz ≈ 44100 frames ring (1 s) — ±1 % de marge. */
    CHECK(rewamp_handoff_serial() == s0 + 1, "serial bascule: relais REUSSI malgre le taux");
    CHECK(nB2 > 43000 && nB2 < 44600, "la duree de B est PRESERVEE par le resampler (~44100 frames ring)");
    CHECK(fake_closed == 1, "A ferme sequentiellement");
    rewamp_data_source_uninit(&ds);

    /* ── cas 3: CROSSFADE 0,2 s — recouvrement mixe, zero silence ── */
    printf("== crossfade ==\n");
    fake_closed = 0;
    g_crossfade_seconds = 0.2;   /* 8820 frames */
    FakeDec* a3 = calloc(1, sizeof *a3);
    a3->left = a3->total = 44100; a3->value = 0.25f;   /* 1 s */
    memset(&ds, 0, sizeof ds);
    rewamp_data_source_init(&ds, &kFakeVt, (RewampDecoder*)a3, fmt);
    g_staged = 1; g_next_value = 0.75f; g_next_frames = 44100; g_next_rate = 44100;
    int64_t s3 = rewamp_handoff_serial();
    usleep(300000);
    total = 0;
    int64_t nPureA = 0, nPureB = 0, nMix = 0, nZero = 0, firstMix = -1;
    int64_t firstZero = -1;
    int64_t boundary3 = -1;
    for (int it = 0; it < 6000; it++) {
        ma_uint64 got = 0;
        ma_result r = ma_data_source_read_pcm_frames(&ds.base, buf, 512, &got);
        for (ma_uint64 i = 0; i < got; i++) {
            float v = buf[i * 2];
            int64_t pos = total + (int64_t)i;
            if (v > 0.70f)      nPureB++;                        /* ~0.75 */
            else if (v > 0.28f) { nMix++; if (firstMix < 0) firstMix = pos; }
            else if (v > 0.10f) nPureA++;                        /* ~0.25 */
            else { nZero++; if (firstZero < 0) firstZero = pos; }
        }
        total += (int64_t)got;
        if (boundary3 < 0 && rewamp_handoff_serial() != s3) boundary3 = total;
        if (r == MA_AT_END) break;
        usleep(11000);
    }
    g_crossfade_seconds = 0.0;
    /* Le mix commence la ou A cesse d'etre pur: vers 44100-8820 = 35280. */
    printf("   (A=%lld mix=%lld B=%lld zero=%lld firstMix=%lld boundary=%lld total=%lld)\n",
           (long long)nPureA, (long long)nMix, (long long)nPureB, (long long)nZero,
           (long long)firstMix, (long long)boundary3, (long long)total);
    /* B est la DERNIERE piste de la file: son crossfade n'a pas de suivant,
     * donc le FONDU DE SORTIE du producteur s'applique a sa fin (comportement
     * voulu — sans lui, fondus moteurs supprimes = coupe seche). Le seul
     * quasi-silence admis est donc la queue de ce fondu. */
    CHECK(firstZero < 0 || firstZero > total - 8820 - 600,
          "le seul quasi-silence est la queue du fondu de sortie de B (fin de file)");
    CHECK(nMix > 4000, "une vraie zone de RECOUVREMENT existe (milliers de frames melangees)");
    CHECK(firstMix > 34000 && firstMix < 36600, "le recouvrement demarre ~0,2 s avant la fin de A");
    CHECK(boundary3 >= firstMix - 600 && boundary3 <= firstMix + 1200,
          "la frontiere (serial) tombe au DEBUT du recouvrement");
    CHECK(total > 78000 && total < 80000,
          "duree totale = A + B - recouvrement (~79380 frames)");
    rewamp_data_source_uninit(&ds);

    /* ── cas 4: moteur SANS FIN (SID/NSF) + fin posée par Dart ── */
    printf("== fin synthetique (moteur sans fin) ==\n");
    fake_closed = 0;
    g_track_end_seconds = 0.5;               /* 22050 frames ring */
    FakeDec* a4 = calloc(1, sizeof *a4);
    a4->left = a4->total = 1LL << 40;        /* ne finit jamais */
    a4->value = 0.25f;
    memset(&ds, 0, sizeof ds);
    rewamp_data_source_init(&ds, &kFakeVt, (RewampDecoder*)a4, fmt);
    ds.trackLenRing = 0;                     /* length() ~infinie: on l'ignore */
    g_staged = 1; g_next_value = 0.75f; g_next_frames = 8000; g_next_rate = 44100;
    int64_t s4 = rewamp_handoff_serial();
    usleep(300000);
    total = 0;
    int64_t nA4 = 0, nB4 = 0, firstB4 = -1;
    for (int it = 0; it < 3000; it++) {
        ma_uint64 got = 0;
        ma_result r = ma_data_source_read_pcm_frames(&ds.base, buf, 512, &got);
        for (ma_uint64 i = 0; i < got; i++) {
            float v = buf[i * 2];
            if (v > 0.5f) { nB4++; if (firstB4 < 0) firstB4 = total + (int64_t)i; }
            else if (v > 0.1f) nA4++;
        }
        total += (int64_t)got;
        if (r == MA_AT_END) break;
        usleep(11000);
    }
    g_track_end_seconds = 0.0;
    printf("   (A=%lld B=%lld firstB=%lld total=%lld)\n",
           (long long)nA4, (long long)nB4, (long long)firstB4, (long long)total);
    CHECK(firstB4 == 22050, "coupe EXACTE a la duree posee par Dart (22050) puis relais");
    CHECK(rewamp_handoff_serial() == s4 + 1, "serial bascule (gapless malgre un moteur sans fin)");
    CHECK(total == 22050 + 8000, "duree totale = fin Dart + piste B");
    rewamp_data_source_uninit(&ds);

    printf(fails ? "\n%d ECHEC(S)\n" : "\nTOUT VERT\n", fails);
    return fails != 0;
}

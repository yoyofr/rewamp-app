/* Oracle GBR — trois questions, un seul programme, aucun fichier requis.
 *
 *   1. un `.gbr` JOUE-t-il ?                (libgbsplay accepte, l'APU sort)
 *   2. la sonde trouve-t-elle les BONS morceaux ?   (liste CREUSE exacte)
 *   3. la sonde laisse-t-elle les oscilloscopes du morceau JOUÉ tranquilles ?
 *
 * Il n'y a pas de `.gbr` sous la main et il n'en faut pas: on en fabrique un
 * dont on CONNAÎT la réponse — en-tête GBRF plus un pilote Game Boy d'une
 * trentaine d'octets qui ne déclenche une voie que pour trois numéros de
 * morceau. Le numéro arrive dans le registre A (gbs_init), donc le pilote le
 * range dans B et le compare.
 *
 * Compilation et exécution: scripts/verify_gbr.sh
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <time.h>

#include "libgbs.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"

/* La sonde vit dans le greffon, qui est compilé avec nous. */
int rewamp_gbsplay_probe_subsong_count(const char *path);
int rewamp_gbsplay_probe_get_index(int idx);

#define ROM_SIZE   0x8000
#define INIT_ADDR  0x0200
#define TONE_ADDR  0x0280
#define PLAY_ADDR  0x0300
#define FRAMES     512            /* le lot du greffon — voir plus bas */

static const int LIVE[] = { 3, 7, 11 };
#define NLIVE ((int)(sizeof(LIVE)/sizeof(LIVE[0])))

static void io(uint8_t *p, int *o, uint8_t val, uint8_t reg)
{
    p[(*o)++] = 0x3e; p[(*o)++] = val;   /* LD A, val   */
    p[(*o)++] = 0xe0; p[(*o)++] = reg;   /* LDH (reg),A */
}

/* `live` == 0 : tous les morceaux jouent. Sinon: seuls ceux de LIVE[]. */
static int write_gbr(const char *path, int selective)
{
    uint8_t *f = calloc(1, 0x20 + ROM_SIZE);
    if (!f) return -1;
    uint8_t *rom = f + 0x20;

    memcpy(f, "GBRF", 4);
    f[0x05] = 0; f[0x06] = 1; f[0x07] = 1;        /* banques + V-Blank */
    f[0x08] = INIT_ADDR & 0xff; f[0x09] = INIT_ADDR >> 8;
    f[0x0a] = PLAY_ADDR & 0xff; f[0x0b] = PLAY_ADDR >> 8;

    int o = INIT_ADDR;
    rom[o++] = 0x47;                              /* LD B,A — A va être écrasé */
    io(rom, &o, 0x80, 0x26);                      /* NR52 — l'APU D'ABORD      */
    io(rom, &o, 0xff, 0x25);                      /* NR51                      */
    io(rom, &o, 0x77, 0x24);                      /* NR50                      */
    if (selective) {
        for (int i = 0; i < NLIVE; i++) {
            rom[o++] = 0x78;                                  /* LD A,B        */
            rom[o++] = 0xfe; rom[o++] = (uint8_t)LIVE[i];     /* CP n          */
            rom[o++] = 0xca;                                  /* JP Z,TONE     */
            rom[o++] = TONE_ADDR & 0xff; rom[o++] = TONE_ADDR >> 8;
        }
        rom[o++] = 0xc9;                          /* RET — morceau muet        */
        o = TONE_ADDR;
    }
    io(rom, &o, 0x80, 0x11);                      /* NR11 rapport cyclique     */
    io(rom, &o, 0xf0, 0x12);                      /* NR12 enveloppe, DAC on    */
    io(rom, &o, 0x00, 0x13);                      /* NR13                      */
    io(rom, &o, 0x87, 0x14);                      /* NR14 déclenchement        */
    rom[o++] = 0xc9;                              /* RET                       */
    rom[PLAY_ADDR] = 0xc9;                        /* rien par trame            */

    FILE *fp = fopen(path, "wb");
    if (!fp) { free(f); return -1; }
    size_t n = fwrite(f, 1, 0x20 + ROM_SIZE, fp);
    fclose(fp); free(f);
    return n == 0x20 + ROM_SIZE ? 0 : -1;
}

static double now_ms(void)
{
    struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec * 1000.0 + t.tv_nsec / 1e6;
}

/* ── 1. ça joue ──────────────────────────────────────────────────────────── */
static long peak = 0, rendered = 0;
static void sound_cb(struct gbs *gbs, struct gbs_output_buffer *buf, void *priv)
{
    (void)gbs; (void)priv;
    for (long i = 0; i < buf->pos * 2; i++) {
        long v = buf->data[i] < 0 ? -buf->data[i] : buf->data[i];
        if (v > peak) peak = v;
    }
    rendered += buf->pos;
}

static int16_t pcm_a[FRAMES * 2], pcm_b[FRAMES * 2];

static struct gbs *open_cfg(const char *path, struct gbs_output_buffer *out,
                            int16_t *pcm, int capture)
{
    struct gbs *g = gbs_open(path);
    if (!g) return NULL;
    out->data = pcm; out->bytes = FRAMES * 2 * (long)sizeof(int16_t); out->pos = 0;
    gbs_configure_output(g, out, 44100);
    gbs_set_voice_capture(g, capture);
    gbs_init(g, 0);
    gbs_configure(g, 0, 0, 0, 0, 0);
    return g;
}

int main(int argc, char **argv)
{
    const char *dir = argc > 1 ? argv[1] : ".";
    char plain[4096], sparse[4096];
    snprintf(plain,  sizeof(plain),  "%s/rewamp_oracle_plain.gbr",  dir);
    snprintf(sparse, sizeof(sparse), "%s/rewamp_oracle_sparse.gbr", dir);
    if (write_gbr(plain, 0) || write_gbr(sparse, 1)) {
        fprintf(stderr, "écriture impossible dans %s\n", dir);
        return 2;
    }

    /* ⚠️ MÊME mise en place que rewamp_plugin_gbsplay.c open(): la taille
     * d'écriture de l'anneau ET les tampons d'accumulation 1..3. Un lot plus
     * grand que celui du greffon déborderait — le patch de capture de gbhw.c
     * les fait glisser de la taille du lot à chaque vidange. */
    rewamp_channel_data_init();
    rewamp_channel_data_reset(4);
    rewamp_channel_data_set_ring_write_size(4096);
    rewamp_channel_data_set_ring_circular(1);
    for (int ch = 1; ch < 4; ch++)
        m_voice_buff_accumul_temp[ch] =
            (signed int*)calloc(FRAMES * 4 * 2, sizeof(signed int));

    int fail = 0;

    /* 1. Le fichier joue-t-il ? */
    struct gbs_output_buffer oa;
    struct gbs *playing = open_cfg(plain, &oa, pcm_a, 1);
    if (!playing) { printf("1. lecture  : gbs_open a REFUSÉ le fichier\n"); return 1; }
    gbs_set_sound_callback(playing, sound_cb, NULL);
    for (int i = 0; i < 200; i++) if (!gbs_step(playing, 12)) break;
    int plays = (rendered > 44100 / 10 && peak > 1000);
    printf("1. lecture  : %ld trames, crête %ld/32767 -> %s\n",
           rendered, peak, plays ? "OK" : "MUET");
    fail |= !plays;

    /* 3. (mesuré ici, pendant que `playing` tient les anneaux) La sonde
     *    écrit-elle dans les oscilloscopes du morceau joué ? */
    int64_t head_before = m_voice_current_ptr[0];

    /* 2. La sonde trouve-t-elle exactement les morceaux vivants ? */
    double t0 = now_ms();
    int n = rewamp_gbsplay_probe_subsong_count(sparse);
    double dt = now_ms() - t0;
    int ok = (n == NLIVE);
    for (int i = 0; ok && i < n; i++) ok = (rewamp_gbsplay_probe_get_index(i) == LIVE[i]);
    printf("2. sonde    : %d morceaux en %.0f ms, indices", n, dt);
    for (int i = 0; i < n; i++) printf(" %d", rewamp_gbsplay_probe_get_index(i));
    printf(" -> %s\n", ok ? "OK" : "ATTENDU 3 7 11");
    fail |= !ok;

    int64_t head_after = m_voice_current_ptr[0];
    printf("3. isolation: tête d'écriture %lld -> %lld -> %s\n",
           (long long)head_before, (long long)head_after,
           head_before == head_after ? "OK" : "LA SONDE A ÉCRIT DANS LES ANNEAUX");
    fail |= (head_before != head_after);

    /* Contre-épreuve: la MÊME sonde avec la capture laissée active DOIT
     * déplacer la tête. Sans ça, le test 3 passerait même si le drapeau ne
     * servait à rien. */
    struct gbs_output_buffer ob;
    struct gbs *loud = open_cfg(sparse, &ob, pcm_b, 1);
    if (loud) {
        for (int i = 0; i < 200; i++) if (!gbs_step(loud, 16)) break;
        gbs_close(loud);
    }
    int moved = (m_voice_current_ptr[0] != head_after);
    printf("4. contre-épreuve: capture ACTIVE déplace la tête -> %s\n",
           moved ? "OK" : "LE DRAPEAU NE SERT À RIEN");
    fail |= !moved;

    gbs_close(playing);
    remove(plain); remove(sparse);
    printf("%s\n", fail ? "ÉCHEC" : "TOUT EST VERT");
    return fail ? 1 : 0;
}

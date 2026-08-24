// Dump canonique d'une grille de motifs, via le PLUGIN — donc exactement la
// conversion que l'app affiche. Compilé DEUX fois par verify_zxtune_patterns.sh:
// une fois contre zxtune (-DUSE_ZXTUNE), une fois contre libpt3.
#include <cstdio>
#include <cstring>
#include <vector>
#include <strings.h>
extern "C" {
#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
}
#ifdef USE_ZXTUNE
extern "C" const RewampPluginVTable* rewamp_zxtune_plugin(void);
static const RewampPluginVTable* plug() { return rewamp_zxtune_plugin(); }
extern "C" int rewamp_ext_in_list(const char* e, const char* const* l) {
    if (!e) return 0; for (; *l; ++l) if (!strcasecmp(e, *l)) return 1; return 0; }
#else
extern "C" const RewampPluginVTable* rewamp_libpt3_plugin(void);
static const RewampPluginVTable* plug() { return rewamp_libpt3_plugin(); }
#endif

int main(int argc, char** argv) {
    if (argc < 2) return 2;
    rewamp_channel_data_init();
    const RewampPluginVTable* vt = plug();
    RewampAudioFormat fmt; memset(&fmt, 0, sizeof(fmt));
    RewampDecoder* d = vt->open(argv[1], &fmt);
    if (!d) { printf("# open failed\n"); return 1; }
    RewampPatternSongInfo si;
    if (!vt->pattern_song_info || !vt->pattern_song_info(d, &si)) { printf("# no grid\n"); vt->close(d); return 0; }
    printf("channels %d orders %d\n", si.num_channels, si.num_orders);
    for (int o = 0; o < si.num_orders; o++) printf("order %d %d\n", o, vt->pattern_order(d, o));
    for (int p = 0; p < si.num_patterns; p++) {
        const int rows = vt->pattern_num_rows(d, p);
        printf("pattern %d rows %d\n", p, rows);
        if (rows <= 0) continue;
        std::vector<RewampPatternCell> c((size_t)rows * si.num_channels);
        vt->pattern_get(d, p, c.data(), (int)c.size());
        for (int r = 0; r < rows; r++)
            for (int ch = 0; ch < si.num_channels; ch++) {
                const RewampPatternCell& z = c[(size_t)r * si.num_channels + ch];
                int orn = -1;
                for (int k = 0; k < z.num_fx; k++) if (z.fx[k][0] == 'O') orn = z.fxval[k];
                int vol = -1;
                if (z.vol[0]) { vol = 0; for (const char* s = z.vol; *s; s++)
                    vol = vol * 16 + (*s <= '9' ? *s - '0' : (*s | 32) - 'a' + 10); }
                if (z.note == REWAMP_NOTE_EMPTY && z.instrument < 0 && orn < 0 && vol < 0) continue;
                // Marque les lignes de portamento: PT3 y écrit la note CIBLE,
                // que les deux moteurs ne rangent pas au même endroit (voir le
                // .sh). Le comparateur s'en sert pour les neutraliser.
                int porta = 0;
                for (int k = 0; k < z.num_fx; k++) if (z.fx[k][0] == '2' && !z.fx[k][1]) porta = 1;
                printf("c %d %d %d n%d s%d o%d v%d%s\n", p, r, ch, z.note, z.instrument,
                       orn, vol, porta ? " PORTA" : "");
            }
    }
    vt->close(d);
    return 0;
}
#ifdef USE_ZXTUNE
extern "C" int rewamp_waveform_pos(void) { return 0; }
extern "C" int rewamp_waveform_read_i8(int c, signed char* o, int n) { (void)c;(void)o;(void)n; return 0; }
#endif

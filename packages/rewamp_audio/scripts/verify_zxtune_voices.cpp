// Oracle des VOIX d'un module zxtune, via le PLUGIN: pour chaque voix
// matérielle, ce que l'oscilloscope par voix reçoit (part non nulle, crête),
// les hauteurs publiées (vgm_last_note) et la part de chaque voix dans le
// mixage; puis la grille de motifs annoncée (largeur) et ses modèles.
//
// Né du MultiTrackContainer (.mtc): les captures par voix de zxtune passent par
// des GLOBAUX de décalage (m_voicesForceOfs) que seule une paire TurboSound
// posait — trois PT3 d'un même .mtc écrivaient tous les voix 0-2, les voix 3-8
// restaient muettes. Voir verify_zxtune_voices.sh.
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <cmath>
#include <set>
#include <vector>
extern "C" {
#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
}
#include "ModizerVoicesData.h"
#include "Spectre.h"

extern "C" const RewampPluginVTable* rewamp_zxtune_plugin(void);
ZxTuneWrapper* rewamp_zxtune_wrapper_of(RewampDecoder* dec);   // rewamp_plugin_zxtune.cpp
extern "C" int rewamp_waveform_pos(void) { return 0; }
extern "C" int rewamp_waveform_read_i8(int c, signed char* o, int n) { (void)c;(void)o;(void)n; return 0; }

int main(int argc, char** argv) {
    double secs = 5.0;
    int ai = 1;
    if (argc > 2 && !strcmp(argv[1], "-s")) { secs = atof(argv[2]); ai = 3; }
    if (ai >= argc) { fprintf(stderr, "usage: %s [-s secondes] <module> [...]\n", argv[0]); return 2; }
    rewamp_channel_data_init();
    const RewampPluginVTable* vt = rewamp_zxtune_plugin();
    for (; ai < argc; ai++) {
        const char* file = argv[ai];
        const char* base = strrchr(file, '/');
        printf("== %s\n", base ? base + 1 : file);
        RewampAudioFormat fmt; memset(&fmt, 0, sizeof(fmt));
        RewampDecoder* d = vt->open(file, &fmt);
        if (!d) { printf("open KO\n"); continue; }
        const int nv = rewamp_channel_count_raw();
        printf("voix %d:", nv);
        for (int v = 0; v < nv; v++) printf(" [%d]%s", v, modizVoicesName[v]);
        printf("\n");
        {
            RewampPatternSongInfo si;
            const int grid = vt->pattern_song_info && vt->pattern_song_info(d, &si);
            printf("grille: %s", grid ? "oui" : "non");
            if (grid) printf(" (%d colonnes, %d ordres, %d motifs)", si.num_channels, si.num_orders, si.num_patterns);
            printf("\n");
        }
        {
            ZxTuneWrapper* w = rewamp_zxtune_wrapper_of(d);
            if (w) {
                const int models = w->pattern_model_count();
                printf("modèles %d:", models);
                for (int m = 0; m < models; m++)
                    printf(" m%d(délégué %d, largeur %d, colonne %d)", m,
                           w->pattern_model_delegate(m), w->pattern_model_width(m),
                           w->pattern_model_offset(m));
                printf("\n");
            }
        }
        const size_t frames = (size_t)(secs * fmt.sampleRate);
        std::vector<float> buf(1024 * 2);
        std::vector<long> nz(nv, 0); std::vector<int> peak(nv, 0);
        std::vector<std::set<unsigned> > notes(nv);
        std::vector<double> sxy(nv, 0), sxx(nv, 0);
        double syy = 0; long total = 0;
        const int ringMask = SOUND_BUFFER_SIZE_SAMPLE * 4 * 2 - 1;
        for (size_t done = 0; done < frames;) {
            const uint64_t got = vt->read(d, buf.data(), 1024);
            if (!got) break;
            for (uint64_t k = 0; k < got; k++) {
                const double mix = buf[k * 2] + buf[k * 2 + 1];
                syy += mix * mix;
                for (int v = 0; v < nv; v++) {
                    if (!m_voice_buff[v]) continue;
                    const int64_t pos = (m_voice_current_ptr[v] >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT) - (int64_t)got + (int64_t)k;
                    const int x = m_voice_buff[v][pos & ringMask];
                    if (x) nz[v]++;
                    if (abs(x) > peak[v]) peak[v] = abs(x);
                    sxy[v] += x * mix; sxx[v] += (double)x * x;
                }
            }
            for (int v = 0; v < nv; v++) if (vgm_last_note[v]) notes[v].insert(vgm_last_note[v]);
            total += (long)got; done += got;
        }
        for (int v = 0; v < nv; v++)
            printf("voix %2d: non nul %5.1f %%, crête %3d, hauteurs %3zu, corr. mix %+.2f\n", v,
                   total ? 100.0 * nz[v] / total : 0.0, peak[v], notes[v].size(),
                   (sxx[v] > 0 && syy > 0) ? sxy[v] / sqrt(sxx[v] * syy) : 0.0);
        vt->close(d);
    }
    return 0;
}

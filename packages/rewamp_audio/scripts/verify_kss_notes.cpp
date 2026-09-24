// Harnais: joue un fichier libkss (KSS/MGS/OPX/BGM/MPK/MUS) hors de l'app et
// imprime, toutes les 250 ms, la note (Hz) que chaque voie publie dans
// vgm_last_note — la source du viz-notes — ainsi que le panneau ⓘ (titre).
// Voir verify_kss_notes.sh.
#include <cstdio>
#include <cstring>
#include <cmath>
#include <vector>
extern "C" {
#include "ModizerVoicesData.h"
#include "rewamp_channel_data.h"
#include "rewamp_plugin.h"
const RewampPluginVTable* rewamp_kss_plugin(void);
long long rewamp_waveform_pos(void) { return 0; }
int rewamp_waveform_read_i8(int, signed char*, int) { return 0; }
int rewamp_ext_in_list(const char*, const char* const*) { return 0; }
}
int main(int argc, char** argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s <file> [seconds]\n", argv[0]); return 2; }
    const double secs = argc > 2 ? atof(argv[2]) : 20.0;
    rewamp_channel_data_init();
    RewampAudioFormat fmt; memset(&fmt, 0, sizeof fmt);
    const RewampPluginVTable* vt = rewamp_kss_plugin();
    RewampDecoder* dec = vt->open(argv[1], &fmt);
    if (!dec) { fprintf(stderr, "open failed\n"); return 1; }
    printf("[info]\n%s\n", rewamp_track_message());
    const int voices = rewamp_channel_count();
    printf("rate=%u ch=%u voices=%d\n", fmt.sampleRate, fmt.channels, voices);
    std::vector<float> buf(1024 * fmt.channels);
    std::vector<int> everNoted(voices, 0);
    uint64_t done = 0, next = 0; const uint64_t step = fmt.sampleRate / 4;
    while (done < (uint64_t)(secs * fmt.sampleRate)) {
        uint64_t n = vt->read(dec, buf.data(), 1024);
        if (n == 0) break;
        done += n;
        if (done >= next) {
            next += step;
            printf("t=%6.2f", done / (double)fmt.sampleRate);
            for (int v = 0; v < voices; v++) {
                float hz = rewamp_channel_freq_hz(v);
                if (hz > 0) { everNoted[v]++; printf(" v%d=%.0f", v, hz); }
            }
            printf("\n");
        }
    }
    int active = 0; for (int v = 0; v < voices; v++) if (everNoted[v]) active++;
    printf("voices with notes: %d / %d\n", active, voices);
    vt->close(dec);
    return active > 0 ? 0 : 3;
}

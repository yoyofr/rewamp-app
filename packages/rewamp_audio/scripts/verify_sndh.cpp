// Harnais: joue un .sndh par le greffon AtariAudio hors de l'app. Une ligne
// par fichier (ou par sous-chanson avec -a): nombre de sous-chansons, durée
// annoncée, RMS des N premières secondes, et pour chaque voix (PSG A/B/C,
// DAC) la part d'échantillons d'oscilloscope non nuls et le nombre de
// colonnes portant une note — de quoi comparer deux versions de la
// bibliothèque fichier par fichier. -x 2 : vitesse native ×2 (durée réelle
// rendue = durée / 2). -m N : voix N coupée (mute), sa trace doit être plate.
// Un .ym passe par le greffon YM de la même bibliothèque (atariaudio_ym) et
// imprime en plus son panneau ⓘ.
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <strings.h>
#include <vector>
extern "C" {
#include "ModizerVoicesData.h"
#include "rewamp_channel_data.h"
#include "rewamp_plugin.h"
const RewampPluginVTable* rewamp_sndh_plugin(void);
const RewampPluginVTable* rewamp_atariaudio_ym_plugin(void);
const char* rewamp_track_message(void);
void rewamp_track_message_clear(void);
int rewamp_sndh_probe_subsong_count(const char* path);
int rewamp_sndh_probe_get_duration_ms(int idx);
const char* rewamp_sndh_probe_get_title(int idx);
volatile int g_seek_cancel = 0;
volatile int g_is_seeking = 0;
volatile double g_seek_progress_s = 0;
void rewamp_decoder_activity(void) {}
long long rewamp_waveform_pos(void) { return 0; }
int rewamp_waveform_read_i8(int, signed char*, int) { return 0; }
void rewamp_waveform_write(const float*, unsigned long long, int) {}
const char* rewamp_get_data_dir(void) { return ""; }
double rewamp_get_engine_param(const char*, const char*, double d) { return d; }
}

static bool is_ym(const char* file) {
    const char* dot = strrchr(file, '.');
    return dot && strcasecmp(dot, ".ym") == 0;
}

static void run(const char* file, int sub, double secs, double speed, int mute, bool all) {
    const RewampPluginVTable* vt = is_ym(file) ? rewamp_atariaudio_ym_plugin() : rewamp_sndh_plugin();
    char path[4200];
    if (sub > 0) snprintf(path, sizeof(path), "%s?subsong=%d", file, sub);
    else snprintf(path, sizeof(path), "%s", file);
    RewampAudioFormat fmt = {0};
    rewamp_track_message_clear();
    RewampDecoder* d = vt->open(path, &fmt);
    /* APRÈS open: rewamp_channel_data_reset remet le masque à zéro. */
    generic_mute_mask = mute >= 0 ? (1LL << mute) : 0;
    const char* base = strrchr(file, '/'); base = base ? base + 1 : file;
    if (!d) { printf("ÉCHEC open  %s\n", base); return; }
    if (is_ym(file)) {
        uint8_t hdr[64] = {0};
        if (FILE* f = fopen(file, "rb")) { fread(hdr, 1, sizeof(hdr), f); fclose(f); }
        const char* dot = strrchr(file, '.');
        printf("probe=%d\n%s", vt->probe(dot + 1, hdr, sizeof(hdr)), rewamp_track_message());
    }
    if (speed != 1.0 && vt->set_speed) vt->set_speed(d, speed);
    const double len = (double)vt->length(d) / fmt.sampleRate;
    const int ringMask = SOUND_BUFFER_SIZE_SAMPLE * 4 * 2 - 1;
    std::vector<float> buf(1024);
    long nz[4] = {0}, notes[4] = {0}, frames = 0; double sum = 0;
    const long target = (long)(secs * fmt.sampleRate);
    while (frames < target) {
        uint64_t got = vt->read(d, buf.data(), 1024);
        if (got == 0) break;
        for (uint64_t i = 0; i < got; i++) sum += buf[i] * buf[i];
        for (int v = 0; v < 4; v++) {
            if (vgm_last_note[v]) notes[v]++;
            if (!m_voice_buff[v]) continue;
            const int64_t pos = m_voice_current_ptr[v] >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT;
            for (uint64_t k = 0; k < got; k++)
                if (m_voice_buff[v][(pos - (int64_t)got + (int64_t)k) & ringMask]) nz[v]++;
        }
        frames += (long)got;
    }
    printf("%-46.46s s%-3d len=%7.2fs rendu=%6.2fs rms=%.4f scope%%=%3ld/%3ld/%3ld/%3ld notes=%ld/%ld/%ld/%ld%s\n",
           base, sub, len, frames / (double)fmt.sampleRate,
           frames ? sqrt(sum / frames) : 0.0,
           frames ? nz[0] * 100 / frames : 0, frames ? nz[1] * 100 / frames : 0,
           frames ? nz[2] * 100 / frames : 0, frames ? nz[3] * 100 / frames : 0,
           notes[0], notes[1], notes[2], notes[3], all ? "" : "");
    vt->close(d);
}

int main(int argc, char** argv) {
    double secs = 10, speed = 1.0; int mute = -1; bool all = false;
    rewamp_channel_data_init();
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-s") && i + 1 < argc) { secs = atof(argv[++i]); continue; }
        if (!strcmp(argv[i], "-x") && i + 1 < argc) { speed = atof(argv[++i]); continue; }
        if (!strcmp(argv[i], "-m") && i + 1 < argc) { mute = atoi(argv[++i]); continue; }
        if (!strcmp(argv[i], "-a")) { all = true; continue; }
        if (is_ym(argv[i])) { run(argv[i], 0, secs, speed, mute, all); continue; }
        const int n = rewamp_sndh_probe_subsong_count(argv[i]);
        const char* base = strrchr(argv[i], '/'); base = base ? base + 1 : argv[i];
        printf("# %s: %d sous-chanson(s);", base, n);
        for (int s = 0; s < n && s < 8; s++)
            printf(" [%d %dms \"%s\"]", s + 1, rewamp_sndh_probe_get_duration_ms(s),
                   rewamp_sndh_probe_get_title(s));
        printf("\n");
        if (all) for (int s = 1; s <= n; s++) run(argv[i], s, secs, speed, mute, all);
        else run(argv[i], 0, secs, speed, mute, all);
    }
    return 0;
}

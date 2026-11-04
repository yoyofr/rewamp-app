// Harnais: joue un fichier par le greffon libADLMIDI (OPL3) hors de l'app.
// Imprime le score de sonde, le texte ⓘ, le RMS par seconde, les voix qui
// portent une note (vgm_last_note — la source des viz piano/notation) et,
// avec -L, vérifie la boucle infinie ARMÉE EN VOL (configure_loop(2) après
// une seconde, puis 2 × la durée sans fin de piste). -w <out.wav> pour écouter.
// Oscilloscope par voix: crête et remplissage de chaque anneau, et la
// CORRÉLATION entre la somme des voix et le mixage (L+R) — une capture
// décalée, ou attribuée au mauvais canal, la fait tomber.
// Paramètres moteur par l'environnement: ADL_BANK, ADL_EMU, ADL_CHIPS,
// ADL_GAIN. Voir verify_adlmidi.sh.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <vector>
extern "C" {
#include "ModizerVoicesData.h"
#include "rewamp_channel_data.h"
#include "rewamp_plugin.h"
const RewampPluginVTable* rewamp_adlmidi_plugin(void);
int rewamp_adlmidi_probe_subsong_count(const char* path);
int g_force_loop_mode = 0;
int g_force_loop_native_veto = 0;
static long g_activity = 0;
void rewamp_decoder_activity(void) { g_activity++; }
long long rewamp_waveform_pos(void) { return 0; }
int rewamp_waveform_read_i8(int, signed char*, int) { return 0; }
void rewamp_waveform_write(const float*, unsigned long long, int) {}
int rewamp_ext_in_list(const char* ext, const char* const* list) {
    for (; list && *list; list++) if (ext && strcasecmp(ext, *list) == 0) return 1;
    return 0;
}
const char* rewamp_get_data_dir(void) { return ""; }
/* TROIS arguments, comme la vraie (un stub qui ment fausse la mesure). */
double rewamp_get_engine_param(const char*, const char* key, double defval) {
    const char* e = nullptr;
    if (!strcmp(key, "bank")) e = getenv("ADL_BANK");
    else if (!strcmp(key, "emulator")) e = getenv("ADL_EMU");
    else if (!strcmp(key, "chips")) e = getenv("ADL_CHIPS");
    else if (!strcmp(key, "gain")) e = getenv("ADL_GAIN");
    return e ? atof(e) : defval;
}
const char* rewamp_track_message(void);
}

static void wav_write(const char* path, const std::vector<float>& pcm, unsigned rate) {
    FILE* f = fopen(path, "wb");
    if (!f) return;
    unsigned n = (unsigned)pcm.size(), dataBytes = n * 2, riff = 36 + dataBytes, br = rate * 4;
    unsigned char h[44] = {'R','I','F','F',0,0,0,0,'W','A','V','E','f','m','t',' ',16,0,0,0,1,0,2,0,0,0,0,0,0,0,0,0,4,0,16,0,'d','a','t','a',0,0,0,0};
    for (int i = 0; i < 4; i++) { h[4+i] = (riff >> (8*i)) & 255; h[24+i] = (rate >> (8*i)) & 255; h[28+i] = (br >> (8*i)) & 255; h[40+i] = (dataBytes >> (8*i)) & 255; }
    fwrite(h, 1, 44, f);
    for (unsigned i = 0; i < n; i++) { float v = pcm[i]; v = v > 1 ? 1 : v < -1 ? -1 : v; short s = (short)(v * 32767); fwrite(&s, 2, 1, f); }
    fclose(f);
}

int main(int argc, char** argv) {
    const char* wav = nullptr; const char* file = nullptr; double secs = 20; int loopTest = 0;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-w") && i + 1 < argc) wav = argv[++i];
        else if (!strcmp(argv[i], "-s") && i + 1 < argc) secs = atof(argv[++i]);
        else if (!strcmp(argv[i], "-L")) loopTest = 1;
        else file = argv[i];
    }
    if (!file) { fprintf(stderr, "usage: %s [-s secondes] [-L] [-w out.wav] <fichier>\n", argv[0]); return 2; }
    rewamp_channel_data_init();
    const RewampPluginVTable* vt = rewamp_adlmidi_plugin();
    uint8_t hdr[64] = {0}; size_t hn = 0;
    if (FILE* f = fopen(file, "rb")) { hn = fread(hdr, 1, sizeof(hdr), f); fclose(f); }
    const char* dot = strrchr(file, '.');
    printf("probe=%d subsongs=%d\n", vt->probe(dot ? dot + 1 : "", hdr, hn),
           rewamp_adlmidi_probe_subsong_count(file));
    RewampAudioFormat fmt = {0};
    RewampDecoder* d = vt->open(file, &fmt);
    if (!d) { fprintf(stderr, "open a échoué\n"); return 3; }
    const double total = (double)vt->length(d) / fmt.sampleRate;
    printf("rate=%u ch=%u length=%.2fs voices=%d\n---\n%s---\n", fmt.sampleRate, fmt.channels,
           total, rewamp_channel_count_raw(), rewamp_track_message());
    const unsigned rate = fmt.sampleRate;
    std::vector<float> pcm, buf(1024 * 2);
    int voiceHit[64] = {0};
    int scopePeak[64] = {0}; long scopeNz[64] = {0}, scopeN = 0;
    double sxy = 0, sxx = 0, syy = 0;
    const int ringMask = SOUND_BUFFER_SIZE_SAMPLE * 4 * 2 - 1;
    double target = loopTest ? 2 * total + 5 : secs, done = 0;
    long frames = 0;
    for (int sec = 0; done < target; sec++) {
        double sum = 0; long n = 0;
        while (n < (long)rate) {
            if (loopTest && frames >= (long)rate && g_force_loop_mode == 0) {
                g_force_loop_mode = 2; vt->configure_loop(d, 2, 0);
                printf("[boucle infinie armée à %.2fs]\n", frames / (double)rate);
            }
            uint64_t got = vt->read(d, buf.data(), 1024);
            if (got == 0) break;
            for (uint64_t i = 0; i < got * 2; i++) sum += buf[i] * buf[i];
            if (wav) pcm.insert(pcm.end(), buf.begin(), buf.begin() + got * 2);
            n += (long)got; frames += (long)got;
            {
                const int nv = rewamp_channel_count_raw();
                for (uint64_t k = 0; k < got; k++) {
                    double sumv = 0;
                    for (int v = 0; v < nv && v < 64; v++) {
                        if (!m_voice_buff[v]) continue;
                        const int64_t pos = (m_voice_current_ptr[v] >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT) - (int64_t)got + (int64_t)k;
                        const int x = m_voice_buff[v][pos & ringMask];
                        if (x) scopeNz[v]++;
                        if (abs(x) > scopePeak[v]) scopePeak[v] = abs(x);
                        sumv += x;
                    }
                    const double mix = buf[k * 2] + buf[k * 2 + 1];
                    sxy += sumv * mix; sxx += sumv * sumv; syy += mix * mix;
                }
                scopeN += (long)got;
            }
            for (int v = 0; v < 64 && v < rewamp_channel_count_raw(); v++) if (vgm_last_note[v]) voiceHit[v]++;
        }
        if (n == 0) { printf("fin de piste à %.2fs\n", frames / (double)rate); break; }
        if (!loopTest || sec % 10 == 0) printf("%3ds rms=%.4f\n", sec, sqrt(sum / (n * 2.0)));
        done += n / (double)rate;
    }
    printf("rendu %.2fs\nvoix avec notes:", frames / (double)rate);
    for (int v = 0; v < rewamp_channel_count_raw(); v++) if (voiceHit[v]) printf(" %d", v);
    printf("\n");
    for (int v = 0; v < rewamp_channel_count_raw() && v < 64; v++)
        printf("scope voix %2d: crête %3d, non nul %5.1f %%\n", v, scopePeak[v],
               scopeN ? 100.0 * scopeNz[v] / scopeN : 0.0);
    printf("corrélation somme des voix / mixage: %.3f\n",
           sxx > 0 && syy > 0 ? sxy / sqrt(sxx * syy) : 0.0);
    vt->close(d);
    if (wav) wav_write(wav, pcm, rate);
    return 0;
}

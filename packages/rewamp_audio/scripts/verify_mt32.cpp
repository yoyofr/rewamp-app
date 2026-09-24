// Harnais: joue un fichier MIDI par le greffon MT-32 (mt32emu) hors de l'app.
// Imprime le jeu de ROM retenu, le RMS par tranche, les parties qui portent une
// note (vgm_last_note, la source du viz-notes/piano), le texte LCD (les scores
// LucasArts y écrivent le titre du jeu par sysex — la preuve que les sysex
// passent), et l'oscilloscope par partie (énergie de l'anneau: une partie qui
// sonne sans anneau = capture cassée). Option -w <out.wav> pour écouter.
// Voir verify_mt32.sh.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <vector>
extern "C" {
#include "ModizerVoicesData.h"
#include "rewamp_channel_data.h"
#include "rewamp_plugin.h"
const RewampPluginVTable* rewamp_mt32_plugin(void);
void rewamp_mt32_set_rom_dir(const char* path);
const char* rewamp_mt32_rom_status(void);
const char* rewamp_mt32_lcd(void);
long long rewamp_waveform_pos(void) { return 0; }
int rewamp_waveform_read_i8(int, signed char*, int) { return 0; }
void rewamp_waveform_write(const float*, unsigned long long, int) {}
int rewamp_ext_in_list(const char* ext, const char* const* list) {
    for (; list && *list; list++) if (ext && strcmp(ext, *list) == 0) return 1;
    return 0;
}
const char* rewamp_get_data_dir(void) { return ""; }
/* ⚠️ TROIS arguments, comme la vraie: un stub à deux rendait 0 et faussait
 * une mesure (fondu PSF). `model` vient de l'environnement
 * pour tester MT-32 / CM-32L: MT32_MODEL=1|2. */
double rewamp_get_engine_param(const char* engine, const char* key, double defval) {
    (void)engine;
    if (strcmp(key, "model") == 0) { const char* e = getenv("MT32_MODEL"); return e ? atof(e) : defval; }
    return defval;
}
}

static void wav_write(const char* path, const std::vector<float>& pcm, unsigned rate) {
    FILE* f = fopen(path, "wb");
    if (!f) return;
    unsigned n = (unsigned)pcm.size();
    unsigned dataBytes = n * 2;
    unsigned char h[44] = {'R','I','F','F',0,0,0,0,'W','A','V','E','f','m','t',' ',16,0,0,0,1,0,2,0,0,0,0,0,0,0,0,0,4,0,16,0,'d','a','t','a',0,0,0,0};
    unsigned riff = 36 + dataBytes;
    h[4]=riff&255; h[5]=(riff>>8)&255; h[6]=(riff>>16)&255; h[7]=(riff>>24)&255;
    h[24]=rate&255; h[25]=(rate>>8)&255; h[26]=(rate>>16)&255; h[27]=(rate>>24)&255;
    unsigned br = rate*4; h[28]=br&255; h[29]=(br>>8)&255; h[30]=(br>>16)&255; h[31]=(br>>24)&255;
    h[40]=dataBytes&255; h[41]=(dataBytes>>8)&255; h[42]=(dataBytes>>16)&255; h[43]=(dataBytes>>24)&255;
    fwrite(h, 1, 44, f);
    for (unsigned i = 0; i < n; i++) {
        float v = pcm[i]; if (v > 1) v = 1; if (v < -1) v = -1;
        short s = (short)(v * 32767); fwrite(&s, 2, 1, f);
    }
    fclose(f);
}

int main(int argc, char** argv) {
    const char* wav = NULL; double secs = 20.0; const char* romdir = NULL; const char* file = NULL;
    int quiet = 0; double seekAt = -1, seekTo = -1;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-w") && i + 1 < argc) wav = argv[++i];
        else if (!strcmp(argv[i], "-r") && i + 1 < argc) romdir = argv[++i];
        else if (!strcmp(argv[i], "-s") && i + 1 < argc) secs = atof(argv[++i]);
        else if (!strcmp(argv[i], "-k") && i + 2 < argc) { seekAt = atof(argv[++i]); seekTo = atof(argv[++i]); }
        else if (!strcmp(argv[i], "-q")) quiet = 1;
        else file = argv[i];
    }
    if (!file || !romdir) { fprintf(stderr, "usage: %s -r <romdir> [-s secondes] [-k <après s> <vers s>] [-w out.wav] [-q] <fichier.mid>\n", argv[0]); return 2; }
    rewamp_mt32_set_rom_dir(romdir);
    rewamp_channel_data_init();
    const char* st = rewamp_mt32_rom_status();
    if (!st[0]) { fprintf(stderr, "aucun jeu de ROM utilisable dans %s\n", romdir); return 3; }
    if (!quiet) printf("ROM: %s\n", st);

    const RewampPluginVTable* vt = rewamp_mt32_plugin();
    {
        /* Score de sonde RÉEL (probe_path, fichier entier): 104 = sysex MT-32
         * détecté, 100 = MIDI ordinaire. C'est lui qui décide du mode auto. */
        FILE* pf = fopen(file, "rb");
        unsigned char hdr[2048]; size_t hn = 0; long fsz = 0;
        if (pf) { hn = fread(hdr, 1, sizeof hdr, pf); fseek(pf, 0, SEEK_END); fsz = ftell(pf); fclose(pf); }
        const char* dot = strrchr(file, '.'); char ext[16] = "";
        if (dot) { size_t k = 0; for (const char* c = dot + 1; *c && k < sizeof ext - 1; c++) ext[k++] = (char)((*c >= 'A' && *c <= 'Z') ? *c + 32 : *c); ext[k] = 0; }
        int score = vt->probe_path ? vt->probe_path(ext, hdr, hn, file, (uint64_t)fsz) : vt->probe(ext, hdr, hn);
        printf("sonde: %d%s\n", score, score >= 104 ? " (sysex MT-32 détecté)" : "");
    }
    RewampAudioFormat fmt{};
    RewampDecoder* dec = vt->open(file, &fmt);
    if (!dec) { fprintf(stderr, "open a échoué: %s\n", file); return 4; }
    if (!quiet) printf("format: %u Hz, %u voies | durée %llu s | %s", fmt.sampleRate, fmt.channels,
                       (unsigned long long)(vt->length(dec) / fmt.sampleRate), rewamp_track_message());

    const unsigned block = 1024;
    std::vector<float> buf(block * 2), all;
    unsigned long long total = 0, target = (unsigned long long)(secs * fmt.sampleRate);
    double sumsq = 0; unsigned long long nz = 0; float peak = 0;
    int partsWithNotes = 0; unsigned partSeen = 0;
    double ringEnergy[16] = {0};
    unsigned long long nextReport = 0;
    int seekDone = 0;
    while (total < target) {
        if (!seekDone && seekAt >= 0 && total >= (unsigned long long)(seekAt * fmt.sampleRate)) {
            vt->seek(dec, (uint64_t)(seekTo * fmt.sampleRate));
            if (!quiet) printf("seek %.1f s → %.1f s\n", seekAt, seekTo);
            seekDone = 1;
        }
        uint64_t got = vt->read(dec, buf.data(), block);
        if (got == 0) break;
        for (uint64_t i = 0; i < got * 2; i++) { sumsq += (double)buf[i] * buf[i]; if (fabsf(buf[i]) > 1e-4f) nz++; if (fabsf(buf[i]) > peak) peak = fabsf(buf[i]); }
        if (wav) all.insert(all.end(), buf.begin(), buf.begin() + got * 2);
        total += got;
        for (int p = 0; p < 9; p++) if (vgm_last_note[p]) partSeen |= 1u << p;
        for (int p = 0; p < 9; p++) if (m_voice_buff[p]) {
            long long ptr = m_voice_current_ptr[p] >> MODIZER_OSCILLO_OFFSET_FIXEDPOINT;
            for (int k = 0; k < 256; k++) { int v = m_voice_buff[p][(ptr - 1 - k) & (SOUND_BUFFER_SIZE_SAMPLE*4*2 - 1)]; ringEnergy[p] += (double)v * v; }
        }
        if (!quiet && total >= nextReport) {
            printf("t=%6.2f  notes:", (double)total / fmt.sampleRate);
            for (int p = 0; p < 9; p++) if (vgm_last_note[p]) printf(" P%d=%u", p + 1, vgm_last_note[p]);
            printf("\n");
            nextReport += fmt.sampleRate * 2;
        }
    }
    for (int p = 0; p < 9; p++) if (partSeen & (1u << p)) partsWithNotes++;
    double rms = total ? sqrt(sumsq / (double)(total * 2)) : 0;
    const char* lcd = rewamp_mt32_lcd();
    printf("%s%s: %.1f s, RMS %.4f (%.1f dBFS), crête %.2f, non-nul %.0f%%, parties avec notes %d/9, LCD « %s »\n",
           quiet ? "" : "\n", strrchr(file, '/') ? strrchr(file, '/') + 1 : file, (double)total / fmt.sampleRate,
           rms, rms > 0 ? 20 * log10(rms) : -999.0, peak, total ? 100.0 * nz / (double)(total * 2) : 0.0,
           partsWithNotes, lcd);
    if (!quiet) {
        printf("voix (noms de patch):");
        for (int p = 0; p < 9; p++) printf(" P%d=%s", p + 1, modizVoicesName[p]);   /* rempli par rewamp_voice_set_name */
        printf("\n");
        printf("oscilloscope par partie (énergie anneau):");
        for (int p = 0; p < 9; p++) printf(" P%d=%.0f", p + 1, ringEnergy[p]);
        printf("\n");
    }
    if (wav) { wav_write(wav, all, fmt.sampleRate); if (!quiet) printf("WAV: %s\n", wav); }
    vt->close(dec);
    return 0;
}

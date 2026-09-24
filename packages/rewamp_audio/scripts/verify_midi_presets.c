/* Oracle: joue un .mid par le VRAI greffon FluidLite (son TU inclus tel quel)
 * et imprime, à 5/12/25/40/60 s, le preset que FluidLite a réellement sur
 * chaque canal 2-10. Né du bug du canal 10 remis sur un PIANO par
 * fluid_synth_system_reset: la batterie d un
 * fichier sans program change sur le 10 doit sortir sur un kit (bank 128).
 * Voir verify_midi_presets.sh. */
#include "rewamp_plugin_midi.c"
long long rewamp_waveform_pos(void) { return 0; }
int rewamp_waveform_read_i8(int a, signed char* b, int c) { (void)a;(void)b;(void)c; return 0; }
void rewamp_waveform_write(const float* a, unsigned long long b, int c) { (void)a;(void)b;(void)c; }
int rewamp_ext_in_list(const char* ext, const char* const* list) { for (; list && *list; list++) if (ext && !strcmp(ext,*list)) return 1; return 0; }
const char* rewamp_get_data_dir(void) { return ""; }
double rewamp_get_engine_param(const char* e, const char* k, double def) { (void)e;(void)k; return def; }
int main(int argc, char** argv) {
    rewamp_channel_data_init();
    rewamp_midi_set_soundfont(argv[2]);
    RewampAudioFormat fmt; MidiDec* d = (MidiDec*)midi_open(argv[1], &fmt);
    if (!d) { printf("open KO\n"); return 1; }
    float buf[2048];
    double marks[] = { 5, 12, 25, 40, 60 }; int mi = 0; uint64_t done = 0;
    while (mi < 5) {
        uint64_t got = midi_read((RewampDecoder*)d, buf, 1024); if (!got) break; done += got;
        if (done >= (uint64_t)(marks[mi] * fmt.sampleRate)) {
            printf("t=%4.0f s:", marks[mi]);
            for (int ch = 1; ch <= 9; ch++) {
                fluid_preset_t* pr = fluid_synth_get_channel_preset(d->synth, ch);
                printf("  c%d=%s", ch + 1, (pr && pr->get_name) ? pr->get_name(pr) : "-");
            }
            printf("\n"); mi++;
        }
    }
    midi_close((RewampDecoder*)d); return 0;
}

// Oracle: une voix ISOLÉE (toutes les autres coupées) donne la sortie réelle
// de cette voix. Si elle est silencieuse depuis assez longtemps pour que
// l'anneau du scope se soit entièrement renouvelé, alors ni note ni forme
// d'onde ne doivent subsister.
#include <cstdio>
#include <cstring>
#include "gme/Spc_Emu.h"
extern "C" {
#include "ModizerVoicesData.h"
#include "rewamp_channel_data.h"
}
long long rewamp_waveform_pos(void) { return 0; }
int rewamp_waveform_read_i8(int, signed char*, int) { return 0; }

#define BUFLEN  (SOUND_BUFFER_SIZE_SAMPLE*4*4)
#define FRAMES  2048          /* ~46 ms */
#define SETTLE  6             /* blocs de silence avant de juger (> anneau) */
#define BLOCKS  600           /* ~28 s */
#define QUIET   8             /* -72 dBFS: inaudible */

int main(int argc, char** argv) {
    int ghostNote = 0, ghostScope = 0, judged = 0;
    for (int v = 0; v < 8; v++) {
        Spc_Emu emu;
        if (emu.set_sample_rate(44100)) { printf("rate fail\n"); return 1; }
        rewamp_channel_data_init();
        rewamp_channel_data_reset(8);
        if (emu.load_file(argv[1])) { printf("load fail\n"); return 1; }
        if (emu.start_track(0))     { printf("track fail\n"); return 1; }
        emu.enable_accuracy(true);  // comme l'app (gme_enable_accuracy(emu,1))
        emu.ignore_silence(true);   // comme l'app (gme silence_detection = 0)
        emu.enable_accuracy(true);  // comme l'app (gme_enable_accuracy(emu,1))
        emu.ignore_silence(true);   // comme l'app (gme silence_detection = 0)
        emu.enable_accuracy(true);  // comme l'app (gme_enable_accuracy(emu,1))
        emu.ignore_silence(true);   // comme l'app (gme silence_detection = 0)
        emu.mute_voices(~(1 << v) & 0xFF);        // seule la voix v sonne
        short buf[FRAMES * 2];
        int silentRun = 0, gN = 0, gS = 0, j = 0;
        for (int b = 0; b < BLOCKS; b++) {
            emu.play(FRAMES * 2, buf);
            int silent = 1;
            for (int i = 0; i < FRAMES * 2; i++) { int a = buf[i] < 0 ? -buf[i] : buf[i];
                                                   if (a > QUIET) { silent = 0; break; } }
            silentRun = silent ? silentRun + 1 : 0;
            if (silentRun < SETTLE) continue;      // pas encore concluant
            j++;
            if (vgm_last_note[v]) gN++;
            for (int i = 0; i < BUFLEN; i++)
                if (m_voice_buff[v][i]) { gS++; break; }
        }
        printf("voix %d: %3d blocs juges silencieux | note fantome %3d | scope fantome %3d\n",
               v, j, gN, gS);
        ghostNote += gN; ghostScope += gS; judged += j;
    }
    printf("=> TOTAL %d blocs silencieux juges | %d notes fantomes | %d scopes fantomes\n",
           judged, ghostNote, ghostScope);
    return (ghostNote || ghostScope) ? 1 : 0;
}

// Vérifie la grille de motifs PT3 (rewamp_plugin_libpt3.cpp) — voir le .sh.
//
// Oracle: la grille statique doit dire la même chose que le joueur.
//  (1) structure — nb de lignes par position observé en lecture == patRows[]
//  (2) notes     — quand la grille pose une note, le joueur joue la même
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
extern "C" {
#include "rewamp_plugin.h"
#include "rewamp_channel_data.h"
#include "ModizerVoicesData.h"
#include "pt3player.h"
const RewampPluginVTable* rewamp_libpt3_plugin(void);
}

int main(int argc, char** argv) {
    if (argc < 2) return 2;
    rewamp_channel_data_init();
    const RewampPluginVTable* vt = rewamp_libpt3_plugin();
    RewampAudioFormat fmt;
    memset(&fmt, 0, sizeof(fmt));
    RewampDecoder* d = vt->open(argv[1], &fmt);
    if (!d) { printf("%-46s OUVERTURE ECHOUEE\n", argv[1]); return 1; }

    RewampPatternSongInfo si;
    if (!vt->pattern_song_info || !vt->pattern_song_info(d, &si)) {
        printf("%-46s pas de grille\n", argv[1]);
        vt->close(d); return 0;
    }
    const int chans = si.num_channels;

    // grille statique
    std::vector<std::vector<RewampPatternCell>> grid(si.num_patterns);
    std::vector<int> gridRows(si.num_patterns);
    for (int p = 0; p < si.num_patterns; p++) {
        int rows = vt->pattern_num_rows(d, p);
        gridRows[p] = rows;
        grid[p].resize((size_t)rows * chans);
        vt->pattern_get(d, p, grid[p].data(), rows * chans);
    }

    // lecture
    std::vector<int> maxRow(si.num_patterns, -1);
    long noteChecks = 0, noteBad = 0, structBad = 0, offGrid = 0;
    std::vector<float> buf(512 * 2);
    int lastPos = -1, lastRow = -2;
    long frames = 0;
    const long cap = (long)fmt.sampleRate * 400;
    while (frames < cap) {
        uint64_t got = vt->read(d, buf.data(), 256);
        if (!got) break;
        frames += (long)got;
        int pos = -1, row = -1;
        func_get_cursor(0, &pos, &row);
        if (pos == lastPos && row == lastRow) continue;
        lastPos = pos; lastRow = row;
        if (pos < 0 || pos >= si.num_patterns || row < 0) continue;
        if (row > maxRow[pos]) maxRow[pos] = row;
        if (row >= gridRows[pos]) { offGrid++; continue; }
        for (int c = 0; c < 3; c++) {
            const RewampPatternCell& cell = grid[pos][(size_t)row * chans + c];
            if (cell.note < 0) continue;
            // Le portamento (commande 2) remet Note à la note PRECEDENTE: la
            // grille dit la cible, le joueur garde l'origine. Exclu.
            bool porta = false;
            for (int f = 0; f < cell.num_fx; f++) if (cell.fx[f][0] == '2') porta = true;
            if (porta) continue;
            int note = -1, vol = 0, en = 0;
            func_get_channel(0, c, &note, &vol, &en);
            noteChecks++;
            if (note + 12 != cell.note) noteBad++;
        }
    }
    // La position où la lecture s'est ARRETEE n'a pas été jouée en entier: son
    // compte de lignes ne dit rien du décodeur.
    if (lastPos >= 0 && lastPos < si.num_patterns) maxRow[lastPos] = -1;
    for (int p = 0; p < si.num_patterns; p++)
        if (maxRow[p] >= 0 && maxRow[p] + 1 != gridRows[p]) {
            structBad++;
            if (getenv("PT3_DIAG"))
                printf("  position %d: grille %d lignes, joue %d\n",
                       p, gridRows[p], maxRow[p] + 1);
        }

    printf("%-46s pos=%3d voies=%d  structure: %ld position(s) en desaccord  "
           "hors-grille=%ld  notes: %ld/%ld fausses\n",
           argv[1], si.num_patterns, chans, structBad, offGrid, noteBad, noteChecks);
    vt->close(d);
    return (structBad || noteBad || offGrid) ? 1 : 0;
}

// Harness: dump the per-frame TIA register trace our .ttt pipeline produces,
// in the same format gold_parse.py prints for the tracker's own exported data.
#include <stdio.h>
#include <stdlib.h>

#include <string>
#include <vector>

#include "ttt_player.h"
#include "ttt_song.h"

int main(int argc, char** argv) {
  if (argc < 2) {
    fprintf(stderr, "usage: ttt_trace <file.ttt> [frames] [--info]\n");
    return 2;
  }
  FILE* f = fopen(argv[1], "rb");
  if (!f) { perror(argv[1]); return 1; }
  fseek(f, 0, SEEK_END);
  long n = ftell(f);
  fseek(f, 0, SEEK_SET);
  std::vector<char> buf((size_t)n);
  if (fread(&buf[0], 1, (size_t)n, f) != (size_t)n) { fclose(f); return 1; }
  fclose(f);

  if (!ttt_probe(&buf[0], buf.size())) fprintf(stderr, "warning: probe says no\n");

  TttTables t;
  std::string err;
  if (!ttt_parse(&buf[0], buf.size(), t, &err)) {
    fprintf(stderr, "parse failed: %s\n", err.c_str());
    return 1;
  }

  const int frames = argc > 2 ? atoi(argv[2]) : 200;
  if (argc > 3 && std::string(argv[3]) == "--info") {
    printf("name=%s author=%s tv=%s speed=%d/%d global=%d funk=%d slide=%d overlay=%d\n",
           t.name.c_str(), t.author.c_str(), t.pal ? "pal" : "ntsc",
           t.speedEven, t.speedOdd, (int)t.globalSpeed, (int)t.useFunkTempo,
           (int)t.useSlide, (int)t.useOverlay);
    printf("insCtrl(%d):", (int)t.insCtrl.size());
    for (size_t i = 0; i < t.insCtrl.size(); ++i) printf(" %02x", t.insCtrl[i]);
    printf("\ninsAD:");
    for (size_t i = 0; i < t.insAD.size(); ++i) printf(" %02x", t.insAD[i]);
    printf("\ninsSustain:");
    for (size_t i = 0; i < t.insSustain.size(); ++i) printf(" %02x", t.insSustain[i]);
    printf("\ninsRelease:");
    for (size_t i = 0; i < t.insRelease.size(); ++i) printf(" %02x", t.insRelease[i]);
    printf("\ninsFreqVol(%d):", (int)t.insFreqVol.size());
    for (size_t i = 0; i < t.insFreqVol.size() && i < 64; ++i) printf(" %02x", t.insFreqVol[i]);
    printf("\nseq(%d) starts %d/%d:", (int)t.sequence.size(), t.seqStart[0], t.seqStart[1]);
    for (size_t i = 0; i < t.sequence.size(); ++i) printf(" %02x", t.sequence[i]);
    int loopStart = 0;
    const int len = ttt_song_length_frames(t, 60 * 60 * 20, &loopStart);
    printf("\npatterns=%d length=%d frames (loop at %d) = %.1f s\n",
           (int)t.patterns.size(), len, loopStart, (double)len / t.frameRateHz());
    return 0;
  }

  TttPlayer p;
  p.reset(&t);
  for (int i = 0; i < frames; ++i) {
    p.frame();
    printf("%d %2d %2d %2d %2d %2d %2d\n", i, p.audc[0], p.audf[0], p.audv[0],
           p.audc[1], p.audf[1], p.audv[1]);
  }
  return 0;
}

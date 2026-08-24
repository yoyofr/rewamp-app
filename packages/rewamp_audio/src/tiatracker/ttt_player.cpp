#include "ttt_player.h"

#include <set>

namespace {

inline uint8_t at(const std::vector<uint8_t>& v, int i) {
  return (i >= 0 && i < (int)v.size()) ? v[i] : 0;
}

}  // namespace

void TttPlayer::reset(const TttTables* tables) {
  t = tables;
  timer = 0;  // tt_init.asm leaves it at 0, so frame one runs the sequencer
  for (int c = 0; c < 2; ++c) {
    curPatIndex[c]  = t ? t->seqStart[c] : 0;
    curNoteIndex[c] = 0;
    curIns[c]       = 0;
    envIndex[c]     = 0;
    audc[c] = audf[c] = audv[c] = 0;
    rowNote[c]      = 0;
  }
  newRow = false;
}

// TT_FETCH_CURRENT_NOTE: returns the note byte, walking past goto entries and
// pattern ends. `prefetched` reports the flag an overlay percussion left in
// bit 7 of the note index — the note it fetched early must stay in sustain
// instead of restarting from attack.
int TttPlayer::fetchNote(int ch, bool* prefetched) {
  if (prefetched) *prefetched = false;
  if (!t || t->sequence.empty() || t->patterns.empty()) return 0;

  // A malformed file can chain gotos into a cycle that never reaches a note;
  // the VCS routine would simply hang there.
  for (int guard = 0; guard < 4096; ++guard) {
    if (curPatIndex[ch] < 0 || curPatIndex[ch] >= (int)t->sequence.size())
      curPatIndex[ch] = t->seqStart[ch];
    int p = t->sequence[curPatIndex[ch]];
    if (p >= 128) {
      curPatIndex[ch] = p & 0x7f;
      continue;
    }
    if (p >= (int)t->patterns.size()) p = 0;

    int ni = curNoteIndex[ch];
    if (t->useOverlay && (ni & 0x80)) {
      ni &= 0x7f;
      curNoteIndex[ch] = ni;
      if (prefetched) *prefetched = true;
    }
    const std::vector<uint8_t>& pat = t->patterns[p];
    const int note = (ni >= 0 && ni < (int)pat.size()) ? pat[ni] : 0;
    if (note != kTttNoteEndOfPattern) return note;

    curNoteIndex[ch] = 0;
    ++curPatIndex[ch];
  }
  return 0;
}

void TttPlayer::frame() {
  newRow = false;
  if (!t) return;

  // ==================== Sequencer ====================
  if (--timer < 0) {
    newRow = true;
    for (int ch = 1; ch >= 0; --ch) {
      bool prefetched = false;
      const int note = fetchNote(ch, &prefetched);
      rowNote[ch] = (uint8_t)note;

      if (note < kTttNotePause) {
        // Slide or hold: f = f + (note - 8), on the whole note byte. An
        // overflow out of the frequency bits into the instrument bits is the
        // composer's problem — the VCS routine does exactly this.
        if (t->useSlide) curIns[ch] = (curIns[ch] + note - 8) & 0xff;
      } else if (note == kTttNotePause) {
        // Into release. A pause can only follow a melodic instrument, so the
        // routine does not check for percussion here.
        const int slot = curIns[ch] >> 5;
        if (slot > 0) envIndex[ch] = at(t->insRelease, slot - 1) + 1;
      } else {
        curIns[ch] = note;
        if (note < 32) {
          envIndex[ch] = at(t->percIndex, note - kTttNoteFirstPerc);
        } else if (!prefetched) {
          envIndex[ch] = at(t->insAD, (note >> 5) - 1);
        }
      }
      curNoteIndex[ch] = (curNoteIndex[ch] + 1) & 0xff;
    }

    // Speed timer. Both the global and the per-pattern form read the parity of
    // channel 0's note index AFTER it was advanced, so an "even" row is one
    // whose index is now even.
    const bool odd = (curNoteIndex[0] & 1) != 0;
    if (t->globalSpeed) {
      const int spd = (t->useFunkTempo && odd) ? t->speedOdd : t->speedEven;
      timer = spd - 1;
    } else {
      int pat = 0;
      if (curPatIndex[0] >= 0 && curPatIndex[0] < (int)t->sequence.size()) {
        pat = t->sequence[curPatIndex[0]];
        if (pat >= (int)t->patterns.size()) pat = 0;
      }
      const int spd = odd ? at(t->patternSpeedOdd, pat) : at(t->patternSpeedEven, pat);
      timer = spd - 1;
    }
    if (timer < 0) timer = 0;
  }

  // ==================== Update registers ====================
  for (int ch = 1; ch >= 0; --ch) {
    const int ins = curIns[ch];
    if (ins == 0) continue;  // nothing has played on this channel yet

    if (ins < 32) {
      // --- percussion: a new waveform, frequency and volume every frame ---
      const int y = envIndex[ch];
      const uint8_t ctrlVol = at(t->percCtrlVol, y - 1);
      if (ctrlVol != 0) ++envIndex[ch];  // 0 = end of data: hold the last read
      audv[ch] = ctrlVol & 0x0f;
      audc[ch] = (ctrlVol >> 4) & 0x0f;
      const uint8_t freq = at(t->percFreq, y - 1);
      audf[ch] = freq & kTttFreqMask;   // bit 7 is the overlay marker, not pitch

      if (t->useOverlay && (freq & 0x80)) {
        // Overlay percussion: pull the next note in NOW, out of tempo, and
        // start a melodic instrument straight in sustain so it sounds as if it
        // had been playing under the percussion all along.
        const int note = fetchNote(ch, NULL);
        if (note >= 32) {
          curIns[ch] = note;
          envIndex[ch] = at(t->insSustain, (note >> 5) - 1);
          curNoteIndex[ch] |= 0x80;
        }
      }
    } else {
      // --- melodic instrument ---
      const int slot = ins >> 5;
      audc[ch] = at(t->insCtrl, slot - 1) & 0x0f;

      int y = envIndex[ch];
      if (y == (int)at(t->insRelease, slot - 1))
        y = at(t->insSustain, slot - 1);  // end of sustain: loop back

      const uint8_t e = (y >= 0 && y < (int)t->insFreqVol.size()) ? t->insFreqVol[y] : 0;
      if (e != 0) ++y;                    // 0 = end of release: stay put, silent
      envIndex[ch] = y;
      audv[ch] = e & 0x0f;
      // The frequency modifier is added to the WHOLE note byte and the TIA only
      // wires up the low 5 bits, which is what makes an over/underflow wrap
      // around the frequency range instead of changing instrument.
      audf[ch] = (uint8_t)(((e >> 4) + ins - 8) & 0xff) & kTttFreqMask;
    }
  }
}

int ttt_song_length_frames(const TttTables& t, int maxFrames, int* loopStartFrame) {
  if (loopStartFrame) *loopStartFrame = 0;
  TttPlayer p;
  p.reset(&t);

  std::set<uint64_t> seen;
  std::vector<std::pair<uint64_t, int> > order;  // key -> frame it was first seen
  for (int f = 0; f < maxFrames; ++f) {
    p.frame();
    if (!p.newRow) continue;
    // Position of both channels in the song. Envelope state is deliberately
    // left out: it is a function of the position for everything but a note
    // still ringing across the loop point, which is inaudible as a length.
    const uint64_t key = ((uint64_t)(uint32_t)p.curPatIndex[0] << 40) |
                         ((uint64_t)(uint32_t)p.curNoteIndex[0] << 24) |
                         ((uint64_t)(uint32_t)p.curPatIndex[1] << 8) |
                         (uint64_t)(uint32_t)(p.curNoteIndex[1] & 0xff);
    if (!seen.insert(key).second) {
      for (size_t i = 0; i < order.size(); ++i) {
        if (order[i].first == key) {
          if (loopStartFrame) *loopStartFrame = order[i].second;
          break;
        }
      }
      return f;
    }
    order.push_back(std::make_pair(key, f));
  }
  return 0;
}

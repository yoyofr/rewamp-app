// TIATracker replayer — one TV frame per call, writing the six TIA audio
// registers. Transcribed from TIATracker's own 6502 routine
// (player/dasm/tt_player.asm, Apache-2.0, Copyright 2016 Andre "Kylearan"
// Wichmann), so the frame-by-frame behaviour is the VCS one rather than an
// interpretation: the sequencer runs BEFORE the register update inside the
// same frame, channel 1 is processed before channel 0, and the envelope index
// advances only while the envelope has not hit its terminator.
#pragma once

#include "ttt_song.h"

struct TttPlayer {
  const TttTables* t;

  int timer;             // frames left on the current row, counts through -1
  int curPatIndex[2];    // index into TttTables::sequence
  int curNoteIndex[2];   // index into the current pattern, bit 7 = prefetched
  int curIns[2];         // the raw note byte currently playing
  int envIndex[2];

  uint8_t audc[2], audf[2], audv[2];
  bool newRow;           // this frame consumed a new pattern row
  // The note byte each channel consumed on that row, for the pattern view.
  // Only meaningful while newRow is set. An overlay percussion fetches the
  // NEXT row early, during the register update — that row is still reported
  // here on the tick that formally consumes it, so no row is counted twice.
  uint8_t rowNote[2];

  void reset(const TttTables* tables);
  void frame();

 private:
  int fetchNote(int ch, bool* prefetched);
};

// Frames until the song repeats, found by replaying it and watching for a
// sequence position both channels have already been at simultaneously. Returns
// 0 when nothing repeats within `maxFrames` (songs without a goto never loop —
// the manual is explicit that the VCS routine's behaviour is undefined past
// the end, so the caller decides what to do). `loopStartFrame` receives the
// frame the repeat begins at.
int ttt_song_length_frames(const TttTables& t, int maxFrames, int* loopStartFrame);

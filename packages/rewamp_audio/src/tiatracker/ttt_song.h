// TIATracker (.ttt) song data — the JSON the PC tracker saves, converted into
// the flat byte tables the Atari VCS replay routine consumes.
//
// Why go through the VCS tables instead of playing the JSON directly: the
// replayer (ttt_player.cpp) is a transcription of TIATracker's own 6502
// routine, which is specified in terms of these tables — implicit index
// modifiers, a junk byte between sustain and release, a $00 terminator, the
// overlay flag riding bit 7 of a frequency byte. Keeping that layout means the
// player has no interpretation of its own to get wrong, and it makes the
// conversion checkable against the tracker's own exporter.
//
// Licensing: the tracker application is GPLv2, but its PLAYER ROUTINE and data
// structures are published under Apache-2.0 (header of player/dasm/*.asm at
// bitbucket.org/kylearan/tiatracker). This file and ttt_player.cpp derive from
// that Apache-2.0 material only; attribution is carried in Settings → À propos.
#pragma once

#include <stdint.h>

#include <string>
#include <vector>

// A note byte, as stored in a pattern (tt_trackdata.asm):
//   bits 7..5 = 1..7  -> play melodic instrument, bits 4..0 = frequency
//   bits 7..5 = 0     -> 0 end of pattern, 1..15 slide (-7..+7, 8 = hold),
//                        16 pause, 17..31 percussion 1..15
enum {
  kTttNoteEndOfPattern = 0,
  kTttNoteHold         = 8,
  kTttNotePause        = 16,
  kTttNoteFirstPerc    = 17,
  kTttFreqMask         = 0x1f,
};

// Flat replay tables. Index modifiers are baked in exactly as the VCS routine
// expects them — do not "fix" them here, the player relies on them.
struct TttTables {
  // Melodic instruments, one entry per slot (slots are 1-based in note bytes,
  // so slot n lives at index n-1 here).
  std::vector<uint8_t> insCtrl;      // AUDC
  std::vector<uint8_t> insAD;        // envelope start index
  std::vector<uint8_t> insSustain;   // sustain start index
  std::vector<uint8_t> insRelease;   // release start index MINUS ONE (the junk byte)
  std::vector<uint8_t> insFreqVol;   // bits 7..4 freq modifier + 8, bits 3..0 volume

  // Percussion, 1..15 addressed as note bytes 17..31.
  std::vector<uint8_t> percIndex;    // first frame index PLUS ONE
  std::vector<uint8_t> percFreq;     // AUDF, bit 7 = overlay marker
  std::vector<uint8_t> percCtrlVol;  // bits 7..4 AUDC, bits 3..0 AUDV, $00 = end

  std::vector<std::vector<uint8_t> > patterns;  // each terminated by a 0 byte
  std::vector<uint8_t> sequence;                // channel 0 then channel 1
  int seqStart[2];                              // absolute index into `sequence`

  int  speedEven;      // frames per even row
  int  speedOdd;       // frames per odd row
  bool useFunkTempo;   // speedEven != speedOdd
  // `globalspeed` false = each pattern carries its own pair and the pattern
  // playing on CHANNEL 0 sets the tempo of the whole song. The key is optional
  // and absent means true: every song in the reference corpus that lacks it
  // exported TT_GLOBAL_SPEED = 1, and Tetris-A proves the per-pattern values
  // survive in the file as stale leftovers even when they are not in use
  // (patterns say 3 and 8, the song plays at 7).
  bool globalSpeed;
  std::vector<uint8_t> patternSpeedEven;  // per pattern index, when !globalSpeed
  std::vector<uint8_t> patternSpeedOdd;
  bool useSlide;
  bool useOverlay;
  bool pal;            // 50 Hz, else NTSC 60 Hz

  std::string name;
  std::string author;
  std::string comment;

  int frameRateHz() const { return pal ? 50 : 60; }
};

// Cheap format sniff: valid JSON object carrying the keys only a .ttt has.
bool ttt_probe(const void* data, size_t size);

// Parse + convert. Returns false and fills `err` (when non-null) on malformed
// input; `out` is left unspecified in that case.
bool ttt_parse(const void* data, size_t size, TttTables& out, std::string* err);

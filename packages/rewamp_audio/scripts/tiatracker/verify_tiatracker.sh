#!/usr/bin/env bash
# Fidelity check for the TIATracker (.ttt) plugin.
#
# There is no reference DECODER to compare against — TIATracker is a Qt
# application and its PC-side player is GPLv2, which we deliberately do not
# link. What there IS, is the tracker's own EXPORTER: chunkypixel/TIATracker
# publishes six songs as .ttt together with the <song>_trackdata.asm /
# _variables.asm / _init.asm the tracker itself generated from them. That
# export is ground truth for everything risky in this plugin — the note-type
# encoding, the envelope layout, the combined-waveform split, goto targets.
#
# Two comparisons run here:
#   1. ttt_convert.py  — our JSON reading vs the exported tables, compared
#      SEMANTICALLY (the exporter renumbers instruments, so table indexes
#      legitimately differ; what each pattern row plays must not).
#   2. gold_parse.py vs ttt_trace — the exported tables and our tables, both
#      run through the same replayer semantics, diffed frame by frame on the
#      six TIA registers. This is the one that must be bit-identical.
#
# Usage: scripts/tiatracker/verify_tiatracker.sh [frames]   (default 20000)
set -euo pipefail

FRAMES="${1:-20000}"
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/../../src/tiatracker"
WORK="${TMPDIR:-/tmp}/rewamp-tiatracker-verify"
BASE="https://raw.githubusercontent.com/chunkypixel/TIATracker/master/examples"
SONGS=("Beside:Beside/Beside" "Miniblast:Miniblast/miniblast" \
       "Speedtest:Speedtest/Speedtest" "Salami:Salami/Salami" \
       "Tetris-A:Tetris-A/Tetris-A" "heckno2:Heckno2/heckno2")

mkdir -p "$WORK/gold"
cd "$WORK"
for entry in "${SONGS[@]}"; do
  name="${entry%%:*}"; path="${entry##*:}"
  [ -f "gold/$name.ttt" ] || curl -sfL -o "gold/$name.ttt" "$BASE/$name.ttt"
  for kind in trackdata variables init; do
    [ -f "gold/${name}_${kind}.asm" ] || \
      curl -sfL -o "gold/${name}_${kind}.asm" "$BASE/${path}_${kind}.asm"
  done
done

cp "$HERE/gold_parse.py" "$HERE/ttt_convert.py" .
clang++ -std=c++17 -O1 -fsanitize=address,undefined -I"$SRC" \
  "$HERE/ttt_trace.cpp" "$SRC/ttt_song.cpp" "$SRC/ttt_player.cpp" -o ttt_trace

echo "== 1. JSON reading vs the tracker's own export"
python3 ttt_convert.py | grep 'low_first=True'

echo
echo "== 2. register traces, $FRAMES frames per song"
fail=0
for entry in "${SONGS[@]}"; do
  name="${entry%%:*}"
  python3 gold_parse.py "$name" "$FRAMES" > "gold_$name.txt"
  ./ttt_trace "gold/$name.ttt" "$FRAMES" > "ours_$name.txt"
  if diff -q "gold_$name.txt" "ours_$name.txt" > /dev/null; then
    printf '   %-10s identical\n' "$name"
  else
    printf '   %-10s DIVERGES: %s frames\n' "$name" \
      "$(diff "gold_$name.txt" "ours_$name.txt" | grep -c '^<')"
    fail=1
  fi
done
exit $fail

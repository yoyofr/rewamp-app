#!/bin/bash
# Oracle du déclic de début de piste (src/rewamp_declick.c), hors app.
#
#   scripts/verify_declick.sh <fichier audio> [secondes=8]
#       décode le début avec ffmpeg, passe dans le déclic, liste les réparations.
#   scripts/verify_declick.sh --scan <dossier> [secondes=6]
#       tous les rips CD du dossier (mp3/ape/ogg/opus/flac/wav…): une ligne par
#       fichier RÉPARÉ, puis le bilan — c'est la mesure des faux positifs.
#
# Exige ffmpeg/ffprobe dans le PATH. Compile avec ASan.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${TMPDIR:-/tmp}/rewamp_declick_harness"
cc -O1 -g -fsanitize=address,undefined -std=c11 -Wall -Wextra \
   "$HERE/../src/rewamp_declick.c" "$HERE/declick_harness.c" -lm -o "$OUT"

probe() { ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate,channels -of csv=p=0 "$1" 2>/dev/null | head -1; }

run_one() {  # file secs → prints harness output
  local f="$1" secs="$2" tmp="${TMPDIR:-/tmp}/rewamp_declick_in.f32"
  local info; info="$(probe "$f")" || return 1
  [ -n "$info" ] || return 1
  local rate="${info%%,*}" ch="${info##*,}"   # ffprobe imprime dans l'ordre du flux: rate,channels
  [ "$ch" -ge 1 ] 2>/dev/null || return 1
  ffmpeg -v error -y -i "$f" -t "$secs" -f f32le "$tmp" 2>/dev/null || return 1
  "$OUT" "$tmp" "$ch" "$rate" "${3:-}"
}

if [ "${1:-}" = "--scan" ]; then
  dir="$2"; secs="${3:-6}"
  total=0; hit=0
  while IFS= read -r -d '' f; do
    total=$((total+1))
    res="$(run_one "$f" "$secs" 2>/dev/null || true)"
    reps="$(printf '%s\n' "$res" | sed -n 's/.*summary repairs=\([0-9]*\).*/\1/p')"
    if [ -n "$reps" ] && [ "$reps" -gt 0 ]; then
      hit=$((hit+1))
      echo "== $f"
      printf '%s\n' "$res" | grep '^repair' | head -8
    fi
  done < <(find "$dir" -type f \( -iname '*.mp3' -o -iname '*.mp2' -o -iname '*.ape' -o -iname '*.ogg' -o -iname '*.oga' -o -iname '*.opus' -o -iname '*.flac' -o -iname '*.wav' -o -iname '*.wv' -o -iname '*.m4a' -o -iname '*.tta' -o -iname '*.tak' \) -print0)
  echo "scan: $hit fichiers réparés sur $total"
else
  run_one "$1" "${2:-8}" "${3:-}"
fi

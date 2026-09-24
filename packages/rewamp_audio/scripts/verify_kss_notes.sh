#!/usr/bin/env bash
# Oracle hors ligne de la capture de notes libkss (viz-notes): compile les
# coeurs vendorés + le greffon, joue un fichier et imprime les notes par voie.
#   scripts/verify_kss_notes.sh <fichier.opx|.kss|.mgs> [secondes]
set -euo pipefail
pkg="$(cd "$(dirname "$0")/.." && pwd)"
kss="$pkg/third_party/libkss"
out="${TMPDIR:-/tmp}/verify_kss_notes"
mkdir -p "$out"
inc=(-I"$kss/src" -I"$kss/src/kss" -I"$kss/src/vm" -I"$kss/src/filters" -I"$kss/src/rconv" -I"$kss/modules" -I"$pkg/third_party/mus2kss" -I"$pkg/src")
srcs=("$kss"/src/*.c "$kss"/src/filters/*.c "$kss"/src/kss/*.c "$kss"/src/rconv/*.c "$kss"/src/vm/*.c
      "$kss"/modules/emu2149/kss_emu2149.c "$kss"/modules/emu2212/kss_emu2212.c
      "$kss"/modules/emu2413/kss_emu2413.c "$kss"/modules/emu8950/emu8950.c "$kss"/modules/emu8950/emuadpcm.c
      "$kss"/modules/emu76489/emu76489.c "$kss"/modules/kmz80/kmdmg.c "$kss"/modules/kmz80/kmevent.c
      "$kss"/modules/kmz80/kmr800.c "$kss"/modules/kmz80/kmz80.c "$kss"/modules/kmz80/kmz80c.c "$kss"/modules/kmz80/kmz80t.c
      "$pkg/third_party/mus2kss/mus2kss.c" "$pkg/src/rewamp_channel_data.c" "$pkg/src/rewamp_loaded_files.c")
objs=()
for s in "${srcs[@]}"; do
  o="$out/$(basename "$s").o"
  [ "$o" -nt "$s" ] || cc -std=gnu11 -O1 -w -DREWAMP_WITH_KSS=1 -DMUS2KSS_LIBRARY=1 "${inc[@]}" -c "$s" -o "$o"
  objs+=("$o")
done
c++ -std=c++17 -O1 -w -DREWAMP_WITH_KSS=1 "${inc[@]}" "$pkg/src/rewamp_plugin_kss.cpp" "$pkg/scripts/verify_kss_notes.cpp" "${objs[@]}" -liconv -o "$out/verify_kss_notes"
"$out/verify_kss_notes" "$@"

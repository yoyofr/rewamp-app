#!/usr/bin/env bash
# Oracle hors ligne du greffon FluidLite: preset réellement actif par canal.
#   scripts/verify_midi_presets.sh <fichier.mid> <soundfont.sf2>
# Le canal 10 doit porter un KIT (Standard, Room, Orchestra…), jamais un piano.
set -euo pipefail
pkg="$(cd "$(dirname "$0")/.." && pwd)"
fl="$pkg/third_party/fluidlite"
out="${TMPDIR:-/tmp}/verify_midi_presets"
mkdir -p "$out"
objs=()
for n in fluid_init fluid_chan fluid_chorus fluid_conv fluid_defsfont fluid_dsp_float fluid_gen \
         fluid_hash fluid_list fluid_mod fluid_ramsfont fluid_rev fluid_settings fluid_synth \
         fluid_sys fluid_tuning fluid_voice; do
  o="$out/$n.o"
  [ "$o" -nt "$fl/src/$n.c" ] || cc -std=gnu11 -O1 -w -DFLUIDLITE_STATIC -DREWAMP_VOICE_CAPTURE=1 \
    -I"$fl/include" -I"$fl/src" -I"$pkg/src" -c "$fl/src/$n.c" -o "$o"
  objs+=("$o")
done
for s in "$pkg/src/rewamp_tml.c" "$pkg/src/rewamp_channel_data.c" "$pkg/src/rewamp_loaded_files.c"; do
  o="$out/$(basename "$s").o"
  [ "$o" -nt "$s" ] || cc -std=gnu11 -O1 -w -I"$pkg/src" -I"$pkg/third_party/tml" -c "$s" -o "$o"
  objs+=("$o")
done
cc -std=gnu11 -O1 -w -DREWAMP_WITH_MIDI=1 -DFLUIDLITE_STATIC -I"$pkg/src" -I"$pkg/third_party/tml" \
  -I"$fl/include" -I"$fl/src" "$pkg/scripts/verify_midi_presets.c" "${objs[@]}" -liconv -lm -o "$out/verify_midi_presets"
"$out/verify_midi_presets" "$@"

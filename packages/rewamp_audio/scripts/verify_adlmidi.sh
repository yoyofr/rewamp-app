#!/usr/bin/env bash
# Oracle hors ligne du greffon libADLMIDI: compile la bibliothèque vendorée
# AVEC son en-tête de renommage injecté (comme cmake et les podspecs), tml, le
# greffon, et joue un fichier (MIDI, XMI, MUS DMX, HMI/HMP, GMF).
#   scripts/verify_adlmidi.sh [-s secondes] [-L] [-w out.wav] <fichier>
#   -L : boucle infinie armée EN VOL, doit tenir 2 × la durée.
#   ADL_BANK=n ADL_EMU=n ADL_CHIPS=n ADL_GAIN=x : paramètres moteur.
#   ASAN=1 : build AddressSanitizer séparé.
set -euo pipefail
pkg="$(cd "$(dirname "$0")/.." && pwd)"
adl="$pkg/third_party/libadlmidi"
san=(); out="${TMPDIR:-/tmp}/verify_adlmidi"
if [ "${ASAN:-0}" = "1" ]; then san=(-fsanitize=address -g -O1); out="$out-asan"; fi
mkdir -p "$out"
defs=(-DADLMIDI_DISABLE_JAVA_EMULATOR -DADLMIDI_DISABLE_MAME_OPL2_EMULATOR -DENABLE_END_SILENCE_SKIPPING)
inc=(-I"$adl/include" -I"$adl/src")
fi_=(-include "$adl/rewamp/adlmidi_rename.h")
# Même liste que cmake/rewamp.cmake (rewamp_add_adlmidi) et les podspecs.
srcs=$(sed -n '/^  set(_adl_srcs/,/^    src\/chips\/ymfm\/ymfm_ssg.cpp)/p' "$pkg/cmake/rewamp.cmake" | grep -oE 'src/[A-Za-z0-9_/]+\.(c|cpp)')
# Un en-tête modifié (rename, scope, opl_chip_base.h…) change la forme des
# classes: tout objet plus ancien que l'en-tête le plus récent est REBÂTI,
# sinon le lien mélange deux formes (ASan: débordement dans un constructeur).
newest_h=$(find "$adl/src" "$adl/include" "$adl/rewamp" \( -name '*.h' -o -name '*.hpp' -o -name '*.tcc' \) -print0 | xargs -0 ls -t | head -1)
objs=()
for s in $srcs; do
  o="$out/$(echo "$s" | tr '/' '_').o"
  if [ ! "$o" -nt "$adl/$s" ] || [ ! "$o" -nt "$newest_h" ]; then
    case "$s" in
      *.c)   cc  ${san[@]+"${san[@]}"} -std=gnu99 -O2 -w "${defs[@]}" "${inc[@]}" "${fi_[@]}" -c "$adl/$s" -o "$o" ;;
      *.cpp) c++ ${san[@]+"${san[@]}"} -std=c++14 -O2 -w "${defs[@]}" "${inc[@]}" "${fi_[@]}" -c "$adl/$s" -o "$o" ;;
    esac
  fi
  objs+=("$o")
done
for s in "$pkg/src/rewamp_tml.c" "$pkg/src/rewamp_channel_data.c" "$pkg/src/rewamp_loaded_files.c" "$pkg/src/rewamp_tags.c"; do
  o="$out/$(basename "$s").o"
  [ "$o" -nt "$s" ] || cc ${san[@]+"${san[@]}"} -std=gnu11 -O2 -w -I"$pkg/src" -I"$pkg/third_party/tml" -c "$s" -o "$o"
  objs+=("$o")
done
c++ ${san[@]+"${san[@]}"} -std=c++14 -O2 -w -DREWAMP_WITH_ADLMIDI=1 -I"$adl/include" -I"$pkg/src" -I"$pkg/third_party/tml" \
  "$pkg/src/rewamp_plugin_adlmidi.cpp" "$pkg/scripts/verify_adlmidi.cpp" "${objs[@]}" -liconv -o "$out/verify_adlmidi"
"$out/verify_adlmidi" "$@"

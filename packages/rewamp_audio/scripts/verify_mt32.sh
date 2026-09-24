#!/usr/bin/env bash
# Oracle hors ligne du greffon MT-32 (mt32emu): compile le cœur vendoré + tml +
# le greffon, joue un fichier MIDI et imprime ROM retenue, RMS, notes par
# partie, texte LCD (les sysex LucasArts y écrivent le titre du jeu) et
# l'énergie de l'oscilloscope par partie.
#   scripts/verify_mt32.sh -r <dossier ROM> [-s secondes] [-w out.wav] [-q] <fichier.mid>
#   MT32_MODEL=1 (MT-32) | 2 (CM-32L) force le modèle (0 = auto: CM-32L si présent).
set -euo pipefail
pkg="$(cd "$(dirname "$0")/.." && pwd)"
emu="$pkg/third_party/mt32emu/mt32emu"
# ASAN=1 : build AddressSanitizer séparé (dossier distinct, objets recompilés)
san=(); out="${TMPDIR:-/tmp}/verify_mt32"
if [ "${ASAN:-0}" = "1" ]; then san=(-fsanitize=address -g -O1); out="$out-asan"; fi
mkdir -p "$out"
cxxflags=(${san[@]+"${san[@]}"} -std=c++11 -O2 -w -DMT32EMU_WITH_INTERNAL_RESAMPLER -DMT32EMU_WITH_STD_SNPRINTF -I"$pkg/third_party/mt32emu" -I"$pkg/src" -I"$pkg/third_party/tml")
srcs=("$emu"/*.cpp "$emu"/sha1/sha1.cpp "$emu"/srchelper/InternalResampler.cpp "$emu"/srchelper/srctools/src/*.cpp)
objs=()
for s in "${srcs[@]}"; do
  o="$out/$(basename "$s").o"
  [ "$o" -nt "$s" ] || c++ "${cxxflags[@]}" -c "$s" -o "$o"
  objs+=("$o")
done
for s in "$pkg/src/rewamp_tml.c" "$pkg/src/rewamp_channel_data.c" "$pkg/src/rewamp_loaded_files.c"; do
  o="$out/$(basename "$s").o"
  [ "$o" -nt "$s" ] || cc ${san[@]+"${san[@]}"} -std=gnu11 -O2 -w -I"$pkg/src" -I"$pkg/third_party/tml" -c "$s" -o "$o"
  objs+=("$o")
done
c++ ${san[@]+"${san[@]}"} -std=c++11 -O2 -w -DREWAMP_WITH_MT32=1 -I"$pkg/third_party/mt32emu" -I"$pkg/src" -I"$pkg/third_party/tml" \
  "$pkg/src/rewamp_plugin_mt32.cpp" "$pkg/scripts/verify_mt32.cpp" "${objs[@]}" -liconv -o "$out/verify_mt32"
"$out/verify_mt32" "$@"

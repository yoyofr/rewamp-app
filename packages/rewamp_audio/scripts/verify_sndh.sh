#!/usr/bin/env bash
# Oracle hors ligne du greffon SNDH (AtariAudio): compile la bibliothèque
# vendorée (même liste que cmake/rewamp.cmake rewamp_add_sndh) + le greffon et
# joue des fichiers.
#   scripts/verify_sndh.sh [-s secondes] [-x vitesse] [-m voix] [-a] <f.sndh>…
#   -a : chaque sous-chanson.   ASAN=1 : build AddressSanitizer séparé.
#   ATARIAUDIO_DIR=<dir> PLUGIN=<cpp> : comparer une AUTRE version (A/B).
set -euo pipefail
pkg="$(cd "$(dirname "$0")/.." && pwd)"
aa="${ATARIAUDIO_DIR:-$pkg/third_party/atariaudio}"
plugin="${PLUGIN:-$pkg/src/rewamp_plugin_sndh.cpp}"
san=(); out="${TMPDIR:-/tmp}/verify_sndh-$(echo "$aa" | shasum | cut -c1-8)"
if [ "${ASAN:-0}" = "1" ]; then san=(-fsanitize=address -g -O1); out="$out-asan"; fi
mkdir -p "$out"
srcs=$(sed -n '/^  add_library(rewamp_sndh STATIC/,/m68kops/p' "$pkg/cmake/rewamp.cmake" | grep -oE '[A-Za-z0-9_/]+\.(c|cpp)' | sed 's|^/||')
[ -n "${SRCS:-}" ] && srcs="$SRCS"
newest_h=$(find "$aa" \( -name '*.h' -o -name '*.inc*' \) -print0 | xargs -0 ls -t | head -1)
objs=()
for s in $srcs; do
  f="$aa/$s"; o="$out/$(echo "$s" | tr '/' '_').o"
  if [ ! "$o" -nt "$f" ] || [ ! "$o" -nt "$newest_h" ]; then
    case "$s" in
      *.c)   cc  ${san[@]+"${san[@]}"} -O2 -w -I"$aa" -I"$pkg/src" -c "$f" -o "$o" ;;
      *.cpp) c++ ${san[@]+"${san[@]}"} -std=c++17 -O2 -w -I"$aa" -I"$pkg/src" -c "$f" -o "$o" ;;
    esac
  fi
  objs+=("$o")
done
for s in "$pkg/src/rewamp_channel_data.c" "$pkg/src/rewamp_loaded_files.c" "$pkg/src/rewamp_tags.c"; do
  o="$out/$(basename "$s").o"
  [ "$o" -nt "$s" ] || cc ${san[@]+"${san[@]}"} -std=gnu11 -O2 -w -I"$pkg/src" -c "$s" -o "$o"
  objs+=("$o")
done
c++ ${san[@]+"${san[@]}"} -std=c++17 -O2 -w -DREWAMP_WITH_SNDH=1 -I"$aa" -I"$pkg/src" \
  "$plugin" "$pkg/scripts/verify_sndh.cpp" "${objs[@]}" -liconv -o "$out/verify_sndh"
"$out/verify_sndh" "$@"

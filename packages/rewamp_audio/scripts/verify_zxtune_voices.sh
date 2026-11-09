#!/usr/bin/env bash
# Oracle des voix et de la grille d'un module zxtune (voir
# verify_zxtune_voices.cpp): par voix, ce que l'oscilloscope reçoit et les
# hauteurs publiées; par module, la grille annoncée et ses modèles.
#
#   ./verify_zxtune_voices.sh [-s secondes] module [autre ...]
#
# Attendu sur un .mtc à trois PT3: NEUF voix actives, chacune corrélée au
# mixage, trois modèles de largeur 3 aux colonnes 0, 3 et 6. Avant le
# 2026-10-31, seules les voix 0-2 bougeaient (les trois puces y écrivaient
# tour à tour) et les trois modèles se disputaient les colonnes.
#
# ⚠️ Recompile zxtune (jeu curaté de ~240 fichiers) à la première exécution,
# puis ne refait que ce qui a changé (objets sous $TMPDIR/verify_zxtune_obj).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
pkg=$(dirname "$here")
zx="$pkg/third_party/libzxtune"
out="${TMPDIR:-/tmp}/verify_zxtune_obj"
# ASAN=1: tout sous AddressSanitizer, dans un tiroir à part.
san=(); if [ "${ASAN:-0}" = "1" ]; then san=(-fsanitize=address -g); out="$out-asan"; fi
mkdir -p "$out"

[ $# -ge 1 ] || { echo "usage: $0 [-s secondes] module [...]" >&2; exit 2; }

srcs=$(grep -oE '\$\{ZXTUNE_ROOT\}/[^"]+\.(c|cc|cpp)' "$zx/zxtune_sources.cmake" |
       sed "s#^\${ZXTUNE_ROOT}#$zx#")
defs=(-DUSE_ZXTUNE=1 -DREWAMP_WITH_ZXTUNE=1 -DBOOST_ERROR_CODE_HEADER_ONLY -DMODIZER
      -DBOOST_NO_RTTI -DBOOST_SYSTEM_NO_DEPRECATED -DNO_DEBUG_LOGS -DNO_L10N
      -DWORDS_LITTLE_ENDIAN -DZ80EX_API_REVISION=1 -DZ80EX_VERSION_MAJOR=1
      -DZ80EX_VERSION_MINOR=19 -DZ80EX_RELEASE_TYPE=pre1 -DZ80EX_VERSION_STR=1.1.19pre1)
incs=(-I"$zx/include" -I"$zx/src" -I"$zx/3rdparty" -I"$zx" -I"$zx/3rdparty/z80ex/include"
      -I"$zx/emscripten" -I"$pkg/third_party/libchpconv" -I"$pkg/src")
# Un en-tête modifié invalide tout (les dépendances ne sont pas suivies).
# (`ls -t | head -1` meurt d'un SIGPIPE sous pipefail: on cherche le plus
# récent sans tube tronqué.)
newest_h=$(find "$zx/src" "$zx/include" "$zx/emscripten" "$pkg/src" -name '*.h' -exec stat -f '%m %N' {} + |
           sort -rn | awk 'NR==1{sub(/^[0-9]+ /, ""); print}')
objs=()
build() { # <source> <compilateur> <std>
  local s=$1 o="$out/$(echo "$1" | tr '/.' '__').o"
  if [ ! "$o" -nt "$s" ] || [ ! "$o" -nt "$newest_h" ]; then
    "$2" -std="$3" -O1 -w ${san[@]+"${san[@]}"} "${defs[@]}" "${incs[@]}" -c "$s" -o "$o"
  fi
  objs+=("$o")
}
echo "compilation de zxtune…" >&2
for c in "$pkg/src/rewamp_channel_data.c" "$pkg/third_party/libchpconv/chp2ym.c" \
         "$here/verify_zxtune_patterns_stubs.c"; do build "$c" cc gnu11; done
for c in $srcs; do
  case "$c" in
    *.c) build "$c" cc gnu11 ;;
    *)   build "$c" c++ c++14 ;;
  esac
done
for c in "$pkg/src/rewamp_plugin_zxtune.cpp" "$pkg/src/rewamp_zxtune_stubs.cpp"; do build "$c" c++ c++14; done
c++ -std=c++14 -O1 -w ${san[@]+"${san[@]}"} "${defs[@]}" "${incs[@]}" -o "$out/verify_zxtune_voices" \
    "$here/verify_zxtune_voices.cpp" "${objs[@]}" -lz -liconv
"$out/verify_zxtune_voices" "$@"

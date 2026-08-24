#!/usr/bin/env bash
# Vérifie la grille de motifs que zxtune expose (rewamp_plugin_zxtune.cpp) en la
# confrontant à celle de libpt3 sur des fichiers .pt3.
#
# L'ORACLE est un SECOND DÉCODEUR, écrit indépendamment: libpt3 lit les trois
# flux d'octets du .pt3 à la main (voir verify_pt3_patterns.sh, qui lui-même se
# vérifie contre son joueur), zxtune passe par son modèle générique rempli par
# ses dix-huit lecteurs. Deux chemins qui ne partagent pas une ligne de code
# doivent produire la MÊME grille: mêmes voies, mêmes ordres, mêmes lignes par
# motif, mêmes note/échantillon/ornement/volume dans chaque cellule.
#
#   ./verify_zxtune_patterns.sh fichier.pt3 [autre.pt3 ...]
#
# Une seule divergence est ATTENDUE et donc exclue: le PORTAMENTO. PT3 y écrit
# la note CIBLE dans le flux, que libpt3 met en colonne de note comme le fait le
# tracker, là où zxtune en fait le paramètre d'une commande. Les deux lectures
# sont fidèles; seule leur présentation diffère.
#
# Une SECONDE divergence est attendue sur les .pt3 TurboSound « mode nom » (un
# module joué sur deux puces, drapeau dans l'octet 98 du nom — WeBberTS.pt3 en
# est un): zxtune fusionne les deux puces en lignes de six canaux et leur fait
# PARTAGER le tempo (TSLine::GetTempo rend celui de la seconde), là où libpt3
# garde un tempo par puce — sa propagation « tsmode » est désactivée par un
# `if (false && ...)` dans pt3player.c. Mesuré au joueur: 6 frames par ligne sur
# une puce, 9 sur l'autre. Chaque grille est donc fidèle à SON moteur; c'est
# libpt3 qui joue les .pt3 dans l'app, donc c'est sa lecture qui compte.
#
# ⚠️ Ce script recompile zxtune (jeu curaté de ~240 fichiers): compter quelques
# minutes à la première exécution.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
pkg=$(dirname "$here")
zx="$pkg/third_party/libzxtune"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

[ $# -ge 1 ] || { echo "usage: $0 fichier.pt3 [...]" >&2; exit 2; }

# --- libpt3 ---------------------------------------------------------------
for c in "$pkg/src/rewamp_channel_data.c" \
         "$pkg/third_party/libpt3/pt3player.c" \
         "$pkg/third_party/libpt3/ayumi.c" \
         "$here/verify_pt3_patterns_stubs.c"; do
  cc -std=gnu11 -O1 -w -DREWAMP_WITH_LIBPT3=1 -I"$pkg/src" -I"$pkg/third_party/libpt3" \
     -c "$c" -o "$tmp/pt3_$(basename "$c").o"
done
c++ -std=c++14 -O1 -w -DREWAMP_WITH_LIBPT3=1 -I"$pkg/src" -I"$pkg/third_party/libpt3" \
    -o "$tmp/dump_pt3" "$here/verify_zxtune_patterns_dump.cpp" \
    "$pkg/src/rewamp_plugin_libpt3.cpp" "$tmp"/pt3_*.o -liconv

# --- zxtune ---------------------------------------------------------------
srcs=$(grep -oE '\$\{ZXTUNE_ROOT\}/[^"]+\.(c|cc|cpp)' "$zx/zxtune_sources.cmake" |
       sed "s#^\${ZXTUNE_ROOT}#$zx#")
defs=(-DUSE_ZXTUNE=1 -DREWAMP_WITH_ZXTUNE=1 -DBOOST_ERROR_CODE_HEADER_ONLY -DMODIZER
      -DBOOST_NO_RTTI -DBOOST_SYSTEM_NO_DEPRECATED -DNO_DEBUG_LOGS -DNO_L10N
      -DWORDS_LITTLE_ENDIAN -DZ80EX_API_REVISION=1 -DZ80EX_VERSION_MAJOR=1
      -DZ80EX_VERSION_MINOR=19 -DZ80EX_RELEASE_TYPE=pre1 -DZ80EX_VERSION_STR=1.1.19pre1)
incs=(-I"$zx/include" -I"$zx/src" -I"$zx/3rdparty" -I"$zx" -I"$zx/3rdparty/z80ex/include"
      -I"$zx/emscripten" -I"$pkg/third_party/libchpconv" -I"$pkg/src")
echo "compilation de zxtune…" >&2
# Les sources C doivent passer par le compilateur C (chp2ym.c et le jeu curaté
# en contiennent), d'où la passe séparée.
for c in "$pkg/src/rewamp_channel_data.c" "$pkg/third_party/libchpconv/chp2ym.c"; do
  cc -std=gnu11 -O1 -w "${defs[@]}" "${incs[@]}" -c "$c" -o "$tmp/zxc_$(basename "$c").o"
done
cobjs=()
for c in $srcs; do
  case "$c" in
    *.c) cc -std=gnu11 -O1 -w "${defs[@]}" "${incs[@]}" -c "$c" \
            -o "$tmp/zxs_$(echo "$c" | tr '/.' '__').o"
         cobjs+=("$tmp/zxs_$(echo "$c" | tr '/.' '__').o") ;;
  esac
done
cxxsrcs=$(printf '%s\n' $srcs | grep -E '\.(cc|cpp)$')
c++ -std=c++14 -O1 -w "${defs[@]}" "${incs[@]}" \
    -o "$tmp/dump_zx" "$here/verify_zxtune_patterns_dump.cpp" \
    "$pkg/src/rewamp_plugin_zxtune.cpp" "$pkg/src/rewamp_zxtune_stubs.cpp" \
    "$tmp"/zxc_*.o "${cobjs[@]}" $cxxsrcs -lz -liconv

python3 "$here/verify_zxtune_patterns_cmp.py" "$tmp/dump_zx" "$tmp/dump_pt3" "$@"

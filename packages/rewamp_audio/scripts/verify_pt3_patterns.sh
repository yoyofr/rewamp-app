#!/usr/bin/env bash
# Vérifie la grille de motifs PT3 exposée par le plugin libpt3.
#
# L'ORACLE est le JOUEUR lui-même. Un .pt3 range chaque motif en TROIS flux
# d'octets, un par canal, que pt3player.c parcourt en jouant; la grille les
# reparcourt SANS appliquer d'état, et ne tient que si elle consomme exactement
# les mêmes octets — un seul opérande mal dimensionné désynchronise le flux et
# tout ce qui suit est du bruit. On rejoue donc le morceau en entier et on
# compare deux choses:
#
#   1. la STRUCTURE — le nombre de lignes que la lecture parcourt réellement
#      dans chaque position doit être celui que la grille annonce (la dernière
#      position atteinte est exclue: elle n'a pas été jouée jusqu'au bout);
#   2. les NOTES — partout où la grille pose une note, le joueur doit jouer la
#      même. Le portamento (commande 2) est exclu: la grille y dit la note
#      CIBLE là où le joueur garde la note d'origine, par construction.
#
#   ./verify_pt3_patterns.sh fichier.pt3 [autre.pt3 ...]
#
# Un fichier TurboSound dont les deux moitiés n'ont pas la même structure sort à
# TROIS voies et non six: la grille se replie sur la première puce, la seule que
# le curseur décrive (voir le garde-fou dans pt3_open).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
pkg=$(dirname "$here")
out=$(mktemp -d)/verify_pt3_patterns
trap 'rm -rf "$(dirname "$out")"' EXIT

[ $# -ge 1 ] || { echo "usage: $0 fichier.pt3 [...]" >&2; exit 2; }

# pt3player.c ne compile qu'en C (arithmétique sur void*), d'où les deux passes.
obj=$(dirname "$out")
common=(-O1 -g -w -fsanitize=address -DREWAMP_WITH_LIBPT3=1
        -I"$pkg/src" -I"$pkg/third_party/libpt3")
for c in "$pkg/src/rewamp_channel_data.c" \
         "$pkg/third_party/libpt3/pt3player.c" \
         "$pkg/third_party/libpt3/ayumi.c" \
         "$here/verify_pt3_patterns_stubs.c"; do
  cc -std=gnu11 "${common[@]}" -c "$c" -o "$obj/$(basename "$c").o"
done
c++ -std=c++14 "${common[@]}" \
    -o "$out" "$here/verify_pt3_patterns.cpp" \
    "$pkg/src/rewamp_plugin_libpt3.cpp" \
    "$obj"/*.o \
    -liconv

fail=0
for f in "$@"; do
  if ! "$out" "$f" 2>/dev/null | grep -E 'pos=|pas de grille'; then fail=1; fi
done
exit $fail

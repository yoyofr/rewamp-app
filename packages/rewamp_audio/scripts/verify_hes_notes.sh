#!/usr/bin/env bash
# Oracle hors ligne de la capture de notes NEZplug++ (.hes HuC6280, .sgc).
#
#   scripts/verify_hes_notes.sh <fichier.hes> [sous-chanson] [secondes]
#
# Compile le jeu de sources vendoré (nez_sources.cmake) + rewamp_channel_data.c
# et imprime, par voie, la plage de hauteurs capturée dans vgm_last_note[] avec
# son équivalent MIDI. Le viz-piano ne garde que les notes de [0,128): une voie
# annoncée « HORS PLAGE » est invisible au piano tout en restant visible dans la
# notation, qui calibre sa plage sur ce qu'elle reçoit — c'est exactement le
# symptôme du facteur 440 parasite corrigé le 2026-09-08 dans s_hes.c.
set -euo pipefail
pkg="$(cd "$(dirname "$0")/.." && pwd)"
nez="$pkg/third_party/nez"
out="${TMPDIR:-/tmp}/verify_hes_notes"
mkdir -p "$out"
inc=(-I"$nez" -I"$nez/format" -I"$nez/device" -I"$nez/device/nes" -I"$nez/device/opl"
     -I"$nez/cpu" -I"$nez/cpu/wkmz80" -I"$nez/cpu/km6502" -I"$pkg/src")

# Le jeu de sources est celui du build (NOT a glob): on le lit dans le .cmake
# plutôt que de le recopier, sinon les deux dérivent.
# (`mapfile` n'existe pas dans le bash 3.2 d'Apple — boucle de lecture.)
srcs=()
while IFS= read -r line; do srcs+=("$line"); done < <(
  sed -n 's|^[[:space:]]*"\${NEZ_ROOT}/\(.*\)"$|'"$nez"'/\1|p' "$nez/nez_sources.cmake")
srcs+=("$pkg/src/rewamp_channel_data.c")
objs=()
for s in "${srcs[@]}"; do
  o="$out/$(echo "${s#$nez/}" | tr / _).o"
  [ -f "$o" ] && [ "$o" -nt "$s" ] || \
    cc -std=gnu11 -O1 -w -DREWAMP_WITH_NEZ=1 "${inc[@]}" -c "$s" -o "$o"
  objs+=("$o")
done
c++ -std=c++17 -O1 -w -DREWAMP_WITH_NEZ=1 "${inc[@]}" \
    "$pkg/scripts/verify_hes_notes.c" "${objs[@]}" -liconv -o "$out/verify_hes_notes"
"$out/verify_hes_notes" "$@"

#!/usr/bin/env bash
# Vérifie la capture par voix du cœur SPC de libgme: une voix qui ne produit
# plus rien ne doit garder ni note ni forme d'onde.
#
# L'ORACLE est l'émulateur lui-même: on rejoue le morceau une fois PAR VOIX,
# toutes les autres coupées, ce qui donne la sortie réelle de cette voix seule.
# Quand elle est inaudible depuis assez longtemps pour que l'anneau du scope se
# soit entièrement renouvelé, `vgm_last_note` et `m_voice_buff` doivent être à
# zéro. Tout ce qui reste est un fantôme.
#
#   ./verify_spc_voice_capture.sh fichier.spc [autre.spc ...]
#
# Réglages calqués sur l'app: `enable_accuracy(true)` et détection de silence
# DÉSACTIVÉE (le réglage `gme/silence_detection` vaut 0 par défaut). Avec la
# détection active, gme sert du silence tamponné sans faire tourner le DSP, la
# capture gèle légitimement et la mesure ne veut plus rien dire.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
pkg=$(dirname "$here")
gme="$pkg/third_party/libgme/gme"
out=$(mktemp -d)/verify_spc_voice_capture
trap 'rm -rf "$(dirname "$out")"' EXIT

[ $# -ge 1 ] || { echo "usage: $0 fichier.spc [...]" >&2; exit 2; }

c++ -std=c++11 -O1 -w -DSILENT \
    -I"$pkg/third_party/libgme" -I"$gme" -I"$pkg/src" \
    -o "$out" "$here/verify_spc_voice_capture.cpp" \
    "$pkg/src/rewamp_channel_data.c" \
    "$gme"/{Spc_Emu,Spc_Dsp,Snes_Spc,Spc_Cpu,Spc_Filter,Music_Emu,Gme_File,M3u_Playlist,Multi_Buffer,Blip_Buffer,Fir_Resampler,Data_Reader}.cpp \
    -liconv -lz

status=0
for f in "$@"; do
  echo "== $(basename "$f")"
  "$out" "$f" || status=1
done
exit $status

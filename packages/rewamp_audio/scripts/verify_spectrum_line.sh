#!/usr/bin/env bash
# La ligne du visualiseur SPECTRE ne doit JAMAIS se couper.
#
# Rend le VRAI shader (src/spectrum_line_shader.inc, le même texte que l'app)
# dans un contexte ANGLE hors écran, puis compte les colonnes voisines dont les
# traits ne se touchent pas — la définition exacte de « la ligne a des trous ».
#
# ⚠️ Trois dimensions, et il faut les trois: la GÉOMÉTRIE (un portrait de
# téléphone est le cas dur, la pente en pixels croît avec la hauteur), le NIVEAU
# audio (à fond la bande est si large qu'elle couvre tout; c'est à niveau moyen
# que le trait est fin et se coupe) et la FORME du spectre (un spectre réel est
# très inégal). Un modèle Python de la formule annonçait zéro trou là où la
# capture d'un utilisateur en montrait 89: seul le shader exécuté fait foi.
#
# Prérequis: ANGLE construit (packages/rewamp_audio/scripts/build_angle_macos.sh).
set -euo pipefail
cd "$(dirname "$0")"
A=../macos/Libs/angle
[ -d "$A/lib" ] || { echo "ANGLE absent: lancer build_angle_macos.sh"; exit 2; }
bin=$(mktemp -d)/verify_spectrum_line
cc -std=gnu11 -Wall -o "$bin" verify_spectrum_line.c \
   -I"$A/include" -L"$A/lib" -lEGL -lGLESv2 -Wl,-rpath,"$PWD/$A/lib"
fail=0
for geom in "794 1366" "1080 1470" "1400 400" "2400 1080"; do
  for lvl in 1.0 0.5 0.25 0.1; do
    for seed in 0 1 7 23 91; do
      out=$("$bin" $geom 0.55 "$lvl" "$seed") || fail=1
      case "$out" in *"DISJOINTES 0 "*) ;; *) echo "$out"; fail=1;; esac
    done
  done
done
if [ "$fail" = 0 ]; then
  echo "OK — aucune coupure sur 4 géométries × 4 niveaux × 5 spectres"
else
  echo "ÉCHEC — la ligne se coupe"; exit 1
fi

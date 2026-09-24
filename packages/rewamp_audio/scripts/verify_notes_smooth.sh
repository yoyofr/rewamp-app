#!/usr/bin/env bash
# Oracle de la tête de lecture LISSÉE partagée par les visualiseurs
# (rewamp_notes_played_smooth), hors de l'app, sur deux scénarios:
#   - changement de piste avec démarrage du son retardé de 0,3 s: l'erreur
#     d'affichage doit se refermer en ~2 s (elle mettait ~8 s: les barres du
#     piano naissaient sous le haut de l'écran pendant tout ce temps);
#   - lecture normale, rappels audio 20±10 ms dont un en retard de 300 ms: la
#     variation d'avance par image doit rester celle du lissage d'origine
#     (~0,3 % en moyenne, < 3 % au pire) — un rattrapage déclenché par un
#     SEUIL d'écart la faisait monter à 19 %.
#   scripts/verify_notes_smooth.sh
set -euo pipefail
pkg="$(cd "$(dirname "$0")/.." && pwd)"
out="${TMPDIR:-/tmp}/verify_notes_smooth"
mkdir -p "$out"
cc -O1 -std=gnu11 -w -I"$pkg/src" -c "$pkg/src/rewamp_channel_data.c" -o "$out/chdata.o"
cc -O1 -std=gnu11 -w -I"$pkg/src" "$pkg/scripts/verify_notes_smooth.c" "$pkg/src/rewamp_notes.c" \
   "$out/chdata.o" -lm -Wl,-undefined,dynamic_lookup -o "$out/verify_notes_smooth"
"$out/verify_notes_smooth"
"$out/verify_notes_smooth" shortskip
"$out/verify_notes_smooth" jitter

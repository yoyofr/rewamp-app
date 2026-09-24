#!/usr/bin/env bash
# Oracle du shader d'éclairage du piano (src/piano_light_shader.inc), rendu
# dans un contexte ANGLE hors écran. Prérequis: build_angle_macos.sh.
set -euo pipefail
cd "$(dirname "$0")"
A=../macos/Libs/angle
[ -d "$A/lib" ] || { echo "ANGLE absent: lancer build_angle_macos.sh"; exit 2; }
bin=$(mktemp -d)/verify_piano_light
cc -std=gnu11 -Wall -o "$bin" verify_piano_light.c \
   -I"$A/include" -L"$A/lib" -lEGL -lGLESv2 -Wl,-rpath,"$PWD/$A/lib"
"$bin" 0
"$bin" 1
"$bin" 2

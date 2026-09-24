#!/usr/bin/env bash
# Vérifie la conversion de jeu de caractères d'ANDROID (src/StrUtils-CPConv_Stub.c),
# qui remplace iconv là où bionic ne le fournit pas (< API 28).
#
# Les deux branches sont exercées:
#   sans argument → convertisseurs INTÉGRÉS (le cas Android 26/27)
#   --iconv       → le chemin iconv (Android >= 28), via le libiconv du poste
#
# Le bug d'origine (2026-09-03): le GD3 d'un VGM est en UTF-16LE et la version
# précédente recopiait les octets, donc « Game Over » sortait « G » — la chaîne
# C s'arrêtait au premier octet nul — et le japonais en caractères corrompus.
set -euo pipefail
cd "$(dirname "$0")"
out=$(mktemp -d)/verify_cpconv
cc -std=gnu11 -Wall -Wextra -fsanitize=address,undefined -o "$out" verify_cpconv.c -liconv
"$out"            # convertisseurs intégrés
"$out" --iconv    # chemin iconv

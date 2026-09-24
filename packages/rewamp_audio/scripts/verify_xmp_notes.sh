#!/usr/bin/env bash
# Compare les notes publiées par libxmp à celles de libopenmpt sur un même
# module (voir l'en-tête de verify_xmp_notes.c pour le pourquoi).
#
#   ./verify_xmp_notes.sh module.xm [autre.it ...]
#
# Les deux moteurs doivent jouer le fichier: c'est un contrôle d'ÉCHELLE, donc
# il se fait sur les formats COMMUNS, pas sur les formats exclusifs à libxmp.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
pkg=$(dirname "$here")
tmp=$(mktemp -d)
out="$tmp/verify_xmp_notes"
trap 'rm -rf "$tmp"' EXIT

[ $# -ge 1 ] || { echo "usage: $0 module [...]" >&2; exit 2; }

xmp="$pkg/third_party/libxmp"
ompt_lib="$pkg/macos/Libs/libopenmpt.a"
[ -f "$ompt_lib" ] || { echo "libopenmpt.a manquant: lancer scripts/build_libopenmpt_macos.sh" >&2; exit 2; }

common=(-O1 -g -w -fsanitize=address -I"$pkg/src" -I"$xmp/include"
        -I"$pkg/third_party/libopenmpt")

for f in "$xmp"/src/*.c "$xmp"/src/loaders/*.c; do
  cc -std=gnu99 "${common[@]}" -DLIBXMP_STATIC -DLIBXMP_NO_DEPACKERS \
     -DLIBXMP_NO_PROWIZARD -include "$xmp/rewamp_xmp_rename.h" -I"$xmp/src" \
     -c "$f" -o "$tmp/xmp_$(basename "$f" .c).o"
done
cc -std=gnu11 "${common[@]}" -c "$pkg/src/rewamp_channel_data.c" -o "$tmp/chan.o"
cc -std=gnu11 "${common[@]}" -DREWAMP_WITH_XMP=1 -c "$pkg/src/rewamp_plugin_xmp.c" -o "$tmp/plugin_xmp.o"
cc -std=gnu11 "${common[@]}" -DREWAMP_WITH_OPENMPT=1 -c "$pkg/src/rewamp_plugin_openmpt.c" -o "$tmp/plugin_ompt.o"
cc -std=gnu11 "${common[@]}" -c "$here/verify_xmp_notes.c" -o "$tmp/main.o"
c++ -O1 -g -fsanitize=address -o "$out" "$tmp"/*.o "$ompt_lib" -lm -liconv -lz

fail=0
for f in "$@"; do
  "$out" "$f" || fail=1
done
exit $fail

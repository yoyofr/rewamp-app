#!/usr/bin/env bash
# Oracle GBR: lecture, sonde de sous-chansons (liste CREUSE) et isolation des
# oscilloscopes. Ne demande AUCUN fichier — le harnais fabrique ses `.gbr`.
#
#   packages/rewamp_audio/scripts/verify_gbr.sh
#
# Les mêmes defines que le podspec / cmake, et ASan: un débordement d'anneau ne
# se voit pas autrement (la note de dimensionnement de ModizerConstants.h a été
# payée ici même).
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/rewamp_verify_gbr"
mkdir -p "$OUT"

CC="${CC:-cc}"
"$CC" -O1 -g -fsanitize=address \
  -DREWAMP_WITH_GBSPLAY=1 \
  -I "$ROOT/src" -I "$ROOT/third_party" -I "$ROOT/third_party/libgbsplay" \
  "$ROOT/scripts/verify_gbr.c" \
  "$ROOT/scripts/verify_gbr_stubs.c" \
  "$ROOT/src/rewamp_plugin_gbsplay.c" \
  "$ROOT/src/rewamp_channel_data.c" \
  "$ROOT/third_party/libgbsplay/gbs.c" \
  "$ROOT/third_party/libgbsplay/gbhw.c" \
  "$ROOT/third_party/libgbsplay/gbcpu.c" \
  "$ROOT/third_party/libgbsplay/gblfsr.c" \
  "$ROOT/third_party/libgbsplay/mapper.c" \
  "$ROOT/third_party/libgbsplay/util.c" \
  "$ROOT/third_party/libgbsplay/crc32.c" \
  -o "$OUT/verify_gbr" -lz -lm

exec "$OUT/verify_gbr" "$OUT"

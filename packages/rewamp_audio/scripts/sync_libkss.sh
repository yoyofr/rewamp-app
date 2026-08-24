#!/usr/bin/env bash
# Regenerates the patched libkss source tree (third_party/libkss) from the
# pristine upstream copies + the rewamp patches. Same philosophy as
# sync_adplug.sh / sync_asap.sh / sync_libopenmpt.sh.
#
# libkss carries two kinds of rewamp modifications, BOTH encoded in the patches:
#   1. a namespace rename (PSG->PSGKSS, SCC->SCCKSS, OPLL->OPLLKSS, OPL->OPLKSS,
#      and the emu2149/emu2212/emu2413 source files -> kss_emu*) that keeps the
#      MSX chip emulators from clashing at link time with libgme's own PSG/SCC/
#      OPLL emulators (libgme also plays KSS);
#   2. the Modizer per-voice scope/notes/mute capture (grep YOYOFR).
#
# Usage:
#   ./scripts/sync_libkss.sh                # re-apply patches on the vendored upstream
#   ./scripts/sync_libkss.sh <git-ref>      # clone that upstream ref + submodules,
#                                           # RE-VENDOR the whole tree, refresh
#                                           # upstream/ + UPSTREAM_VERSION, re-apply
#
# Layout:
#   third_party/libkss/{src,modules}/**            vendored + patched (builds use these)
#   third_party/libkss/upstream/<relpath>          pristine copies of the patched files
#   patches/libkss/<basename>.patch                rewamp mods (rename + YOYOFR)
#   patches/libkss/UPSTREAM_VERSION                pinned upstream commit
set -euo pipefail

PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KSS_DIR="$PKG_DIR/third_party/libkss"
UP_DIR="$KSS_DIR/upstream"
PATCH_DIR="$PKG_DIR/patches/libkss"

# Vendored source file set (relative to third_party/libkss). Mirrors upstream's
# CMake build minus the CLI tools / kss2vgm / hardware drivers, with the three
# clashing emu cores renamed kss_*.
SRC_FILES="
src/kssplay.c src/kssplay.h
src/filters/dc_filter.c src/filters/dc_filter.h
src/filters/filter.c src/filters/filter.h
src/filters/rc_filter.c src/filters/rc_filter.h
src/kss/kss.c src/kss/kss.h src/kss/kss2kss.c src/kss/kssload.c
src/kss/bgm2kss.c src/kss/mbm2kss.c src/kss/mgs2kss.c src/kss/mpk2kss.c src/kss/opx2kss.c
src/rconv/psg_rconv.c src/rconv/psg_rconv.h
src/vm/detect.c src/vm/detect.h src/vm/mmap.c src/vm/mmap.h src/vm/vm.c src/vm/vm.h
modules/emu2149/kss_emu2149.c modules/emu2149/kss_emu2149.h
modules/emu2212/kss_emu2212.c modules/emu2212/kss_emu2212.h
modules/emu2413/kss_emu2413.c modules/emu2413/kss_emu2413.h
modules/emu8950/emu8950.c modules/emu8950/emu8950.h
modules/emu8950/emuadpcm.c modules/emu8950/emuadpcm.h
modules/emu76489/emu76489.c modules/emu76489/emu76489.h
modules/kmz80/kmdmg.c modules/kmz80/kmevent.c modules/kmz80/kmevent.h
modules/kmz80/kmr800.c modules/kmz80/kmtypes.h
modules/kmz80/kmz80.c modules/kmz80/kmz80.h modules/kmz80/kmz80c.c
modules/kmz80/kmz80i.h modules/kmz80/kmz80t.c
modules/drivers/kinrou5.h modules/drivers/mbr143.h modules/drivers/mgsdrv.h
modules/drivers/mpk103.h modules/drivers/mpk106.h modules/drivers/opx4kss.h
"

# Map a vendored relpath to its pristine upstream relpath (the emu rename).
upstream_relpath() {
  case "$1" in
    modules/emu2149/kss_emu2149.c) echo "modules/emu2149/emu2149.c";;
    modules/emu2149/kss_emu2149.h) echo "modules/emu2149/emu2149.h";;
    modules/emu2212/kss_emu2212.c) echo "modules/emu2212/emu2212.c";;
    modules/emu2212/kss_emu2212.h) echo "modules/emu2212/emu2212.h";;
    modules/emu2413/kss_emu2413.c) echo "modules/emu2413/emu2413.c";;
    modules/emu2413/kss_emu2413.h) echo "modules/emu2413/emu2413.h";;
    *) echo "$1";;
  esac
}

if [ -n "${1:-}" ]; then
  REF="$1"
  TMP="$(mktemp -d)"
  echo "cloning libkss@$REF (with submodules) …"
  git clone --quiet "https://github.com/digital-sound-antiques/libkss.git" "$TMP/libkss"
  git -C "$TMP/libkss" checkout --quiet "$REF"
  git -C "$TMP/libkss" submodule update --init --recursive --quiet
  HASH="$(git -C "$TMP/libkss" rev-parse HEAD)"

  echo "re-vendoring source tree …"
  for rel in $SRC_FILES; do
    up="$(upstream_relpath "$rel")"
    if [ ! -f "$TMP/libkss/$up" ]; then echo "  WARN missing upstream: $up" >&2; continue; fi
    mkdir -p "$KSS_DIR/$(dirname "$rel")"
    cp "$TMP/libkss/$up" "$KSS_DIR/$rel"
  done
  cp "$TMP/libkss/LICENSE.md" "$KSS_DIR/" 2>/dev/null || true

  echo "refreshing upstream/ pristine mirror …"
  rm -rf "$UP_DIR"
  for pf in "$PATCH_DIR"/*.patch; do
    base="$(basename "$pf" .patch)"
    # find the vendored relpath whose basename matches this patch
    for rel in $SRC_FILES; do
      if [ "$(basename "$rel")" = "$base" ]; then
        up="$(upstream_relpath "$rel")"
        mkdir -p "$UP_DIR/$(dirname "$rel")"
        cp "$TMP/libkss/$up" "$UP_DIR/$rel"
        break
      fi
    done
  done
  echo "$HASH" > "$PATCH_DIR/UPSTREAM_VERSION"
  rm -rf "$TMP"
fi

# Reset the patched files to pristine, then apply the rewamp patches.
FAIL=0
cd "$UP_DIR"
for f in $(find . -type f); do
  rel="${f#./}"; base="$(basename "$rel")"
  patch_file="$PATCH_DIR/$base.patch"
  cp "$UP_DIR/$rel" "$KSS_DIR/$rel"
  if patch --silent "$KSS_DIR/$rel" "$patch_file"; then
    echo "applied:  $base.patch"
  else
    echo "CONFLICT: $base.patch — resolve on third_party/libkss/$rel, then regenerate:" >&2
    echo "  diff -u third_party/libkss/upstream/$rel third_party/libkss/$rel > $patch_file" >&2
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] || exit 1

echo "done — libkss = upstream $(head -1 "$PATCH_DIR/UPSTREAM_VERSION") + rewamp patches."

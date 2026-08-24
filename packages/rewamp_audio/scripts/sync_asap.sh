#!/usr/bin/env bash
# Regenerates third_party/asap/asap.c (the file the builds compile) from the
# pristine upstream copy + the rewamp patches — same philosophy as
# sync_libopenmpt.sh but for a vendored 2-file generated library (ASAP's C is
# transpiled from .fu sources upstream; we vendor the released, generated C).
#
# Usage:
#   ./scripts/sync_asap.sh              # re-apply patches on the vendored upstream
#   ./scripts/sync_asap.sh 8.1.0        # fetch that release from SourceForge,
#                                       # replace upstream/, try the patches
#                                       # (updates patches/asap/UPSTREAM_VERSION)
#
# Layout:
#   third_party/asap/upstream/asap.{c,h}   pristine release (committed)
#   patches/asap/*.patch                   rewamp modifications (committed)
#   third_party/asap/asap.{c,h}            patched output (committed — what builds use)
set -euo pipefail

PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ASAP_DIR="$PKG_DIR/third_party/asap"
PATCH_DIR="$PKG_DIR/patches/asap"

if [ -n "${1:-}" ]; then
  VER="$1"
  TMP="$(mktemp -d)"
  echo "fetching asap-$VER from SourceForge…"
  curl -sL "https://downloads.sourceforge.net/project/asap/asap/$VER/asap-$VER.tar.gz" \
    -o "$TMP/asap.tar.gz"
  tar xzf "$TMP/asap.tar.gz" -C "$TMP"
  cp "$TMP/asap-$VER/asap.c" "$TMP/asap-$VER/asap.h" "$ASAP_DIR/upstream/"
  cp "$TMP/asap-$VER/COPYING" "$TMP/asap-$VER/README" "$ASAP_DIR/" 2>/dev/null || true
  echo "$VER" > "$PATCH_DIR/UPSTREAM_VERSION"
  rm -rf "$TMP"
fi

cp "$ASAP_DIR/upstream/asap.c" "$ASAP_DIR/asap.c"
cp "$ASAP_DIR/upstream/asap.h" "$ASAP_DIR/asap.h"

for patch in "$PATCH_DIR"/*.patch; do
  if patch -p0 --silent --directory / --input "$patch" --dry-run \
       "$ASAP_DIR/asap.c" >/dev/null 2>&1; then :; fi
  if patch --silent "$ASAP_DIR/asap.c" "$patch"; then
    echo "applied:  $(basename "$patch")"
  else
    echo "CONFLICT: $(basename "$patch") — resolve on third_party/asap/asap.c," >&2
    echo "then regenerate: diff -u upstream/asap.c asap.c > $patch" >&2
    exit 1
  fi
done

echo "done — third_party/asap/asap.c = upstream $(cat "$PATCH_DIR/UPSTREAM_VERSION") + rewamp patches."

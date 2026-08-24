#!/usr/bin/env bash
# Regenerates the patched AdPlug source files (third_party/adplug/src/woodyopl.cpp
# + surroundopl.cpp — the OPL cores that carry the rewamp per-voice scope/notes/
# mute capture) from the pristine upstream copies + the rewamp patches. Same
# philosophy as sync_asap.sh / sync_libopenmpt.sh but for a vendored copy (AdPlug
# is not a submodule; its src/ is committed directly).
#
# Usage:
#   ./scripts/sync_adplug.sh                 # re-apply patches on the vendored upstream
#   ./scripts/sync_adplug.sh <git-ref>       # clone that upstream ref, RE-VENDOR the
#                                            # whole src/ (minus x86 realopl/analopl),
#                                            # refresh upstream/ + patches/UPSTREAM_VERSION,
#                                            # then re-apply the patches
#
# Layout:
#   third_party/adplug/upstream/{woodyopl,surroundopl}.cpp   pristine (committed)
#   patches/adplug/*.cpp.patch                               rewamp mods (committed)
#   third_party/adplug/src/*                                 vendored + patched (committed — builds use)
set -euo pipefail

PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ADPLUG_DIR="$PKG_DIR/third_party/adplug"
PATCH_DIR="$PKG_DIR/patches/adplug"
# Files that carry rewamp patches (pristine kept in upstream/, patch in patches/).
PATCHED_FILES="woodyopl.cpp surroundopl.cpp"

if [ -n "${1:-}" ]; then
  REF="$1"
  TMP="$(mktemp -d)"
  echo "cloning adplug@$REF …"
  git clone --quiet "https://github.com/adplug/adplug.git" "$TMP/adplug"
  git -C "$TMP/adplug" checkout --quiet "$REF"
  HASH="$(git -C "$TMP/adplug" rev-parse HEAD)"
  # Re-vendor the whole src/ (drop the x86 hardware backends realopl/analopl).
  rm -f "$ADPLUG_DIR"/src/*.cpp "$ADPLUG_DIR"/src/*.c "$ADPLUG_DIR"/src/*.h
  cp "$TMP/adplug"/src/*.cpp "$TMP/adplug"/src/*.c "$TMP/adplug"/src/*.h "$ADPLUG_DIR/src/"
  rm -f "$ADPLUG_DIR"/src/realopl.cpp "$ADPLUG_DIR"/src/realopl.h \
        "$ADPLUG_DIR"/src/analopl.cpp "$ADPLUG_DIR"/src/analopl.h
  cp "$TMP/adplug/COPYING" "$ADPLUG_DIR/" 2>/dev/null || true
  # version.h is configure-generated upstream — keep our committed stub.
  # Refresh the pristine copies of the patched files.
  for f in $PATCHED_FILES; do cp "$TMP/adplug/src/$f" "$ADPLUG_DIR/upstream/$f"; done
  echo "$HASH" > "$PATCH_DIR/UPSTREAM_VERSION"
  rm -rf "$TMP"
fi

# Reset the patched files to pristine, then apply the rewamp patches.
for f in $PATCHED_FILES; do
  cp "$ADPLUG_DIR/upstream/$f" "$ADPLUG_DIR/src/$f"
  patch_file="$PATCH_DIR/$f.patch"
  if patch --silent "$ADPLUG_DIR/src/$f" "$patch_file"; then
    echo "applied:  $f.patch"
  else
    echo "CONFLICT: $f.patch — resolve on third_party/adplug/src/$f, then regenerate:" >&2
    echo "  diff -u third_party/adplug/upstream/$f third_party/adplug/src/$f > $patch_file" >&2
    exit 1
  fi
done

echo "done — AdPlug src = upstream $(cat "$PATCH_DIR/UPSTREAM_VERSION") + rewamp patches."

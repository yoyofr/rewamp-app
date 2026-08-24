#!/usr/bin/env bash
# Syncs the libopenmpt submodule to the pinned upstream commit and applies the
# rewamp patches (Modizer oscilloscope/note captures) on top as WORKING-TREE
# changes. The submodule pointer stays on a genuine upstream SHA, so fresh
# clones can always fetch it; the patches live in patches/libopenmpt/ and are
# re-applied by this script (idempotent).
#
# Usage:
#   ./scripts/sync_libopenmpt.sh            # checkout pinned base + apply patches
#   ./scripts/sync_libopenmpt.sh <sha|tag>  # try the patches on a NEWER upstream
#                                           # (updates UPSTREAM_BASE on success)
#
# After any change here, rebuild the prebuilt libs:
#   ./scripts/build_libopenmpt_macos.sh && ./scripts/build_libopenmpt_ios.sh
set -euo pipefail

PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SUB="$PKG_DIR/third_party/libopenmpt"
PATCH_DIR="$PKG_DIR/patches/libopenmpt"
BASE_FILE="$PATCH_DIR/UPSTREAM_BASE"

if [ ! -d "$SUB/.git" ] && [ ! -f "$SUB/.git" ]; then
  echo "error: submodule not initialized. Run: git submodule update --init $SUB" >&2
  exit 1
fi

TARGET="${1:-$(cat "$BASE_FILE")}"

cd "$SUB"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "note: discarding local submodule modifications (they are regenerated from patches/)"
  git checkout -- .
fi

git fetch origin --quiet
git checkout --quiet "$TARGET"
echo "libopenmpt at $(git rev-parse --short HEAD) ($(git log -1 --format=%s | cut -c1-60))"

for patch in "$PATCH_DIR"/*.patch; do
  if git apply --check "$patch" 2>/dev/null; then
    git apply "$patch"
    echo "applied:  $(basename "$patch")"
  elif git apply --check --reverse "$patch" 2>/dev/null; then
    echo "already:  $(basename "$patch")"
  else
    echo "CONFLICT: $(basename "$patch") does not apply on $TARGET — resolve manually," >&2
    echo "then regenerate the patch (git diff > $patch style) and update $BASE_FILE." >&2
    exit 1
  fi
done

if [ -n "${1:-}" ]; then
  git rev-parse HEAD > "$BASE_FILE"
  echo "UPSTREAM_BASE updated to $(git rev-parse --short HEAD)"
  echo "Remember: commit the new submodule pointer in the superproject and rebuild the prebuilts."
fi

echo "done — patches applied as working-tree changes (submodule pointer = upstream SHA)."

#!/usr/bin/env bash
# Builds ANGLE (OpenGL ES 3.0 -> Metal) as universal (arm64 + x86_64) dynamic
# libraries for macOS, carrying the rewamp GL_EXT_shader_framebuffer_fetch patch.
# Output: macos/Libs/angle/{lib/{libEGL,libGLESv2}.dylib, include/}
#         (consumed by macos/rewamp_audio.podspec; the whole Libs/ dir is
#          gitignored, so run this once on a fresh checkout).
#
# The heavy ANGLE checkout (depot_tools + gclient deps, ~10 GB) lives OUTSIDE
# the repo under $WORK (default: ~/Documents/Dev/metalangle-build) and is reused
# across runs. Only the two dylibs + headers land in the repo.
#
# Requirements: git, python3, Xcode + the Metal Toolchain. If ninja fails with
#   "cannot execute tool 'metal' ... missing Metal Toolchain"
# run once:  xcodebuild -downloadComponent MetalToolchain
set -euo pipefail

PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PATCH="$PKG_DIR/patches/angle/0001-metal-EXT_shader_framebuffer_fetch.patch"
OUT_LIB="$PKG_DIR/macos/Libs/angle/lib"
OUT_INC="$PKG_DIR/macos/Libs/angle/include"

WORK="${ANGLE_WORK_DIR:-$HOME/Documents/Dev/metalangle-build}"
DEPOT="$WORK/depot_tools"
ANGLE="$WORK/angle"
# Pin to the upstream commit the patch was generated against.
ANGLE_REF="$(cat "$PKG_DIR/patches/angle/UPSTREAM_COMMIT" 2>/dev/null || echo '')"

GN_ARGS='is_debug=false angle_enable_metal=true angle_enable_vulkan=false angle_enable_gl=false angle_enable_null=false is_component_build=false angle_build_tests=false use_custom_libcxx=false symbol_level=0 treat_warnings_as_errors=false'

mkdir -p "$WORK"

# --- 1. depot_tools ---------------------------------------------------------
if [ ! -d "$DEPOT" ]; then
  echo "==> cloning depot_tools"
  git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git "$DEPOT"
fi
export PATH="$DEPOT:$PATH"

# --- 2. ANGLE source + deps -------------------------------------------------
if [ ! -d "$ANGLE" ]; then
  echo "==> cloning ANGLE"
  git clone https://chromium.googlesource.com/angle/angle "$ANGLE"
fi
cd "$ANGLE"
if [ -n "$ANGLE_REF" ]; then
  echo "==> checking out pinned $ANGLE_REF"
  git fetch --depth 1 origin "$ANGLE_REF" 2>/dev/null || git fetch origin
  git checkout -q "$ANGLE_REF"
fi
echo "==> gclient sync (long)"
python3 scripts/bootstrap.py
gclient sync -D --no-history

# --- 3. apply the framebuffer-fetch patch (idempotent) ----------------------
if [ -f "$PATCH" ]; then
  if git apply --reverse --check "$PATCH" 2>/dev/null; then
    echo "==> patch already applied"
  else
    echo "==> applying $PATCH"
    git apply "$PATCH"
  fi
fi

# --- 4. build both arches (non-component: 2 self-contained dylibs) -----------
for arch in arm64 x64; do
  echo "==> gn gen out/ship-$arch"
  gn gen "out/ship-$arch" --args="target_cpu=\"$arch\" $GN_ARGS"
  echo "==> autoninja $arch"
  autoninja -C "out/ship-$arch" libEGL libGLESv2
done

# --- 5. lipo universal + install --------------------------------------------
echo "==> lipo + install into $OUT_LIB"
mkdir -p "$OUT_LIB" "$OUT_INC"
for l in libEGL libGLESv2; do
  lipo -create "out/ship-arm64/$l.dylib" "out/ship-x64/$l.dylib" -output "$OUT_LIB/$l.dylib"
  install_name_tool -id "@rpath/$l.dylib" "$OUT_LIB/$l.dylib"
  echo "    $l: $(lipo -archs "$OUT_LIB/$l.dylib")"
done

# libEGL dlopens "libGLESv2.dylib" from its own directory (ModuleDir search), so
# both must keep their filenames and sit side by side — CocoaPods vendored_
# libraries + use_frameworks! embeds them into Contents/Frameworks together.
cp -R include/EGL include/GLES2 include/GLES3 include/KHR \
      include/angle_gl.h include/export.h "$OUT_INC/"

echo "==> done. Universal libEGL/libGLESv2 + headers in macos/Libs/angle/"

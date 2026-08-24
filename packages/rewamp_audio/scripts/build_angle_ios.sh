#!/usr/bin/env bash
# Builds ANGLE (OpenGL ES 3.0 -> Metal) as STATIC libraries for iOS — device
# (arm64) and simulator (arm64, plus x86_64 with REWAMP_ANGLE_SIM_X64=1) — and
# packs them into ios/Libs/angle/ANGLE.xcframework, carrying the rewamp
# GL_EXT_shader_framebuffer_fetch patch (the same one the macOS build uses).
#
# Output: ios/Libs/angle/ANGLE.xcframework  (consumed by ios/rewamp_audio.podspec)
#         ios/Libs/angle/include/           (headers, also inside each slice)
#         The whole Libs/ dir is gitignored → run once on a fresh checkout.
#
# Static, not a framework: no embedding, no code signing, no dlopen dance
# (libEGL_static links libGLESv2_static directly, where the macOS dylibs have
# libEGL dlopen libGLESv2.dylib from its own directory).
#
# The heavy ANGLE checkout (depot_tools + gclient deps, ~10 GB) lives OUTSIDE
# the repo under $WORK (default: ~/Documents/Dev/metalangle-build), SHARED with
# build_angle_macos.sh — same source tree, same pinned commit, same patch.
#
# Requirements: git, python3, Xcode + the Metal Toolchain. If ninja fails with
#   "cannot execute tool 'metal' ... missing Metal Toolchain"
# run once:  xcodebuild -downloadComponent MetalToolchain
set -euo pipefail

PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PATCH="$PKG_DIR/patches/angle/0001-metal-EXT_shader_framebuffer_fetch.patch"
OUT_DIR="$PKG_DIR/ios/Libs/angle"
OUT_INC="$OUT_DIR/include"

WORK="${ANGLE_WORK_DIR:-$HOME/Documents/Dev/metalangle-build}"
DEPOT="$WORK/depot_tools"
ANGLE="$WORK/angle"
ANGLE_REF="$(cat "$PKG_DIR/patches/angle/UPSTREAM_COMMIT" 2>/dev/null || echo '')"
IOS_MIN="${REWAMP_IOS_MIN:-13.0}"

# angle_enable_wgpu=false: the WebGPU backend drags in dawn, whose
# WorkerThread.cpp uses std::atomic<>::wait — unavailable below iOS 14 — and we
# hold the iOS 13 floor. Nothing in rewamp goes through WebGPU anyway.
GN_COMMON="is_debug=false angle_enable_metal=true angle_enable_vulkan=false \
angle_enable_gl=false angle_enable_null=false angle_enable_wgpu=false \
is_component_build=false \
angle_build_tests=false use_custom_libcxx=false symbol_level=0 \
treat_warnings_as_errors=false target_os=\"ios\" ios_enable_code_signing=false \
ios_deployment_target=\"$IOS_MIN\""

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
if [ ! -d "$ANGLE/third_party/zlib" ]; then
  if [ -n "$ANGLE_REF" ]; then
    echo "==> checking out pinned $ANGLE_REF"
    git fetch --depth 1 origin "$ANGLE_REF" 2>/dev/null || git fetch origin
    git checkout -q "$ANGLE_REF"
  fi
  echo "==> gclient sync (long)"
  python3 scripts/bootstrap.py
  gclient sync -D --no-history
fi

# --- 3. apply the framebuffer-fetch patch (idempotent) ----------------------
if [ -f "$PATCH" ]; then
  if git apply --reverse --check "$PATCH" 2>/dev/null; then
    echo "==> patch already applied"
  else
    echo "==> applying $PATCH"
    git apply "$PATCH"
  fi
fi

# --- 4. build one slice -----------------------------------------------------
# Each gn static_library lands as its own obj/**/*.a — but those are THIN
# archives (`!<thin>`, just paths into obj/), which libtool refuses to merge.
# So weld the object files themselves: ninja only compiles what the two
# requested targets transitively need, so obj/**/*.o IS that closure.
build_slice() {                       # $1=outdir  $2=target_cpu  $3=environment
  local out="out/$1"
  echo "==> gn gen $out ($2/$3)"
  gn gen "$out" --args="target_cpu=\"$2\" target_environment=\"$3\" $GN_COMMON"
  echo "==> autoninja $1"
  autoninja -C "$out" libEGL_static libGLESv2_static
  local objs
  objs=$(find "$out/obj" -name '*.o' | sort)
  [ -n "$objs" ] || { echo "no objects produced in $out/obj"; exit 1; }
  rm -f "$out/libangle.a"
  # shellcheck disable=SC2086
  libtool -static -no_warning_for_no_symbols -o "$out/libangle.a" $objs
  echo "    $1: $(du -h "$out/libangle.a" | cut -f1) — $(lipo -archs "$out/libangle.a")"
}

build_slice ios-device       arm64  device
build_slice ios-sim-arm64    arm64  simulator
SIM_LIB="out/ios-sim-arm64/libangle.a"
# The simulator slice must carry BOTH arches: CocoaPods/Xcode look for
# "ios-arm64_x86_64-simulator" and an arm64-only slice fails the copy phase
# ("ios-arm64_x86_64-simulator/*: (l)stat: No such file or directory"), which
# reads as a missing file rather than a missing arch. REWAMP_ANGLE_SIM_ARM64=1
# skips the x86_64 half when you only ever run Apple-silicon simulators.
if [ "${REWAMP_ANGLE_SIM_ARM64:-0}" != "1" ]; then
  build_slice ios-sim-x64    x64    simulator
  # BOTH slices must carry the SAME library filename: CocoaPods derives one
  # -l"angle" from it, so a lipo output named libangle-sim-universal.a linked
  # fine on device and failed the simulator with "Library 'angle' not found".
  mkdir -p out/sim-universal
  lipo -create out/ios-sim-arm64/libangle.a out/ios-sim-x64/libangle.a \
       -output out/sim-universal/libangle.a
  SIM_LIB="out/sim-universal/libangle.a"
fi

# --- 5. headers + xcframework ----------------------------------------------
echo "==> staging headers"
STAGE="$(mktemp -d)/include"
mkdir -p "$STAGE"
cp -R include/EGL include/GLES2 include/GLES3 include/KHR \
      include/angle_gl.h include/export.h "$STAGE/"

echo "==> create-xcframework into $OUT_DIR"
rm -rf "$OUT_DIR/ANGLE.xcframework" "$OUT_INC"
mkdir -p "$OUT_DIR"
xcodebuild -create-xcframework \
  -library "out/ios-device/libangle.a" -headers "$STAGE" \
  -library "$SIM_LIB"                  -headers "$STAGE" \
  -output "$OUT_DIR/ANGLE.xcframework"

# A plain copy too: CocoaPods' handling of headers inside a static-library
# xcframework varies by version, the podspec's HEADER_SEARCH_PATHS does not.
mkdir -p "$OUT_INC"
cp -R "$STAGE/." "$OUT_INC/"

echo "==> done. ios/Libs/angle/ANGLE.xcframework (device + simulator, iOS $IOS_MIN+)"

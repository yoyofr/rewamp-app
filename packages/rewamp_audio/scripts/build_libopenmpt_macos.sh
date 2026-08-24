#!/usr/bin/env bash
# Builds libopenmpt as a universal (arm64 + x86_64) static library for macOS,
# from the vendored source submodule, using the shared CMake recipe.
# Output: macos/Libs/libopenmpt.a  (consumed by macos/rewamp_audio.podspec).
set -euo pipefail

PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SUBMODULE="$PKG_DIR/third_party/libopenmpt"
BUILD_DIR="$PKG_DIR/build/libopenmpt-macos"
OUT_DIR="$PKG_DIR/macos/Libs"

if [ ! -f "$SUBMODULE/libopenmpt/libopenmpt.h" ]; then
  echo "error: submodule missing. Run:" >&2
  echo "  git submodule update --init packages/rewamp_audio/third_party/libopenmpt" >&2
  exit 1
fi

# Minimal CMake project that reuses rewamp_add_libopenmpt() from cmake/rewamp.cmake.
mkdir -p "$BUILD_DIR"
cat > "$BUILD_DIR/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.16)
project(libopenmpt_macos CXX C)
include("$PKG_DIR/cmake/rewamp.cmake")
set(REWAMP_WITH_OPENMPT ON)
rewamp_add_libopenmpt()
EOF

cmake -S "$BUILD_DIR" -B "$BUILD_DIR/cmake-build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=10.14

cmake --build "$BUILD_DIR/cmake-build" -j"$(sysctl -n hw.ncpu)"

mkdir -p "$OUT_DIR"
cp "$BUILD_DIR/cmake-build/libopenmpt.a" "$OUT_DIR/libopenmpt.a"

echo ""
echo "Built: $OUT_DIR/libopenmpt.a"
lipo -info "$OUT_DIR/libopenmpt.a" 2>/dev/null || true

#!/usr/bin/env bash
# Builds libopenmpt as an XCFramework for iOS (device arm64 + simulator arm64/x86_64).
# Output: ios/Libs/libopenmpt.xcframework  (consumed by ios/rewamp_audio.podspec).
set -euo pipefail

PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SUBMODULE="$PKG_DIR/third_party/libopenmpt"
BUILD_DIR="$PKG_DIR/build/libopenmpt-ios"
OUT_DIR="$PKG_DIR/ios/Libs"
XCFW="$OUT_DIR/libopenmpt.xcframework"

if [ ! -f "$SUBMODULE/libopenmpt/libopenmpt.h" ]; then
  echo "error: submodule missing. Run:" >&2
  echo "  git submodule update --init packages/rewamp_audio/third_party/libopenmpt" >&2
  exit 1
fi

NCPU=$(sysctl -n hw.ncpu)

# Build one slice. Output goes directly to the terminal (not captured).
# $1=name  $2=sysroot  $3=archs (semicolon-separated for CMake)
build_slice() {
  local name="$1" sysroot="$2" archs="$3"
  local bdir="$BUILD_DIR/$name"
  mkdir -p "$bdir"

  cat > "$bdir/CMakeLists.txt" <<CMEOF
cmake_minimum_required(VERSION 3.16)
project(libopenmpt_ios CXX C)
include("$PKG_DIR/cmake/rewamp.cmake")
set(REWAMP_WITH_OPENMPT ON)
rewamp_add_libopenmpt()
CMEOF

  cmake -S "$bdir" -B "$bdir/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="$sysroot" \
    -DCMAKE_OSX_ARCHITECTURES="$archs" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -Wno-dev -DCMAKE_MESSAGE_LOG_LEVEL=WARNING

  cmake --build "$bdir/build" -j"$NCPU"

  local lib="$bdir/build/libopenmpt.a"
  if [ ! -f "$lib" ]; then
    echo "error: build did not produce $lib" >&2
    exit 1
  fi
}

echo "==> Building device slice (arm64, iphoneos)…"
build_slice "device" "iphoneos" "arm64"
DEVICE_LIB="$BUILD_DIR/device/build/libopenmpt.a"

echo ""
echo "==> Building simulator slice (arm64 + x86_64, iphonesimulator)…"
build_slice "simulator" "iphonesimulator" "arm64;x86_64"
SIM_LIB="$BUILD_DIR/simulator/build/libopenmpt.a"

echo ""
echo "==> Packaging XCFramework…"
mkdir -p "$OUT_DIR"
rm -rf "$XCFW"

xcodebuild -create-xcframework \
  -library "$DEVICE_LIB" \
  -library "$SIM_LIB" \
  -output "$XCFW"

echo ""
echo "Built: $XCFW"
echo "Slices:"
ls "$XCFW/"

#!/usr/bin/env bash
# Builds libvgmstream as an XCFramework for iOS (device arm64 + simulator arm64/x86_64).
# Output: ios/Libs/libvgmstream.xcframework  (consumed by ios/rewamp_audio.podspec).
#
# Usage: ./packages/rewamp_audio/scripts/build_vgmstream_ios.sh
set -euo pipefail

PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$PKG_DIR/third_party/vgmstream"
BUILD_DIR="$PKG_DIR/build/vgmstream-ios"
OUT_DIR="$PKG_DIR/ios/Libs"
XCFW="$OUT_DIR/libvgmstream.xcframework"

if [ ! -f "$SRC_DIR/src/libvgmstream.h" ]; then
  echo "error: vgmstream submodule missing. Run:" >&2
  echo "  git submodule update --init packages/rewamp_audio/third_party/vgmstream" >&2
  exit 1
fi

NCPU=$(sysctl -n hw.ncpu)

# FFmpeg (ffmpeg-kit prebuilt): same bypass as build_vgmstream_macos.sh — keep
# USE_FFMPEG=OFF (vgmstream's path builds FFmpeg from source), define
# VGM_USE_FFMPEG ourselves + point at ffmpeg-kit framework Headers so
# ffmpeg_decoder.c compiles. The libav* symbols stay unresolved in this static
# lib and are satisfied at the final app link (ios podspec vendored_frameworks).
# Headers are identical across xcframework slices, so one -I (ios-arm64) serves
# both the device and simulator builds.
FFKIT="$PKG_DIR/ios/Libs/ffmpeg-kit"
FF_FLAGS=""
if [ -d "$FFKIT" ]; then
  FF_INC="$BUILD_DIR/ff_include"
  rm -rf "$FF_INC"; mkdir -p "$FF_INC"
  for lib in libavcodec libavformat libavutil libswresample libavfilter libswscale libavdevice; do
    hdr="$FFKIT/$lib.xcframework/ios-arm64/$lib.framework/Headers"
    [ -d "$hdr" ] && ln -s "$hdr" "$FF_INC/$lib"
  done
  FF_FLAGS="-DVGM_USE_FFMPEG -I$FF_INC"
  echo "vgmstream: FFmpeg enabled via ffmpeg-kit ($FFKIT)"
else
  echo "vgmstream: ffmpeg-kit not found at $FFKIT — building without FFmpeg"
fi

# Vorbis: le décodeur « custom » de vgmstream (Wwise, FSB, OGL…) est ENTIÈREMENT
# derrière #ifdef VGM_USE_VORBIS — sans lui, un .txtp Wwise est reconnu mais
# refuse de s'ouvrir, faute de codec. FFmpeg ne rattrape pas ce cas: Wwise stocke
# du Vorbis aux EN-TÊTES RETIRÉS, que seul ce décodeur sait reconstruire avant de
# les passer à vorbis_synthesis.
#
# Même contournement que FFmpeg ci-dessus: USE_VORBIS reste OFF (sa branche va
# CHERCHER libvorbis sur le réseau à la configuration), on définit VGM_USE_VORBIS
# nous-mêmes et on donne juste les en-têtes. Les symboles vorbis_*/ogg_* restent
# indéfinis dans ce .a et sont satisfaits au lien final, où le podspec compile
# les sources.
#
# Ces sources viennent de l'arbre vendoré par le submodule libopenmpt, qui les
# porte déjà (et n'en compile AUCUNE: son .a n'a zéro symbole vorbis, donc pas
# de doublon possible). config_types.h, lui, est généré par le build amont de
# libogg et absent de cet arbre — on le fournit depuis src/vorbis_compat/.
VORB_INC="$PKG_DIR/third_party/libopenmpt/include"
if [ -f "$VORB_INC/vorbis/lib/vorbisfile.c" ]; then
  VORB_FLAGS="-DVGM_USE_VORBIS -I$PKG_DIR/src/vorbis_compat -I$VORB_INC/ogg/include -I$VORB_INC/vorbis/include"
  echo "vgmstream: Vorbis custom activé (Wwise, FSB, OGL…)"
else
  VORB_FLAGS=""
  echo "vgmstream: libvorbis introuvable — Wwise Vorbis NE JOUERA PAS" >&2
  echo "  git submodule update --init packages/rewamp_audio/third_party/libopenmpt" >&2
fi

CMAKE_COMMON=(
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0
  -DCMAKE_SYSTEM_NAME=iOS
  -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
  -DCMAKE_C_FLAGS="$FF_FLAGS $VORB_FLAGS"
  -DCMAKE_CXX_FLAGS="$FF_FLAGS $VORB_FLAGS"
  -DBUILD_CLI=OFF
  -DBUILD_AUDACIOUS=OFF
  -DBUILD_STATIC=OFF
  -DUSE_MPEG=OFF
  -DUSE_VORBIS=OFF
  -DUSE_FFMPEG=OFF
  -DUSE_G7221=OFF
  -DUSE_G719=OFF
  -DUSE_ATRAC9=OFF
  -DUSE_CELT=OFF
  -DUSE_SPEEX=OFF
  -Wno-dev
  -DCMAKE_MESSAGE_LOG_LEVEL=WARNING
)

echo "==> Building device slice (arm64, iphoneos)…"
cmake -S "$SRC_DIR" -B "$BUILD_DIR/device" \
  "${CMAKE_COMMON[@]}" \
  -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_OSX_ARCHITECTURES=arm64
cmake --build "$BUILD_DIR/device" --target libvgmstream -j"$NCPU"
DEVICE_LIB="$BUILD_DIR/device/src/libvgmstream.a"

echo ""
echo "==> Building simulator slice (arm64 + x86_64, iphonesimulator)…"
cmake -S "$SRC_DIR" -B "$BUILD_DIR/simulator" \
  "${CMAKE_COMMON[@]}" \
  -DCMAKE_OSX_SYSROOT=iphonesimulator \
  -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"
cmake --build "$BUILD_DIR/simulator" --target libvgmstream -j"$NCPU"
SIM_LIB="$BUILD_DIR/simulator/src/libvgmstream.a"

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

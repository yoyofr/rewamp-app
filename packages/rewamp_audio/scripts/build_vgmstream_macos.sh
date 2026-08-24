#!/usr/bin/env bash
# Builds libvgmstream as a universal (arm64 + x86_64) static library for macOS.
# Output: macos/Libs/libvgmstream.a  (consumed by macos/rewamp_audio.podspec).
#
# Usage: ./packages/rewamp_audio/scripts/build_vgmstream_macos.sh
set -euo pipefail

PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$PKG_DIR/third_party/vgmstream"
BUILD_DIR="$PKG_DIR/build/vgmstream-macos"
OUT_DIR="$PKG_DIR/macos/Libs"

if [ ! -f "$SRC_DIR/src/libvgmstream.h" ]; then
  echo "error: vgmstream submodule missing. Run:" >&2
  echo "  git submodule update --init packages/rewamp_audio/third_party/vgmstream" >&2
  exit 1
fi

NCPU=$(sysctl -n hw.ncpu)

mkdir -p "$BUILD_DIR"

# FFmpeg (ffmpeg-kit prebuilt): vgmstream's own USE_FFMPEG path builds FFmpeg
# from source (treats FFMPEG_PATH as a source tree), which does NOT work with a
# prebuilt. Bypass it: keep USE_FFMPEG=OFF, but define VGM_USE_FFMPEG ourselves
# and point at the ffmpeg-kit framework headers so ffmpeg_decoder.c (always
# globbed, guarded by #ifdef VGM_USE_FFMPEG) compiles. The libav* symbols stay
# unresolved in this static lib and are satisfied at the final app link, where
# the macos podspec links + embeds the ffmpeg-kit frameworks.
FFKIT="$PKG_DIR/macos/Libs/ffmpeg-kit"
FF_FLAGS=""
if [ -d "$FFKIT" ]; then
  FF_INC="$BUILD_DIR/ff_include"
  rm -rf "$FF_INC"; mkdir -p "$FF_INC"
  for lib in libavcodec libavformat libavutil libswresample libavfilter libswscale libavdevice; do
    hdr="$FFKIT/$lib.xcframework/macos-arm64_x86_64/$lib.framework/Headers"
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

cmake -S "$SRC_DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=10.14 \
  -DCMAKE_C_FLAGS="$FF_FLAGS $VORB_FLAGS" \
  -DCMAKE_CXX_FLAGS="$FF_FLAGS $VORB_FLAGS" \
  -DBUILD_CLI=OFF \
  -DBUILD_AUDACIOUS=OFF \
  -DBUILD_STATIC=OFF \
  -DUSE_MPEG=OFF \
  -DUSE_VORBIS=OFF \
  -DUSE_FFMPEG=OFF \
  -DUSE_G7221=OFF \
  -DUSE_G719=OFF \
  -DUSE_ATRAC9=OFF \
  -DUSE_CELT=OFF \
  -DUSE_SPEEX=OFF \
  -Wno-dev -DCMAKE_MESSAGE_LOG_LEVEL=WARNING

cmake --build "$BUILD_DIR" --target libvgmstream -j"$NCPU"

mkdir -p "$OUT_DIR"
cp "$BUILD_DIR/src/libvgmstream.a" "$OUT_DIR/libvgmstream.a"

echo ""
echo "Built: $OUT_DIR/libvgmstream.a"
lipo -info "$OUT_DIR/libvgmstream.a" 2>/dev/null || true

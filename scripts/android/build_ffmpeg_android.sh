#!/usr/bin/env bash
# Construit un FFmpeg MINIMAL pour une ABI Android, posé là où le plugin le
# cherche (packages/rewamp_audio/third_party/ffmpeg-kit/<dossier>/ffmpeg).
#
# POURQUOI: ffmpeg-kit est abandonné et n'a jamais été vendoré qu'en arm64 et
# x86_64. Sans FFmpeg, une ABI compile et tourne mais vgmstream y perd EN
# SILENCE tous les formats dont le codec passe par FFmpeg (MP3, Vorbis, AAC,
# Opus, ATRAC3/3+, WMA, XMA, AC3…) — c'est ce qui gardait l'app en 64 bits seuls.
# Cible première: les box Android TV, souvent en armeabi-v7a seul même sur un
# SoC 64 bits.
#
# Même recette que scripts/appimage/build_ffmpeg_minimal.sh: `--disable-autodetect`
# coupe toute bibliothèque externe mais GARDE les décodeurs NATIFS de FFmpeg,
# c'est-à-dire tout ce que vgmstream demande. Dépendances résiduelles: libc,
# libm, libdl, libz — toutes fournies par Android.
#
# ⚠️ Deux exigences d'Android que l'artefact doit respecter, vérifiées à la fin:
#   * SONAME SANS VERSION (`libavcodec.so`, pas `.so.61`): l'APK n'embarque que
#     des `lib*.so` à plat, et le chargeur cherche exactement le nom inscrit
#     dans DT_NEEDED. `--target-os=android` donne ces noms-là.
#   * même NDK que Flutter (flutter.ndkVersion), sinon deux libc++/libunwind
#     d'âges différents dans le même processus.
#
# Usage:  scripts/android/build_ffmpeg_android.sh [armeabi-v7a]
set -euo pipefail

ABI="${1:-armeabi-v7a}"
FFMPEG_VERSION="${REWAMP_FFMPEG_VERSION:-7.1}"
API=26   # minSdk de l'app (AAudio)
NDK_VERSION="${REWAMP_NDK_VERSION:-28.2.13676358}"
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
NDK="${ANDROID_NDK_HOME:-$SDK/ndk/$NDK_VERSION}"

bold() { printf '\033[1m==> %s\033[0m\n' "$1"; }
die()  { printf '\033[31mERREUR: %s\033[0m\n' "$1" >&2; exit 1; }

case "$ABI" in
  armeabi-v7a) TRIPLE=armv7a-linux-androideabi; ARCH=arm;  CPU=armv7-a; DIR=android-arm ;;
  *) die "ABI non prévue: $ABI (armeabi-v7a seulement; arm64/x86_64 viennent de ffmpeg-kit)" ;;
esac

[[ -d "$NDK" ]] || die "NDK $NDK_VERSION introuvable: $NDK (sdkmanager \"ndk;$NDK_VERSION\")"
HOST_TAG=$(ls "$NDK/toolchains/llvm/prebuilt" | head -1)
TC="$NDK/toolchains/llvm/prebuilt/$HOST_TAG"
CC="$TC/bin/${TRIPLE}${API}-clang"
[[ -x "$CC" ]] || die "compilateur absent: $CC"

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$SRC/app/build/ffmpeg-android"
OUT="$SRC/packages/rewamp_audio/third_party/ffmpeg-kit/$DIR/ffmpeg"
TARBALL="ffmpeg-${FFMPEG_VERSION}.tar.xz"
JOBS="$(sysctl -n hw.ncpu 2>/dev/null || nproc)"

if [[ -f "$OUT/include/libavcodec/avcodec.h" && -f "$OUT/lib/libavcodec.so" ]]; then
  bold "FFmpeg $ABI déjà présent: $OUT  (effacer pour reconstruire)"
  exit 0
fi

mkdir -p "$WORK"
cd "$WORK"
if [[ ! -f "$TARBALL" ]]; then
  bold "Téléchargement de FFmpeg ${FFMPEG_VERSION}"
  curl -fL --retry 3 -o "$TARBALL" "https://ffmpeg.org/releases/${TARBALL}"
fi
# Un arbre de source PAR ABI: configure écrit config.h en place.
BUILD="$WORK/ffmpeg-${FFMPEG_VERSION}-$ABI"
if [[ ! -d "$BUILD" ]]; then
  mkdir -p "$BUILD"
  tar xf "$TARBALL" -C "$BUILD" --strip-components=1
fi
cd "$BUILD"

if [[ ! -f config.h ]]; then
  bold "configure ($ABI, API $API, NDK $NDK_VERSION)"
  ./configure \
    --prefix="$OUT" \
    --enable-cross-compile --target-os=android \
    --arch="$ARCH" --cpu="$CPU" \
    --cc="$CC" --cxx="${CC}++" \
    --nm="$TC/bin/llvm-nm" --ar="$TC/bin/llvm-ar" --ranlib="$TC/bin/llvm-ranlib" \
    --strip="$TC/bin/llvm-strip" \
    --sysroot="$TC/sysroot" \
    --enable-neon \
    --enable-shared --disable-static \
    --disable-programs --disable-doc \
    --disable-avdevice --disable-avfilter --disable-swscale --disable-postproc \
    --disable-encoders --disable-muxers --disable-devices \
    --disable-network --disable-protocols --enable-protocol=file \
    --disable-autodetect \
    --enable-zlib \
    --disable-debug \
    --enable-pic
fi

bold "make -j$JOBS"
make -j"$JOBS"
make install

# ── Contrôles sur l'ARTEFACT, pas sur les drapeaux ─────────────────────────────
READELF="$TC/bin/llvm-readelf"
bold "Contrôle des bibliothèques produites"
bad=0
for so in "$OUT"/lib/lib*.so; do
  [[ -L "$so" ]] && continue
  name="$(basename "$so")"
  soname="$("$READELF" -d "$so" | sed -n 's/.*(SONAME).*\[\(.*\)\]/\1/p')"
  if [[ "$soname" != "$name" ]]; then
    echo "    $name: SONAME « $soname » ≠ nom du fichier"; bad=1
  fi
  ext="$("$READELF" -d "$so" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p' \
         | grep -vE '^(libc|libm|libdl|libz|liblog|libav[a-z]*|libsw[a-z]*)\.so$' || true)"
  if [[ -n "$ext" ]]; then
    echo "    $name dépend de: $ext"; bad=1
  fi
  cls="$("$READELF" -h "$so" | sed -n 's/.*Class: *//p')"
  [[ "$cls" == "ELF32" ]] || { echo "    $name: classe $cls, ELF32 attendu"; bad=1; }
done
[[ $bad -eq 0 ]] || die "artefact non conforme"
echo "    SONAME à plat, ELF32, dépendances système seulement ✓"
bold "OK — $OUT  ($(du -sh "$OUT/lib" | cut -f1))"
ls -la "$OUT"/lib/*.so | sed 's/^/    /'

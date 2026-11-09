#!/usr/bin/env bash
# Construit un FFmpeg STATIQUE et MINIMAL pour le wasm, celui que vgmstream lie
# par REWAMP_FFMPEG_DIR (même contournement qu'ailleurs: le CMake de vgmstream ne
# sait que BÂTIR FFmpeg depuis ses sources, pas lier un prébuilt).
#   ./build_ffmpeg.sh        → build/ffmpeg/{include,lib/*.a}
#
# La liste de démultiplexeurs / parseurs / décodeurs est CELLE DE VGMSTREAM
# (third_party/vgmstream/cmake/dependencies/ffmpeg.cmake): c'est le scope dont
# ses formats ont besoin, et rien de plus — un FFmpeg complet pèserait plusieurs
# dizaines de Mo de wasm. À resynchroniser quand vgmstream change la sienne.
#
# ⚠️ `-pthread` obligatoire même si FFmpeg n'a pas de threads ici: le module
# final a une mémoire PARTAGÉE, et wasm-ld refuse tout objet compilé sans la
# fonctionnalité `atomics` (« --shared-memory is disallowed »).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
ver="${REWAMP_FFMPEG_VERSION:-7.1}"
work="$here/build/ffmpeg-src"
out="$here/build/ffmpeg"
command -v emconfigure >/dev/null || { echo "emconfigure introuvable: brew install emscripten" >&2; exit 1; }

if [[ -f "$out/lib/libavcodec.a" && -f "$out/include/libavcodec/avcodec.h" ]]; then
  echo "FFmpeg wasm déjà présent: $out (effacer pour reconstruire)"; exit 0
fi

mkdir -p "$work"; cd "$work"
tarball="ffmpeg-$ver.tar.xz"
[[ -f "$tarball" ]] || curl -fL --retry 3 -o "$tarball" "https://ffmpeg.org/releases/$tarball"
[[ -d "ffmpeg-$ver" ]] || tar xf "$tarball"
cd "ffmpeg-$ver"

demuxers=ac3,eac3,spdif,asf,xwma,mov,oma,xmv,ogg,flac,wav,aac,mp3,smacker,bink,caf,mpc,mpc8,tak,ape,flv,voc
parsers=ac3,mpegaudio,xma,vorbis,opus
decoders=ac3,eac3,wmapro,wmav1,wmav2,xma1,xma2,aac,atrac3,atrac3p,mp2float,mp3float,smackaud,binkaudio_dct,binkaudio_rdft,pcm_s16be,pcm_s16be_planar,pcm_s16le,pcm_s16le_planar,pcm_s8,pcm_s8_planar,pcm_u8,flac,vorbis,mpc7,mpc8,alac,adpcm_ima_qt,adpcm_ima_dk3,adpcm_ima_dk4,tak,ape,adpcm_swf,opus

emconfigure ./configure \
  --prefix="$out" \
  --cc=emcc --cxx=em++ --ar=emar --ranlib=emranlib --nm=emnm \
  --enable-cross-compile --target-os=none --arch=x86_32 \
  --enable-static --disable-shared \
  --disable-programs --disable-doc --disable-autodetect \
  --disable-avdevice --disable-avfilter --disable-swscale --disable-postproc \
  --disable-network --disable-everything \
  --enable-protocol=file \
  --enable-demuxer="$demuxers" --enable-parser="$parsers" --enable-decoder="$decoders" \
  --enable-swresample \
  --disable-runtime-cpudetect --disable-asm --disable-inline-asm \
  --disable-pthreads --disable-w32threads --disable-os2threads \
  --disable-debug \
  --extra-cflags="-O3 -pthread" --extra-ldflags="-pthread"

make -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
make install
ls -l "$out/lib"/*.a

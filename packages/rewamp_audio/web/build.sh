#!/usr/bin/env bash
# Construit le moteur wasm et prépare site/dist/ (noms hachés, assets en packs, .br).
#   ./build.sh                       tous les moteurs (FFmpeg de vgmstream construit au 1er passage)
#   REWAMP_WITH_UADE=0 ./build.sh    mêmes drapeaux que les autres plateformes
#   BUILD_DIR=/tmp/rw ./build.sh     dossier de build ailleurs
#   REWAMP_WEB_NAMES=1 ./build.sh    garde les noms de fonctions (pile lisible, +2 Mo)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
build="${BUILD_DIR:-$here/build}"
command -v emcmake >/dev/null || { echo "emcmake introuvable: brew install emscripten" >&2; exit 1; }

# vgmstream a besoin de FFmpeg: build_ffmpeg.sh le construit une fois (statique,
# minimal) dans build/ffmpeg, que CMakeLists.txt trouve seul.
if [[ "${REWAMP_WITH_VGMSTREAM:-1}" != 0 ]]; then "$here/build_ffmpeg.sh" > "$here/build_ffmpeg.log" 2>&1 \
  || { tail -20 "$here/build_ffmpeg.log" >&2; echo "build.sh: FFmpeg wasm a échoué (build_ffmpeg.log)" >&2; exit 1; }; fi

emcmake cmake -S "$here" -B "$build" -DCMAKE_BUILD_TYPE=Release -DREWAMP_WEB_NAMES="${REWAMP_WEB_NAMES:-0}"
cmake --build "$build" -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)" 2>&1 | tee "$build/build.log" | grep -E "error|\[100%\]" || true

# Un appel à signature incompatible devient un PIÈGE à l'exécution (voir le
# bloc zlib de CMakeLists.txt): l'avertissement de wasm-ld est donc une erreur.
if grep -q "function signature mismatch" "$build/build.log"; then
  grep -A2 "function signature mismatch" "$build/build.log" >&2
  echo "build.sh: signature incompatible au lien, voir ci-dessus" >&2; exit 1
fi

node "$here/tools/dist.mjs" "$build"
echo "Démo: node $here/site/server.mjs  →  http://127.0.0.1:8797/"

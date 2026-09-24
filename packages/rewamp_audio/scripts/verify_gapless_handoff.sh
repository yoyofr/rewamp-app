#!/bin/bash
# Oracle mécanique du relais gapless (rewamp_datasource.c), SANS device audio:
# décodeurs factices, ds_read piloté à la cadence du vrai rappel (512 frames /
# 11,6 ms). Vérifie: zéro frame perdue et zéro silence à la frontière, serial
# au franchissement CONSOMMATEUR, fermeture séquentielle des décodeurs,
# curseur relatif à la piste, et refus propre sur désaccord de taux.
#
# ⚠️ La cadence est le point qui compte: un harnais qui draine plus vite que
# le producteur ne remplit compte du SILENCE DE BOURRAGE (le chemin underrun
# de ds_read) et conclut à tort que le relais fuit.
set -e
cd "$(dirname "$0")"
B=/tmp/rewamp_gapless_harness
mkdir -p "$B"
cat > "$B/CMakeLists.txt" <<CMAKE
cmake_minimum_required(VERSION 3.16)
project(dstest LANGUAGES C)
set(SRC "\${RW}/packages/rewamp_audio/src")
add_executable(dstest "\${RW}/packages/rewamp_audio/scripts/verify_gapless_handoff.c"
               "\${SRC}/rewamp_datasource.c" "\${SRC}/miniaudio_impl.c")
target_include_directories(dstest PRIVATE "\${SRC}")
find_package(Threads REQUIRED)
target_link_libraries(dstest PRIVATE Threads::Threads)
if(APPLE)
  target_link_libraries(dstest PRIVATE "-framework CoreAudio" "-framework AudioToolbox" "-framework CoreFoundation")
endif()
CMAKE
cmake -S "$B" -B "$B/build" -DRW="$(cd ../../.. && pwd)" -DCMAKE_BUILD_TYPE=Release > /dev/null
cmake --build "$B/build" -j8 > /dev/null
"$B/build/dstest"

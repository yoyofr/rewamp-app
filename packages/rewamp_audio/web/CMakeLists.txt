# Moteur Rewamp en WebAssembly (Emscripten) — voir README.md.
#
#   ./build.sh            (emcmake + build + copie vers site/)
#
# Même module que les autres plateformes (cmake/rewamp.cmake): mêmes sources,
# mêmes drapeaux REWAMP_WITH_*. Ce qui est PROPRE au web est ici et dans
# src/web/ (sortie audio, couche GL).
cmake_minimum_required(VERSION 3.14)
project(rewamp_web C CXX)

if(NOT EMSCRIPTEN)
  message(FATAL_ERROR "web/: à configurer par emcmake (Emscripten), voir README.md")
endif()

# Threads (producteur, pompe de sortie, seek, threads internes de reSIDfp),
# exceptions C++ (sidplayfp, zxtune…) et setjmp/longjmp (UADE) natifs wasm.
# À la compilation ET à l'édition de liens.
set(_rw_web_flags "-pthread -fwasm-exceptions -sSUPPORT_LONGJMP=wasm")
set(CMAKE_C_FLAGS   "${CMAKE_C_FLAGS} ${_rw_web_flags}")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${_rw_web_flags}")

get_filename_component(_rw_pkg "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)

# zlib vendorée, comme sous Windows (Emscripten n'en fournit qu'en « port »).
# ⚠️ HAVE_UNISTD_H doit être PUBLIC: posé en PRIVATE, zlib se compile avec un
# z_off_t 64 bits et ses appelants (libvgm FileLoader) avec 32 bits; wasm-ld
# ne fait qu'AVERTIR (« function signature mismatch: gzseek ») et remplace
# l'appel par un piège — un .vgz plante à l'exécution.
file(GLOB _rw_zlib "${_rw_pkg}/third_party/zlib/*.c")
add_library(z STATIC ${_rw_zlib})
target_include_directories(z PUBLIC "${_rw_pkg}/third_party/zlib")
target_compile_definitions(z PUBLIC HAVE_UNISTD_H)

# vgmstream veut FFmpeg: celui de build_ffmpeg.sh (statique, minimal) s'il est
# là, sinon vgmstream est coupé par défaut — sans FFmpeg il ouvrirait ses
# formats Vorbis/Opus/AAC/ATRAC/XMA… et rendrait du silence.
set(_rw_ffmpeg "${CMAKE_CURRENT_SOURCE_DIR}/build/ffmpeg")
if(NOT DEFINED REWAMP_FFMPEG_DIR AND NOT DEFINED ENV{REWAMP_FFMPEG_DIR}
   AND EXISTS "${_rw_ffmpeg}/lib/libavcodec.a")
  set(REWAMP_FFMPEG_DIR "${_rw_ffmpeg}" CACHE PATH "")
endif()
if(NOT REWAMP_FFMPEG_DIR AND NOT DEFINED ENV{REWAMP_FFMPEG_DIR}
   AND NOT DEFINED REWAMP_WITH_VGMSTREAM AND NOT DEFINED ENV{REWAMP_WITH_VGMSTREAM})
  message(STATUS "web: pas de FFmpeg (./build_ffmpeg.sh) ⇒ vgmstream coupé")
  set(REWAMP_WITH_VGMSTREAM OFF CACHE BOOL "")
endif()

include("${_rw_pkg}/cmake/rewamp.cmake")

add_executable(rewamp_audio ${REWAMP_CORE_SOURCES}
  "${CMAKE_CURRENT_SOURCE_DIR}/rewamp_web_main.c")
# Visualiseurs: le contexte WebGL 2 de la page (rewamp_gl_web.c) et les six
# renderers partagés en UNE TU (rewamp_viz_web.cpp, montage Linux/Android).
# projectM, s'il est là, rend dans le même contexte depuis sa propre TU.
target_sources(rewamp_audio PRIVATE
  "${REWAMP_SRC_DIR}/web/rewamp_gl_web.c"
  "${REWAMP_SRC_DIR}/web/rewamp_viz_web.cpp")
rewamp_configure_decoders(rewamp_audio)

# Furnace: workPool.cpp appelle abort() sans inclure <cstdlib> (amont).
if(TARGET rewamp_furnace)
  target_compile_options(rewamp_furnace PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:-include;cstdlib>")
endif()

# ⚠️ PTHREAD_POOL_SIZE: dans un NAVIGATEUR un nouveau Worker de pthread ne
# démarre que quand le créateur rend la main à sa boucle d'événements. Un fil
# qui crée puis JOINT (reSIDfp lance 6 threads pour ses tables de filtre) gèle
# donc si le pool préparé ne suffit pas — Node ne le montre pas. 12 couvre
# producteur + pompe + seek + reSIDfp; STRICT=2 fait ÉCHOUER un dépassement au
# lieu de geler.
target_link_options(rewamp_audio PRIVATE
  -pthread -fwasm-exceptions -sSUPPORT_LONGJMP=wasm
  -sPTHREAD_POOL_SIZE=12 -sPTHREAD_POOL_SIZE_STRICT=2
  # ⚠️ MAXIMUM_MEMORY: une mémoire PARTAGÉE (threads) ne peut pas être
  # réallouée en grandissant, donc le navigateur RÉSERVE d'emblée tout le
  # maximum. Safari le fait vraiment: à 2 Go, quelques rechargements (les
  # Workers des pages précédentes pas encore libérés) suffisaient à rendre
  # « RangeError: Out of memory » au démarrage. 1 Go couvre largement le plus
  # gros cas mesuré (album PSF de 87 Mo dont l'archive déplie 105 Mo).
  -sALLOW_MEMORY_GROWTH=1 -sINITIAL_MEMORY=64MB -sMAXIMUM_MEMORY=1GB -sSTACK_SIZE=1MB
  -sMODULARIZE=1 -sEXPORT_NAME=RewampAudio -sENVIRONMENT=web,worker,node
  -sEXPORTED_RUNTIME_METHODS=FS,ccall,cwrap,HEAPF32,UTF8ToString,GL
  -sMAX_WEBGL_VERSION=2 -sMIN_WEBGL_VERSION=2
  -sEXPORTED_FUNCTIONS=_main,_malloc,_free
  # Les greffons partagent des symboles faibles hérités des bibliothèques
  # vendorées, comme sur les autres cibles (-multiply_defined sur Apple).
  -Wl,--allow-multiple-definition)
# Noms de fonctions dans le wasm: une pile lisible pour un gel (CDP), mais 2 Mo
# de plus — hors du build par défaut (REWAMP_WEB_NAMES=1 ./build.sh).
option(REWAMP_WEB_NAMES "web: garder les noms de fonctions dans le wasm" OFF)
if(REWAMP_WEB_NAMES)
  target_link_options(rewamp_audio PRIVATE --profiling-funcs)
endif()

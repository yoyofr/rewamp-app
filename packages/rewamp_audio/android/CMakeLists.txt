cmake_minimum_required(VERSION 3.18.1)
project(rewamp_audio VERSION 0.0.1)

include("${CMAKE_CURRENT_SOURCE_DIR}/../cmake/rewamp.cmake")

# zxtune — validated on Android; enabled here while the cmake option stays OFF
# by default (desktop not yet validated). Furnace is ON by default in rewamp.cmake.
set(REWAMP_WITH_ZXTUNE ON CACHE BOOL "" FORCE)

# FFmpeg (ffmpeg-kit prebuilt) for vgmstream — point REWAMP_FFMPEG_DIR at the
# per-ABI ffmpeg-kit slice. rewamp.cmake does NOT feed this to vgmstream's own
# USE_FFMPEG (which would ./configure-build FFmpeg from source); it uses the
# prebuilt-bypass (VGM_USE_FFMPEG + link the .so). Only 64-bit slices are
# vendored by ffmpeg-kit; armeabi-v7a (box Android TV) gets OURS, built by
# scripts/android/build_ffmpeg_android.sh into android-arm/. build.gradle's
# copyFfmpegLibs packages the .so.
set(_ffk "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/ffmpeg-kit")
if(ANDROID_ABI STREQUAL "arm64-v8a")
  set(REWAMP_FFMPEG_DIR "${_ffk}/android-arm64/ffmpeg" CACHE PATH "" FORCE)
elseif(ANDROID_ABI STREQUAL "x86_64")
  set(REWAMP_FFMPEG_DIR "${_ffk}/android-x86_64/ffmpeg" CACHE PATH "" FORCE)
elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
  set(REWAMP_FFMPEG_DIR "${_ffk}/android-arm/ffmpeg" CACHE PATH "" FORCE)
endif()
# ⚠️ Sans FFmpeg une ABI compile et TOURNE, mais vgmstream y perd en silence
# MP3, Vorbis, AAC, Opus, ATRAC, WMA, XMA… — l'échec doit se VOIR ici, pas dans
# un rapport de bug des mois plus tard.
# Échappatoire, comme sous Linux/Windows: REWAMP_ALLOW_NO_FFMPEG=1 (environnement
# ou -D) construit SANS FFmpeg, en connaissance de cause — c'est le cas d'un
# clone du dépôt PUBLIC, où les tranches ffmpeg-kit ne sont pas redistribuées.
if(NOT REWAMP_FFMPEG_DIR OR NOT EXISTS "${REWAMP_FFMPEG_DIR}/lib/libavcodec.so")
  if(REWAMP_ALLOW_NO_FFMPEG OR "$ENV{REWAMP_ALLOW_NO_FFMPEG}" STREQUAL "1")
    message(WARNING "FFmpeg absent pour ${ANDROID_ABI}: vgmstream SANS MP3/Vorbis/AAC/Opus/ATRAC/WMA/XMA (REWAMP_ALLOW_NO_FFMPEG).")
    set(REWAMP_FFMPEG_DIR "" CACHE PATH "" FORCE)
  else()
    message(FATAL_ERROR
      "FFmpeg absent pour ${ANDROID_ABI} (${REWAMP_FFMPEG_DIR}).\n"
      "Construire: scripts/android/build_ffmpeg_android.sh ${ANDROID_ABI}\n"
      "(arm64/x86_64: ou les tranches ffmpeg-kit sous third_party/ffmpeg-kit).\n"
      "Ou, en connaissance de cause: REWAMP_ALLOW_NO_FFMPEG=1 (vgmstream perd\n"
      "alors MP3, Vorbis, AAC, Opus, ATRAC, WMA, XMA).")
  endif()
endif()

get_filename_component(REWAMP_ANDROID_SRC "${CMAKE_CURRENT_SOURCE_DIR}/../src/android" ABSOLUTE)

add_library(rewamp_audio SHARED
  ${REWAMP_CORE_SOURCES}
  "${REWAMP_ANDROID_SRC}/rewamp_gl_android.cpp"
  "${REWAMP_ANDROID_SRC}/rewamp_viz_android.cpp"
)

rewamp_configure_decoders(rewamp_audio)

# libopenmpt and vgmstream each vendor minimp3 → duplicate mp3dec_* symbols.
# Both are the same upstream minimp3 (identical decode), so let the linker keep
# the first definition rather than erroring.
target_link_options(rewamp_audio PRIVATE "-Wl,--allow-multiple-definition")

# GLES flag: selects "#version 300 es" preamble in rewamp_viz_render.cpp
target_compile_definitions(rewamp_audio PRIVATE REWAMP_GL_GLES=1)

# miniaudio on Android uses AAudio / OpenSL ES
find_library(LOG_LIB log)
find_library(ANDROID_LIB android)

target_link_libraries(rewamp_audio PRIVATE
  ${LOG_LIB}
  ${ANDROID_LIB}
)

# EGL + GLES3 for oscilloscope
find_library(EGL_LIB EGL)
find_library(GLES3_LIB GLESv3)
if(EGL_LIB AND GLES3_LIB)
  target_link_libraries(rewamp_audio PRIVATE ${EGL_LIB} ${GLES3_LIB})
else()
  message(WARNING "EGL or GLESv3 not found — GPU oscilloscope disabled")
endif()

# AAudio (Android 8.0+)
find_library(AAUDIO_LIB aaudio)
if(AAUDIO_LIB)
  target_link_libraries(rewamp_audio PRIVATE ${AAUDIO_LIB})
endif()

# OpenSL ES fallback
find_library(OPENSL_LIB OpenSLES)
if(OPENSL_LIB)
  target_link_libraries(rewamp_audio PRIVATE ${OPENSL_LIB})
endif()

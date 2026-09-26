cmake_minimum_required(VERSION 3.14)

set(PLUGIN_NAME "rewamp_audio")

set(REWAMP_WITH_VGM ON CACHE BOOL "" FORCE)
include("${CMAKE_CURRENT_SOURCE_DIR}/../cmake/rewamp.cmake")

add_library(${PLUGIN_NAME} SHARED ${REWAMP_CORE_SOURCES})

# ⚠️ RUNPATH: ces bibliothèques partent dans le bundle avec le RUNPATH de
# l'arbre de BUILD, et on ne le corrige PAS ici — voir scripts/appimage/.
#
# Le gabarit Flutter installe les greffons par `install(FILES ...)` et non
# `install(TARGETS ...)`: CMake ne réécrit donc jamais leur RUNPATH. Seul
# l'exécutable reçoit `$ORIGIN/lib`. Et un `DT_RUNPATH` ne s'HÉRITE PAS: pour
# résoudre les dépendances de `librewamp_audio.so`, l'éditeur de liens dynamique
# lit le RUNPATH de CETTE bibliothèque, pas celui de l'exécutable.
#
# Mesuré le 2026-09-21: l'AppImage tournait en chargeant `libavcodec.so.61`
# depuis `…/app/build/appimage/ffmpeg/lib`, un chemin qui n'existe sur aucune
# autre machine.
#
# ⚠️ Tenté et ANNULÉ: `BUILD_WITH_INSTALL_RPATH` + `INSTALL_RPATH "$ORIGIN"`.
# Ça retire le RPATH de build DÈS la construction, donc l'édition de liens du
# greffon ne trouve plus les dépendances TRANSITIVES de librewamp_audio.so
# (« libswresample.so.5 … not found (try using -rpath or -rpath-link) ») — et
# ça ne réglerait de toute façon que NOS deux cibles, pas les sept greffons
# tiers qui ont exactement le même RUNPATH de build.
#
# La relocalisation est donc faite là où elle est vraiment exigée, en UNE passe
# sur toutes les bibliothèques: `patchelf --set-rpath '$ORIGIN'` dans
# scripts/appimage/build_appimage.sh, avec un contrôle qui ÉCHOUE si un RUNPATH
# sort de $ORIGIN.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  C_VISIBILITY_PRESET hidden
)

target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
rewamp_configure_decoders(${PLUGIN_NAME})

# vgmstream et libopenmpt embarquent CHACUN leur copie de minimp3, avec les
# mêmes noms de symboles (mp3dec_init, mp3dec_decode_frame). Aucun des deux
# n'est de trop — ce sont deux décodeurs séparés qui l'utilisent en interne —
# et les renommer voudrait dire patcher deux amonts. android/CMakeLists.txt
# pose déjà exactement la même option pour la même raison.
target_link_options(${PLUGIN_NAME} PRIVATE "-Wl,--allow-multiple-definition")

# miniaudio requires these on Linux
target_link_libraries(${PLUGIN_NAME} PRIVATE
  pthread
  m
  dl
)

# miniaudio ALSA / PulseAudio backends — add pkg-config libs if present
find_package(PkgConfig QUIET)
if(PKG_CONFIG_FOUND)
  pkg_check_modules(ALSA QUIET alsa)
  if(ALSA_FOUND)
    target_link_libraries(${PLUGIN_NAME} PRIVATE ${ALSA_LIBRARIES})
    target_include_directories(${PLUGIN_NAME} PRIVATE ${ALSA_INCLUDE_DIRS})
  endif()
endif()

# -- Plugin GTK: visualiseurs OpenGL ES --------------------------------------
# Cible SEPAREE du moteur, et c'est impose par Flutter: la boucle
# FLUTTER_PLUGIN_LIST de generated_plugins.cmake lie une cible nommee
# exactement `<paquet>_plugin`, tandis que Dart ouvre le moteur par son propre
# nom (librewamp_audio.so). Les deux sont empaquetees -- la premiere par
# $<TARGET_FILE:...>, la seconde par ${rewamp_audio_bundled_libraries}.
#
# EGL/GLES viennent du SYSTEME (Mesa), pas d'ANGLE: Linux fournit GLES 3.0
# nativement, ce que REWAMP_GL_GLES=1 et les preambules `#version 300 es` des
# renderers partages ciblent deja.
find_package(PkgConfig REQUIRED)
pkg_check_modules(REWAMP_GTK REQUIRED IMPORTED_TARGET gtk+-3.0)
pkg_check_modules(REWAMP_EGL REQUIRED IMPORTED_TARGET egl glesv2)

add_library(rewamp_audio_plugin SHARED
  "${CMAKE_CURRENT_SOURCE_DIR}/rewamp_audio_plugin.cc")
set_target_properties(rewamp_audio_plugin PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(rewamp_audio_plugin PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(rewamp_audio_plugin
  INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(rewamp_audio_plugin PRIVATE
  flutter PkgConfig::REWAMP_GTK PkgConfig::REWAMP_EGL ${PLUGIN_NAME})
if(REWAMP_WITH_PROJECTM)
  target_compile_definitions(rewamp_audio_plugin PRIVATE REWAMP_WITH_PROJECTM=1)
endif()

# Les renderers partages + la couche EGL vivent dans le MOTEUR (le plugin GTK
# n'est qu'un pont vers le registrar), donc ils se compilent dans ${PLUGIN_NAME}.
target_sources(${PLUGIN_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/linux/rewamp_gl_linux.cc"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/linux/rewamp_viz_linux.cc"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/linux/rewamp_viz_stats.cc")
target_compile_definitions(${PLUGIN_NAME} PRIVATE REWAMP_GL_GLES=1)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::REWAMP_EGL)

# Flutter empaquette un plugin FFI en lisant CETTE variable, remontée au scope
# parent (voir la boucle FLUTTER_FFI_PLUGIN_LIST de generated_plugins.cmake).
# Sans elle la .so est bel et bien CONSTRUITE — la build est verte — mais elle
# n'est jamais copiée dans bundle/lib/, et l'app meurt au démarrage sur un
# DynamicLibrary.open('librewamp_audio.so') introuvable. C'est le genre d'échec
# qu'une build réussie ne révèle pas: il se voit à l'exécution, ou en listant
# bundle/lib/.
set(rewamp_audio_bundled_libraries
  $<TARGET_FILE:${PLUGIN_NAME}>
  PARENT_SCOPE
)

cmake_minimum_required(VERSION 3.14)

set(PLUGIN_NAME "rewamp_audio")

# ── Conformité MSVC, posée au scope du DOSSIER ───────────────────────────────
#
# Le reste du dépôt passe par `target_compile_*`, et pour une bonne
# raison: une option de COMPORTEMENT doit viser une cible, sinon un
# décodeur se comporte autrement que sur Apple. Ce bloc-ci est l'exception
# ASSUMÉE, et elle tient à trois choses: ce sont des drapeaux de CONFORMITÉ au
# standard (pas de comportement), ils ne concernent QUE cl.exe, et ils doivent
# couvrir les ~41 cibles statiques que `rewamp_configure_decoders` crée plus
# bas — les viser une par une voudrait dire 41 sites et un oubli garanti au
# prochain moteur ajouté. `add_compile_options`/`add_compile_definitions`
# atteignent C **et** C++, contrairement à un `CMAKE_CXX_FLAGS` global, qui
# n'atteindrait jamais les sources C — c'est lui qui est vraiment interdit.
#
# ⚠️ Doit rester AVANT la création des cibles: CMake lit les propriétés de
# dossier au moment où la cible naît, pas à la fin de la configuration.
if(MSVC)
  # /Zc:preprocessor — préprocesseur conforme (C99/C++11). Sans lui libopenmpt
  #   avertit « C++ preprocessor is not standard conforming » depuis
  #   mpt/check/compiler.hpp, et ses macros variadiques se déplient de travers.
  # /Zc:__cplusplus — sans lui `__cplusplus` vaut 199711L quel que soit
  #   /std:..., et libsidplayfp s'arrête net sur `#error "This is not a C++11
  #   compiler"` (siddefs-fp.h) alors que le compilateur fait du C++17.
  # /bigobj — un .obj de MSVC plafonne à 65 535 sections; les coeurs de puces
  #   générés par macro (libvgm, furnace) le dépassent.
  add_compile_options(/Zc:preprocessor /Zc:__cplusplus /bigobj)
  # _USE_MATH_DEFINES — `M_PI` n'est PAS dans le <math.h> standard, et MSVC
  #   s'y tient. 118 erreurs à lui seul (furnace, projectM, et plusieurs
  #   coeurs). Les deux _CRT_* retirent des erreurs de dépréciation sur des
  #   fonctions POSIX que tous ces arbres vendorés utilisent (`strdup`,
  #   `fopen`, `read`…), que MSVC refuse par défaut.
  # NOMINMAX — `windows.h` définit `min` et `max` comme des MACROS, qui cassent
  #   `std::min(...)` et `std::max(...)` partout où elles sont visibles. Le
  #   message ne parle pas de macros: il sort en « '(' jeton non conforme à
  #   droite de '::' », sur du code parfaitement valide (furnace, vio2sf).
  #   ⚠️ Ça ne se déclenche que là où windows.h finit par entrer, donc l'ajout
  #   d'un `#include <windows.h>` dans un arbre vendoré peut réveiller l'erreur
  #   AILLEURS. C'est arrivé ici.
  add_compile_definitions(_USE_MATH_DEFINES _CRT_SECURE_NO_WARNINGS
                          _CRT_NONSTDC_NO_DEPRECATE NOMINMAX)

  # ⚠️ `app/windows/CMakeLists.txt` (gabarit Flutter) pose `-DUNICODE
  # -D_UNICODE` au scope de SON dossier, et les sous-répertoires l'héritent.
  # Pour le runner c'est juste; pour le MOTEUR c'est faux, et de trois façons
  # qui n'ont pas le même symptôme:
  #   * MACLib et pmdmini viennent de vrais players Windows de l'époque MBCS:
  #     leur branche Windows est prise, donc `TCHAR` devient `wchar_t` et leurs
  #     appels Win32 basculent sur les variantes W alors qu'ils passent des
  #     `char*` (`FindFirstFileW`, `GetLogicalDriveStringsW`, `music_load`…).
  #   * sundog (SunVox) fait de même, et pousse jusqu'à passer un callback
  #     ANSI à `DirectSoundEnumerateW`.
  # Notre propre code C/C++ n'utilise PAS `TCHAR`: il manipule de l'UTF-8 et
  # appelle explicitement les variantes qu'il veut. Retirer les deux defines
  # pour CE dossier est donc la correction de fond, et elle vaut mieux qu'un
  # `/UUNICODE` par cible — tenté d'abord, et dépendant de l'ordre des options
  # sur la ligne de commande (les defines de CMake sortent AVANT les
  # `AdditionalOptions`, donc le `/U` ne gagnait pas).
  #
  # ⚠️ Un `remove_definitions` agit sur la propriété de DOSSIER, donc il doit
  # rester AVANT la création des cibles, comme les options ci-dessus.
  remove_definitions(-DUNICODE -D_UNICODE)
endif()

set(REWAMP_WITH_VGM ON CACHE BOOL "" FORCE)
include("${CMAKE_CURRENT_SOURCE_DIR}/../cmake/rewamp.cmake")

add_library(${PLUGIN_NAME} SHARED ${REWAMP_CORE_SOURCES})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  C_VISIBILITY_PRESET hidden
)

target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Visualiseurs: l'option et le dossier d'ANGLE sont posés AVANT
# rewamp_configure_decoders, qui s'en sert pour décider de bâtir projectM. Le
# reste du câblage est plus bas (« Greffon de plateforme »).
rewamp_option(REWAMP_WINDOWS_VIZ "Visualiseurs OpenGL ES (ANGLE) sous Windows" ON)
set(REWAMP_ANGLE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/Libs/angle")
if(REWAMP_WINDOWS_VIZ AND
   (NOT EXISTS "${REWAMP_ANGLE_DIR}/lib/libEGL.lib"
    OR NOT EXISTS "${REWAMP_ANGLE_DIR}/include/GLES3/gl3.h"))
  # ERREUR, pas un repli muet: `flutter build` filtre STATUS et WARNING, et
  # des visualiseurs qui disparaissent en silence sont exactement la panne que
  # ce dépôt documente partout.
  message(FATAL_ERROR
    "Windows: ANGLE est absent de ${REWAMP_ANGLE_DIR}.\n"
    "Les visualiseurs en ont besoin (celui de Flutter n'est pas utilisable).\n"
    "Le bâtir une fois par checkout:\n"
    "  powershell -File packages/rewamp_audio/scripts/build_angle_windows.ps1\n"
    "ou s'en passer: REWAMP_WINDOWS_VIZ=0 flutter build windows")
endif()

# FFmpeg du vgmstream: le NÔTRE, minimal (scripts/build_ffmpeg_windows.ps1).
# Un REWAMP_FFMPEG_DIR passé en -D ou par l'environnement garde la main. Son
# absence est une ERREUR, levée dans le bloc vgmstream de rewamp.cmake.
set(_rewamp_ffmpeg_local "${CMAKE_CURRENT_SOURCE_DIR}/Libs/ffmpeg")
if(NOT REWAMP_FFMPEG_DIR AND EXISTS "${_rewamp_ffmpeg_local}/include/libavcodec/avcodec.h")
  set(REWAMP_FFMPEG_DIR "${_rewamp_ffmpeg_local}" CACHE PATH
      "FFmpeg prebuilt dir (include/+lib/) for vgmstream" FORCE)
endif()

rewamp_configure_decoders(${PLUGIN_NAME})

# ── Le COEUR du moteur sous MSVC ─────────────────────────────────────────────
#
# Les 39 cibles vendorées ont chacune reçu leur traitement dans rewamp.cmake;
# celle-ci est la nôtre, et elle a trois besoins distincts:
#
#   * la couche src/windows/compat/ (strcasecmp, <strings.h>, <dirent.h>,
#     <unistd.h>): les greffons `rewamp_plugin_*` et les décodeurs compilés
#     DANS cette cible (libgbsplay, highlyexperimental…) s'en servent autant
#     que les arbres vendorés;
#   * src/windows/posix/: <pthread.h>, clock_gettime, nanosleep, S_ISREG. ⚠️ Sur le
#     chemin de CETTE cible seulement — un pthread.h visible des cibles
#     vendorées changerait le comportement de celles qui testent sa présence;
#   * le C en C11 avec les atomiques: cl.exe compile le C en C89/90 étendu tant
#     qu'on ne demande rien, et garde <stdatomic.h> derrière un drapeau à part
#     (même cause et même correctif que rewamp_fmp, voir rewamp.cmake).
if(MSVC)
  rewamp_win_compat(${PLUGIN_NAME})
  target_include_directories(${PLUGIN_NAME} PRIVATE
    "${REWAMP_SRC_DIR}/windows/posix")
  target_sources(${PLUGIN_NAME} PRIVATE
    "${REWAMP_SRC_DIR}/windows/posix/rewamp_win_posix.c"
    # REWAMP_CRASH_TRACE=1: pile symbolisée au premier plantage (dbghelp).
    "${REWAMP_SRC_DIR}/windows/rewamp_win_crash.c")
  target_compile_options(${PLUGIN_NAME} PRIVATE "/FIrewamp_win_posix.h")
  set_target_properties(${PLUGIN_NAME} PROPERTIES C_STANDARD 11)
  # ⚠️ Par FICHIER, et pas `$<$<COMPILE_LANGUAGE:C>:...>` comme pour rewamp_fmp:
  # les générateurs Visual Studio ne savent pas distinguer C et C++ dans les
  # options d'une cible MIXTE — l'expression y est évaluée pour C++ dès qu'il y
  # a un seul .cpp, donc l'option n'atteignait AUCUN .c, sans avertissement
  # (mesuré: « C atomic support is not enabled » malgré l'option). rewamp_fmp
  # est tout en C, d'où la différence. Toute nouvelle source C du coeur qui
  # inclut <stdatomic.h> doit être ajoutée ici.
  set_source_files_properties(
    "${REWAMP_SRC_DIR}/rewamp_viz_idle.c"
    PROPERTIES COMPILE_OPTIONS "/experimental:c11atomics")
endif()

# miniaudio on Windows uses WinMM / WASAPI — no extra link needed
target_link_libraries(${PLUGIN_NAME} PRIVATE ole32 uuid)

# vgmstream et libopenmpt embarquent CHACUN leur copie de minimp3, avec les
# mêmes noms de symboles (mp3dec_init, mp3dec_decode_frame). Même raison que
# le `-Wl,--allow-multiple-definition` de linux/CMakeLists.txt et de
# android/CMakeLists.txt; chez MSVC l'option s'appelle /FORCE:MULTIPLE, et
# elle vaut aussi pour les coeurs de puces dupliqués entre arbres vendorés.
#
# Mesuré le 2026-10-02 en retirant /IGNORE:4006 le temps d'une édition de
# liens: EXACTEMENT deux doublons, `mp3dec_init` et `mp3dec_decode_frame`, la
# copie de vgmstream cédant à celle de libopenmpt. Rien d'autre ne se cache
# derrière l'option — à condition que les force-includes de renommage soient
# bien appliqués (rewamp_force_include_option, rewamp.cmake). ⚠️ /IGNORE:4006
# rend un futur doublon MUET: refaire cette mesure après l'ajout d'un moteur.
target_link_options(${PLUGIN_NAME} PRIVATE /FORCE:MULTIPLE /IGNORE:4006 /IGNORE:4088)

# ── Greffon de plateforme: visualiseurs OpenGL ES sur ANGLE ─────────────────
#
# Même découpage que linux/CMakeLists.txt, pour la même raison: Dart ouvre le
# MOTEUR par son nom en FFI (rewamp_audio.dll), mais un registre de textures
# n'est remis qu'à un vrai greffon de plateforme, et la boucle
# FLUTTER_PLUGIN_LIST de generated_plugins.cmake lie une cible nommée
# exactement `<paquet>_plugin`. Les renderers et la couche EGL vivent dans le
# moteur; le greffon n'est qu'un pont vers le registre.
#
# ⚠️ `pluginClass: RewampAudioPlugin` (pubspec.yaml) rend cette cible
# OBLIGATOIRE: le registrant généré appelle RewampAudioPluginRegisterWithRegistrar
# quoi qu'il arrive. D'où un greffon toujours construit, visualiseurs ou non.
#
# ANGLE: le NÔTRE (windows/Libs/angle, scripts/build_angle_windows.ps1). Celui
# de Flutter est lié statiquement dans flutter_windows.dll et n'exporte aucun
# symbole egl*/gl*. Son absence est une ERREUR, levée plus haut;
# REWAMP_WINDOWS_VIZ=0 pour s'en passer sciemment.
set(_rewamp_viz_bundled "")

add_library(rewamp_audio_plugin SHARED
  "${CMAKE_CURRENT_SOURCE_DIR}/rewamp_audio_plugin.cpp")
apply_standard_settings(rewamp_audio_plugin)
set_target_properties(rewamp_audio_plugin PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(rewamp_audio_plugin PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(rewamp_audio_plugin INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(rewamp_audio_plugin PRIVATE
  flutter flutter_wrapper_plugin ${PLUGIN_NAME})

if(REWAMP_WINDOWS_VIZ)
  target_sources(${PLUGIN_NAME} PRIVATE
    "${REWAMP_SRC_DIR}/windows/rewamp_gl_windows.cc"
    "${REWAMP_SRC_DIR}/windows/rewamp_viz_windows.cc")
  # REWAMP_GL_GLES: préambule `#version 300 es` des renderers.
  # REWAMP_ENGINE_IMPL: le pont de rewamp_viz_windows.h est EXPORTÉ d'ici.
  target_compile_definitions(${PLUGIN_NAME} PRIVATE
    REWAMP_GL_GLES=1 REWAMP_ENGINE_IMPL REWAMP_WINDOWS_VIZ=1)
  target_include_directories(${PLUGIN_NAME} PRIVATE "${REWAMP_ANGLE_DIR}/include")
  target_link_libraries(${PLUGIN_NAME} PRIVATE
    "${REWAMP_ANGLE_DIR}/lib/libEGL.lib"
    "${REWAMP_ANGLE_DIR}/lib/libGLESv2.lib")

  target_compile_definitions(rewamp_audio_plugin PRIVATE REWAMP_WINDOWS_VIZ=1)

  # Les DLL d'ANGLE (et leurs dépendances) voyagent avec l'app.
  file(GLOB _rewamp_viz_bundled "${REWAMP_ANGLE_DIR}/bin/*.dll")
endif()

# ⚠️ Flutter empaquette les bibliothèques d'un greffon en lisant CETTE
# variable, remontée au scope parent. La boucle FLUTTER_PLUGIN_LIST copie
# d'elle-même `$<TARGET_FILE:rewamp_audio_plugin>`, mais PAS le moteur: c'est
# une cible à part, que Dart ouvre par son nom.
#
# Sans cette ligne la DLL du moteur est bel et bien CONSTRUITE — la build est
# VERTE — et elle n'est jamais copiée à côté de rewamp.exe: l'app meurt au
# démarrage sur un `DynamicLibrary.open('rewamp_audio.dll')` introuvable.
# C'est exactement l'échec que linux/CMakeLists.txt documente au même endroit.
# Il ne se voit PAS à une build réussie: il se voit à l'exécution, ou en
# listant le dossier de sortie.
#
# Même règle pour les DLL de FFmpeg: liées par leurs .lib d'import, il faut
# qu'elles voyagent, sinon rewamp_audio.dll ne se CHARGE plus du tout.
set(_rewamp_ffmpeg_bundled "")
if(REWAMP_WITH_VGMSTREAM AND REWAMP_FFMPEG_DIR)
  file(GLOB _rewamp_ffmpeg_bundled "${REWAMP_FFMPEG_DIR}/bin/*.dll")
endif()
set(rewamp_audio_bundled_libraries
  $<TARGET_FILE:${PLUGIN_NAME}>
  ${_rewamp_viz_bundled}
  ${_rewamp_ffmpeg_bundled}
  PARENT_SCOPE
)

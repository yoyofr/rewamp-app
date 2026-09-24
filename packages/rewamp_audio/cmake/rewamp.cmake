# Shared configuration for the rewamp_audio native target across desktop and
# Android. Included by linux/, windows/ and android/ CMakeLists.txt.
#
# Provides:
#   REWAMP_SRC_DIR        absolute path to the shared C sources
#   REWAMP_CORE_SOURCES   list of core .c files to compile
#   rewamp_configure_decoders(<target>)  add optional decoder plugins

# ⚠️ Le C doit être activé ICI, par le module, et pas par l'hôte.
#
# Le moteur est massivement en C (libgme, vgmstream, uade, FluidLite, la
# quasi-totalité des coeurs de puce), mais l'hôte n'active pas forcément ce
# langage:
#   - Android: Gradle fait du CMakeLists du plugin le TOP-LEVEL, et son
#     `project()` sans clause LANGUAGES active C et CXX. Le C est donc là par
#     accident, gratuitement.
#   - Linux et Windows: le runner généré par Flutter est le top-level et
#     déclare `project(runner LANGUAGES CXX)` — SEUL le C++. Le plugin n'est
#     qu'un `add_subdirectory()`, et toute cible créée par les fonctions
#     rewamp_* hérite du jeu de langages de la racine. CMake n'a alors AUCUNE
#     règle pour les sources .c: `CMAKE_C_COMPILE_OBJECT` est vide et l'erreur
#     tombe une fois PAR CIBLE C, ce qui masque la cause unique.
#
# Rien de tout ça n'apparaît sur Apple: là, Flutter passe par CocoaPods et
# Xcode, jamais par CMake. Le poser dans le module (et non dans le runner
# généré, qui est régénérable, ni dans linux/CMakeLists.txt seul) rend le
# module autonome pour n'importe quel hôte — y compris un harnais de test
# autonome hors Flutter. `enable_language` est global une fois appelé.
enable_language(C)

# ⚠️ Même raisonnement que enable_language(C) ci-dessus: c'est au MODULE de le
# poser, pas à l'hôte. Le plugin est une bibliothèque PARTAGÉE construite à
# partir d'une trentaine de bibliothèques statiques intermédiaires, et une
# statique doit être compilée en code indépendant de la position pour pouvoir
# entrer dans une .so. Android ne le montre pas: le toolchain du NDK compile en
# PIC par défaut (tout y est PIE). Sur Linux, clang et gcc ne le font PAS, et
# l'échec arrive tout à la FIN, à l'édition de liens, sous une forme qui ne
# nomme pas la cause ('dangerous relocation: unsupported relocation'). Le poser
# une fois ici couvre toutes les cibles créées par ce module — y compris celles
# ajoutées plus tard, et le add_subdirectory(vgmstream) qui hérite du réglage —
# au lieu de le répéter cible par cible et d'en oublier une.
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

get_filename_component(REWAMP_SRC_DIR "${CMAKE_CURRENT_LIST_DIR}/../src" ABSOLUTE)
get_filename_component(REWAMP_THIRD_PARTY_DIR "${CMAKE_CURRENT_LIST_DIR}/../third_party" ABSOLUTE)

set(REWAMP_CORE_SOURCES
  "${REWAMP_SRC_DIR}/rewamp_audio.c"
  "${REWAMP_SRC_DIR}/rewamp_assets.c"
  "${REWAMP_SRC_DIR}/rewamp_registry.c"
  "${REWAMP_SRC_DIR}/rewamp_datasource.c"
  "${REWAMP_SRC_DIR}/rewamp_channel_data.c"
  "${REWAMP_SRC_DIR}/rewamp_loaded_files.c"
  "${REWAMP_SRC_DIR}/rewamp_declick.c"
  "${REWAMP_SRC_DIR}/rewamp_viz_idle.c"
  "${REWAMP_SRC_DIR}/rewamp_tags.c"
  "${REWAMP_SRC_DIR}/rewamp_notes.c"
  "${REWAMP_SRC_DIR}/rewamp_pattern.c"
  # « ce MIDI vise-t-il le MT-32 ? » — partagé par les DEUX greffons MIDI,
  # donc compilé quel que soit REWAMP_WITH_MT32.
  "${REWAMP_SRC_DIR}/rewamp_mt32_detect.c"
  "${REWAMP_SRC_DIR}/rewamp_extract.c"
  "${REWAMP_SRC_DIR}/miniaudio_impl.c"
)

# ─────────────────────────────────────────────────────────────────────────────
# rewamp_option — une option dont l'ENVIRONNEMENT peut fixer le défaut
#
# ⚠️ CMake IGNORE l'environnement pour `option()` et `set(... CACHE ...)`. Les
# podspecs Apple, eux, lisent `ENV[...]`. Conséquence, MESURÉE le 2026-09-21 sur
# une configuration réelle: `REWAMP_WITH_UNRAR=0 flutter build linux` laissait
# le cache à `REWAMP_WITH_UNRAR:BOOL=ON`. Autrement dit la recette de build
# « propre » de LICENSING.md — celle qui retire psgplay, UnRAR et
# highlytheoritical pour une distribution GPL conforme — ne valait QUE sur
# Apple, et échouait en SILENCE sur Linux et Windows: le drapeau existe, on
# croit l'avoir posé, et le binaire contient quand même ce qu'on voulait
# retirer. Sur le canal PUBLIC, c'est le pire endroit pour ce genre de panne.
#
# ⚠️ L'ORDRE de précédence est obtenu PAR CONSTRUCTION, pas par un test: un `-D`
# de ligne de commande crée déjà l'entrée de cache, et `option()` n'écrase
# jamais une entrée existante. D'où -D > environnement > défaut. Android, qui
# passe ses `-D` explicitement (android/build.gradle), n'est donc pas affecté.
#
# ⚠️ Une valeur que l'on ne sait pas lire est une ERREUR, pas un repli. Un
# `REWAMP_WITH_UNRAR=non` silencieusement ignoré ramènerait exactement le bug
# qu'on corrige ici — et `flutter build` FILTRE la sortie de configuration de
# CMake (ni STATUS ni WARNING n'atteignent le terminal, cf. le bloc vgmstream),
# donc seule une erreur se voit.
function(rewamp_option _name _doc _default)
  set(_def "${_default}")
  if(DEFINED ENV{${_name}})
    string(TOUPPER "$ENV{${_name}}" _env)
    if(_env MATCHES "^(0|OFF|NO|FALSE|N)$")
      set(_def OFF)
    elseif(_env MATCHES "^(1|ON|YES|TRUE|Y)$")
      set(_def ON)
    else()
      message(FATAL_ERROR
        "${_name}=$ENV{${_name}} : valeur incomprise.\n"
        "Attendu 0/1, OFF/ON, NO/YES, FALSE/TRUE.")
    endif()
    message(STATUS "rewamp: ${_name}=${_def} (environnement)")
  endif()
  option(${_name} "${_doc}" ${_def})
endfunction()

rewamp_option(REWAMP_WITH_OPENMPT "Build the libopenmpt decoder plugin" ON)
rewamp_option(REWAMP_WITH_XMP      "Build the libxmp decoder plugin (.musx/.liq/.fnk/.mgt/…)" ON)
rewamp_option(REWAMP_WITH_VGM     "Build the libvgm decoder plugin (VGM/VGZ/S98/GYM/DRO)" ON)
rewamp_option(REWAMP_WITH_GME      "Build the libgme decoder plugin (NSF/GBS/SPC/AY/HES/KSS/SAP/RSN)" ON)
rewamp_option(REWAMP_WITH_SID      "Build the libsidplayfp SID decoder plugin (.sid/.psid/.rsid)" ON)
rewamp_option(REWAMP_WITH_NSFPLAY  "Build the libnsfplay NSF/NSFe decoder plugin" ON)
rewamp_option(REWAMP_WITH_GBSPLAY  "Build the libgbsplay Game Boy GBS decoder plugin" ON)
rewamp_option(REWAMP_WITH_HIGHLYEXP "Build the Highly Experimental PSF/PSF2 decoder plugin" ON)
rewamp_option(REWAMP_WITH_VGMSTREAM "Build the vgmstream decoder plugin (200+ game formats)" ON)
rewamp_option(REWAMP_WITH_ARCHIVE  "Build vendored liblzma+libarchive (zip/7z/tar/gz/xz extraction)" ON)
rewamp_option(REWAMP_WITH_FURNACE  "Build the Furnace (DivEngine) tracker plugin (.fur/.dmf/.dmp)" ON)
# Default OFF until the 237-file engine build is validated; enabled per-platform.
rewamp_option(REWAMP_WITH_ZXTUNE   "Build the libzxtune ZX Spectrum/AY chiptune plugin" OFF)
# Default OFF until the UADE engine build is validated on each platform; flip ON once green.
rewamp_option(REWAMP_WITH_UADE     "Build the UADE Amiga custom-chip plugin (.ahx/.tfmx/.cust/.fc/…)" ON)
rewamp_option(REWAMP_WITH_NEZ      "Build the NEZplug++ plugin (.hes HuC6280 / .sgc SN76489+YM2413)" ON)
rewamp_option(REWAMP_WITH_KSS      "Build the libkss MSX plugin (.kss/.mgs/.bgm/.mpk/.mbm/.opx/.mus)" ON)
rewamp_option(REWAMP_WITH_MAC      "Build the Monkey's Audio decoder plugin (.ape)" ON)
rewamp_option(REWAMP_WITH_ASAP     "Build the ASAP Atari 8-bit plugin (.sap/.cmc/.rmt/...)" ON)
rewamp_option(REWAMP_WITH_HVL      "Build the HivelyTracker plugin (.hvl/.ahx)" ON)
rewamp_option(REWAMP_WITH_V2M      "Build the Farbrausch V2M plugin (.v2m/.v2mz)" ON)
rewamp_option(REWAMP_WITH_MIDI     "Build the FluidLite MIDI plugin (.mid, SF2 SoundFont)" ON)
rewamp_option(REWAMP_WITH_MT32     "Build the mt32emu MIDI plugin (.mid on a Roland MT-32 / CM-32L, user-imported ROMs)" ON)
rewamp_option(REWAMP_WITH_GSF      "Build the libgsf plugin (GBA .gsf/.minigsf via VBA)" ON)
rewamp_option(REWAMP_WITH_VIO2SF   "Build the vio2sf plugin (Nintendo DS .2sf/.mini2sf via melonDS)" ON)
rewamp_option(REWAMP_WITH_NCSF     "Build the NCSF plugin (Nintendo DS .ncsf/.minincsf via SSEQPlayer)" ON)
rewamp_option(REWAMP_WITH_SNSF     "Build the SNSF plugin (Super Nintendo .snsf/.minisnsf via snsf9x)" ON)
rewamp_option(REWAMP_WITH_PROJECTM "Build the projectM (Milkdrop) visualizer — Android/desktop" ON)
rewamp_option(REWAMP_PM_PROFILE    "projectM: log preset-load CPU/GL timings (adds a link sync point)" OFF)
rewamp_option(REWAMP_WITH_ADPLUG   "Build the AdPlug plugin (AdLib OPL2/OPL3 .d00/.hsc/.cmf/.imf/.rol/.a2m/…)" ON)
rewamp_option(REWAMP_WITH_SNDH     "Build the SNDH plugin (Atari ST .sndh via AtariAudio/Musashi)" ON)
rewamp_option(REWAMP_WITH_PSGPLAY  "Build the PSG play plugin (2nd .sndh engine: Atari ST machine + LMC1992)" ON)
rewamp_option(REWAMP_WITH_LAZYUSF  "Build the libLazyusf plugin (N64 .usf/.miniusf, R4300 interpreter)" ON)
rewamp_option(REWAMP_WITH_WONDERSWAN "Build the WonderSwan plugin (.wsr rip, beetle-wswan/Mednafen V30MZ core)" ON)
rewamp_option(REWAMP_WITH_HIGHLYQUIXOTIC "Build the HighlyQuixotic plugin (Capcom QSound .qsf/.qsflib)" ON)
rewamp_option(REWAMP_WITH_HIGHLYTHEORITICAL "Build the highlytheoritical plugin (Saturn .ssf / Dreamcast .dsf)" ON)
rewamp_option(REWAMP_WITH_LIBPT3 "Build the libpt3 plugin (ZX Spectrum .pt3, AY-3-8910/YM2149)" ON)
rewamp_option(REWAMP_WITH_ORGANYA "Build the Organya plugin (Cave Story .org)" ON)
rewamp_option(REWAMP_WITH_TIATRACKER "Build the TIATracker plugin (Atari VCS 2600 .ttt)" ON)
rewamp_option(REWAMP_WITH_PXTONE  "Build the PxTone Collage plugin (.ptcop/.pttune)" ON)
rewamp_option(REWAMP_WITH_PMD     "Build the PMD plugin (PC-98 .m/.m2/.mz, OPNA)" ON)
rewamp_option(REWAMP_WITH_MDX     "Build the MDX plugin (X68000 .mdx + .pdx, YM2151)" ON)
rewamp_option(REWAMP_WITH_FMP     "Build the FMP plugin (PC-98 .opi/.ovi/.ozi, OPNA)" ON)
rewamp_option(REWAMP_WITH_EUP     "Build the EUP plugin (FM Towns .eup, YM2612 + PCM)" ON)
rewamp_option(REWAMP_WITH_SC68    "Build the sc68 plugin (.sc68 Atari ST + Amiga, emu68 68k)" ON)
rewamp_option(REWAMP_WITH_SUNVOX  "Build the SunVox plugin (.sunvox modular synth+tracker)" ON)
rewamp_option(REWAMP_WITH_PROWIZARD "Build ProWizard packed-Amiga-module conversion (last-resort, no plugin of its own)" ON)
# Official UnRAR: required for *solid* RARv3/v4 archives (RSN = solid SPC sets),
# which libarchive cannot decode. Wires libgme's Rsn_Emu (RARDLL path).
rewamp_option(REWAMP_WITH_UNRAR    "Build the bundled UnRAR (solid RAR/RSN support in libgme)" ON)
# Path to an FFmpeg install (ffmpeg-kit prebuilt dir with include/ + lib/) for the
# current ABI. When set + valid, vgmstream is built with USE_FFMPEG=ON.
# Même remarque que pour rewamp_option: l'environnement ne traverse pas CMake
# tout seul. Utile hors Android — la recette AppImage y met son FFmpeg minimal
# (scripts/appimage/), justement pour ne pas dépendre du SONAME de la distro.
if(DEFINED ENV{REWAMP_FFMPEG_DIR} AND NOT DEFINED REWAMP_FFMPEG_DIR)
  set(REWAMP_FFMPEG_DIR "$ENV{REWAMP_FFMPEG_DIR}" CACHE PATH "FFmpeg prebuilt dir (include/+lib/) for vgmstream")
  message(STATUS "rewamp: REWAMP_FFMPEG_DIR=${REWAMP_FFMPEG_DIR} (environnement)")
else()
  set(REWAMP_FFMPEG_DIR "" CACHE PATH "FFmpeg prebuilt dir (include/+lib/) for vgmstream")
endif()
# Échappatoire pour construire sur Linux sans FFmpeg (scope vgmstream réduit).
# Sans ça, l'absence de FFmpeg est une ERREUR de configuration — voir le bloc
# vgmstream. Ne concerne QUE Linux: Android pose lui-même REWAMP_FFMPEG_DIR par
# ABI dans android/CMakeLists.txt, depuis le ffmpeg-kit vendoré, et le seul
# risque de perte silencieuse y est l'ABI 32 bits sans tranche vendorée — déjà
# fermé par l'exclusion 64-bit-only d'android/build.gradle.
rewamp_option(REWAMP_ALLOW_NO_FFMPEG "Linux: autoriser un vgmstream sans FFmpeg" OFF)

# Builds libopenmpt as a static library from vendored source (git submodule),
# self-contained with no external dependencies. See PLUGINS.md.
function(rewamp_add_libopenmpt)
  set(_root "${REWAMP_THIRD_PARTY_DIR}/libopenmpt")
  if(NOT EXISTS "${_root}/libopenmpt/libopenmpt.h")
    message(FATAL_ERROR
      "REWAMP_WITH_OPENMPT=ON but ${_root} is missing. Run:\n"
      "  git submodule update --init packages/rewamp_audio/third_party/libopenmpt")
  endif()

  file(GLOB _common  "${_root}/common/*.cpp")
  file(GLOB _dsp     "${_root}/sounddsp/*.cpp")
  file(GLOB_RECURSE _soundlib "${_root}/soundlib/*.cpp")
  set(_lib
    "${_root}/libopenmpt/libopenmpt_c.cpp"
    "${_root}/libopenmpt/libopenmpt_cxx.cpp"
    "${_root}/libopenmpt/libopenmpt_ext_impl.cpp"
    "${_root}/libopenmpt/libopenmpt_impl.cpp"
  )
  # Bundled codec implementations (all dependency-free C):
  #   miniz      — zlib-based module containers (J2B, ...)
  #   minimp3    — MP3-compressed samples
  #   stb_vorbis — OGG/Vorbis-compressed samples (MO3, XM, ...)
  set(_bundled
    "${_root}/include/miniz/miniz.c"
    "${_root}/include/minimp3/minimp3.c"
    "${_root}/include/stb_vorbis/stb_vorbis.c"
  )

  add_library(openmpt STATIC ${_common} ${_dsp} ${_soundlib} ${_lib} ${_bundled})

  target_compile_features(openmpt PRIVATE cxx_std_17)
  set_target_properties(openmpt PROPERTIES POSITION_INDEPENDENT_CODE ON)

  # std::to_chars for floats requires iOS 16.3+ / macOS 13.3+.
  # On older deployment targets use the ostringstream fallback.
  if(CMAKE_SYSTEM_NAME STREQUAL "iOS" AND
     CMAKE_OSX_DEPLOYMENT_TARGET VERSION_LESS "16.3")
    set(_no_to_chars MPT_LIBCXX_QUIRK_NO_TO_CHARS_FLOAT)
  elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin" AND
         CMAKE_OSX_DEPLOYMENT_TARGET VERSION_LESS "13.3")
    set(_no_to_chars MPT_LIBCXX_QUIRK_NO_TO_CHARS_FLOAT)
  else()
    set(_no_to_chars "")
  endif()

  target_compile_definitions(openmpt PRIVATE
    LIBOPENMPT_BUILD
    MPT_WITH_MINIZ        # bundled, no external dep
    MPT_WITH_MINIMP3      # bundled header-only MP3 sample decoder
    MPT_WITH_STBVORBIS    # bundled OGG/Vorbis sample decoder
    ${_no_to_chars}
  )

  # Private build includes (mpt support lib + bundled codecs).
  target_include_directories(openmpt PRIVATE
    "${_root}" "${_root}/common" "${_root}/src" "${_root}/include")
  # Public API header lives at <_root>/libopenmpt/libopenmpt.h
  target_include_directories(openmpt PUBLIC "${_root}")
endfunction()

# Builds libvgm chip emulator cores + player layer from Modizer's modified
# source tree. Each .c/.cpp gets its own translation unit — required because
# many cores share file-static symbol names (ReadLE32, init_tables, …).
function(rewamp_add_libvgm target)
  set(_libvgm "${REWAMP_THIRD_PARTY_DIR}/libvgm/libvgm")
  if(NOT EXISTS "${_libvgm}/player/playera.cpp")
    message(FATAL_ERROR
      "REWAMP_WITH_VGM=ON but libvgm not found at ${_libvgm}.\n"
      "Copy Modizer's modified libvgm to:\n"
      "  packages/rewamp_audio/third_party/libvgm/libvgm/")
  endif()

  # ── Chip cores (C) ─────────────────────────────────────────────────────────
  # Each core is its own TU. Skip the two include-only helpers that are
  # #included by their parent core and must NOT be compiled stand-alone:
  #   scsplfo.c        → included by scsp.c
  #   adlibemu_opl_inc.c → included by adlibemu_opl2/3.c
  file(GLOB _cores "${_libvgm}/emu/cores/*.c")
  list(FILTER _cores EXCLUDE REGEX "(scsplfo|adlibemu_opl_inc)\\.c$")

  # ── Emulator dispatch / resampling / DAC (C) ───────────────────────────────
  set(_emu_c
    "${_libvgm}/emu/SoundEmu.c"
    "${_libvgm}/emu/Resampler.c"
    "${_libvgm}/emu/dac_control.c"
    "${_libvgm}/emu/logging.c"
    "${_libvgm}/emu/panning.c"
  )

  # ── Utility layer (C) ──────────────────────────────────────────────────────
  # Charset conversion backend selection:
  #   Windows  → CPConv_Win.c  (MultiByteToWideChar)
  #   Android  → CPConv_Stub.c (le NÔTRE: iconv n'est dans bionic qu'à partir
  #               de l'API 28 et notre plancher est 26. Il le cherche à
  #               l'exécution et, à défaut, convertit lui-même l'UTF-16LE des
  #               GD3 et le CP1252 des GYM. ⚠️ Ne PAS revenir à une recopie
  #               d'octets: un GD3 est en UTF-16, donc « Game Over » sortait
  #               « G » — la chaîne C s'arrête au premier octet nul. Oracle:
  #               scripts/verify_cpconv.sh)
  #   Others   → CPConv_IConv.c (POSIX iconv, in glibc/macOS/iOS libc)
  if(WIN32)
    set(_str_conv "${_libvgm}/utils/StrUtils-CPConv_Win.c")
  elseif(CMAKE_SYSTEM_NAME STREQUAL "Android")
    set(_str_conv "${REWAMP_SRC_DIR}/StrUtils-CPConv_Stub.c")
  else()
    set(_str_conv "${_libvgm}/utils/StrUtils-CPConv_IConv.c")
  endif()
  set(_utils_c
    "${_libvgm}/utils/DataLoader.c"
    "${_libvgm}/utils/FileLoader.c"
    "${_libvgm}/utils/MemoryLoader.c"
    "${_str_conv}"
  )

  # ── Player helpers (C) ─────────────────────────────────────────────────────
  set(_player_c
    "${_libvgm}/player/helper.c"
    "${_libvgm}/player/dblk_compr.c"
  )

  # ── Player engines (C++) — each its own TU ─────────────────────────────────
  # File-static name conflicts: ReadLE16/32 in vgmplayer_cmdhandler.cpp,
  # SaveDeviceConfig in s98player.cpp + gymplayer.cpp.
  set(_player_cpp
    "${_libvgm}/player/playerbase.cpp"
    "${_libvgm}/player/vgmplayer.cpp"
    "${_libvgm}/player/vgmplayer_cmdhandler.cpp"
    "${_libvgm}/player/s98player.cpp"
    "${_libvgm}/player/droplayer.cpp"
    "${_libvgm}/player/gymplayer.cpp"
    "${_libvgm}/player/playera.cpp"
  )

  # ── rewamp glue ────────────────────────────────────────────────────────────
  target_sources(${target} PRIVATE
    ${_cores} ${_emu_c} ${_utils_c} ${_player_c} ${_player_cpp}
    "${REWAMP_SRC_DIR}/rewamp_plugin_vgm.cpp"
  )

  # Explicitly compile all .c sources as C (CMake infers from extension, but
  # some build systems may override — be defensive).
  set(_all_c ${_cores} ${_emu_c} ${_utils_c} ${_player_c})
  set_source_files_properties(${_all_c} PROPERTIES LANGUAGE C)

  # ── Build defines (mirrors Modizer's libvgm.xcodeproj OTHER_CFLAGS) ────────
  target_compile_definitions(${target} PRIVATE
    REWAMP_WITH_VGM=1
    VGM_LITTLE_ENDIAN
    HAVE_STDINT_H
    SNDDEV_SN76496 SNDDEV_YM2413 SNDDEV_YM2612 SNDDEV_YM2151 SNDDEV_SEGAPCM
    SNDDEV_RF5C68 SNDDEV_YM2203 SNDDEV_YM2608 SNDDEV_YM2610 SNDDEV_YM3812
    SNDDEV_YM3526 SNDDEV_Y8950 SNDDEV_YMF262 SNDDEV_YMF278B SNDDEV_YMF271
    SNDDEV_YMZ280B SNDDEV_32X_PWM SNDDEV_AY8910 SNDDEV_GAMEBOY SNDDEV_NES_APU
    SNDDEV_YMW258 SNDDEV_UPD7759 SNDDEV_MSM6258 SNDDEV_MSM6295 SNDDEV_K051649
    SNDDEV_K054539 SNDDEV_C6280 SNDDEV_C140 SNDDEV_C219 SNDDEV_K053260
    SNDDEV_POKEY SNDDEV_QSOUND SNDDEV_SCSP SNDDEV_WSWAN SNDDEV_VBOY_VSU
    SNDDEV_SAA1099 SNDDEV_ES5503 SNDDEV_ES5506 SNDDEV_X1_010 SNDDEV_C352
    SNDDEV_GA20 SNDDEV_MIKEY
    SNDDEV_K007232 SNDDEV_K005289 SNDDEV_MSM5205 SNDDEV_MSM5232 SNDDEV_BSMT2000
    SNDDEV_ICS2115
    SNDDEV_SELECT
    EC_AY8910_EMU2149 EC_AY8910_MAME EC_GB_SAMEBOY EC_GB_MAME EC_C6280_MAME EC_C6280_OOTAKE
    EC_NES_MAME EC_NES_NSFP_FDS EC_NES_NSFPLAY EC_QSOUND_CTR EC_QSOUND_MAME
    EC_RF5C68_GENS EC_RF5C68_MAME EC_SAA1099_MAME EC_SAA1099_NRS EC_SAA1099_VB
    EC_SN76496_MAME EC_SN76496_MAXIM EC_YM2151_MAME EC_YM2151_NUKED
    EC_YM2413_EMU2149 EC_YM2413_MAME EC_YM2413_NUKED EC_YM2612_GENS
    EC_YM2612_GPGX EC_YM2612_NUKED EC_YM3812_ADLIBEMU EC_YM3812_MAME
    EC_YM3812_NUKED EC_YMF262_ADLIBEMU EC_YMF262_MAME EC_YMF262_NUKED
  )

  target_include_directories(${target} PRIVATE
    "${_libvgm}"
    "${_libvgm}/emu"
    "${_libvgm}/emu/cores"
    "${_libvgm}/player"
    "${_libvgm}/utils"
    "${REWAMP_SRC_DIR}"
  )

  # ── System libraries ───────────────────────────────────────────────────────

  # iconv (charset conversion for music titles)
  #   macOS/iOS: explicit libiconv (handled by CocoaPods for pod builds;
  #              CMake find_library will locate it for standalone builds)
  #   Linux/glibc: iconv is in libc — no explicit link
  #   Android: using CPConv_Stub.c — no iconv needed
  #   Windows: using CPConv_Win.c (MultiByteToWideChar) — no iconv needed
  if(NOT WIN32 AND NOT CMAKE_SYSTEM_NAME STREQUAL "Android")
    find_library(_rewamp_iconv_lib iconv)
    if(_rewamp_iconv_lib)
      target_link_libraries(${target} PRIVATE ${_rewamp_iconv_lib})
    endif()
  endif()

  # zlib (for .vgz gzip decompression in FileLoader.c)
  if(CMAKE_SYSTEM_NAME STREQUAL "Android")
    # Android NDK bundles zlib; link by name
    target_link_libraries(${target} PRIVATE z)
  else()
    find_package(ZLIB QUIET)
    if(ZLIB_FOUND)
      target_link_libraries(${target} PRIVATE ZLIB::ZLIB)
    else()
      find_library(_rewamp_z_lib z)
      if(_rewamp_z_lib)
        target_link_libraries(${target} PRIVATE ${_rewamp_z_lib})
      endif()
    endif()
  endif()
endfunction()

# Builds libgme as a static library from vendored source.
# All files are standard C++ — no file-static name conflicts, no TU restrictions.
function(rewamp_add_libgme target)
  set(_root "${REWAMP_THIRD_PARTY_DIR}/libgme")
  if(NOT EXISTS "${_root}/gme/gme.h")
    message(FATAL_ERROR
      "REWAMP_WITH_GME=ON but ${_root}/gme/gme.h is missing.\n"
      "Copy Modizer's libgme to:\n"
      "  packages/rewamp_audio/third_party/libgme/")
  endif()

  file(GLOB _gme_srcs "${_root}/gme/*.cpp")
  # ext/ contains emu2413.c (OPLL/VRC7 for NSF) and panning.c — must be C, not C++.
  file(GLOB _gme_ext_c "${_root}/gme/ext/*.c")

  add_library(gme STATIC ${_gme_srcs} ${_gme_ext_c})
  target_compile_features(gme PRIVATE cxx_std_11)
  set_target_properties(gme PROPERTIES POSITION_INDEPENDENT_CODE ON)
  set_source_files_properties(${_gme_ext_c} PROPERTIES LANGUAGE C)
  # gme source files reference "../../../src/ModizerVoicesData.h" relative to
  # their own location; that path resolves to packages/rewamp_audio/src/ where
  # Rewamp already keeps ModizerVoicesData.h and ModizerConstants.h.
  target_include_directories(gme PUBLIC "${_root}")
  target_include_directories(gme PRIVATE "${REWAMP_SRC_DIR}" "${_root}/gme/ext")
  # Nuked YM2612 core (used by Vgm_Emu and Gym_Emu).
  target_compile_definitions(gme PRIVATE VGM_YM2612_NUKED=1)

  # zlib for transparent decompression (HAVE_ZLIB_H in blargg_config.h)
  if(CMAKE_SYSTEM_NAME STREQUAL "Android")
    target_link_libraries(gme PRIVATE z)
  else()
    find_package(ZLIB QUIET)
    if(ZLIB_FOUND)
      target_link_libraries(gme PRIVATE ZLIB::ZLIB)
    else()
      find_library(_gme_z_lib z)
      if(_gme_z_lib)
        target_link_libraries(gme PRIVATE ${_gme_z_lib})
      endif()
    endif()
  endif()

  # RSN (solid RARv3/v4 SPC sets) via bundled UnRAR: Spc_Emu.cpp's Rsn_Emu
  # takes the RARDLL path (#include <dll.hpp>) when these are defined.
  if(REWAMP_WITH_UNRAR)
    rewamp_add_unrar()
    target_compile_definitions(gme PRIVATE RARDLL=1 RAR_HDR_DLL_HPP=1 SILENT=1)
    target_link_libraries(gme PRIVATE rewamp_unrar)
  endif()

  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_gme.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_GME=1)
  target_link_libraries(${target} PRIVATE gme)
  target_include_directories(${target} PRIVATE "${_root}")

  # RSN extraction via system libarchive (Apple platforms only)
  if(APPLE)
    find_library(_gme_archive_lib archive)
    if(_gme_archive_lib)
      target_link_libraries(${target} PRIVATE ${_gme_archive_lib})
    endif()
  endif()
endfunction()

# Builds libsidplayfp (reSIDfp engine) as a static library from vendored source.
# reSIDfp + SIDLite builders are compiled; C++17 required for std::optional.
function(rewamp_add_libsidplayfp target)
  set(_sid    "${REWAMP_THIRD_PARTY_DIR}/libsidplayfp")
  set(_lib    "${_sid}/libsidplayfp/src")
  set(_resid  "${_sid}/libresidfp/src")

  if(NOT EXISTS "${_lib}/player.cpp")
    message(FATAL_ERROR
      "REWAMP_WITH_SID=ON but libsidplayfp not found at ${_lib}.\n"
      "Copy Modizer's libsidplayfp to:\n"
      "  packages/rewamp_audio/third_party/libsidplayfp/")
  endif()

  # libsidplayfp core — explicit list mirrors the podspec prepare_command.
  set(_sid_srcs
    "${_lib}/EventScheduler.cpp"
    "${_lib}/player.cpp"
    "${_lib}/psiddrv.cpp"
    "${_lib}/reloc65.cpp"
    "${_lib}/sidemu.cpp"
    "${_lib}/simpleMixer.cpp"
    "${_lib}/sidplayfp/sidplayfp.cpp"
    "${_lib}/sidplayfp/SidConfig.cpp"
    "${_lib}/sidplayfp/SidInfo.cpp"
    "${_lib}/sidplayfp/SidTune.cpp"
    "${_lib}/sidplayfp/SidTuneInfo.cpp"
    "${_lib}/sidplayfp/sidbuilder.cpp"
    "${_lib}/sidtune/PSID.cpp"
    "${_lib}/sidtune/SidTuneBase.cpp"
    "${_lib}/sidtune/SidTuneTools.cpp"
    "${_lib}/sidtune/MUS.cpp"
    "${_lib}/sidtune/prg.cpp"
    "${_lib}/sidtune/p00.cpp"
    "${_lib}/c64/c64.cpp"
    "${_lib}/c64/mmu.cpp"
    "${_lib}/c64/CPU/mos6510.cpp"
    "${_lib}/c64/CPU/mos6510debug.cpp"
    "${_lib}/c64/CIA/mos652x.cpp"
    "${_lib}/c64/CIA/tod.cpp"
    "${_lib}/c64/CIA/timer.cpp"
    "${_lib}/c64/CIA/SerialPort.cpp"
    "${_lib}/c64/CIA/interrupt.cpp"
    "${_lib}/c64/VIC_II/mos656x.cpp"
    "${_lib}/builders/residfp-builder/residfp-builder.cpp"
    "${_lib}/builders/residfp-builder/residfp-emu.cpp"
    "${_lib}/builders/sidlite-builder/sidlite-builder.cpp"
    "${_lib}/builders/sidlite-builder/sidlite-emu.cpp"
    "${_lib}/builders/sidlite-builder/sidlite/ADSR.cpp"
    "${_lib}/builders/sidlite-builder/sidlite/Filter.cpp"
    "${_lib}/builders/sidlite-builder/sidlite/SID.cpp"
    "${_lib}/builders/sidlite-builder/sidlite/WavGen.cpp"
    "${_lib}/utils/SidDatabase.cpp"
    "${_lib}/utils/iniParser.cpp"
    "${_lib}/utils/STILview/stil.cpp"
  )

  # libresidfp chip emulation (reSIDfp).
  file(GLOB _resid_srcs "${_resid}/*.cpp")
  set(_resid_extra
    "${_resid}/resample/SincResampler.cpp"
    "${_resid}/residfp/residfp.cpp"
  )

  add_library(sidplayfp STATIC ${_sid_srcs} ${_resid_srcs} ${_resid_extra})
  target_compile_features(sidplayfp PRIVATE cxx_std_17)
  set_target_properties(sidplayfp PROPERTIES POSITION_INDEPENDENT_CODE ON)

  target_compile_definitions(sidplayfp PRIVATE
    HAVE_CONFIG_H=1
    HAVE_CXX23=1
    REWAMP_WITH_SID=1
  )

  # REWAMP_SRC_DIR covers the fallback for "../../../../../src/ModizerVoicesData.h"
  # in the Modizer-patched SID.h (relative path overshoots the tree; compiler falls
  # back to -I search dirs, which resolves it correctly from REWAMP_SRC_DIR).
  target_include_directories(sidplayfp PRIVATE "${REWAMP_SRC_DIR}")
  target_include_directories(sidplayfp PUBLIC
    "${_lib}"
    "${_lib}/sidplayfp"
    "${_lib}/builders/residfp-builder"
    "${_lib}/builders/sidlite-builder"
    "${_resid}"
  )

  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_sid.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_SID=1 HAVE_CXX23=1)
  target_compile_features(${target} PRIVATE cxx_std_17)
  target_link_libraries(${target} PRIVATE sidplayfp)
endfunction()

# Adds decoder plugin sources + libraries to the given target, based on the
# REWAMP_WITH_* options. Each plugin is self-contained and gated by a macro.
# Builds vendored liblzma + libarchive as one isolated static lib and wires
# archive extraction (zip/7z/tar/gz/xz) into the target. Mirrors the macOS/iOS
# podspec block. liblzma + libarchive both use a file named config.h guarded by
# HAVE_CONFIG_H; the libarchive root must precede the liblzma root on the include
# path so both translation units pick up libarchive's merged config.h (it carries
# the appended liblzma HAVE_DECODER_* defines), exactly as the Apple build relies on.
function(rewamp_add_libarchive target)
  set(_arc  "${REWAMP_THIRD_PARTY_DIR}/libarchive")
  set(_lzma "${REWAMP_THIRD_PARTY_DIR}/liblzma")
  if(NOT EXISTS "${_arc}/archive.h")
    message(FATAL_ERROR "REWAMP_WITH_ARCHIVE=ON but ${_arc}/archive.h is missing.")
  endif()
  # liblzma: all cores under src/liblzma/*/ plus the tuklib helpers in src/common.
  file(GLOB _lzma_srcs
    "${_lzma}/src/liblzma/check/*.c"
    "${_lzma}/src/liblzma/common/*.c"
    "${_lzma}/src/liblzma/delta/*.c"
    "${_lzma}/src/liblzma/lz/*.c"
    "${_lzma}/src/liblzma/lzma/*.c"
    "${_lzma}/src/liblzma/rangecoder/*.c"
    "${_lzma}/src/liblzma/simple/*.c"
    "${_lzma}/src/common/*.c")
  # config.h leaves HAVE_SMALL undefined → use the table/fast CRC variants, not
  # the *_small.c ones (which redefine lzma_crc*_table with a clashing type), and
  # drop the *_tablegen.c standalone table generators.
  list(FILTER _lzma_srcs EXCLUDE REGEX "(_small|_tablegen)\\.c$")
  # libarchive: top-level *.c only (the src/ subdir holds the CLI, not the lib).
  file(GLOB _arc_srcs "${_arc}/*.c")
  # Drop platform-specific sources rewamp's extraction path doesn't need and that
  # don't build against bionic/glibc: BSD/macOS/Solaris ACL backends, the
  # disk-scanning read_disk_* readers (we only read archives + write to disk),
  # and the Windows reader. config.h's appended __linux__ block neutralizes the
  # rest. Vaut pour Android ET Linux de bureau: archive_disk_acl_darwin.c veut
  # <membership.h> et archive_read_disk_posix.c veut le `struct statfs` de
  # Darwin, deux choses qu'aucun Linux n'a.
  if(ANDROID OR CMAKE_SYSTEM_NAME STREQUAL "Linux")
    list(FILTER _arc_srcs EXCLUDE REGEX
      "archive_(disk_acl_(darwin|freebsd|sunos)|read_disk_(windows|posix|entry_from_file|set_standard_lookup))\\.c$")
  endif()

  add_library(rewamp_archive STATIC ${_lzma_srcs} ${_arc_srcs})
  target_compile_definitions(rewamp_archive PRIVATE
    HAVE_CONFIG_H=1 TUKLIB_SYMBOL_PREFIX=lzma_)
  target_include_directories(rewamp_archive PRIVATE
    "${_arc}"                               # merged config.h (must be first)
    "${_lzma}"                              # liblzma config.h
    "${_lzma}/src/liblzma/api"
    "${_lzma}/src/liblzma/common"
    "${_lzma}/src/liblzma/check"
    "${_lzma}/src/liblzma/lz"
    "${_lzma}/src/liblzma/lzma"
    "${_lzma}/src/liblzma/delta"
    "${_lzma}/src/liblzma/simple"
    "${_lzma}/src/liblzma/rangecoder"
    "${_lzma}/src/common")
  # archive.h for consumers (rewamp_extract.c).
  target_include_directories(rewamp_archive PUBLIC "${_arc}")
  target_link_libraries(rewamp_archive PRIVATE z)
  # config.h garde HAVE_BZLIB_H hors Android: le filtre bzip2 appelle BZ2_*.
  if(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND NOT ANDROID)
    target_link_libraries(rewamp_archive PRIVATE bz2)
    target_link_libraries(${target} PRIVATE bz2)
  endif()

  target_link_libraries(${target} PRIVATE rewamp_archive z)
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_ARCHIVE=1)
endfunction()

# Builds the Furnace tracker engine (DivEngine) as an isolated static lib and wires
# the plugin. Source set is the exact curated list from Modizer's libfurnace.xcodeproj
# (furnace_sources.cmake, 298 files) — NOT a GLOB, because the vendored extern/ dirs
# carry extra files the headless engine doesn't compile. furnace bundles its own chip
# cores (Nuked-OPLL, emu2413, opl/opm/opn, SAASound, ymfm, vgsound_emu, YM*-LLE…) that
# collide with libvgm/libgme/nsfplay, so every furnace TU is force-included with
# furnace_chip_rename.h (same trick as nsfplay's symbol rename).
function(rewamp_add_furnace target)
  set(FURNACE_ROOT "${REWAMP_THIRD_PARTY_DIR}/furnace")
  if(NOT EXISTS "${FURNACE_ROOT}/src/modizer/FurnacePlayer.h")
    message(FATAL_ERROR "REWAMP_WITH_FURNACE=ON but furnace sources are missing at ${FURNACE_ROOT}")
  endif()
  include("${FURNACE_ROOT}/furnace_sources.cmake")   # → FURNACE_SOURCES

  # momo is furnace's gettext/locale shim; on Android its momo.c pulls SDL_locale.h
  # (#ifdef ANDROID), which we don't ship. Headless playback needs no translations,
  # so drop momo there and leave HAVE_MOMO undefined → ta-utils' `_()` is identity.
  # ta-utils' `_()` is gettext under HAVE_LOCALE (→ momo or libintl), else identity.
  # Android has neither momo's SDL dep nor libintl, so leave HAVE_LOCALE/HAVE_MOMO
  # undefined there (translations are pointless for a player) → identity macro.
  set(_furnace_defs HAVE_DIRENT_TYPE=1 HAVE_SETLOCALE=1)
  if(ANDROID)
    list(FILTER FURNACE_SOURCES EXCLUDE REGEX "/src/momo/momo\\.c$")
  else()
    list(APPEND _furnace_defs HAVE_LOCALE=1 HAVE_MOMO=1)
  endif()

  add_library(rewamp_furnace STATIC ${FURNACE_SOURCES})
  set_target_properties(rewamp_furnace PROPERTIES CXX_STANDARD 14 CXX_STANDARD_REQUIRED ON)
  target_compile_definitions(rewamp_furnace PRIVATE ${_furnace_defs})
  target_include_directories(rewamp_furnace PRIVATE
    "${FURNACE_ROOT}/extern/fmt/include"
    "${FURNACE_ROOT}/src/momo"
    "${FURNACE_ROOT}/extern/vgsound_emu-modified"
    "${FURNACE_ROOT}/extern/IconFontCppHeaders"
    "${FURNACE_ROOT}/extern/blip_buf"
    "${FURNACE_ROOT}/src/icon")
  set_source_files_properties(${FURNACE_SOURCES} PROPERTIES
    COMPILE_OPTIONS "-include;${FURNACE_ROOT}/src/modizer/furnace_chip_rename.h")
  target_link_libraries(rewamp_furnace PRIVATE z)
  # FurnacePlayer.h for the plugin TU.
  target_include_directories(rewamp_furnace PUBLIC "${FURNACE_ROOT}/src/modizer")

  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_furnace.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_FURNACE=1)
  target_link_libraries(${target} PRIVATE rewamp_furnace z)
endfunction()

# Builds libzxtune (ZX Spectrum / AY chiptune engine) as an isolated static lib and
# wires the plugin. Curated 237-file set from Modizer's libzxtune.xcodeproj
# (zxtune_sources.cmake — NOT a GLOB). Header-only boost (BOOST_ERROR_CODE_HEADER_ONLY).
function(rewamp_add_zxtune target)
  set(ZXTUNE_ROOT "${REWAMP_THIRD_PARTY_DIR}/libzxtune")
  if(NOT EXISTS "${ZXTUNE_ROOT}/emscripten/Spectre.h")
    message(FATAL_ERROR "REWAMP_WITH_ZXTUNE=ON but libzxtune sources are missing at ${ZXTUNE_ROOT}")
  endif()
  include("${ZXTUNE_ROOT}/zxtune_sources.cmake")   # → ZXTUNE_SOURCES

  # libchpconv: converts .chp (Amstrad CPC ChipTracker) → YM3 for zxtune.
  set(CHPCONV_DIR "${REWAMP_THIRD_PARTY_DIR}/libchpconv")
  add_library(rewamp_zxtune STATIC ${ZXTUNE_SOURCES}
    "${REWAMP_SRC_DIR}/rewamp_zxtune_stubs.cpp"
    "${CHPCONV_DIR}/chp2ym.c")
  set_target_properties(rewamp_zxtune PROPERTIES CXX_STANDARD 14 CXX_STANDARD_REQUIRED ON)
  target_compile_definitions(rewamp_zxtune PRIVATE
    REWAMP_WITH_ZXTUNE=1
    BOOST_ERROR_CODE_HEADER_ONLY MODIZER BOOST_NO_RTTI BOOST_SYSTEM_NO_DEPRECATED
    NO_DEBUG_LOGS NO_L10N
    WORDS_LITTLE_ENDIAN Z80EX_API_REVISION=1 Z80EX_VERSION_MAJOR=1 Z80EX_VERSION_MINOR=19 Z80EX_RELEASE_TYPE=pre1 Z80EX_VERSION_STR=1.1.19pre1)
  # zxtune uses rooted includes: <module/...>, <sound/...>, <types.h>, boost, 3rdparty.
  target_include_directories(rewamp_zxtune PRIVATE
    "${ZXTUNE_ROOT}/include"
    "${ZXTUNE_ROOT}/src"
    "${ZXTUNE_ROOT}/3rdparty"
    "${ZXTUNE_ROOT}"
    "${ZXTUNE_ROOT}/3rdparty/z80ex/include"
    "${REWAMP_SRC_DIR}")
  # Spectre.h (+ transitive types.h/boost) for the plugin TU.
  target_include_directories(rewamp_zxtune PUBLIC
    "${ZXTUNE_ROOT}/emscripten"
    "${ZXTUNE_ROOT}/include"
    "${ZXTUNE_ROOT}"
    "${CHPCONV_DIR}")            # chp2ym.h for the plugin TU

  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_zxtune.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_ZXTUNE=1)
  set_source_files_properties("${REWAMP_SRC_DIR}/rewamp_plugin_zxtune.cpp"
    PROPERTIES COMPILE_DEFINITIONS "MODIZER")  # types.h needs the MODIZER typedef branch
  target_link_libraries(${target} PRIVATE rewamp_zxtune z)
endfunction()

# Builds UADE (Unix Amiga Delitracker Emulator) as an isolated static lib and
# wires the plugin. Plays Amiga custom-chip formats via real 68k emulation +
# bundled eagleplayers. Mirrors the VALIDATED BUILD RECIPE in the uade-integration
# memory (and scratchpad/uade_vendor_build.sh).
#
# Single-process / iOS-safe: the whole tree is built with -DUADE_IN_PROCESS so
# uadecore runs in a pthread (no fork). The patched ossupport.c/uadestate.c/
# uademain.c provide that; uademain.c's exit()→longjmp shim is force-included via
# uade_inprocess.h on the uadecore emulator TUs only.
function(rewamp_add_uade target)
  set(_uade "${REWAMP_THIRD_PARTY_DIR}/uade")
  set(_s    "${_uade}/src")
  if(NOT EXISTS "${_s}/frontends/include/uade/uade.h")
    message(FATAL_ERROR "REWAMP_WITH_UADE=ON but UADE sources are missing at ${_uade}")
  endif()

  # libzakalwe (already pruned of *-test.c / configure-*.c in the vendor).
  file(GLOB _zak_srcs "${_uade}/libzakalwe/*.c")
  # bencode-tools: bencode.c only (bencat.c/bencodetest.c are CLIs — not vendored).
  set(_ben_srcs "${_uade}/bencodetools/bencode.c")

  # libuade = src/frontends/common/*.c, EXCEPT md5.c (it is #included by
  # src/state_detection.c, so compiling it standalone duplicates MD5*).
  file(GLOB _libuade_srcs "${_s}/frontends/common/*.c")
  list(FILTER _libuade_srcs EXCLUDE REGEX "/md5\\.c$")

  # uadecore emulator = src/*.c, EXCEPT:
  #   ossupport/uadeipc/uadeutils/unixatomic — configure-duplicated, provided by
  #                                            frontends/common (same symbols)
  #   sd-sound.c   — dup of sd-sound-generic.c
  #   cpuemu.c     — compiled ×8 with -DPART_n below
  file(GLOB _core_srcs "${_s}/*.c")
  list(FILTER _core_srcs EXCLUDE REGEX
    "/(ossupport|uadeipc|uadeutils|unixatomic|sd-sound|cpuemu)\\.c$")

  # cpuemu.c ×8 (PART_1..8): generate one wrapper TU per part in the build dir,
  # each #including the single source with its PART_n define.
  set(_cpuemu_parts "")
  foreach(_n RANGE 1 8)
    set(_w "${CMAKE_CURRENT_BINARY_DIR}/uade_cpuemu_part${_n}.c")
    file(WRITE "${_w}" "#define PART_${_n}\n#include \"${_s}/cpuemu.c\"\n")
    list(APPEND _cpuemu_parts "${_w}")
  endforeach()

  add_library(rewamp_uade STATIC
    ${_zak_srcs} ${_ben_srcs} ${_libuade_srcs} ${_core_srcs} ${_cpuemu_parts})
  set_target_properties(rewamp_uade PROPERTIES POSITION_INDEPENDENT_CODE ON)

  # -D_DARWIN_C_SOURCE is macOS/iOS-only (the cmake path is Linux/Windows/Android).
  set(_uade_defs UADE_IN_PROCESS _DEFAULT_SOURCE)
  if(APPLE)
    list(APPEND _uade_defs _DARWIN_C_SOURCE)
  endif()
  target_compile_definitions(rewamp_uade PRIVATE ${_uade_defs})

  target_include_directories(rewamp_uade PRIVATE
    "${_s}"
    "${_s}/include"
    "${_s}/frontends/common"
    # webUADE+ audio.device layer: audiodevice.c includes the AmigaOS struct
    # headers ("devices/audio/audio.h", "exec/libraries.h") that live in the
    # score's own source tree. PRIVATE — these names are far too generic to
    # ever reach a shared include path.
    "${_uade}/amigasrc/score"
    "${_uade}/libzakalwe/include"
    "${_uade}/bencodetools/include"
    # ossupport.c (le résolveur de fichiers d'UADE) déclare les compagnons via
    # rewamp_loaded_files.h. Le header vit
    # dans src/, que ce target n'avait pas dans son chemin.
    "${REWAMP_SRC_DIR}")
  # Public API <uade/uade.h> for the plugin TU.
  target_include_directories(rewamp_uade PUBLIC "${_s}/frontends/include")

  # Force-include the exit()→longjmp shim on the uadecore emulator TUs ONLY
  # (uademain.c defines uadecore_exit/jmp_buf there); NOT on libuade/zakalwe/bencode.
  set_source_files_properties(${_core_srcs} ${_cpuemu_parts} PROPERTIES
    COMPILE_OPTIONS "-include;${_s}/uade_inprocess.h")

  find_package(Threads REQUIRED)
  target_link_libraries(rewamp_uade PRIVATE Threads::Threads)

  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_uade.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_UADE=1)
  target_link_libraries(${target} PRIVATE rewamp_uade)
endfunction()

# Builds NEZplug++ (HES / SGC-SMS) as an isolated static lib and wires the plugin.
# Per-voice oscilloscope + notes + mute live inside the vendored cores (device/
# s_hes.c, s_sng.c, opl/s_opl.c fill nezChan_output[]; format/audiosys.c copies it
# into m_voice_buff[] and honors generic_mute_mask). The curated source list is in
# nez_sources.cmake (NOT a glob — many cores share static fn names, so each is its
# own TU here; the Apple podspec builds one wrapper TU per file for the same reason).
function(rewamp_add_nez target)
  set(NEZ_ROOT "${REWAMP_THIRD_PARTY_DIR}/nez")
  if(NOT EXISTS "${NEZ_ROOT}/nezplug.h")
    message(FATAL_ERROR "REWAMP_WITH_NEZ=ON but NEZplug sources are missing at ${NEZ_ROOT}")
  endif()
  include("${NEZ_ROOT}/nez_sources.cmake")   # → NEZ_SOURCES

  add_library(rewamp_nez STATIC ${NEZ_SOURCES})
  set_target_properties(rewamp_nez PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_compile_definitions(rewamp_nez PRIVATE REWAMP_WITH_NEZ=1)
  target_include_directories(rewamp_nez PRIVATE
    "${NEZ_ROOT}"
    "${NEZ_ROOT}/format"
    "${NEZ_ROOT}/device"
    "${NEZ_ROOT}/device/nes"
    "${NEZ_ROOT}/device/opl"
    "${NEZ_ROOT}/cpu"
    "${NEZ_ROOT}/cpu/wkmz80"
    "${NEZ_ROOT}/cpu/km6502"
    "${REWAMP_SRC_DIR}")             # ModizerVoicesData.h for the patched cores
  # Public nezplug.h (+ format/songinfo.h) for the plugin TU.
  target_include_directories(rewamp_nez PUBLIC "${NEZ_ROOT}" "${NEZ_ROOT}/format")

  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_nez.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_NEZ=1)
  target_link_libraries(${target} PRIVATE rewamp_nez)
endfunction()

# Builds libkss (MSX chiptunes: KSS/MGS/BGM/MPK/MBM/OPX/MUS) as an isolated
# static lib and wires the plugin. Per-voice oscilloscope + notes + mute live
# inside the vendored cores (kssplay.c + emu2149/emu2212/emu2413/emu8950/
# emu76489 write m_voice_buff[] via m_voicesForceOfs, honor generic_mute_mask —
# grep YOYOFR). The three emu cores that clash with libgme's own PSG/SCC/OPLL
# emulators are namespaced kss_* (see patches/libkss). Curated by directory glob
# — the vendored tree carries only the build sources (kss2vgm / CLI tools pruned).
function(rewamp_add_kss target)
  set(KSS_ROOT "${REWAMP_THIRD_PARTY_DIR}/libkss")
  if(NOT EXISTS "${KSS_ROOT}/src/kssplay.h")
    message(FATAL_ERROR "REWAMP_WITH_KSS=ON but libkss sources are missing at ${KSS_ROOT}")
  endif()
  file(GLOB KSS_SOURCES
    "${KSS_ROOT}/src/*.c"
    "${KSS_ROOT}/src/filters/*.c"
    "${KSS_ROOT}/src/kss/*.c"
    "${KSS_ROOT}/src/rconv/*.c"
    "${KSS_ROOT}/src/vm/*.c"
    "${KSS_ROOT}/modules/emu2149/kss_emu2149.c"
    "${KSS_ROOT}/modules/emu2212/kss_emu2212.c"
    "${KSS_ROOT}/modules/emu2413/kss_emu2413.c"
    "${KSS_ROOT}/modules/emu8950/emu8950.c"
    "${KSS_ROOT}/modules/emu8950/emuadpcm.c"
    "${KSS_ROOT}/modules/emu76489/emu76489.c"
    "${KSS_ROOT}/modules/kmz80/kmdmg.c"
    "${KSS_ROOT}/modules/kmz80/kmevent.c"
    "${KSS_ROOT}/modules/kmz80/kmr800.c"
    "${KSS_ROOT}/modules/kmz80/kmz80.c"
    "${KSS_ROOT}/modules/kmz80/kmz80c.c"
    "${KSS_ROOT}/modules/kmz80/kmz80t.c")

  # FAC Soundtracker: le .MUS est enveloppé avec FST2.BIN — le replayer FAC
  # d'origine — dans une image KSS que la VM Z80 de libkss exécute. Même patron
  # que mgs2kss/mbm2kss/opx2kss, qui embarquent chacun leur driver MSX.
  list(APPEND KSS_SOURCES "${REWAMP_THIRD_PARTY_DIR}/mus2kss/mus2kss.c")

  add_library(rewamp_kss STATIC ${KSS_SOURCES})
  set_target_properties(rewamp_kss PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_compile_definitions(rewamp_kss PRIVATE REWAMP_WITH_KSS=1)
  # mus2kss porte un `main()` sous `#ifndef MUS2KSS_LIBRARY`: sans ce define, un
  # SECOND point d'entrée entre dans le binaire.
  target_compile_definitions(rewamp_kss PRIVATE MUS2KSS_LIBRARY=1)
  # libkss bundles Mamiya's kmz80 Z80 core; nez (wkmz80) bundles the SAME core and
  # exports 11 identical C symbols (kmevent_* + kmz80_ot_*, unprefixed — nez only
  # renamed its kmz80_/exec/reset to wkmz80_). Namespace libkss's to kss_* so both
  # link. Scoped to this lib → nez TUs keep the originals (decl+def+use rename
  # consistently since these symbols are libkss-internal). Kept in sync with the
  # app Podfiles' kss_kmz80_defs. See the kss-integration project memory.
  target_compile_definitions(rewamp_kss PRIVATE
    kmevent_alloc=kss_kmevent_alloc kmevent_free=kss_kmevent_free
    kmevent_gettimer=kss_kmevent_gettimer kmevent_init=kss_kmevent_init
    kmevent_process=kss_kmevent_process kmevent_reset=kss_kmevent_reset
    kmevent_setevent=kss_kmevent_setevent kmevent_settimer=kss_kmevent_settimer
    KMEVENT_FLAG=kss_KMEVENT_FLAG
    kmz80_ot_cbxx=kss_kmz80_ot_cbxx kmz80_ot_xx=kss_kmz80_ot_xx)
  target_include_directories(rewamp_kss PRIVATE
    "${REWAMP_THIRD_PARTY_DIR}/mus2kss"
    "${KSS_ROOT}/src"
    "${KSS_ROOT}/src/kss"
    "${KSS_ROOT}/src/vm"
    "${KSS_ROOT}/src/filters"
    "${KSS_ROOT}/src/rconv"
    "${KSS_ROOT}/modules"           # emu2149/kss_emu2149.h + drivers/*.h
    "${REWAMP_SRC_DIR}")            # ModizerVoicesData.h for the patched cores
  # Public headers for the plugin TU (rewamp_plugin_kss.cpp, compiled on ${target}):
  # kssplay.h pulls kss.h via -Isrc/kss AND rconv/psg_rconv.h via -Isrc, and that
  # header does #include "emu2149/kss_emu2149.h" → needs -Imodules. modules/ holds
  # only subdirs (emu2149/, kmz80/, …), no loose generic headers, so exposing it to
  # ${target} can't shadow another plugin's headers.
  target_include_directories(rewamp_kss PUBLIC
    "${KSS_ROOT}/src" "${KSS_ROOT}/src/kss" "${KSS_ROOT}/modules"
    # mus2kss.h: nom unique, aucun risque d'ombrage — le TU du greffon en a
    # besoin pour la porte .MUS.
    "${REWAMP_THIRD_PARTY_DIR}/mus2kss")

  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_kss.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_KSS=1)
  target_link_libraries(${target} PRIVATE rewamp_kss)
endfunction()

# Monkey's Audio (.ape) via the vendored MACLib (Modizer's curated 26-file set,
# mac_sources.cmake — NOT a glob: Old/ legacy core + Windows dialogs excluded).
# Flags mirror monkeyaudiocodec.xcodeproj: -DMACLIB_COMPILE (typedefs in
# NoWindows.h); config.h ships pre-generated with BUILD_CROSS_PLATFORM.
function(rewamp_add_mac target)
  set(MAC_ROOT "${REWAMP_THIRD_PARTY_DIR}/monkeyaudio/mac-master")
  if(NOT EXISTS "${MAC_ROOT}/src/MACLib/MACLib.h")
    message(FATAL_ERROR "REWAMP_WITH_MAC=ON but MACLib sources are missing at ${MAC_ROOT}")
  endif()
  include("${REWAMP_THIRD_PARTY_DIR}/monkeyaudio/mac_sources.cmake")  # → MAC_SOURCES

  add_library(rewamp_mac STATIC ${MAC_SOURCES})
  set_target_properties(rewamp_mac PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_compile_definitions(rewamp_mac PRIVATE MACLIB_COMPILE=1)
  target_include_directories(rewamp_mac PUBLIC
    "${MAC_ROOT}/src/Shared"
    "${MAC_ROOT}/src/MACLib")

  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_mac.cpp")
  set_source_files_properties("${REWAMP_SRC_DIR}/rewamp_plugin_mac.cpp"
    PROPERTIES COMPILE_DEFINITIONS "MACLIB_COMPILE=1")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_MAC=1)
  target_link_libraries(${target} PRIVATE rewamp_mac)
endfunction()

# ASAP (Atari 8-bit POKEY) — vendored generated C (third_party/asap/asap.c =
# upstream release + rewamp patches, see scripts/sync_asap.sh).
function(rewamp_add_asap target)
  set(ASAP_ROOT "${REWAMP_THIRD_PARTY_DIR}/asap")
  if(NOT EXISTS "${ASAP_ROOT}/asap.c")
    message(FATAL_ERROR "REWAMP_WITH_ASAP=ON but ASAP sources are missing at ${ASAP_ROOT}")
  endif()
  add_library(rewamp_asap STATIC "${ASAP_ROOT}/asap.c")
  set_target_properties(rewamp_asap PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_include_directories(rewamp_asap
    PRIVATE "${REWAMP_SRC_DIR}"          # ModizerVoicesData.h (voice patches)
    PUBLIC  "${ASAP_ROOT}")
  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_asap.c")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_ASAP=1)
  target_link_libraries(${target} PRIVATE rewamp_asap)
endfunction()

# HivelyTracker (.hvl/.ahx) — single vendored TU (Modizer hvl_replay with
# inline voice-capture patches).
function(rewamp_add_hvl target)
  set(HVL_ROOT "${REWAMP_THIRD_PARTY_DIR}/hivelytracker")
  if(NOT EXISTS "${HVL_ROOT}/hvl_replay.cpp")
    message(FATAL_ERROR "REWAMP_WITH_HVL=ON but sources are missing at ${HVL_ROOT}")
  endif()
  add_library(rewamp_hvl STATIC "${HVL_ROOT}/hvl_replay.cpp")
  set_target_properties(rewamp_hvl PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_include_directories(rewamp_hvl
    PRIVATE "${REWAMP_SRC_DIR}"
    PUBLIC  "${HVL_ROOT}")
  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_hvl.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_HVL=1)
  target_link_libraries(${target} PRIVATE rewamp_hvl)
endfunction()

# Farbrausch V2M (.v2m/.v2mz) — moteur v2redux, 5 TU. Détail dans la fonction.
function(rewamp_add_v2m target)
  # v2redux (spheenik, CC0): portage C++17 propre du V2, VERSION-NATIVE — il joue
  # chaque .v2m avec le moteur de son époque (formats 0..6) au lieu de convertir
  # vers la dernière version. Nos deux accroches d'affichage (oscilloscope par
  # voix, hauteur) sont dans src/v2core.cpp, marquées YOYOFR; le patch et son
  # amont pristine vivent dans patches/v2redux/.
  set(V2M_ROOT "${REWAMP_THIRD_PARTY_DIR}/v2redux")
  if(NOT EXISTS "${V2M_ROOT}/src/v2core.cpp")
    message(FATAL_ERROR "REWAMP_WITH_V2M=ON but sources are missing at ${V2M_ROOT}")
  endif()
  add_library(rewamp_v2m STATIC
    "${V2M_ROOT}/src/v2player.cpp" "${V2M_ROOT}/src/v2load.cpp"
    "${V2M_ROOT}/src/v2core.cpp"   "${V2M_ROOT}/src/v2seq.cpp"
    "${V2M_ROOT}/src/ronan.cpp")
  set_target_properties(rewamp_v2m PROPERTIES
    POSITION_INDEPENDENT_CODE ON CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON)
  # Contrat de déterminisme du moteur: pas de contraction FMA, jamais de
  # fast-math. Le Ronan (synthé de parole) est ON, sinon la voie 15 des morceaux
  # parlés (candytron, kkrieger) laisse fuir sa source glottale en bruit.
  target_compile_options(rewamp_v2m PRIVATE -ffp-contract=off)
  # V2MPLAYER_SYNC_FUNCTIONS ouvre CalcPositions, dont on tire l'instant du
  # DERNIER événement — lengthMs() rend la fin de la SÉQUENCE, très loin après
  # la dernière note sur certains fichiers (fr019: 4 min de musique, 67 min
  # annoncées).
  target_compile_definitions(rewamp_v2m PUBLIC V2_RONAN=1 V2MPLAYER_SYNC_FUNCTIONS=1)
  target_include_directories(rewamp_v2m
    PRIVATE "${REWAMP_SRC_DIR}"
    PUBLIC  "${V2M_ROOT}/src")
  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_v2m.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_V2M=1)
  target_link_libraries(${target} PRIVATE rewamp_v2m z)
endfunction()

# SNDH (Atari ST) — vendored AtariAudio (Arnaud Carré) + Musashi 68000 core.
# 8 TUs: the library's 5 top-level .cpp + Musashi's m68kcpu.c/m68kops.c (which
# #include m68kfpu.c/m68kops.h — NOT compiled standalone) + the ICE depacker.
# Per-voice scope + notes + mute live in the vendored cores (ym2149c.cpp fills
# m_voice_buff[0..2] for the PSG + honors generic_mute_mask in the actual mix;
# AtariMachine.cpp does the same for the STE DAC as voice 3 — grep YOYOFR).
# Musashi's CPU core is process-global (single static context): only one SNDH
# file can be actively decoding at a time (fine — rewamp only ever runs one).
function(rewamp_add_sndh target)
  set(SNDH_ROOT "${REWAMP_THIRD_PARTY_DIR}/atariaudio")
  if(NOT EXISTS "${SNDH_ROOT}/SndhFile.cpp")
    message(FATAL_ERROR "REWAMP_WITH_SNDH=ON but sources are missing at ${SNDH_ROOT}")
  endif()
  add_library(rewamp_sndh STATIC
    "${SNDH_ROOT}/AtariMachine.cpp" "${SNDH_ROOT}/Mk68901.cpp"
    "${SNDH_ROOT}/SndhFile.cpp" "${SNDH_ROOT}/SteDac.cpp" "${SNDH_ROOT}/ym2149c.cpp"
    "${SNDH_ROOT}/external/ice_24.c"
    "${SNDH_ROOT}/external/Musashi/m68kcpu.c" "${SNDH_ROOT}/external/Musashi/m68kops.c")
  set_target_properties(rewamp_sndh PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_include_directories(rewamp_sndh
    PRIVATE "${REWAMP_SRC_DIR}"          # ModizerVoicesData.h (voice patches)
    PUBLIC  "${SNDH_ROOT}")
  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_sndh.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_SNDH=1)
  target_link_libraries(${target} PRIVATE rewamp_sndh)
endfunction()

# PSG play (2nd Atari ST .sndh engine) — vendored psgplay (Fredrik Noring):
# whole-machine emulation (68000 + cf2149 YM2149 + cf68901 MFP + cf300588
# LMC1992 tone/volume mixer). GPL-2.0, like UADE and the other GPL cores here.
#
# It ships its OWN Musashi, which is the third 68000 in this binary (AtariAudio
# has one, highlytheoritical a second) — hence the rename block below, mirroring
# what highlytheoritical does. The list is not guesswork: it is the intersection
# of psgplay's exported symbols with the ones already in librewamp_audio, so it
# also catches the two non-m68k collisions (fifo_read / fifo_write, which the
# UADE/HVL side already defines).
#
# `include/tos/tos.h` and `lib/m68k/m68kops.c` are GENERATED upstream (by an
# m68k cross build and by m68kmake). Both are vendored pre-generated, exactly
# like AtariAudio's m68kops.c — no cross toolchain is needed to build rewamp.
set(REWAMP_PSGPLAY_RENAMES
  m68k_context_size m68k_cycles_remaining m68k_cycles_run m68k_end_timeslice
  m68k_execute m68k_get_context m68k_get_reg m68k_get_virq m68k_init
  m68k_modify_timeslice m68k_pulse_halt m68k_pulse_reset m68k_read_memory_16
  m68k_read_memory_32 m68k_read_memory_8 m68k_set_bkpt_ack_callback
  m68k_set_cmpild_instr_callback m68k_set_context m68k_set_cpu_type
  m68k_set_fc_callback m68k_set_illg_instr_callback m68k_set_instr_hook_callback
  m68k_set_int_ack_callback m68k_set_irq m68k_set_pc_changed_callback
  m68k_set_reg m68k_set_reset_instr_callback m68k_set_rte_instr_callback
  m68k_set_tas_instr_callback m68k_set_virq m68k_write_memory_16
  m68k_write_memory_32 m68k_write_memory_8 m68k_clear_timeslice
  m68ki_build_opcode_table m68ki_cpu_names m68ki_ea_idx_cycle_table
  m68ki_exception_cycle_table m68ki_shift_16_table m68ki_shift_32_table
  m68ki_shift_8_table m68ki_instruction_jump_table
  fifo_read fifo_write)

function(rewamp_add_psgplay target)
  set(PSG_ROOT "${REWAMP_THIRD_PARTY_DIR}/psgplay")
  if(NOT EXISTS "${PSG_ROOT}/lib/psgplay/psgplay.c")
    message(FATAL_ERROR "REWAMP_WITH_PSGPLAY=ON but sources are missing at ${PSG_ROOT}")
  endif()
  # The vendored tree is a CURATED subset (upstream tooling — m68kmake, the
  # disassembler, the ALSA/portaudio writers — was left out), so a recursive
  # glob matches exactly the set that goes into upstream's libpsgplay.a.
  file(GLOB_RECURSE PSGPLAY_SOURCES "${PSG_ROOT}/lib/*.c")
  add_library(rewamp_psgplay STATIC ${PSGPLAY_SOURCES})
  set_target_properties(rewamp_psgplay PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_include_directories(rewamp_psgplay PUBLIC
    "${PSG_ROOT}/include"
    "${PSG_ROOT}/lib/cf2149/include"
    "${PSG_ROOT}/lib/cf68901/include"
    "${PSG_ROOT}/lib/cf300588/include"
    "${PSG_ROOT}/lib/toslibc/include")
  set(_psg_defs "")
  foreach(sym ${REWAMP_PSGPLAY_RENAMES})
    list(APPEND _psg_defs "${sym}=psg_${sym}")
  endforeach()
  target_compile_definitions(rewamp_psgplay PUBLIC ${_psg_defs})
  target_compile_options(rewamp_psgplay PRIVATE -w)
  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_psgplay.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_PSGPLAY=1)
  target_link_libraries(${target} PRIVATE rewamp_psgplay)
endfunction()

# libLazyusf (N64 .usf/.miniusf) — vendored, curated ~52-file interpreter-only
# subset of a Mupen64plus-derived R4300+RSP emulator (no dynarec: only the
# files listed as compiled in the upstream Makefile's non-DYNAREC path, +
# r4300/empty_dynarec.c). third_party/lazyusf/ contains ONLY that curated set
# (unlike most vendored trees here, nothing extra to glob past), so a
# recursive glob is safe and exactly matches it. RSP LLE vector-unit code
# auto-picks NEON via the compiler's own __ARM_NEON define; SSE2 needs an
# explicit -DARCH_MIN_SSE2 (falls back to a portable scalar path without it —
# correctness is never at risk, only performance on x86). Uses zlib (psflib's
# _lib chain decompression + an internal adler32/crc32 utility).
function(rewamp_add_lazyusf target)
  set(LAZYUSF_ROOT "${REWAMP_THIRD_PARTY_DIR}/lazyusf")
  if(NOT EXISTS "${LAZYUSF_ROOT}/usf/usf.c")
    message(FATAL_ERROR "REWAMP_WITH_LAZYUSF=ON but sources are missing at ${LAZYUSF_ROOT}")
  endif()
  file(GLOB_RECURSE LAZYUSF_SOURCES "${LAZYUSF_ROOT}/*.c")
  add_library(rewamp_lazyusf STATIC ${LAZYUSF_SOURCES})
  set_target_properties(rewamp_lazyusf PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_include_directories(rewamp_lazyusf
    PRIVATE "${REWAMP_SRC_DIR}"          # ModizerVoicesData.h (voice patches)
    PUBLIC  "${LAZYUSF_ROOT}")
  if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
    target_compile_definitions(rewamp_lazyusf PRIVATE ARCH_MIN_SSE2)
  endif()
  target_link_libraries(rewamp_lazyusf PRIVATE z)
  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_lazyusf.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_LAZYUSF=1)
  # USF is a PSF-family format (magic 0x21), read via libpsflib — same file
  # highlyexp/vio2sf/gsf already compile, in that priority order; only add it
  # here if none of them did (avoids duplicate symbols — see the gsf block).
  target_include_directories(${target} PRIVATE "${REWAMP_THIRD_PARTY_DIR}")
  if(NOT REWAMP_WITH_HIGHLYEXP AND NOT REWAMP_WITH_VIO2SF AND NOT REWAMP_WITH_GSF)
    target_sources(${target} PRIVATE
      "${REWAMP_THIRD_PARTY_DIR}/libpsflib/psflib.c"
      "${REWAMP_THIRD_PARTY_DIR}/libpsflib/psf2fs.c")
  endif()
  target_link_libraries(${target} PRIVATE rewamp_lazyusf)
endfunction()

# WonderSwan (.wsr rip) — beetle-wswan-libretro (Mednafen lineage), vendored
# headless. The tree is curated (no tcache renderer frontend, no libretro glue),
# so a recursive glob is exact. wswan/ and sound/ are upstream byte-for-byte
# except the capture hooks in sound.c (see patches/wonderswan/); everything the
# libretro frontend used to provide lives in the compat headers at the root and
# in rewamp_wswan.c.
#
# No symbol renames needed, verified with nm against the whole engine set: the
# only names shared with another core (rom_size, v30mz_timestamp, wsRAM) are
# locals/members/class fields elsewhere, never competing globals. The Blip_Buffer
# here is the C one and clashes with nothing (libgme's is a C++ class, vio2sf's
# was already renamed blip_* → vio2sf_blip_*).
function(rewamp_add_wonderswan target)
  set(WS_ROOT "${REWAMP_THIRD_PARTY_DIR}/wonderswan")
  if(NOT EXISTS "${WS_ROOT}/rewamp_wswan.c")
    message(FATAL_ERROR "REWAMP_WITH_WONDERSWAN=ON but sources are missing at ${WS_ROOT}")
  endif()
  file(GLOB_RECURSE WS_SOURCES "${WS_ROOT}/*.c")
  add_library(rewamp_wonderswan STATIC ${WS_SOURCES})
  set_target_properties(rewamp_wonderswan PROPERTIES POSITION_INDEPENDENT_CODE ON)
  # Every internal include is RELATIVE except <boolean.h>/<retro_inline.h>;
  # both live in include/ and neither name exists anywhere else in the tree.
  target_include_directories(rewamp_wonderswan
    PRIVATE "${REWAMP_SRC_DIR}"          # ModizerVoicesData.h (capture hooks)
    PUBLIC  "${WS_ROOT}" "${WS_ROOT}/include")
  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_wonderswan.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_WONDERSWAN=1)
  target_link_libraries(${target} PRIVATE rewamp_wonderswan)
endfunction()

# HighlyQuixotic (Capcom QSound .qsf/.qsflib) — real Z80 CPU (z80.c) driving
# the ripped CPS2 sound-board program against a QSound DSP core (hq_qsound_ctr.c,
# libvgm-derived), kabuki.c decrypting kabuki-protected Z80 program ROMs.
# QSF is PSF-family (magic 0x41); the loader (KEY/Z80/SMP tagged sections) is
# NOT the usual PSF exe-blob convention and ships nowhere in Modizer's own
# libs (the ObjC wrapper was an empty stub) — it's ported into
# rewamp_plugin_highlyquixotic.cpp from Modizer's real, working
# ModizMusicPlayer.mm (mmp_HCLoad, HC_type==0x41). Needs EMU_COMPILE +
# EMU_LITTLE_ENDIAN + HAVE_STDINT_H (Modizer's shared emuconfig.h convention).
# Per-voice scope+notes+mute live in hq_qsound_ctr.c (grep YOYOFR) — its two
# gates originally referenced a Modizer app-level global (HC_voicesMuteMask1)
# that doesn't exist in rewamp; fixed to rely on chip->muteMask (a real
# per-instance field, wired from generic_mute_mask via qsoundc_set_mute_mask
# in the plugin) instead of reintroducing a bare global.
function(rewamp_add_highlyquixotic target)
  set(HQ_ROOT "${REWAMP_THIRD_PARTY_DIR}/highlyquixotic")
  if(NOT EXISTS "${HQ_ROOT}/qsound.c")
    message(FATAL_ERROR "REWAMP_WITH_HIGHLYQUIXOTIC=ON but sources are missing at ${HQ_ROOT}")
  endif()
  set(HQ_SOURCES
    "${HQ_ROOT}/qsound.c" "${HQ_ROOT}/hq_qsound_ctr.c"
    "${HQ_ROOT}/kabuki.c" "${HQ_ROOT}/z80.c")
  add_library(rewamp_highlyquixotic STATIC ${HQ_SOURCES})
  set_target_properties(rewamp_highlyquixotic PROPERTIES POSITION_INDEPENDENT_CODE ON)
  # Full isolation while debugging the QSF silent-hang issue (see the
  # highlyquixotic-qsf-hang project memory): every non-static (externally
  # linked) symbol across qsound.c/z80.c/kabuki.c/hq_qsound_ctr.c gets an
  # hqx_ prefix, verified exhaustively via `nm` on the compiled objects
  # (not just grepping headers) so nothing is missed. Superset of Modizer's
  # own qsoundc_*/device_*_qsound_ctr HQ* renames. Must ALSO apply to the
  # plugin TU below (not just this lib), since it calls these functions
  # directly through the same headers.
  set(HQ_SYMBOL_RENAMES
    z80_break=hqx_z80_break
    z80_clear_state=hqx_z80_clear_state
    z80_execute=hqx_z80_execute
    z80_get_state_size=hqx_z80_get_state_size
    z80_getpc=hqx_z80_getpc
    z80_init=hqx_z80_init
    z80_set_advance_callback=hqx_z80_set_advance_callback
    z80_set_memory_maps=hqx_z80_set_memory_maps
    z80_setirq=hqx_z80_setirq
    z80_setnmi=hqx_z80_setnmi
    kabuki_decode=hqx_kabuki_decode
    qsound_clear_state=hqx_qsound_clear_state
    qsound_execute=hqx_qsound_execute
    qsound_get_odometer=hqx_qsound_get_odometer
    qsound_get_qmix_state=hqx_qsound_get_qmix_state
    qsound_get_r3000_state=hqx_qsound_get_r3000_state
    qsound_get_state_size=hqx_qsound_get_state_size
    qsound_get_z80_state=hqx_qsound_get_z80_state
    qsound_getpc=hqx_qsound_getpc
    qsound_getversion=hqx_qsound_getversion
    qsound_init=hqx_qsound_init
    qsound_map_op_entries=hqx_qsound_map_op_entries
    qsound_map_read_entries=hqx_qsound_map_read_entries
    qsound_map_write_entries=hqx_qsound_map_write_entries
    qsound_set_kabuki_key=hqx_qsound_set_kabuki_key
    qsound_set_rates=hqx_qsound_set_rates
    qsound_set_sample_rom=hqx_qsound_set_sample_rom
    qsound_set_z80_rom=hqx_qsound_set_z80_rom
    device_get_qsound_ctr_state_size=hqx_device_get_qsound_ctr_state_size
    device_reset_qsound_ctr=hqx_device_reset_qsound_ctr
    device_start_qsound_ctr=hqx_device_start_qsound_ctr
    device_stop_qsound_ctr=hqx_device_stop_qsound_ctr
    qsoundc_alloc_rom=hqx_qsoundc_alloc_rom
    qsoundc_r=hqx_qsoundc_r
    qsoundc_set_mute_mask=hqx_qsoundc_set_mute_mask
    qsoundc_update=hqx_qsoundc_update
    qsoundc_w=hqx_qsoundc_w
    qsoundc_write_data=hqx_qsoundc_write_data
    qsoundc_write_rom=hqx_qsoundc_write_rom)
  target_compile_definitions(rewamp_highlyquixotic PRIVATE
    EMU_COMPILE EMU_LITTLE_ENDIAN HAVE_STDINT_H ${HQ_SYMBOL_RENAMES})
  target_include_directories(rewamp_highlyquixotic
    PRIVATE "${REWAMP_SRC_DIR}"          # ModizerVoicesData.h (voice patches)
    PUBLIC  "${HQ_ROOT}")
  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_highlyquixotic.cpp")
  set_source_files_properties("${REWAMP_SRC_DIR}/rewamp_plugin_highlyquixotic.cpp" PROPERTIES
    COMPILE_DEFINITIONS "${HQ_SYMBOL_RENAMES}")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_HIGHLYQUIXOTIC=1)
  # QSF is a PSF-family format (magic 0x41), read via libpsflib — same
  # priority-chain ownership as gsf/vio2sf/lazyusf (see the gsf block).
  target_include_directories(${target} PRIVATE "${REWAMP_THIRD_PARTY_DIR}")
  if(NOT REWAMP_WITH_HIGHLYEXP AND NOT REWAMP_WITH_VIO2SF AND NOT REWAMP_WITH_GSF AND NOT REWAMP_WITH_LAZYUSF)
    target_sources(${target} PRIVATE
      "${REWAMP_THIRD_PARTY_DIR}/libpsflib/psflib.c"
      "${REWAMP_THIRD_PARTY_DIR}/libpsflib/psf2fs.c")
    target_link_libraries(${target} PRIVATE z)
  endif()
  target_link_libraries(${target} PRIVATE rewamp_highlyquixotic)
endfunction()

# highlytheoritical (Saturn .ssf 32ch SCSP / Dreamcast .dsf 64ch AICA) — real
# Musashi-derived 68000 CPU (Saturn's sound-board MC68EC000, satsound.c built
# with -DUSE_M68K — the other two options, Starscream and c68k, aren't
# vendored: Modizer's own checkout doesn't have them) or ARM7 core
# (Dreamcast's AICA controller, arm.c) driving the ripped sound-driver
# program against a shared Yamaha SCSP-derived DSP (yam.c). SSF/DSF are
# PSF-family (magic 0x11/0x12); loader ported from ModizMusicPlayer.mm
# (mmp_HCLoad, HC_type==0x11/0x12) same as HighlyQuixotic's QSF loader —
# Modizer's own libs/highlytheoritical shipped no working glue either.
# Musashi's public m68k_*/m68ki_* symbols are -D-renamed to ht_* to avoid a
# duplicate-symbol clash with the SNDH engine's OWN separate Musashi vendor
# copy (third_party/atariaudio/external/Musashi) — different vendored
# instance, same upstream project, same public API surface.
function(rewamp_add_highlytheoritical target)
  set(HT_ROOT "${REWAMP_THIRD_PARTY_DIR}/highlytheoritical")
  if(NOT EXISTS "${HT_ROOT}/sega.c")
    message(FATAL_ERROR "REWAMP_WITH_HIGHLYTHEORITICAL=ON but sources are missing at ${HT_ROOT}")
  endif()
  set(HT_SOURCES
    "${HT_ROOT}/sega.c" "${HT_ROOT}/satsound.c" "${HT_ROOT}/dcsound.c"
    "${HT_ROOT}/arm.c" "${HT_ROOT}/yam.c"
    "${HT_ROOT}/m68k/m68kcpu.c" "${HT_ROOT}/m68k/m68kops.c")
  add_library(rewamp_highlytheoritical STATIC ${HT_SOURCES})
  set_target_properties(rewamp_highlytheoritical PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_compile_definitions(rewamp_highlytheoritical PRIVATE
    EMU_COMPILE EMU_LITTLE_ENDIAN HAVE_STDINT_H USE_M68K LSB_FIRST
    m68k_set_irq=ht_m68k_set_irq
    m68k_execute=ht_m68k_execute
    m68k_pulse_reset=ht_m68k_pulse_reset
    m68k_init=ht_m68k_init
    m68ki_build_opcode_table=ht_m68ki_build_opcode_table
    m68ki_shift_8_table=ht_m68ki_shift_8_table
    m68ki_shift_16_table=ht_m68ki_shift_16_table
    m68ki_shift_32_table=ht_m68ki_shift_32_table
    m68ki_exception_cycle_table=ht_m68ki_exception_cycle_table
    m68ki_ea_idx_cycle_table=ht_m68ki_ea_idx_cycle_table
    m68ki_instruction_jump_table=ht_m68ki_instruction_jump_table
    m68ki_cycles=ht_m68ki_cycles)
  target_include_directories(rewamp_highlytheoritical
    PRIVATE "${REWAMP_SRC_DIR}"          # ModizerVoicesData.h (voice patches)
    PUBLIC  "${HT_ROOT}" "${HT_ROOT}/m68k")
  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_highlytheoritical.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_HIGHLYTHEORITICAL=1)
  # SSF/DSF is a PSF-family format (magic 0x11/0x12), read via libpsflib —
  # same priority-chain ownership as gsf/vio2sf/lazyusf/highlyquixotic.
  target_include_directories(${target} PRIVATE "${REWAMP_THIRD_PARTY_DIR}")
  if(NOT REWAMP_WITH_HIGHLYEXP AND NOT REWAMP_WITH_VIO2SF AND NOT REWAMP_WITH_GSF
     AND NOT REWAMP_WITH_LAZYUSF AND NOT REWAMP_WITH_HIGHLYQUIXOTIC)
    target_sources(${target} PRIVATE
      "${REWAMP_THIRD_PARTY_DIR}/libpsflib/psflib.c"
      "${REWAMP_THIRD_PARTY_DIR}/libpsflib/psf2fs.c")
    target_link_libraries(${target} PRIVATE z)
  endif()
  target_link_libraries(${target} PRIVATE rewamp_highlytheoritical)
endfunction()

# libpt3 (ZX Spectrum .pt3, ProTracker 3) — pt3player.c (Volutar) + ayumi.c
# (Peter Sovietov, AY-3-8910/YM2149 synth). Self-contained, no libpsflib
# dependency. Unlike the PSF-family engines earlier in this batch, the
# register-to-synth translation + render loop live in
# rewamp_plugin_libpt3.cpp itself (ported from ModizMusicPlayer.mm, which
# doesn't patch pt3player.c/ayumi.c with that logic — only the per-voice
# capture patches are inline in ayumi.c, grep YOYOFR). No generic header
# names here (ayumi.h/pt3player.h are unique pod-wide) — no per-file scoping
# needed, unlike every other engine in this batch.
function(rewamp_add_libpt3 target)
  set(PT3_ROOT "${REWAMP_THIRD_PARTY_DIR}/libpt3")
  if(NOT EXISTS "${PT3_ROOT}/pt3player.c")
    message(FATAL_ERROR "REWAMP_WITH_LIBPT3=ON but sources are missing at ${PT3_ROOT}")
  endif()
  add_library(rewamp_libpt3 STATIC "${PT3_ROOT}/pt3player.c" "${PT3_ROOT}/ayumi.c")
  set_target_properties(rewamp_libpt3 PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_include_directories(rewamp_libpt3
    PRIVATE "${REWAMP_SRC_DIR}"          # ModizerVoicesData.h (voice patches)
    PUBLIC  "${PT3_ROOT}")
  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_libpt3.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_LIBPT3=1)
  target_link_libraries(${target} PRIVATE rewamp_libpt3)
endfunction()

# TIATracker (Atari VCS 2600 .ttt) — our own JSON parser + replayer under
# src/tiatracker (the replayer transcribes TIATracker's 6502 routine, which is
# Apache-2.0; the tracker APPLICATION is GPLv2 and none of it is used here),
# on top of Stella's TIA sound core vendored at third_party/tiasound.
#
# That core is a SECOND copy of what furnace already ships under
# src/engine/platform/sound/tia, renamed to `namespace TttTia`. Linking
# furnace's objects instead would make .ttt support vanish whenever
# REWAMP_WITH_FURNACE=0 — and the file names (Audio.cpp / AudioChannel.cpp)
# are generic enough that they need their own target regardless.
function(rewamp_add_tiatracker target)
  set(TIA_ROOT "${REWAMP_THIRD_PARTY_DIR}/tiasound")
  if(NOT EXISTS "${TIA_ROOT}/Audio.cpp")
    message(FATAL_ERROR "REWAMP_WITH_TIATRACKER=ON but sources are missing at ${TIA_ROOT}")
  endif()
  add_library(rewamp_tiasound STATIC "${TIA_ROOT}/Audio.cpp" "${TIA_ROOT}/AudioChannel.cpp")
  set_target_properties(rewamp_tiasound PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_include_directories(rewamp_tiasound PRIVATE "${TIA_ROOT}")
  target_sources(${target} PRIVATE
    "${REWAMP_SRC_DIR}/rewamp_plugin_tiatracker.cpp"
    "${REWAMP_SRC_DIR}/tiatracker/ttt_song.cpp"
    "${REWAMP_SRC_DIR}/tiatracker/ttt_player.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_TIATRACKER=1)
  target_link_libraries(${target} PRIVATE rewamp_tiasound)
endfunction()

# Organya (Cave Story .org) — a single self-contained file (Daisuke "Pixel"
# Amaya's engine, ported to a portable memory-based API by Juergen Wothke's
# webPixel project — third_party/libpixel/organya/organya.c IS that
# adapter, not the raw Windows Winamp plugin source Modizer's libs/libpixel
# also carries). No header of its own; the 34 .inc drum-sample data files
# are same-directory quote-includes (self-resolving, no extra include dir
# needed at all — simplest wiring in this whole batch). The plugin declares
# the org_* API directly via extern "C" prototypes, no shared header.
function(rewamp_add_organya target)
  set(ORG_ROOT "${REWAMP_THIRD_PARTY_DIR}/libpixel/organya")
  if(NOT EXISTS "${ORG_ROOT}/organya.c")
    message(FATAL_ERROR "REWAMP_WITH_ORGANYA=ON but sources are missing at ${ORG_ROOT}")
  endif()
  add_library(rewamp_organya STATIC "${ORG_ROOT}/organya.c")
  set_target_properties(rewamp_organya PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_include_directories(rewamp_organya PRIVATE "${REWAMP_SRC_DIR}")  # ModizerVoicesData.h
  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_organya.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_ORGANYA=1)
  target_link_libraries(${target} PRIVATE rewamp_organya)
endfunction()

# ProWizard (packed Amiga modules → Protracker MOD). NOT a decoder plugin: it
# is a converter rewamp_load_file() calls as a LAST RESORT when no plugin could
# open a file (see the comment there). Sources are libxmp's MIT prowizard set,
# vendored verbatim except prowiz.h's three include lines; this directory also
# supplies rewamp's own minimal xmp.h/common.h/format.h/hio.h so no part of
# libxmp itself is needed. Everything sits in ONE flat directory on purpose:
# every include is a same-dir quote-include, so NO include dir is needed here
# or in the podspecs — and "common.h"/"format.h"/"hio.h" (about as
# collision-prone as header names get) never reach anyone else's search path.
# rewamp_audio.c reaches the public header by relative path for the same reason.
function(rewamp_add_prowizard target)
  set(PW_ROOT "${REWAMP_THIRD_PARTY_DIR}/prowizard")
  if(NOT EXISTS "${PW_ROOT}/prowiz.c")
    message(FATAL_ERROR "REWAMP_WITH_PROWIZARD=ON but sources are missing at ${PW_ROOT}")
  endif()
  file(GLOB PW_SOURCES "${PW_ROOT}/*.c")
  add_library(rewamp_prowizard STATIC ${PW_SOURCES})
  set_target_properties(rewamp_prowizard PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_compile_options(rewamp_prowizard PRIVATE -w)
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_PROWIZARD=1)
  target_link_libraries(${target} PRIVATE rewamp_prowizard)
endfunction()

# sc68 (.sc68, Atari ST + Amiga) — real emu68 68000 emulation driving YM-2149
# + STE MicroWire (Atari) or Paula (Amiga). Curated 50-file set mirroring
# modizer.xcodeproj (emu68's line*_68.c / lines/*.c / cc68 / table68 and
# io68's ym_*_table.c are #include-only; dial68 + sc68-libc + the unice68 CLI
# are not compiled). EMU68_MONOLITIC is mandatory for lines68.c. The pre-baked
# config.h (tree root) carries FILE68_Z/FILE68_UNICE68/USE_REPLAY68 — see its
# comments; include dirs stay PRIVATE to this target ("config.h", io68's
# "default.h" are collision-prone names). REWAMP_SC68 turns on the Wothke
# trace-stream scope plumbing (guards extended from EMSCRIPTEN||__APPLE__).
function(rewamp_add_sc68 target)
  set(SC68_ROOT "${REWAMP_THIRD_PARTY_DIR}/sc68")
  if(NOT EXISTS "${SC68_ROOT}/libsc68/src/api68.c")
    message(FATAL_ERROR "REWAMP_WITH_SC68=ON but sources are missing at ${SC68_ROOT}")
  endif()
  set(_sc68_srcs
    file68/src/endian68.c file68/src/error68.c file68/src/file68.c
    file68/src/gzip68.c file68/src/ice68.c file68/src/init68.c
    file68/src/msg68.c file68/src/option68.c file68/src/registry68.c
    file68/src/replay68.c file68/src/rsc68.c file68/src/string68.c
    file68/src/timedb68.c file68/src/uri68.c file68/src/vfs68.c
    file68/src/vfs68_ao.c file68/src/vfs68_curl.c file68/src/vfs68_fd.c
    file68/src/vfs68_file.c file68/src/vfs68_mem.c file68/src/vfs68_null.c
    file68/src/vfs68_z.c
    libsc68/emu68/emu68.c libsc68/emu68/error68.c libsc68/emu68/getea68.c
    libsc68/emu68/inst68.c libsc68/emu68/ioplug68.c libsc68/emu68/lines68.c
    libsc68/emu68/mem68.c
    libsc68/io68/io68.c libsc68/io68/mfp_io.c libsc68/io68/mfpemul.c
    libsc68/io68/mw_io.c libsc68/io68/mwemul.c libsc68/io68/paula_io.c
    libsc68/io68/paulaemul.c libsc68/io68/shifter_io.c libsc68/io68/ym_blep.c
    libsc68/io68/ym_dump.c libsc68/io68/ym_envel.c libsc68/io68/ym_io.c
    libsc68/io68/ym_puls.c libsc68/io68/ymemul.c
    libsc68/src/api68.c libsc68/src/conf68.c libsc68/src/libsc68.c
    libsc68/src/mixer68.c
    unice68/unice68_pack.c unice68/unice68_unpack.c unice68/unice68_version.c)
  list(TRANSFORM _sc68_srcs PREPEND "${SC68_ROOT}/")
  add_library(rewamp_sc68 STATIC ${_sc68_srcs})
  set_target_properties(rewamp_sc68 PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_compile_definitions(rewamp_sc68 PRIVATE
    HAVE_CONFIG_H EMU68_MONOLITIC REWAMP_SC68)
  target_include_directories(rewamp_sc68 PRIVATE
    "${SC68_ROOT}"                # pre-baked config.h
    "${SC68_ROOT}/file68"
    "${SC68_ROOT}/file68/sc68"
    "${SC68_ROOT}/file68/src"
    "${SC68_ROOT}/libsc68"
    "${SC68_ROOT}/libsc68/sc68"
    "${SC68_ROOT}/libsc68/emu68"
    "${SC68_ROOT}/libsc68/io68"
    "${SC68_ROOT}/unice68")
  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_sc68.cpp")
  set_source_files_properties("${REWAMP_SRC_DIR}/rewamp_plugin_sc68.cpp"
    PROPERTIES COMPILE_DEFINITIONS "REWAMP_SC68"
               INCLUDE_DIRECTORIES "${SC68_ROOT}/libsc68")  # <sc68/sc68.h>
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_SC68=1)
  target_link_libraries(${target} PRIVATE rewamp_sc68 z)
endfunction()

# SunVox (.sunvox) — Alexander Zolotov's modular synth + tracker. Vendored full
# source (headless SunDog config). Dedicated static lib: the SunDog tree has
# ultra-generic header names (file.h/log.h/main.h/memory.h/sound.h/time.h/…) so
# ALL include dirs stay PRIVATE — only the unique-named public sunvox.h is
# exposed to ${target} for the plugin TU. sound.cpp compiles the platform audio
# backend even in OFFLINE mode, so the per-OS device libs must be linked.
function(rewamp_add_sunvox target)
  set(SV_ROOT "${REWAMP_THIRD_PARTY_DIR}/sunvox")
  if(NOT EXISTS "${SV_ROOT}/sunvox_sources.txt")
    message(FATAL_ERROR "REWAMP_WITH_SUNVOX=ON but sources are missing at ${SV_ROOT}")
  endif()
  # Même abonnement que pour projectM (voir la note là-bas): sans lui, ajouter
  # un fichier à la liste ne reconfigure pas et l'échec sort en symbole non
  # défini à l'édition de liens.
  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
      "${SV_ROOT}/sunvox_sources.txt")
  file(STRINGS "${SV_ROOT}/sunvox_sources.txt" SV_REL_SOURCES)
  set(SV_SOURCES "")
  foreach(_rel ${SV_REL_SOURCES})
    string(STRIP "${_rel}" _rel)
    if(_rel)
      list(APPEND SV_SOURCES "${SV_ROOT}/${_rel}")
    endif()
  endforeach()
  # Android: NOT SunDog's own sundog_bridge.cpp — that TU is a full
  # NativeActivity host and does not compile under NOGUI/NOVIDEO (its `engine`
  # struct declares EGLDisplay/EGLSurface/EGLContext members whose headers only
  # come in through the GUI path). Under NOMAIN the only thing the compiled
  # SunDog TUs still need from it is a handful of g_android_* path globals, so a
  # small stand-in supplies those. Desktop uses file.cpp's POSIX path and needs
  # no platform TU at all (file_apple.mm is Apple/podspec only).
  if(ANDROID)
    list(APPEND SV_SOURCES "${SV_ROOT}/rewamp_sunvox_android.cpp")
  endif()

  add_library(rewamp_sunvox STATIC ${SV_SOURCES})
  set_target_properties(rewamp_sunvox PROPERTIES
    POSITION_INDEPENDENT_CODE ON CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON)
  # Headless SunDog defines (HOW_TO_MAKE.txt + make/Makefile), encoders off.
  target_compile_definitions(rewamp_sunvox PRIVATE
    NOMAIN NOGUI NDEBUG MIN_SAMPLE_RATE=44100 SUNVOX_LIB
    NOVIDEO NOVCAP NOLIST NOFILEUTILS NOIMAGEFORMATS NOMIDI
    PS_STYPE_FLOAT32 COLOR16BITS NOOGGENC NOFLACENC)
  target_compile_options(rewamp_sunvox PRIVATE -w)   # vendored tree is noisy
  if(ANDROID)
    # sundog_bridge.h (pulled in by file.cpp/misc.cpp/thread.cpp under
    # OS_ANDROID) includes <android_native_app_glue.h>, which the NDK ships as
    # a source module rather than in the sysroot. Header only — the glue .c is
    # for apps that own the activity, which we do not.
    target_include_directories(rewamp_sunvox PRIVATE
      "${CMAKE_ANDROID_NDK}/sources/android/native_app_glue")
  endif()
  target_include_directories(rewamp_sunvox PRIVATE
    "${SV_ROOT}/lib_sundog"
    "${SV_ROOT}/lib_sunvox"
    "${SV_ROOT}/lib_dsp"
    "${SV_ROOT}/lib_flac/libFLAC"
    "${SV_ROOT}/lib_vorbis/tremor"
    "${SV_ROOT}/lib_mp3")
  # Only the unique-named public C API header is visible to ${target}.
  target_include_directories(rewamp_sunvox PUBLIC "${SV_ROOT}/sunvox_lib/headers")

  # Per-OS audio-device backend that sound.cpp pulls in (compiled even offline).
  if(ANDROID)
    target_link_libraries(rewamp_sunvox PRIVATE OpenSLES aaudio log android)
  elseif(WIN32)
    target_link_libraries(rewamp_sunvox PRIVATE dsound dxguid winmm ole32)
  elseif(UNIX)
    target_link_libraries(rewamp_sunvox PRIVATE asound pthread dl)
  endif()

  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_sunvox.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_SUNVOX=1)
  target_link_libraries(${target} PRIVATE rewamp_sunvox)
endfunction()

# PxTone Collage (.ptcop/.pttune) — Pixel's own library (Modizer's copy with
# the YOYOFR voice-capture patches), sibling of Organya in libpixel/. All 21
# .cpp compile (glob-safe: the vendored dir holds exactly the curated set,
# vorbis dir deliberately NOT vendored — pxINCLUDE_OGGVORBIS stays off,
# matching Modizer). Headers are pxtn*-prefixed, no collision risk.
function(rewamp_add_pxtone target)
  set(PXT_ROOT "${REWAMP_THIRD_PARTY_DIR}/libpixel/pxtone")
  if(NOT EXISTS "${PXT_ROOT}/pxtnService.cpp")
    message(FATAL_ERROR "REWAMP_WITH_PXTONE=ON but sources are missing at ${PXT_ROOT}")
  endif()
  file(GLOB PXT_SOURCES "${PXT_ROOT}/*.cpp")
  add_library(rewamp_pxtone STATIC ${PXT_SOURCES})
  set_target_properties(rewamp_pxtone PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_include_directories(rewamp_pxtone
    PRIVATE "${REWAMP_SRC_DIR}"          # ModizerVoicesData.h (voice patches)
    PUBLIC  "${PXT_ROOT}")               # pxtn*-prefixed headers, no collision
  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_pxtone.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_PXTONE=1)
  target_link_libraries(${target} PRIVATE rewamp_pxtone)
endfunction()

# PMD (PC-98 Professional Music Driver, .m/.m2/.mz) — libpmdmini: C60's PMDWin
# core + ymfm's OPNA/SSG/ADPCM emulation, with Modizer's YOYOFR voice capture.
# 15 TUs (the vendored tree holds exactly the upstream-compiled set, so the glob
# is exact — ymfm_fm.ipp is #include-only and not globbed by *.cpp).
#
# pmdwin/ and ymfm/ carry very generic header names (table.h, util.h, opna.h,
# ifileio.h, portability_*.h) and include each other across dirs, so both stay
# PRIVATE to this static lib — only src/ (pmdmini.h alone) goes PUBLIC. A
# separate target is what makes that isolation possible: cmake cannot scope an
# include dir per file the way the Podfiles can (PLUGINS.md §6.4).
function(rewamp_add_pmd target)
  set(PMD_ROOT "${REWAMP_THIRD_PARTY_DIR}/pmdmini/src")
  if(NOT EXISTS "${PMD_ROOT}/pmdmini.cpp")
    message(FATAL_ERROR "REWAMP_WITH_PMD=ON but sources are missing at ${PMD_ROOT}")
  endif()
  file(GLOB PMD_SOURCES
    "${PMD_ROOT}/pmdmini.cpp"
    "${PMD_ROOT}/pmdwin/*.cpp"
    "${PMD_ROOT}/ymfm/*.cpp")
  add_library(rewamp_pmd STATIC ${PMD_SOURCES})
  set_target_properties(rewamp_pmd PROPERTIES POSITION_INDEPENDENT_CODE ON)
  # ymfm needs C++17 or later (if constexpr, structured bindings); Modizer's own
  # project builds this tree at gnu++20.
  target_compile_features(rewamp_pmd PRIVATE cxx_std_20)
  # FURNACE VENDORS ITS OWN ymfm (src/engine/platform/sound/ymfm) — two copies
  # of the same upstream library in one binary means 120 duplicate ymfm::*
  # symbols at link. Rename this copy's namespace (every use here is qualified
  # `ymfm::`; the `#include "ymfm.h"` lines are quoted strings, which the
  # preprocessor does not macro-expand). Same precedent as KSS's kmz80 rename.
  # Kept in sync with the app Podfiles' pmd_inc.
  target_compile_definitions(rewamp_pmd PRIVATE ymfm=pmd_ymfm)
  target_include_directories(rewamp_pmd
    PRIVATE "${REWAMP_SRC_DIR}"          # ModizerVoicesData.h (voice patches)
    PRIVATE "${PMD_ROOT}/pmdwin"
    PRIVATE "${PMD_ROOT}/ymfm"
    PUBLIC  "${PMD_ROOT}")               # pmdmini.h only — no generic names here
  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_pmd.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_PMD=1)
  target_link_libraries(${target} PRIVATE rewamp_pmd)
endfunction()

# MDX (Sharp X68000, .mdx + its .pdx sample bank) — mdxplay: YM2151 FM + the
# PCM8 sample driver, plus freeverb (mdx_load turns reverb on by default).
# 7 TUs mirroring what modizer.xcodeproj compiles (mdxopl3/mdxmml_opl3 are NOT
# built — mdx_load forces no_opl3; ioaccess/getopt are CLI-only) + freeverb's 4.
#
# NOTHING here goes on a PUBLIC/target-wide include path: the dir holds
# version.h (one of nine under third_party/), mdx.h and pcm8.h, and freeverb
# adds comb.hpp/tuning.h. The plugin reaches mdx.h by relative path instead.
#
# seek_needed/decode_pos_ms/PLAYBACK_FREQ are app-globals mdxplay expects;
# rewamp_plugin_gsf.cpp already defines seek_needed/decode_pos_ms for VBA, so
# this engine's are renamed rather than silently shared (same reasoning as
# gbsplay's gbs_seek_needed). Kept in sync with the app Podfiles' mdx_inc.
function(rewamp_add_mdx target)
  set(MDX_ROOT "${REWAMP_THIRD_PARTY_DIR}/mdxplay")
  if(NOT EXISTS "${MDX_ROOT}/mdxmain.c")
    message(FATAL_ERROR "REWAMP_WITH_MDX=ON but sources are missing at ${MDX_ROOT}")
  endif()
  add_library(rewamp_mdx STATIC
    "${MDX_ROOT}/mdxmain.c"
    "${MDX_ROOT}/mdxfile.c"
    "${MDX_ROOT}/mdxmml_ym2151.c"
    "${MDX_ROOT}/mdx2151.c"
    "${MDX_ROOT}/mdx_ym2151.c"
    "${MDX_ROOT}/pcm8.c"
    "${MDX_ROOT}/pdxfile.c"
    "${MDX_ROOT}/freeverb/allpass.cpp"
    "${MDX_ROOT}/freeverb/comb.cpp"
    "${MDX_ROOT}/freeverb/freeverb.cpp"
    "${MDX_ROOT}/freeverb/revmodel.cpp")
  set_target_properties(rewamp_mdx PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_include_directories(rewamp_mdx
    PRIVATE "${REWAMP_SRC_DIR}"          # ModizerVoicesData.h / ModizerConstants.h
    PRIVATE "${MDX_ROOT}"
    PRIVATE "${MDX_ROOT}/freeverb")
  target_compile_definitions(rewamp_mdx PRIVATE
    seek_needed=mdx_seek_needed
    decode_pos_ms=mdx_decode_pos_ms
    PLAYBACK_FREQ=mdx_playback_freq)
  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_mdx.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_MDX=1)
  target_link_libraries(${target} PRIVATE rewamp_mdx)
endfunction()

# FMP (PC-98 FM driver, .opi/.ovi/.ozi) — libfmpmini: 98fmplayer's FMP driver +
# its own C libopna (OPNA/SSG/ADPCM/rhythm) + the PPZ8 PCM driver, behind
# fmpmini.c's small C API. A DIFFERENT PC-98 engine from PMD (different driver,
# different OPNA implementation — no shared symbols), but it reads the SAME
# YM2608 rhythm ROM via the shared bundlePath global.
#
# 17 TUs mirroring modizer.xcodeproj. The x86 opnassg-sinc-sse2.c and the NEON
# opnassg-sinc-neon.s are NOT vendored: libopna defaults opna_ssg_sinc_calc_func
# to the portable _c variant and nothing in the headless path swaps it, so the
# SIMD ones are dead — and sse2's <emmintrin.h> breaks the arm64 build outright.
#
# libopna/, fmdriver/, common/ carry generic header names (opna.h, ppz8.h,
# fmdriver.h, s98gen.h, opnatimer.h) and are included both root-relative
# ("libopna/opna.h") and same-dir ("opna.h"), so ALL four dirs stay PRIVATE to
# this static lib — the plugin reaches fmpmini.h by relative path.
function(rewamp_add_fmp target)
  set(FMP_ROOT "${REWAMP_THIRD_PARTY_DIR}/fmpmini")
  if(NOT EXISTS "${FMP_ROOT}/fmpmini.c")
    message(FATAL_ERROR "REWAMP_WITH_FMP=ON but sources are missing at ${FMP_ROOT}")
  endif()
  add_library(rewamp_fmp STATIC
    "${FMP_ROOT}/fmpmini.c"
    "${FMP_ROOT}/libopna/opna.c"
    "${FMP_ROOT}/libopna/opnaadpcm.c"
    "${FMP_ROOT}/libopna/opnadrum.c"
    "${FMP_ROOT}/libopna/opnafm.c"
    "${FMP_ROOT}/libopna/opnassg.c"
    "${FMP_ROOT}/libopna/opnassg-sinc-c.c"
    "${FMP_ROOT}/libopna/opnatimer.c"
    "${FMP_ROOT}/libopna/s98gen.c"
    "${FMP_ROOT}/fmdriver/fmdriver_common.c"
    "${FMP_ROOT}/fmdriver/fmdriver_fmp.c"
    "${FMP_ROOT}/fmdriver/fmdriver_pmd.c"
    "${FMP_ROOT}/fmdriver/ppz8.c"
    "${FMP_ROOT}/common/fmplayer_file.c"
    "${FMP_ROOT}/common/fmplayer_work_opna.c"
    "${FMP_ROOT}/common/fmplayer_drumrom_unix.c"
    "${FMP_ROOT}/common/fmplayer_file_unix.c")
  set_target_properties(rewamp_fmp PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_include_directories(rewamp_fmp
    PRIVATE "${REWAMP_SRC_DIR}"          # ModizerVoicesData.h (voice patches)
    PRIVATE "${FMP_ROOT}"
    PRIVATE "${FMP_ROOT}/libopna"
    PRIVATE "${FMP_ROOT}/fmdriver"
    PRIVATE "${FMP_ROOT}/common")
  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_fmp.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_FMP=1)
  target_link_libraries(${target} PRIVATE rewamp_fmp)
endfunction()

# EUP (FM Towns EUPHONY, .eup + .fmb/.pmb banks) — eupmini: the EUPHONY
# sequencer + Nuked-OPN2 (YM2612) FM (mame/fmopn.c + Nuked-OPN2/ym3438.c wrapped
# by eupmini/opn2.c) + the FM Towns PCM emulator. 8 TUs mirroring
# libeupmini.xcodeproj.
#
# The Nuked-OPN2 + mame YM2612 symbols (OPN2_*, ym2612_*, device_*_ym2612)
# COLLIDE with libvgm's own Nuked-OPN2 — Modizer's project renames all 56 with
# a `-D SYM=eup_SYM` set; replicated here (target-wide on this static lib) and
# kept in sync with the app Podfiles' eup_defs. mame/, Nuked-OPN2/ and eupmini/
# also carry generic header names (stdtype.h, snddef.h, common_def.h,
# EmuHelper.h, mamedef.h, opn2.h) → all three dirs stay PRIVATE; the plugin
# reaches eupplayer.hpp by relative path.
function(rewamp_add_eup target)
  set(EUP_ROOT "${REWAMP_THIRD_PARTY_DIR}/eupmini")
  if(NOT EXISTS "${EUP_ROOT}/eupmini/eupplayer.cpp")
    message(FATAL_ERROR "REWAMP_WITH_EUP=ON but sources are missing at ${EUP_ROOT}")
  endif()
  add_library(rewamp_eup STATIC
    "${EUP_ROOT}/eupmini/eupplayer.cpp"
    "${EUP_ROOT}/eupmini/eupplayer_townsEmulator.cpp"
    "${EUP_ROOT}/eupmini/sintbl.cpp"
    "${EUP_ROOT}/eupmini/TownsFmEmulator.cpp"
    "${EUP_ROOT}/eupmini/TownsFmEmulator2.cpp"
    "${EUP_ROOT}/eupmini/opn2.c"
    "${EUP_ROOT}/Nuked-OPN2/ym3438.c"
    "${EUP_ROOT}/mame/fmopn.c")
  set_target_properties(rewamp_eup PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_include_directories(rewamp_eup
    PRIVATE "${REWAMP_SRC_DIR}"          # ModizerVoicesData.h (voice patches)
    PRIVATE "${EUP_ROOT}/eupmini"
    PRIVATE "${EUP_ROOT}/mame"
    PRIVATE "${EUP_ROOT}/Nuked-OPN2")
  target_compile_definitions(rewamp_eup PRIVATE
    SNDDEV_SELECT SNDDEV_YM2612 NO_DEBUG_LOGS HAVE_LIMITS_H HAVE_STDINT_H
    device_reset_ym2612=eup_device_reset_ym2612
    device_start_ym2612=eup_device_start_ym2612
    device_stop_ym2612=eup_device_stop_ym2612
    OPN2_ChGenerate=eup_OPN2_ChGenerate
    OPN2_ChOutput=eup_OPN2_ChOutput
    OPN2_Clock=eup_OPN2_Clock
    OPN2_DoIO=eup_OPN2_DoIO
    OPN2_DoRegWrite=eup_OPN2_DoRegWrite
    OPN2_DoTimerA=eup_OPN2_DoTimerA
    OPN2_DoTimerB=eup_OPN2_DoTimerB
    OPN2_EnvelopeADSR=eup_OPN2_EnvelopeADSR
    OPN2_EnvelopeGenerate=eup_OPN2_EnvelopeGenerate
    OPN2_EnvelopePrepare=eup_OPN2_EnvelopePrepare
    OPN2_EnvelopeSSGEG=eup_OPN2_EnvelopeSSGEG
    OPN2_FMGenerate=eup_OPN2_FMGenerate
    OPN2_FMPrepare=eup_OPN2_FMPrepare
    OPN2_GenerateResampled=eup_OPN2_GenerateResampled
    OPN2_GenerateStream=eup_OPN2_GenerateStream
    OPN2_KeyOn=eup_OPN2_KeyOn
    OPN2_PhaseCalcIncrement=eup_OPN2_PhaseCalcIncrement
    OPN2_PhaseGenerate=eup_OPN2_PhaseGenerate
    OPN2_Read=eup_OPN2_Read
    OPN2_ReadIRQPin=eup_OPN2_ReadIRQPin
    OPN2_ReadTestPin=eup_OPN2_ReadTestPin
    OPN2_Reset=eup_OPN2_Reset
    OPN2_SetChipType=eup_OPN2_SetChipType
    OPN2_SetMute=eup_OPN2_SetMute
    OPN2_SetOptions=eup_OPN2_SetOptions
    OPN2_SetTestPin=eup_OPN2_SetTestPin
    OPN2_UpdateLFO=eup_OPN2_UpdateLFO
    OPN2_Write=eup_OPN2_Write
    OPN2_WriteBuffered=eup_OPN2_WriteBuffered
    ym2612_control_port_a_w=eup_ym2612_control_port_a_w
    ym2612_control_port_b_w=eup_ym2612_control_port_b_w
    ym2612_data_port_a_r=eup_ym2612_data_port_a_r
    ym2612_data_port_a_w=eup_ym2612_data_port_a_w
    ym2612_data_port_b_r=eup_ym2612_data_port_b_r
    ym2612_data_port_b_w=eup_ym2612_data_port_b_w
    ym2612_init=eup_ym2612_init
    ym2612_r=eup_ym2612_r
    ym2612_read=eup_ym2612_read
    ym2612_reset_chip=eup_ym2612_reset_chip
    ym2612_set_log_cb=eup_ym2612_set_log_cb
    ym2612_set_mute_mask=eup_ym2612_set_mute_mask
    ym2612_set_mutemask=eup_ym2612_set_mutemask
    ym2612_set_options=eup_ym2612_set_options
    ym2612_setoptions=eup_ym2612_setoptions
    ym2612_shutdown=eup_ym2612_shutdown
    ym2612_status_port_a_r=eup_ym2612_status_port_a_r
    ym2612_status_port_b_r=eup_ym2612_status_port_b_r
    ym2612_stream_update=eup_ym2612_stream_update
    ym2612_timer_over=eup_ym2612_timer_over
    ym2612_update_one=eup_ym2612_update_one
    ym2612_update_request=eup_ym2612_update_request
    ym2612_w=eup_ym2612_w
    ym2612_write=eup_ym2612_write)
  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_eup.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_EUP=1)
  target_link_libraries(${target} PRIVATE rewamp_eup)
endfunction()

# FluidLite (FluidSynth fork, no glib) + tml.h sequencer → .mid via SF2.
# 17-file source list mirrors upstream CMakeLists (SF3 disabled, WITH_FLOAT
# pre-baked in src/fluid_config.h; version.h pre-generated).
function(rewamp_add_midi target)
  set(FL_ROOT "${REWAMP_THIRD_PARTY_DIR}/fluidlite")
  if(NOT EXISTS "${FL_ROOT}/include/fluidlite.h")
    message(FATAL_ERROR "REWAMP_WITH_MIDI=ON but FluidLite sources are missing at ${FL_ROOT}")
  endif()
  set(_fl_names
    fluid_init fluid_chan fluid_chorus fluid_conv fluid_defsfont
    fluid_dsp_float fluid_gen fluid_hash fluid_list fluid_mod
    fluid_ramsfont fluid_rev fluid_settings fluid_synth fluid_sys
    fluid_tuning fluid_voice)
  set(_fl_srcs "")
  foreach(_n IN LISTS _fl_names)
    list(APPEND _fl_srcs "${FL_ROOT}/src/${_n}.c")
  endforeach()
  add_library(rewamp_fluidlite STATIC ${_fl_srcs})
  set_target_properties(rewamp_fluidlite PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_compile_definitions(rewamp_fluidlite PUBLIC FLUIDLITE_STATIC)
  # Per-MIDI-channel voice capture hooks (rewamp_plugin_midi.c) patched into
  # fluid_synth.c's voice loop.
  target_compile_definitions(rewamp_fluidlite PRIVATE REWAMP_VOICE_CAPTURE=1)
  target_include_directories(rewamp_fluidlite PRIVATE "${REWAMP_SRC_DIR}")
  target_include_directories(rewamp_fluidlite
    PRIVATE "${FL_ROOT}/src"
    PUBLIC  "${FL_ROOT}/include")

  # tml.h implementation, shared with the MT-32 plugin (one per binary).
  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_midi.c" "${REWAMP_SRC_DIR}/rewamp_tml.c")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_MIDI=1)
  target_include_directories(${target} PRIVATE "${REWAMP_THIRD_PARTY_DIR}/tml")
  target_link_libraries(${target} PRIVATE rewamp_fluidlite)
endfunction()

# ── MT-32: Roland MT-32 / CM-32L emulation for .mid (munt mt32emu, LGPL-2.1) ──
# Second MIDI engine next to FluidLite; shares tml.h (implementation TU
# rewamp_tml.c is added by whichever of the two is on first). ROMs are NOT
# bundled (Roland copyright): imported by the user into <datadir>/mt32.
# Static C++ API build, internal resampler, no c_interface / VersionTagging.
# Baked third_party/mt32emu/mt32emu/config.h (the upstream cmake generates it).
function(rewamp_add_mt32 target)
  set(MT_ROOT "${REWAMP_THIRD_PARTY_DIR}/mt32emu")
  if(NOT EXISTS "${MT_ROOT}/mt32emu/Synth.cpp")
    message(FATAL_ERROR "REWAMP_WITH_MT32=ON but mt32emu sources are missing at ${MT_ROOT}")
  endif()
  set(_mt_names Analog BReverbModel Display File FileStream LA32FloatWaveGenerator
      LA32Ramp LA32WaveGenerator MidiStreamParser Part Partial PartialManager Poly
      ROMInfo Synth Tables TVA TVF TVP SampleRateConverter)
  set(_mt_srcs "")
  foreach(_n IN LISTS _mt_names)
    list(APPEND _mt_srcs "${MT_ROOT}/mt32emu/${_n}.cpp")
  endforeach()
  list(APPEND _mt_srcs
    "${MT_ROOT}/mt32emu/sha1/sha1.cpp"
    "${MT_ROOT}/mt32emu/srchelper/InternalResampler.cpp"
    "${MT_ROOT}/mt32emu/srchelper/srctools/src/FIRResampler.cpp"
    "${MT_ROOT}/mt32emu/srchelper/srctools/src/IIR2xResampler.cpp"
    "${MT_ROOT}/mt32emu/srchelper/srctools/src/LinearResampler.cpp"
    "${MT_ROOT}/mt32emu/srchelper/srctools/src/ResamplerModel.cpp"
    "${MT_ROOT}/mt32emu/srchelper/srctools/src/SincResampler.cpp")
  add_library(rewamp_mt32emu STATIC ${_mt_srcs})
  set_target_properties(rewamp_mt32emu PROPERTIES POSITION_INDEPENDENT_CODE ON CXX_STANDARD 11)
  target_compile_definitions(rewamp_mt32emu PRIVATE MT32EMU_WITH_INTERNAL_RESAMPLER MT32EMU_WITH_STD_SNPRINTF)
  # Per-part scope hooks (rewamp_mt32_capture.h) are included by relative path
  # from the vendored Partial.cpp / Synth.cpp; only the top dir goes on the
  # plugin's path (<mt32emu/mt32emu.h>): its generic header names (File.h,
  # Types.h, Tables.h) stay off the target-wide include path.
  target_include_directories(rewamp_mt32emu PRIVATE "${MT_ROOT}" "${REWAMP_SRC_DIR}")

  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_mt32.cpp")
  if(NOT REWAMP_WITH_MIDI)
    target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_tml.c")
  endif()
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_MT32=1)
  target_include_directories(${target} PRIVATE "${MT_ROOT}" "${REWAMP_THIRD_PARTY_DIR}/tml")
  target_link_libraries(${target} PRIVATE rewamp_mt32emu)
endfunction()

# Official UnRAR as a static lib — only the .cpp files its makefile compiles
# (OBJECTS + LIB_OBJ); the rest (crypt1-5, unpack15/20/30/50, blake2s_sse, …)
# are #included by those. RAR_SMP deliberately NOT set (single-threaded, no
# pthread). Mirrors the Apple podspec's unrar_cores wiring.
# libogg + libvorbis, à partir de l'arbre vendoré par le SUBMODULE libopenmpt
# (qui les porte déjà et n'en compile aucune: son .a n'a zéro symbole vorbis,
# donc pas de doublon possible). Sert au décodeur Vorbis « custom » de vgmstream
# — Wwise, FSB, OGL… — qui est entièrement derrière #ifdef VGM_USE_VORBIS.
#
# `ogg/config_types.h` est GÉNÉRÉ par le build amont de libogg et absent de cet
# arbre: il vient de src/vorbis_compat/, puisqu'on ne modifie jamais un
# submodule.
function(rewamp_add_vorbis)
  if(TARGET rewamp_vorbis)
    return()
  endif()
  set(_lom "${REWAMP_THIRD_PARTY_DIR}/libopenmpt/include")
  if(NOT EXISTS "${_lom}/vorbis/lib/vorbisfile.c")
    message(WARNING
      "libvorbis introuvable sous ${_lom} — Wwise Vorbis ne jouera pas.\n"
      "  git submodule update --init packages/rewamp_audio/third_party/libopenmpt")
    return()
  endif()
  file(GLOB _ogg_src  "${_lom}/ogg/src/*.c")
  file(GLOB _vorb_src "${_lom}/vorbis/lib/*.c")
  # ⚠️ barkmel/psytune/tone sont des OUTILS autonomes avec un main(): les
  # compiler ferait plusieurs points d'entrée. sharedbook.c en a un aussi mais
  # sous #ifdef _V_SELFTEST, donc sans risque.
  list(FILTER _vorb_src EXCLUDE REGEX "/(barkmel|psytune|tone)\\.c$")
  add_library(rewamp_vorbis STATIC ${_ogg_src} ${_vorb_src})
  target_include_directories(rewamp_vorbis PUBLIC
    "${REWAMP_SRC_DIR}/vorbis_compat"
    "${_lom}/ogg/include"
    "${_lom}/vorbis/include")
  target_include_directories(rewamp_vorbis PRIVATE "${_lom}/vorbis/lib")
endfunction()

function(rewamp_add_unrar)
  set(UNRAR_ROOT "${REWAMP_THIRD_PARTY_DIR}/unrar")
  if(NOT EXISTS "${UNRAR_ROOT}/dll.hpp")
    message(FATAL_ERROR "REWAMP_WITH_UNRAR=ON but sources are missing at ${UNRAR_ROOT}")
  endif()
  set(_unrar_names
    rar strlist strfn pathfn smallfn global file filefn filcreat
    archive arcread unicode system crypt crc rawread encname
    resource match timefn rdwrfn consio options errhnd rarvm secpassword
    rijndael getbits sha1 sha256 blake2s hash extinfo extract volume
    list find unpack headers threadpool rs16 cmddata ui
    filestr scantree dll qopen)
  set(_unrar_srcs "")
  foreach(_n IN LISTS _unrar_names)
    list(APPEND _unrar_srcs "${UNRAR_ROOT}/${_n}.cpp")
  endforeach()
  add_library(rewamp_unrar STATIC ${_unrar_srcs})
  set_target_properties(rewamp_unrar PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_compile_features(rewamp_unrar PRIVATE cxx_std_11)
  target_compile_definitions(rewamp_unrar PRIVATE
    RARDLL=1 SILENT=1 _FILE_OFFSET_BITS=64 _LARGEFILE_SOURCE)
  target_include_directories(rewamp_unrar PUBLIC "${UNRAR_ROOT}")
endfunction()

# libgsf: GBA .gsf/.minigsf via the VBA emulator (Modizer's vendored tree, with
# the per-voice oscilloscope patch in VBA/Sound.cpp). psftag.c is C; memgzio is
# stubbed (GSF uses zlib uncompress(), not the gz path). System zlib for decomp.
function(rewamp_add_gsf target)
  set(GSF_ROOT "${REWAMP_THIRD_PARTY_DIR}/gsf")
  if(NOT EXISTS "${GSF_ROOT}/gsf.cpp")
    message(FATAL_ERROR "REWAMP_WITH_GSF=ON but libgsf sources are missing at ${GSF_ROOT}")
  endif()
  set(_gsf_srcs
    "${GSF_ROOT}/gsf.cpp"
    "${GSF_ROOT}/VBA/GBA.cpp" "${GSF_ROOT}/VBA/Globals.cpp"
    "${GSF_ROOT}/VBA/Sound.cpp" "${GSF_ROOT}/VBA/Util.cpp"
    "${GSF_ROOT}/VBA/bios.cpp" "${GSF_ROOT}/VBA/snd_interp.cpp"
    "${GSF_ROOT}/VBA/unzip.cpp" "${GSF_ROOT}/VBA/memgzio.c"
    "${GSF_ROOT}/VBA/psftag.c"
    "${GSF_ROOT}/libresample/src/filterkit.c"
    "${GSF_ROOT}/libresample/src/resample.c"
    "${GSF_ROOT}/libresample/src/resamplesubs.c")
  add_library(rewamp_gsf STATIC ${_gsf_srcs})
  set_target_properties(rewamp_gsf PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_compile_definitions(rewamp_gsf PRIVATE REWAMP_WITH_GSF=1 LINUX=1)
  target_include_directories(rewamp_gsf PRIVATE
    "${GSF_ROOT}" "${GSF_ROOT}/VBA"
    "${GSF_ROOT}/libresample/include" "${GSF_ROOT}/libresample/src"
    "${REWAMP_SRC_DIR}")
  # psftag.c defines a static truncate(); build it as C so it isn't C++-mangled.
  set_source_files_properties("${GSF_ROOT}/VBA/psftag.c"
    "${GSF_ROOT}/VBA/memgzio.c" PROPERTIES LANGUAGE C)
  if(CMAKE_SYSTEM_NAME STREQUAL "Android")
    target_link_libraries(rewamp_gsf PRIVATE z)
  else()
    find_package(ZLIB QUIET)
    if(ZLIB_FOUND)
      target_link_libraries(rewamp_gsf PRIVATE ZLIB::ZLIB)
    else()
      find_library(_gsf_z z)
      if(_gsf_z)
        target_link_libraries(rewamp_gsf PRIVATE ${_gsf_z})
      endif()
    endif()
  endif()

  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_gsf.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_GSF=1)
  # gsf reads its length/fade + metadata tags via libpsflib (GSF is a PSF 0x22),
  # so the plugin TU needs the third_party include. psflib.c itself is compiled
  # by highlyexp/vio2sf (both default ON, like gsf); only add it here if none of
  # them did, to avoid duplicate symbols.
  target_include_directories(${target} PRIVATE "${REWAMP_THIRD_PARTY_DIR}")
  if(NOT REWAMP_WITH_HIGHLYEXP AND NOT REWAMP_WITH_VIO2SF)
    target_sources(${target} PRIVATE
      "${REWAMP_THIRD_PARTY_DIR}/libpsflib/psflib.c"
      "${REWAMP_THIRD_PARTY_DIR}/libpsflib/psf2fs.c")
  endif()
  target_link_libraries(${target} PRIVATE rewamp_gsf)
endfunction()

# vio2sf: Nintendo DS .2sf/.mini2sf via Cog's melonDS core (interpreter only —
# JIT_ENABLED is left OFF so no RWX pages are needed → iOS-safe; the JIT/emitter
# TUs are excluded from vio2sf_sources.cmake). Headers are flattened under
# include/vio2sf/ (framework-style) so <vio2sf/X> resolves for every subdir
# header. SPU.cpp carries the per-voice scope + mute capture (REWAMP_WITH_VIO2SF).
function(rewamp_add_vio2sf target)
  set(VIO2SF_ROOT "${REWAMP_THIRD_PARTY_DIR}/vio2sf")
  if(NOT EXISTS "${VIO2SF_ROOT}/src/vio2sf/melonDS/NDS.cpp")
    message(FATAL_ERROR "REWAMP_WITH_VIO2SF=ON but melonDS sources are missing at ${VIO2SF_ROOT}")
  endif()
  include("${VIO2SF_ROOT}/vio2sf_sources.cmake")   # → VIO2SF_SOURCES

  add_library(rewamp_vio2sf STATIC ${VIO2SF_SOURCES})
  set_target_properties(rewamp_vio2sf PROPERTIES POSITION_INDEPENDENT_CODE ON CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON)
  # REWAMP_WITH_VIO2SF enables the scope/mute capture patch in SPU.cpp.
  target_compile_definitions(rewamp_vio2sf PRIVATE REWAMP_WITH_VIO2SF=1)
  # melonDS bundles Shay Green's blip_buf; its symbols collide with furnace's copy
  # when both static libs link into one target. Namespace melonDS's blip API so
  # furnace keeps the originals (decl+def+call rename together).
  foreach(_bf new delete set_rates clear clocks_needed end_frame
              samples_avail read_samples add_delta add_delta_fast)
    target_compile_definitions(rewamp_vio2sf PRIVATE "blip_${_bf}=vio2sf_blip_${_bf}")
  endforeach()
  target_include_directories(rewamp_vio2sf PRIVATE
    "${VIO2SF_ROOT}/include"                 # <vio2sf/...>
    "${VIO2SF_ROOT}/include/vio2sf"          # bare "GPU3D_Soft.h" etc.
    "${VIO2SF_ROOT}/src/vio2sf/melonDS"      # "blip-buf/...", "version.h"
    "${VIO2SF_ROOT}/src/vio2sf"
    "${REWAMP_SRC_DIR}")                      # ModizerVoicesData.h for capture
  target_include_directories(rewamp_vio2sf PUBLIC "${VIO2SF_ROOT}/include")

  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_vio2sf.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_VIO2SF=1)
  target_include_directories(${target} PRIVATE "${VIO2SF_ROOT}/include" "${REWAMP_THIRD_PARTY_DIR}")
  target_link_libraries(${target} PRIVATE rewamp_vio2sf)
  # libpsflib parses the 2sf container. highlyexp also compiles it into ${target};
  # only add it here when highlyexp is disabled, to avoid duplicate symbols.
  if(NOT REWAMP_WITH_HIGHLYEXP)
    target_sources(${target} PRIVATE
      "${REWAMP_THIRD_PARTY_DIR}/libpsflib/psflib.c"
      "${REWAMP_THIRD_PARTY_DIR}/libpsflib/psf2fs.c")
  endif()
  # zlib for the compressed 2sf save-map path (uncompress/crc32).
  if(CMAKE_SYSTEM_NAME STREQUAL "Android")
    target_link_libraries(rewamp_vio2sf PRIVATE z)
  else()
    find_package(ZLIB QUIET)
    if(ZLIB_FOUND)
      target_link_libraries(rewamp_vio2sf PRIVATE ZLIB::ZLIB)
    else()
      find_library(_vio_z z)
      if(_vio_z)
        target_link_libraries(rewamp_vio2sf PRIVATE ${_vio_z})
      endif()
    endif()
  endif()
endfunction()

# NCSF: Nintendo DS .ncsf/.minincsf via SSEQPlayer (Naram Qashat's SDAT/SSEQ
# software synth, from Cog's SSEQPlayer framework). NOT an emulator — the file
# embeds an SDAT sound archive, so this is a separate engine from vio2sf's
# melonDS, sharing only libpsflib. Player.cpp carries the per-voice scope +
# notes + mute capture. Headers live under include/SSEQPlayer/ (framework-style,
# <SSEQPlayer/X> resolves) — their bare names (common.h, consts.h, Player.h,
# Track.h…) are far too generic to expose directly.
function(rewamp_add_ncsf target)
  set(NCSF_ROOT "${REWAMP_THIRD_PARTY_DIR}/sseqplayer")
  if(NOT EXISTS "${NCSF_ROOT}/src/Player.cpp")
    message(FATAL_ERROR "REWAMP_WITH_NCSF=ON but SSEQPlayer sources are missing at ${NCSF_ROOT}")
  endif()
  file(GLOB NCSF_SRC "${NCSF_ROOT}/src/*.cpp")

  add_library(rewamp_ncsf STATIC ${NCSF_SRC})
  set_target_properties(rewamp_ncsf PROPERTIES POSITION_INDEPENDENT_CODE ON CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON)
  target_include_directories(rewamp_ncsf PRIVATE
    "${NCSF_ROOT}/include"          # <SSEQPlayer/...>
    "${REWAMP_SRC_DIR}")            # ModizerVoicesData.h for the capture patch
  target_include_directories(rewamp_ncsf PUBLIC "${NCSF_ROOT}/include")

  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_ncsf.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_NCSF=1)
  target_include_directories(${target} PRIVATE "${NCSF_ROOT}/include" "${REWAMP_THIRD_PARTY_DIR}")
  target_link_libraries(${target} PRIVATE rewamp_ncsf)
  # libpsflib parses the NCSF container (PSF 0x25). It is already compiled by
  # highlyexp/vio2sf/gsf/lazyusf (all default ON); only add it here when none of
  # them did — same fallback-owner chain, to avoid duplicate symbols.
  if(NOT REWAMP_WITH_HIGHLYEXP AND NOT REWAMP_WITH_VIO2SF AND NOT REWAMP_WITH_GSF
     AND NOT REWAMP_WITH_LAZYUSF)
    target_sources(${target} PRIVATE
      "${REWAMP_THIRD_PARTY_DIR}/libpsflib/psflib.c"
      "${REWAMP_THIRD_PARTY_DIR}/libpsflib/psf2fs.c")
  endif()
endfunction()

# SNSF: Super Nintendo .snsf/.minisnsf via snsf9x — a stripped snes9x (65c816 +
# PPU + DMA + SA-1 + S-DD1) driving blargg's SPC700/S-DSP APU. Unlike NCSF this
# IS full hardware emulation; the 8 scope voices are the S-DSP's real channels
# (capture lives in snes9x/apu/SPC_DSP.cpp, grep YOYOFR). 16 TUs, exactly the set
# snsf.xcodeproj compiles — the rest of the tree is header-only or behind
# SNSF9X_REMOVED (snsf9x's own "this is a music player, not an emulator" gate).
#
# ⚠ The three -D renames come straight from Modizer's snsf.xcodeproj: snsf9x and
# libgme are BOTH blargg codebases and collide on `resampler`/`Resampler`/
# `blargg_vector`. Applied to this target only (Modizer sets them in its Debug
# config alone, which looks like an oversight — they are needed in every config).
function(rewamp_add_snsf target)
  set(SNSF_ROOT "${REWAMP_THIRD_PARTY_DIR}/snsf")
  if(NOT EXISTS "${SNSF_ROOT}/snsf_drvimpl.cpp")
    message(FATAL_ERROR "REWAMP_WITH_SNSF=ON but snsf9x sources are missing at ${SNSF_ROOT}")
  endif()
  set(SNSF_SRC
    "${SNSF_ROOT}/snsf_drvimpl.cpp"
    "${SNSF_ROOT}/snes9x/cpu.cpp"
    "${SNSF_ROOT}/snes9x/cpuexec.cpp"
    "${SNSF_ROOT}/snes9x/cpuops.cpp"
    "${SNSF_ROOT}/snes9x/dma.cpp"
    "${SNSF_ROOT}/snes9x/globals.cpp"
    "${SNSF_ROOT}/snes9x/memmap.cpp"
    "${SNSF_ROOT}/snes9x/ppu.cpp"
    "${SNSF_ROOT}/snes9x/sa1.cpp"
    "${SNSF_ROOT}/snes9x/sdd1.cpp"
    "${SNSF_ROOT}/snes9x/apu/apu.cpp"
    "${SNSF_ROOT}/snes9x/apu/SNES_SPC.cpp"
    "${SNSF_ROOT}/snes9x/apu/SNES_SPC_misc.cpp"
    "${SNSF_ROOT}/snes9x/apu/SNES_SPC_state.cpp"
    "${SNSF_ROOT}/snes9x/apu/SPC_DSP.cpp"
    "${SNSF_ROOT}/snes9x/apu/SPC_Filter.cpp")

  add_library(rewamp_snsf STATIC ${SNSF_SRC})
  set_target_properties(rewamp_snsf PROPERTIES POSITION_INDEPENDENT_CODE ON
    CXX_STANDARD 14 CXX_STANDARD_REQUIRED ON)   # gnu++14, as snsf.xcodeproj uses
  target_compile_definitions(rewamp_snsf PRIVATE
    HAVE_STDINT_H
    resampler=SNSF_resampler
    Resampler=SNSF_Resampler
    blargg_vector=SNSF_blargg_vector
    # A FOURTH rename Modizer's project does NOT have (it never linked snsf9x and
    # libgme into one binary): libgme's Spc_Filter.h declares `SPC_Filter` with
    # the exact same capitalization, so all four of its methods collide at link.
    # Renaming the identifier is safe — `#include "SPC_Filter.h"` is a string
    # literal the preprocessor never macro-expands (the ymfm/pmd precedent).
    SPC_Filter=SNSF_SPC_Filter)
  # PRIVATE only: the tree's own header names (XSFCommon.h and, worse, convert.h,
  # port.h, memmap.h, apu.h, messages.h) must never reach the shared target-wide
  # include path — cmake cannot per-file-scope a collision away (§6.4).
  target_include_directories(rewamp_snsf PRIVATE
    "${SNSF_ROOT}"                  # XSFCommon.h, pulled by the resampler headers
    "${REWAMP_SRC_DIR}")            # ModizerVoicesData.h for the capture patch
  target_compile_options(rewamp_snsf PRIVATE -w)   # vendored snes9x, not our warnings

  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_snsf.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_SNSF=1)
  # The plugin TU reaches snsf_drvimpl.h by RELATIVE path, so nothing from the
  # engine goes on ${target}'s include path; it only needs third_party/ for
  # <libpsflib/psflib.h>.
  target_include_directories(${target} PRIVATE "${REWAMP_THIRD_PARTY_DIR}")
  target_link_libraries(${target} PRIVATE rewamp_snsf)
  # SNSF is PSF-family (magic 0x23), read via libpsflib — same fallback-owner
  # chain as ncsf/gsf/vio2sf/lazyusf: only compile it here if nobody else did.
  if(NOT REWAMP_WITH_HIGHLYEXP AND NOT REWAMP_WITH_VIO2SF AND NOT REWAMP_WITH_GSF
     AND NOT REWAMP_WITH_LAZYUSF AND NOT REWAMP_WITH_NCSF)
    target_sources(${target} PRIVATE
      "${REWAMP_THIRD_PARTY_DIR}/libpsflib/psflib.c"
      "${REWAMP_THIRD_PARTY_DIR}/libpsflib/psf2fs.c")
  endif()
endfunction()

# projectM (Milkdrop) visualizer — the 4th viz mode. Apple builds it through the
# podspecs; this is the Android/desktop path. projectM lives in its OWN static
# library on purpose: its src/ and vendor/ carry very generic header names
# (Shader.hpp, Factory.cpp, a "compiler"/filesystem layer) which, on a shared
# include path, shadow other plugins' headers — that is exactly what the Apple
# build works around with per-file include scoping, and a separate target gives
# it to us for free here (PRIVATE include dirs never leak to ${target}).
#
# The curated file list is third_party/projectm/projectm_sources.txt (shared with
# the podspecs — ONE list, no drift). The fast shape-render path is chosen at
# RUNTIME from the GL extensions actually present (FramebufferFetch.cpp), so
# nothing here has to guess what the GPU supports.
function(rewamp_add_projectm target)
  set(PM_ROOT "${REWAMP_THIRD_PARTY_DIR}/projectm")
  if(NOT EXISTS "${PM_ROOT}/projectm_sources.txt")
    message(FATAL_ERROR "REWAMP_WITH_PROJECTM=ON but projectM sources are missing at ${PM_ROOT}")
  endif()
  # ⚠️ `file(STRINGS ...)` LIT le fichier, il ne s'y ABONNE pas: modifier la
  # liste ne fait donc pas reconfigurer CMake, et un dossier `.cxx` déjà
  # configuré continue de bâtir l'ANCIEN jeu de sources. Un fichier ajouté à la
  # liste n'est alors jamais compilé, et ça ne se voit qu'à l'ÉDITION DE LIENS,
  # sous la forme d'un symbole non défini dont rien ne dit qu'il s'agit d'un
  # fichier manquant — payé sur `AudioTexture.cpp` (les fonctions `get_fft` /
  # `get_wave` des shaders), ajouté à la liste et compilé côté Apple pendant
  # que l'APK échouait sur « undefined symbol: AudioTexture::Update ».
  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
      "${PM_ROOT}/projectm_sources.txt")
  file(STRINGS "${PM_ROOT}/projectm_sources.txt" PM_REL_SOURCES)
  set(PM_SOURCES "")
  foreach(_rel ${PM_REL_SOURCES})
    string(STRIP "${_rel}" _rel)
    if(_rel)
      list(APPEND PM_SOURCES "${PM_ROOT}/${_rel}")
    endif()
  endforeach()

  add_library(rewamp_projectm STATIC ${PM_SOURCES})
  set_target_properties(rewamp_projectm PROPERTIES
    POSITION_INDEPENDENT_CODE ON CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON)
  # Same define set the podspecs bake into each generated wrapper — minus
  # PROJECTM_USE_THREADS, which libprojectM's own config.h owns (and sets to 0).
  #
  # SINGLE-THREADED GL, ON PURPOSE: preset loading — and therefore shader
  # compilation — happens on the render thread. An EGLContext can be current to
  # exactly ONE thread at a time (eglMakeCurrent from a second thread while it is
  # current elsewhere fails with EGL_BAD_ACCESS, and GL calls from a thread with
  # no current context are a no-op: glCreateProgram returns 0). So a background
  # thread must NEVER touch this context. If async preset precompilation is ever
  # wanted, the only legal way is a SECOND EGLContext in the same share group
  # (eglCreateContext with share_context, made current on the loader thread with
  # a pbuffer/EGL_NO_SURFACE): shaders and programs are shareable objects in
  # GLES3 — FBOs and VAOs are not. The vendored Shader.cpp still carries
  # Modizer's mdzMainThreadId/mdzRenderInProgress guard from such a design; it is
  # inert here (no such thread exists) and must stay that way.
  target_compile_definitions(rewamp_projectm PRIVATE
    USE_GLES=1
    SOIL_GLES2=1
    PRJM_F_SIZE=8
    PROJECTM_FILESYSTEM_NAMESPACE=std
    "PROJECTM_FILESYSTEM_INCLUDE=<filesystem>")
  target_compile_options(rewamp_projectm PRIVATE -w)   # vendored tree is noisy
  target_include_directories(rewamp_projectm PRIVATE
    "${PM_ROOT}/src/api/include"
    "${PM_ROOT}/src/playlist/api"
    "${PM_ROOT}/src/libprojectM"
    "${PM_ROOT}/src/libprojectM/MilkdropPreset"
    "${PM_ROOT}/vendor"
    "${PM_ROOT}/vendor/projectm-eval"
    "${PM_ROOT}/vendor/projectm-eval/projectm-eval"
    "${PM_ROOT}/vendor/projectm-eval/projectm-eval/api"
    "${PM_ROOT}/vendor/hlslparser/src"
    "${PM_ROOT}/vendor/SOIL2/src"
    "${PM_ROOT}/vendor/glm")
  # Only the public C API header dir is PUBLIC — the generic-named internals stay
  # private, so ${target} never sees them.
  target_include_directories(rewamp_projectm PUBLIC "${PM_ROOT}/src/api/include")

  # The renderer TU (ours) needs the projectM-4 public header + the GLES headers.
  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_projectm_render.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_PROJECTM=1 REWAMP_GL_GLES=1)
  if(REWAMP_PM_PROFILE)
    target_compile_definitions(${target} PRIVATE REWAMP_PM_PROFILE=1)
    target_compile_definitions(rewamp_projectm PRIVATE REWAMP_PM_PROFILE=1)
  endif()
  target_link_libraries(${target} PRIVATE rewamp_projectm)
endfunction()

# AdPlug: AdLib OPL2/OPL3 formats (.d00/.hsc/.cmf/.imf/.rol/.a2m/.dro/…) via the
# latest upstream AdPlug + vendored libbinio, driven by the DOSBox "woody" OPL3
# emulator in CSurroundopl. Per-voice scope + notes + mute live in the vendored
# woodyopl.cpp/surroundopl.cpp (write m_voice_buff[], honor generic_mute_mask).
# Each player is its own TU (globbed, not unity — some share static fn names).
# stricmp→strcasecmp on non-Windows (AdPlug's own CMake does the same). The x86
# hardware backends (realopl/analopl) are not vendored.
function(rewamp_add_adplug target)
  set(ADPLUG_ROOT "${REWAMP_THIRD_PARTY_DIR}/adplug")
  if(NOT EXISTS "${ADPLUG_ROOT}/src/adplug.cpp")
    message(FATAL_ERROR "REWAMP_WITH_ADPLUG=ON but AdPlug sources are missing at ${ADPLUG_ROOT}")
  endif()
  file(GLOB ADPLUG_SRC "${ADPLUG_ROOT}/src/*.cpp" "${ADPLUG_ROOT}/src/*.c"
                       "${ADPLUG_ROOT}/libbinio/*.cpp")

  add_library(rewamp_adplug STATIC ${ADPLUG_SRC})
  set_target_properties(rewamp_adplug PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_compile_definitions(rewamp_adplug PRIVATE stricmp=strcasecmp)
  target_include_directories(rewamp_adplug PRIVATE
    "${ADPLUG_ROOT}/src"
    "${ADPLUG_ROOT}/libbinio"
    "${REWAMP_SRC_DIR}")             # ModizerVoicesData.h for the patched OPL cores
  target_include_directories(rewamp_adplug PUBLIC "${ADPLUG_ROOT}/src" "${ADPLUG_ROOT}/libbinio")

  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_adplug.cpp")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_ADPLUG=1)
  target_link_libraries(${target} PRIVATE rewamp_adplug)
endfunction()

# libxmp (.musx Archimedes Tracker, .liq, .fnk, .mgt, .stim, .emod, .mfp,
# .coco, .muse) — the module formats libopenmpt cannot load. Three things this
# target must keep doing:
#   - LIBXMP_NO_PROWIZARD: third_party/prowizard IS libxmp's ProWizard set,
#     vendored separately as a last-resort converter; building it twice would
#     define pw_* / ptk_table / tun_table twice,
#   - LIBXMP_NO_DEPACKERS: rewamp unpacks archives itself, and libxmp's
#     depackers duplicate zip/lzma/crc32 symbols from libarchive + liblzma,
#   - the force-included rename header, which prefixes the ~68 globals libxmp
#     exports outside the xmp_/libxmp_ namespace (hio_*, read*/write* endian
#     helpers, MD5*) — see third_party/libxmp/rewamp_xmp_rename.h.
# Includes stay PRIVATE: libxmp's headers are named common.h / mixer.h /
# player.h / format.h / loader.h, about as collision-prone as it gets.
function(rewamp_add_libxmp target)
  set(_x "${REWAMP_THIRD_PARTY_DIR}/libxmp")
  if(NOT EXISTS "${_x}/src/mixer.c")
    message(FATAL_ERROR "REWAMP_WITH_XMP=ON but libxmp is missing at ${_x}")
  endif()

  file(GLOB _xmp_src "${_x}/src/*.c" "${_x}/src/loaders/*.c")
  add_library(rewamp_xmp STATIC ${_xmp_src})
  set_target_properties(rewamp_xmp PROPERTIES POSITION_INDEPENDENT_CODE ON)
  target_compile_options(rewamp_xmp PRIVATE -w
    "-include" "${_x}/rewamp_xmp_rename.h")
  target_compile_definitions(rewamp_xmp PRIVATE
    LIBXMP_STATIC LIBXMP_NO_DEPACKERS LIBXMP_NO_PROWIZARD)
  # REWAMP_SRC_DIR: mixer.c's scope capture includes ModizerVoicesData.h.
  target_include_directories(rewamp_xmp PRIVATE
    "${_x}/src" "${_x}/include" "${REWAMP_SRC_DIR}")
  target_include_directories(rewamp_xmp PUBLIC "${_x}/include")

  target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_xmp.c")
  target_compile_definitions(${target} PRIVATE REWAMP_WITH_XMP=1)
  target_link_libraries(${target} PRIVATE rewamp_xmp)
endfunction()

function(rewamp_configure_decoders target)
  target_include_directories(${target} PRIVATE "${REWAMP_SRC_DIR}")

  if(REWAMP_WITH_OPENMPT)
    rewamp_add_libopenmpt()
    target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_openmpt.c")
    target_compile_definitions(${target} PRIVATE REWAMP_WITH_OPENMPT)
    target_link_libraries(${target} PRIVATE openmpt)
  endif()

  if(REWAMP_WITH_XMP)
    rewamp_add_libxmp(${target})
  endif()

  if(REWAMP_WITH_VGM)
    rewamp_add_libvgm(${target})
  endif()

  if(REWAMP_WITH_GME)
    rewamp_add_libgme(${target})
  endif()

  if(REWAMP_WITH_ARCHIVE)
    rewamp_add_libarchive(${target})
  endif()

  if(REWAMP_WITH_FURNACE)
    rewamp_add_furnace(${target})
  endif()

  if(REWAMP_WITH_ZXTUNE)
    rewamp_add_zxtune(${target})
  endif()

  if(REWAMP_WITH_UADE)
    rewamp_add_uade(${target})
  endif()

  if(REWAMP_WITH_NEZ)
    rewamp_add_nez(${target})
  endif()

  if(REWAMP_WITH_KSS)
    rewamp_add_kss(${target})
  endif()

  if(REWAMP_WITH_MAC)
    rewamp_add_mac(${target})
  endif()

  if(REWAMP_WITH_ASAP)
    rewamp_add_asap(${target})
  endif()

  if(REWAMP_WITH_HVL)
    rewamp_add_hvl(${target})
  endif()

  if(REWAMP_WITH_V2M)
    rewamp_add_v2m(${target})
  endif()

  if(REWAMP_WITH_MIDI)
    rewamp_add_midi(${target})
  endif()

  if(REWAMP_WITH_MT32)
    rewamp_add_mt32(${target})
  endif()

  if(REWAMP_WITH_GSF)
    rewamp_add_gsf(${target})
  endif()

  if(REWAMP_WITH_VIO2SF)
    rewamp_add_vio2sf(${target})
  endif()

  if(REWAMP_WITH_NCSF)
    rewamp_add_ncsf(${target})
  endif()

  if(REWAMP_WITH_SNSF)
    rewamp_add_snsf(${target})
  endif()

  # projectM a besoin d'une couche GL. Il en existe une pour Android
  # (src/android/rewamp_gl_android.cpp), pour Apple (podspecs) et désormais pour
  # Linux (src/linux/rewamp_gl_linux.cc, EGL/Mesa natif). Windows n'en a
  # toujours pas: y compiler rewamp_projectm_render.cpp échouerait sur des
  # GLuint/glGenTextures non déclarés, et le TU ne trouverait aucun contexte à
  # l'édition de liens.
  if(REWAMP_WITH_PROJECTM AND NOT ANDROID AND NOT CMAKE_SYSTEM_NAME STREQUAL "Linux")
    message(STATUS "rewamp: projectM désactivé — pas de couche GL pour cette plateforme")
  else()
    if(REWAMP_WITH_PROJECTM)
      rewamp_add_projectm(${target})
    endif()
  endif()

  if(REWAMP_WITH_ADPLUG)
    rewamp_add_adplug(${target})
  endif()

  if(REWAMP_WITH_SNDH)
    rewamp_add_sndh(${target})
  endif()

  if(REWAMP_WITH_PSGPLAY)
    rewamp_add_psgplay(${target})
  endif()

  if(REWAMP_WITH_LAZYUSF)
    rewamp_add_lazyusf(${target})
  endif()

  if(REWAMP_WITH_WONDERSWAN)
    rewamp_add_wonderswan(${target})
  endif()

  if(REWAMP_WITH_HIGHLYQUIXOTIC)
    rewamp_add_highlyquixotic(${target})
  endif()

  if(REWAMP_WITH_HIGHLYTHEORITICAL)
    rewamp_add_highlytheoritical(${target})
  endif()

  if(REWAMP_WITH_LIBPT3)
    rewamp_add_libpt3(${target})
  endif()

  if(REWAMP_WITH_TIATRACKER)
    rewamp_add_tiatracker(${target})
  endif()

  if(REWAMP_WITH_ORGANYA)
    rewamp_add_organya(${target})
  endif()

  if(REWAMP_WITH_PROWIZARD)
    rewamp_add_prowizard(${target})
  endif()

  if(REWAMP_WITH_PXTONE)
    rewamp_add_pxtone(${target})
  endif()

  if(REWAMP_WITH_PMD)
    rewamp_add_pmd(${target})
  endif()

  if(REWAMP_WITH_MDX)
    rewamp_add_mdx(${target})
  endif()

  if(REWAMP_WITH_FMP)
    rewamp_add_fmp(${target})
  endif()

  if(REWAMP_WITH_EUP)
    rewamp_add_eup(${target})
  endif()

  if(REWAMP_WITH_SC68)
    rewamp_add_sc68(${target})
  endif()

  if(REWAMP_WITH_SUNVOX)
    rewamp_add_sunvox(${target})
  endif()

  if(REWAMP_WITH_SID)
    rewamp_add_libsidplayfp(${target})
  endif()

  if(REWAMP_WITH_NSFPLAY)
    set(_nsfplay_root "${REWAMP_THIRD_PARTY_DIR}/libnsfplay")
    set(_nsfplay_srcs
      "${_nsfplay_root}/fileutil.cpp"
      "${_nsfplay_root}/devices/Audio/echo.cpp"
      "${_nsfplay_root}/devices/Audio/filter.cpp"
      "${_nsfplay_root}/devices/Audio/MedianFilter.cpp"
      "${_nsfplay_root}/devices/Audio/rconv.cpp"
      "${_nsfplay_root}/devices/CPU/nes_cpu.cpp"
      "${_nsfplay_root}/devices/Memory/nes_bank.cpp"
      "${_nsfplay_root}/devices/Memory/nes_mem.cpp"
      "${_nsfplay_root}/devices/Memory/nsf2_vectors.cpp"
      "${_nsfplay_root}/devices/Memory/ram64k.cpp"
      "${_nsfplay_root}/devices/Misc/detect.cpp"
      "${_nsfplay_root}/devices/Misc/log_cpu.cpp"
      "${_nsfplay_root}/devices/Misc/nes_detect.cpp"
      "${_nsfplay_root}/devices/Misc/nsf2_irq.cpp"
      "${_nsfplay_root}/devices/Sound/nes_apu.cpp"
      "${_nsfplay_root}/devices/Sound/nes_dmc.cpp"
      "${_nsfplay_root}/devices/Sound/nes_fds.cpp"
      "${_nsfplay_root}/devices/Sound/nes_fme7.cpp"
      "${_nsfplay_root}/devices/Sound/nes_mmc5.cpp"
      "${_nsfplay_root}/devices/Sound/nes_n106.cpp"
      "${_nsfplay_root}/devices/Sound/nes_vrc6.cpp"
      "${_nsfplay_root}/devices/Sound/nes_vrc7.cpp"
      "${_nsfplay_root}/player/nsf/nsf.cpp"
      "${_nsfplay_root}/player/nsf/nsfconfig.cpp"
      "${_nsfplay_root}/player/nsf/nsfplay.cpp"
      # playlist parser (PLSITEM_*) — lives under player/nsf/pls/
      "${_nsfplay_root}/player/nsf/pls/ppls.cpp"
      "${_nsfplay_root}/player/nsf/pls/sstream.cpp"
      # vcm config value system (vcm::Value) — outside xgm/, in third_party/vcm/
      "${_nsfplay_root}/../vcm/value.cpp"
      "${_nsfplay_root}/../vcm/group.cpp"
    )
    # Legacy C sources need OPLL/PSG symbol renames to avoid clash with libvgm.
    set(_nsfplay_legacy_c
      "${_nsfplay_root}/devices/Sound/legacy/emu2413.c"
      "${_nsfplay_root}/devices/Sound/legacy/emu2149.c"
      "${_nsfplay_root}/devices/Sound/legacy/emu2212.c"
    )
    target_sources(${target} PRIVATE ${_nsfplay_srcs} ${_nsfplay_legacy_c})
    target_include_directories(${target} PRIVATE "${_nsfplay_root}/..")
    target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_nsfplay.cpp")
    # The OPLL_*/PSG_* symbol rename must apply to EVERY nsfplay translation unit
    # (not just the legacy C): the C++ devices (nes_vrc7/nes_fme7) reference those
    # symbols and must see the same renamed names as the legacy C that defines them.
    set_source_files_properties(
      ${_nsfplay_srcs} ${_nsfplay_legacy_c}
      "${REWAMP_SRC_DIR}/rewamp_plugin_nsfplay.cpp"
      PROPERTIES
      COMPILE_OPTIONS "-include;${REWAMP_SRC_DIR}/nsfplay_symbol_rename.h")
    target_compile_definitions(${target} PRIVATE REWAMP_WITH_NSFPLAY=1 REWAMP_NSF_OSCILLO_SIZE=4096)
  endif()

  if(REWAMP_WITH_GBSPLAY)
    set(_gbs_root "${REWAMP_THIRD_PARTY_DIR}/libgbsplay")
    if(NOT EXISTS "${_gbs_root}/libgbs.h")
      message(FATAL_ERROR
        "REWAMP_WITH_GBSPLAY=ON but ${_gbs_root}/libgbs.h is missing.\n"
        "Copy Modizer's gbsplay sources to:\n"
        "  packages/rewamp_audio/third_party/libgbsplay/")
    endif()
    set(_gbs_srcs
      "${_gbs_root}/gbs.c"
      "${_gbs_root}/gbhw.c"
      "${_gbs_root}/gbcpu.c"
      "${_gbs_root}/gblfsr.c"
      "${_gbs_root}/mapper.c"
      "${_gbs_root}/util.c"
      "${_gbs_root}/crc32.c"
    )
    target_sources(${target} PRIVATE ${_gbs_srcs})
    target_include_directories(${target} PRIVATE "${_gbs_root}")
    target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_gbsplay.c")
    target_compile_definitions(${target} PRIVATE REWAMP_WITH_GBSPLAY=1)
    target_link_libraries(${target} PRIVATE z)
  endif()

  if(REWAMP_WITH_HIGHLYEXP)
    set(_he_root  "${REWAMP_THIRD_PARTY_DIR}/highlyexperimental")
    set(_psf_root "${REWAMP_THIRD_PARTY_DIR}/libpsflib")
    if(NOT EXISTS "${_he_root}/Core/psx.h")
      message(FATAL_ERROR
        "REWAMP_WITH_HIGHLYEXP=ON but ${_he_root}/Core/psx.h is missing.\n"
        "Copy Modizer's highlyexperimental + libpsflib sources to:\n"
        "  packages/rewamp_audio/third_party/highlyexperimental/\n"
        "  packages/rewamp_audio/third_party/libpsflib/")
    endif()
    set(_he_srcs
      "${_he_root}/Core/psx.c"
      "${_he_root}/Core/ioptimer.c"
      "${_he_root}/Core/iop.c"
      "${_he_root}/Core/bios.c"
      "${_he_root}/Core/r3000dis.c"
      "${_he_root}/Core/r3000asm.c"
      "${_he_root}/Core/r3000.c"
      "${_he_root}/Core/vfs.c"
      "${_he_root}/Core/spucore.c"
      "${_he_root}/Core/spu.c"
      "${_he_root}/Core/mkhebios.c"
      "${_psf_root}/psflib.c"
      "${_psf_root}/psf2fs.c"
    )
    target_sources(${target} PRIVATE ${_he_srcs})
    target_include_directories(${target} PRIVATE "${REWAMP_THIRD_PARTY_DIR}")
    target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_highlyexp.c")
    target_compile_definitions(${target} PRIVATE
      REWAMP_WITH_HIGHLYEXP=1 EMU_COMPILE EMU_LITTLE_ENDIAN HAVE_STDINT_H)
    target_link_libraries(${target} PRIVATE z)
  endif()

  # vgmstream: enabled when the submodule is present and a prebuilt libvgmstream.a exists.
  # Apple targets use the podspec build system; this stub covers Linux/Windows/Android.
  # TODO: wire full cmake build once Android/Linux support is needed.
  if(REWAMP_WITH_VGMSTREAM)
    set(_vgm_dir "${REWAMP_THIRD_PARTY_DIR}/vgmstream")
    if(NOT EXISTS "${_vgm_dir}/src/libvgmstream.h")
      message(FATAL_ERROR
        "REWAMP_WITH_VGMSTREAM=ON but vgmstream submodule is missing.\n"
        "Run: git submodule update --init packages/rewamp_audio/third_party/vgmstream\n")
    endif()
    # FFmpeg (ffmpeg-kit prebuilt) → decode codecs vgmstream can't natively
    # (Vorbis .ogg, Opus, AAC…). BYPASS vgmstream's own USE_FFMPEG: its
    # dependencies/ffmpeg.cmake treats FFMPEG_PATH as a *source tree* to
    # ./configure-build, incompatible with a prebuilt. Instead keep USE_FFMPEG=OFF
    # and (below, after add_subdirectory) define VGM_USE_FFMPEG + add the prebuilt
    # include dir on the libvgmstream target so ffmpeg_decoder.c (always globbed,
    # guarded by #ifdef VGM_USE_FFMPEG) compiles; the libav*/swr_ symbols are then
    # satisfied by linking the prebuilt .so. Same recipe as the Apple podspecs.
    set(USE_FFMPEG OFF CACHE BOOL "" FORCE)
    set(_vgm_ffmpeg OFF)
    set(_vgm_ffmpeg_pc OFF)
    if(REWAMP_FFMPEG_DIR AND EXISTS "${REWAMP_FFMPEG_DIR}/include/libavcodec/avcodec.h")
      set(_vgm_ffmpeg ON)
      message(STATUS "vgmstream: FFmpeg enabled via prebuilt bypass (${REWAMP_FFMPEG_DIR})")
    elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND NOT ANDROID)
      # Linux de bureau: FFmpeg est une bibliothèque SYSTÈME, pas un prebuilt.
      # REWAMP_FFMPEG_DIR ne peut pas le décrire — Debian/Ubuntu posent les
      # en-têtes sous /usr/include/<triplet>/libavcodec/, jamais sous un
      # <dir>/include/. On passe donc par pkg-config, qui rend le bon chemin
      # quel que soit le triplet et la distribution.
      #
      # ⚠️ Sans ce chemin, vgmstream se construit SANS FFmpeg et le fait en
      # SILENCE: la build est verte, l'app démarre, et une partie des formats
      # vgmstream (ceux qui passent par ffmpeg_decoder.c — Vorbis, Opus, AAC,
      # ATRAC3…) échoue seulement à la lecture, fichier par fichier. C'est une
      # perte de scope qu'aucun message ne signale, d'où le message(STATUS)
      # explicite dans les DEUX branches.
      #
      # ffmpeg_decoder.c n'a besoin que de trois bibliothèques (ses includes:
      # libavcodec/avcodec.h, libavformat/avformat.h, libswresample/swresample.h),
      # plus libavutil dont les deux premières dépendent.
      find_package(PkgConfig QUIET)
      if(PKG_CONFIG_FOUND)
        pkg_check_modules(REWAMP_FF QUIET IMPORTED_TARGET
          libavcodec libavformat libavutil libswresample)
        if(REWAMP_FF_FOUND)
          set(_vgm_ffmpeg ON)
          set(_vgm_ffmpeg_pc ON)
          message(STATUS
            "vgmstream: FFmpeg système via pkg-config (libavcodec ${REWAMP_FF_libavcodec_VERSION})")
        endif()
      endif()
      if(NOT _vgm_ffmpeg AND NOT REWAMP_ALLOW_NO_FFMPEG)
        # ⚠️ FATAL, pas WARNING. `flutter build` FILTRE la sortie de
        # configuration de cmake: ni STATUS ni WARNING n'atteignent le terminal
        # (vérifié — le message de succès ci-dessus n'apparaît pas non plus).
        # Un avertissement serait donc invisible, et la perte de formats
        # resterait exactement aussi silencieuse que sans message. Seule une
        # erreur se voit. REWAMP_ALLOW_NO_FFMPEG=ON pour construire quand même,
        # en connaissance de cause.
        message(FATAL_ERROR
          "vgmstream: FFmpeg introuvable.\n"
          "Les formats qui passent par ffmpeg_decoder.c (Vorbis, Opus, AAC, "
          "ATRAC3…) seraient absents, et l'échec ne se verrait qu'à la lecture, "
          "fichier par fichier.\n"
          "  sudo apt install libavcodec-dev libavformat-dev libavutil-dev libswresample-dev\n"
          "Pour construire sans (scope vgmstream réduit): "
          "-DREWAMP_ALLOW_NO_FFMPEG=ON")
      endif()
    endif()
    # vgmstream's own optional codec libs (built separately, off here).
    set(USE_MPEG OFF CACHE BOOL "" FORCE)
    set(USE_VORBIS OFF CACHE BOOL "" FORCE)
    set(USE_CELT OFF CACHE BOOL "" FORCE)
    set(USE_SPEEX OFF CACHE BOOL "" FORCE)
    set(USE_ATRAC9 OFF CACHE BOOL "" FORCE)
    set(USE_G719 OFF CACHE BOOL "" FORCE)
    set(USE_G7221 OFF CACHE BOOL "" FORCE)
    set(BUILD_CLI OFF CACHE BOOL "" FORCE)
    set(BUILD_AUDACIOUS OFF CACHE BOOL "" FORCE)

    # vgmstream's base/codec_info.c declares codec externs directly after `case`
    # labels (a C23 construct). Apple clang (podspec builds) accepts it, but the
    # NDK/gcc defaults (gnu17) reject it ("expected expression"). Force C23 on the
    # vgmstream subdirectory only — CMAKE_C_FLAGS is inherited by add_subdirectory
    # and restored afterward so it doesn't leak to the other decoders.
    set(_saved_c_flags "${CMAKE_C_FLAGS}")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=gnu2x")
    add_subdirectory("${_vgm_dir}" "${CMAKE_CURRENT_BINARY_DIR}/vgmstream" EXCLUDE_FROM_ALL)
    set(CMAKE_C_FLAGS "${_saved_c_flags}")
    target_sources(${target} PRIVATE "${REWAMP_SRC_DIR}/rewamp_plugin_vgmstream.cpp")
    target_compile_definitions(${target} PRIVATE REWAMP_WITH_VGMSTREAM=1)
    target_include_directories(${target} PRIVATE
      "${_vgm_dir}/src"
      "${_vgm_dir}/ext_includes")
    target_link_libraries(${target} PRIVATE libvgmstream)

    # FFmpeg bypass: compile ffmpeg_decoder.c into libvgmstream (VGM_USE_FFMPEG +
    # prebuilt headers) and link the ffmpeg-kit shared libs to the final target so
    # the libav*/swr_ symbols resolve. Android packages the .so via jniLibs (see
    # android/build.gradle copyFfmpegLibs); the DT_NEEDED entries created here are
    # resolved from the APK's lib dir at runtime.
    # Vorbis « custom » (Wwise, FSB, OGL…): même contournement que FFmpeg —
    # USE_VORBIS reste OFF (sa branche va CHERCHER libvorbis sur le réseau à la
    # configuration) et on définit VGM_USE_VORBIS nous-mêmes en fournissant la
    # bibliothèque. Sans ça un .txtp Wwise est RECONNU mais refuse de s'ouvrir,
    # faute de codec — et FFmpeg ne rattrape pas: Wwise stocke du Vorbis aux
    # en-têtes RETIRÉS, que seul ce décodeur sait reconstruire.
    rewamp_add_vorbis()
    if(TARGET rewamp_vorbis)
      target_compile_definitions(libvgmstream PRIVATE VGM_USE_VORBIS)
      target_link_libraries(libvgmstream PRIVATE rewamp_vorbis)
      target_link_libraries(${target}    PRIVATE rewamp_vorbis)
    endif()

    if(_vgm_ffmpeg)
      target_compile_definitions(libvgmstream PRIVATE VGM_USE_FFMPEG)
      if(_vgm_ffmpeg_pc)
        # La cible importée porte À LA FOIS les includes et les libs; on lie la
        # MÊME cible aux deux endroits — à libvgmstream pour que
        # ffmpeg_decoder.c trouve ses en-têtes, et au plugin pour que les
        # symboles libav*/swr_ résolvent dans la .so finale.
        target_link_libraries(libvgmstream PRIVATE PkgConfig::REWAMP_FF)
        target_link_libraries(${target}    PRIVATE PkgConfig::REWAMP_FF)
      else()
        target_include_directories(libvgmstream PRIVATE "${REWAMP_FFMPEG_DIR}/include")
        foreach(_ff avcodec avformat avutil swresample avfilter swscale avdevice)
          set(_ff_so "${REWAMP_FFMPEG_DIR}/lib/lib${_ff}.so")
          if(EXISTS "${_ff_so}")
            target_link_libraries(${target} PRIVATE "${_ff_so}")
          endif()
        endforeach()
      endif()
    endif()
  endif()
endfunction()

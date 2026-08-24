Pod::Spec.new do |s|
  s.name             = 'rewamp_audio'
  s.version          = '0.0.1'
  s.summary          = 'Rewamp audio engine — miniaudio backend'
  s.homepage         = 'https://github.com/modizer/rewamp'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Modizer' => 'ymagnien@gmail.com' }

  s.source           = { :path => '.' }
  s.source_files        = 'Classes/**/*'
  s.public_header_files = 'Classes/RewampAudioPlugin.h'

  s.platform = :osx, '13.0'
  s.dependency 'FlutterMacOS'

  # Base xcconfig: always include src/ for rewamp_audio.h etc.
  header_dirs     = ['$(PODS_TARGET_SRCROOT)/../src']
  preprocessor    = ['$(inherited)']
  need_cpp_stdlib = false
  prepare_parts   = []
  vendored_libs   = []
  vendored_frameworks = []
  extra_ldflags   = []

  # miniaudio on macOS uses CoreAudio. The GPU visualizers run on OpenGL ES 3.0
  # via ANGLE (Metal backend) — see the ANGLE block below — so no system OpenGL.
  s.frameworks = 'CoreAudio', 'AudioUnit', 'AudioToolbox', 'CoreVideo',
                 'IOSurface', 'Metal', 'QuartzCore',
                 'Cocoa', 'Carbon'   # SunVox's sound.cpp/file_apple.mm (offline still links them)

  # --- ANGLE (OpenGL ES 3.0 -> Metal) for the GL visualizers + projectM -------
  # Universal libEGL/libGLESv2 dylibs prebuilt by scripts/build_angle_macos.sh
  # into Libs/angle/. REWAMP_GL_GLES=1 switches the shared renderers to the
  # #version 300 es shader path (same as iOS/Android).
  # libEGL loads libGLESv2 from its OWN directory (ANGLE SearchType::ModuleDir),
  # dlopen'ing the bare name "libGLESv2.dylib" — so both dylibs must keep their
  # filenames and sit side by side. We link them here (resolves egl*/gl* at build)
  # and the app Podfile's post_install copies both into Runner.app/Contents/
  # Frameworks (their @rpath install_name + the app's @executable_path/../Frameworks
  # rpath resolve them; co-location satisfies the ModuleDir dlopen).
  preprocessor  << 'REWAMP_GL_GLES=1'
  header_dirs   << '$(PODS_TARGET_SRCROOT)/Libs/angle/include'
  vendored_libs << 'Libs/angle/lib/libEGL.dylib'
  vendored_libs << 'Libs/angle/lib/libGLESv2.dylib'

  # --- Optional decoder plugins -------------------------------------------

  # libopenmpt: enabled by default; opt out with REWAMP_WITH_OPENMPT=0.
  # Requires prebuilt static lib (already in Libs/):
  #   packages/rewamp_audio/scripts/build_libopenmpt_macos.sh
  if ENV['REWAMP_WITH_OPENMPT'] != '0'
    vendored_libs << 'Libs/libopenmpt.a'
    need_cpp_stdlib = true
    preprocessor   << 'REWAMP_WITH_OPENMPT=1'
    header_dirs    << '$(PODS_TARGET_SRCROOT)/../third_party/libopenmpt'
  end

  # libvgm: enabled by default; opt out with REWAMP_WITH_VGM=0.
  #
  # Strategy: CocoaPods source_files only picks up files within the pod root
  # (macos/).  We use prepare_command to generate thin .mm wrapper files in
  # Classes/vgm_cores/ — one per chip core — so each core becomes its own
  # Xcode compilation unit (required because cores define static functions with
  # the same names across files).  The player layer is unity-built from
  # Classes/rewamp_vgm_impl.mm.
  if ENV['REWAMP_WITH_VGM'] != '0'
    libvgm_root = '$(PODS_TARGET_SRCROOT)/../third_party/libvgm/libvgm'

    need_cpp_stdlib = true
    preprocessor   << 'REWAMP_WITH_VGM=1'
    header_dirs    += [
      libvgm_root,
      "#{libvgm_root}/emu",
      "#{libvgm_root}/emu/cores",
      "#{libvgm_root}/player",
      "#{libvgm_root}/utils",
    ]

    # libvgm build-config defines (mirrors Modizer's libvgm.xcodeproj):
    #   VGM_LITTLE_ENDIAN / HAVE_STDINT_H — platform config
    #   SNDDEV_*  — which sound devices are compiled in
    #   EC_*      — which emulation cores are selected
    preprocessor += %w[
      VGM_LITTLE_ENDIAN HAVE_STDINT_H
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
      EC_YM2413_EMU2413 EC_YM2413_MAME EC_YM2413_NUKED EC_YM2612_GENS
      EC_YM2612_GPGX EC_YM2612_NUKED EC_YM3812_ADLIBEMU EC_YM3812_MAME
      EC_YM3812_NUKED EC_YMF262_ADLIBEMU EC_YMF262_MAME EC_YMF262_NUKED
    ]

    # CocoaPods only compiles files inside the pod root (macos/), so we generate
    # thin wrapper files in Classes/vgm_cores/ that #include the real sources.
    #
    # Each libvgm .c becomes its OWN translation unit (exactly like Modizer's
    # libvgm.xcodeproj) — they cannot be unity-built because many define static
    # functions with identical names across files (e.g. ReadLE32 in both
    # FileLoader.c and MemoryLoader.c, init_tables in several FM cores).
    #   - every libvgm .c → one .c wrapper (own TU)
    #   - rewamp_channel_data.c → one .c wrapper
    #   - C++ player layer + plugin → one .mm wrapper (unity-built C++)
    prepare_parts << <<-'SH'
      LIBVGM="$(pwd)/../third_party/libvgm/libvgm"
      CLASSES="$(pwd)/Classes"
      WRAPPERS_DIR="$CLASSES/vgm_cores"

      rm -rf "$WRAPPERS_DIR"
      mkdir -p "$WRAPPERS_DIR"

      # Wrappers live in Classes/vgm_cores/ → ../../../third_party reaches the lib.
      REL="../../../third_party/libvgm/libvgm"

      emit() {  # $1 = subdir under libvgm, $2 = basename without extension
        printf '#include "%s/%s/%s.c"\n' "$REL" "$1" "$2" > "$WRAPPERS_DIR/$2.c"
      }

      # Chip cores — skip include-only helpers (#included by another core):
      #   adlibemu_opl_inc.c (→ adlibemu_opl2/3.c), scsplfo.c (→ scsp.c)
      for f in "$LIBVGM"/emu/cores/*.c; do
        name="$(basename "$f" .c)"
        case "$name" in
          adlibemu_opl_inc|scsplfo) continue ;;
        esac
        emit "emu/cores" "$name"
      done

      # Emulator dispatch / resampling / DAC / logging / panning
      for name in SoundEmu Resampler dac_control logging panning; do
        emit "emu" "$name"
      done

      # Data loaders + charset conversion (iconv-backed)
      for name in DataLoader FileLoader MemoryLoader StrUtils-CPConv_IConv; do
        emit "utils" "$name"
      done

      # Player-layer C helpers
      for name in helper dblk_compr; do
        emit "player" "$name"
      done

      # C++ player engines — each its own .mm TU (file-static name conflicts:
      # ReadLE16/32 in cmdhandler, SaveDeviceConfig in s98/gym).
      emit_mm() {  # $1 = subdir, $2 = basename
        printf '#include "%s/%s/%s.cpp"\n' "$REL" "$1" "$2" > "$WRAPPERS_DIR/$2.mm"
      }
      for name in playerbase vgmplayer vgmplayer_cmdhandler s98player droplayer gymplayer playera; do
        emit_mm "player" "$name"
      done

      # Channel-data globals (rewamp source, separate TU)
      printf '#include "../../src/rewamp_channel_data.c"\n' > "$CLASSES/rewamp_channel_data.c"

      # Les fichiers réellement ouverts par un décodage (panneau ⓘ)
      printf '#include "../../src/rewamp_loaded_files.c"\n' > "$CLASSES/rewamp_loaded_files.c"

      # rewamp VGM plugin glue (compiled as ObjC++)
      printf '#include "../../src/rewamp_plugin_vgm.cpp"\n' > "$CLASSES/rewamp_vgm_impl.mm"
    SH
  end

  # liblzma + libarchive: bundled from Modizer (Modizer-derived).
  # liblzma provides XZ/LZMA decompression; libarchive uses it for .xz, .7z, etc.
  # Supports RAR, RAR5, 7z, ZIP, gz, bzip2, LHA, tar, xz, lzma, and more.
  # Compiled whenever GME is enabled (needed for RSN + generic archive support).
  if ENV['REWAMP_WITH_GME'] != '0'
    libarchive_root = '$(PODS_TARGET_SRCROOT)/../third_party/libarchive'
    liblzma_root    = '$(PODS_TARGET_SRCROOT)/../third_party/liblzma'

    preprocessor << 'REWAMP_WITH_ARCHIVE=1'
    preprocessor << 'HAVE_CONFIG_H=1'          # archive_platform.h + liblzma sysdefs.h
    preprocessor << 'TUKLIB_SYMBOL_PREFIX=lzma_'  # avoid symbol conflicts (same as Modizer)
    header_dirs  << libarchive_root                            # for archive.h / config.h
    header_dirs  << liblzma_root                               # for liblzma config.h
    header_dirs  << "#{liblzma_root}/src/liblzma/api"         # lzma.h (public API)
    # liblzma internal subdirs: each subdir #includes headers from sibling dirs
    # (e.g. simple/simple_coder.h includes "common.h" from common/).
    # Xcode adds each source file's dir automatically; we must do it explicitly.
    %w[common check lz lzma delta simple rangecoder api].each do |d|
      header_dirs << "#{liblzma_root}/src/liblzma/#{d}"
    end
    header_dirs << "#{liblzma_root}/src/common"                # tuklib headers

    # Each .c file gets its own TU (mirrors Modizer's Xcode projects).
    # _tablegen.c files have main() and are table generators — excluded.
    # All platform-specific files (#if _WIN32, #if __FreeBSD__, etc.) compile
    # to empty translation units on macOS — safe to include unconditionally.
    prepare_parts << <<-'SH'
      LIBARCHIVE="$(pwd)/../third_party/libarchive"
      LIBLZMA="$(pwd)/../third_party/liblzma"
      CLASSES="$(pwd)/Classes"

      # --- liblzma cores ---
      LZMA_DIR="$CLASSES/lzma_cores"
      LZMA_REL="../../../third_party/liblzma"
      rm -rf "$LZMA_DIR"
      mkdir -p "$LZMA_DIR"

      # Compile all liblzma .c files (recursively under src/).
      # Excluded: *_tablegen.c (have main()), *_small.c (conflict with *_fast.c/*_table.c)
      find "$LIBLZMA/src/liblzma" "$LIBLZMA/src/common" -name "*.c" \
          ! -name "*_tablegen.c" ! -name "*_small.c" | while read f; do
        rel="${f#$LIBLZMA/}"
        name="$(echo "$rel" | tr '/' '_' | sed 's/\.c$//')"
        printf '#include "%s/%s"\n' "$LZMA_REL" "$rel" > "$LZMA_DIR/$name.c"
      done

      # --- libarchive cores ---
      ARC_DIR="$CLASSES/archive_cores"
      ARC_REL="../../../third_party/libarchive"
      rm -rf "$ARC_DIR"
      mkdir -p "$ARC_DIR"

      for f in "$LIBARCHIVE"/*.c; do
        name="$(basename "$f" .c)"
        printf '#include "%s/%s.c"\n' "$ARC_REL" "$name" > "$ARC_DIR/$name.c"
      done
    SH

    # unrar: official UnRAR library — handles *solid* RARv3/v4 archives, which
    # libarchive's RAR reader cannot.  RSN files (SPC sets) are solid RARs.
    # Build flags mirror UnRAR's makefile + Modizer's project: -DRARDLL -DSILENT.
    # RAR_SMP is deliberately NOT set, so unrar stays single-threaded (no pthread,
    # threadpool.cpp compiles to nothing).
    unrar_root = '$(PODS_TARGET_SRCROOT)/../third_party/unrar'
    preprocessor << 'REWAMP_WITH_UNRAR=1'
    preprocessor << 'RARDLL=1'
    preprocessor << 'RAR_HDR_DLL_HPP=1'      # libgme Spc_Emu.cpp → #include <dll.hpp>
    preprocessor << 'SILENT=1'
    preprocessor << '_FILE_OFFSET_BITS=64'   # no-op on macOS (off_t already 64-bit)
    preprocessor << '_LARGEFILE_SOURCE=1'
    header_dirs  << unrar_root

    # Only the .cpp files UnRAR's makefile actually compiles (OBJECTS + LIB_OBJ).
    # The rest (crypt1-5, unpack15/20/30/50, recvol*, blake2sp/_sse, …) are
    # #included by those or unused — compiling them standalone breaks the build.
    prepare_parts << <<-'SH'
      UNRAR="$(pwd)/../third_party/unrar"
      CLASSES="$(pwd)/Classes"
      UNRAR_DIR="$CLASSES/unrar_cores"
      UNRAR_REL="../../../third_party/unrar"

      rm -rf "$UNRAR_DIR"
      mkdir -p "$UNRAR_DIR"

      for name in \
        rar strlist strfn pathfn smallfn global file filefn filcreat \
        archive arcread unicode system crypt crc rawread encname \
        resource match timefn rdwrfn consio options errhnd rarvm secpassword \
        rijndael getbits sha1 sha256 blake2s hash extinfo extract volume \
        list find unpack headers threadpool rs16 cmddata ui \
        filestr scantree dll qopen; do
        printf '#include "%s/%s.cpp"\n' "$UNRAR_REL" "$name" > "$UNRAR_DIR/$name.cpp"
      done
    SH
  end

  # libgme: enabled by default; opt out with REWAMP_WITH_GME=0.
  # Supports NES (NSF/NSFe), Game Boy (GBS), SNES (SPC), PC Engine (HES),
  # MSX/Sega (KSS), Atari (SAP), ZX Spectrum (AY), and RSN archives.
  if ENV['REWAMP_WITH_GME'] != '0'
    gme_root = '$(PODS_TARGET_SRCROOT)/../third_party/libgme'

    need_cpp_stdlib = true
    preprocessor   << 'REWAMP_WITH_GME=1'
    preprocessor   << 'VGM_YM2612_NUKED=1'   # select Nuked YM2612 core (default in Ym2612_Emu.h)
    header_dirs    << gme_root
    header_dirs    << "#{gme_root}/gme/ext"  # emu2413.h, panning.h

    # generate one .mm wrapper per libgme .cpp so each is its own TU,
    # then a single wrapper for the rewamp plugin glue.
    prepare_parts << <<-'SH'
      LIBGME="$(pwd)/../third_party/libgme/gme"
      CLASSES="$(pwd)/Classes"
      GME_DIR="$CLASSES/gme_cores"
      GME_REL="../../../third_party/libgme/gme"

      rm -rf "$GME_DIR"
      mkdir -p "$GME_DIR"

      for f in "$LIBGME"/*.cpp; do
        name="$(basename "$f" .cpp)"
        printf '#include "%s/%s.cpp"\n' "$GME_REL" "$name" > "$GME_DIR/$name.mm"
      done

      # ext/ contains emu2413.c (OPLL/VRC7 for NSF) and panning.c — compile as C.
      for f in "$LIBGME"/ext/*.c; do
        name="$(basename "$f" .c)"
        printf '#include "%s/ext/%s.c"\n' "$GME_REL" "$name" > "$GME_DIR/ext_$name.c"
      done

      printf '#include "../../src/rewamp_plugin_gme.cpp"\n' > "$CLASSES/rewamp_gme_impl.mm"

      # rewamp_channel_data.c is a committed static file in Classes/ so it is
      # always available; no need to regenerate it here.
    SH
  end

  # libsidplayfp: enabled by default; opt out with REWAMP_WITH_SID=0.
  if ENV['REWAMP_WITH_SID'] != '0'
    sid_root = '$(PODS_TARGET_SRCROOT)/../third_party/libsidplayfp'
    need_cpp_stdlib = true
    preprocessor   << 'REWAMP_WITH_SID=1'
    preprocessor   << 'HAVE_CXX23=1'   # sidcxx11.h needs this to cascade down to HAVE_CXX11
    header_dirs    += [
      "#{sid_root}/libsidplayfp/src",
      "#{sid_root}/libsidplayfp/src/sidplayfp",
      "#{sid_root}/libsidplayfp/src/builders/residfp-builder",
      "#{sid_root}/libsidplayfp/src/builders/sidlite-builder",
      "#{sid_root}/libresidfp/src",
    ]

    prepare_parts << <<-'SH'
      SID_LIB="$(pwd)/../third_party/libsidplayfp/libsidplayfp/src"
      SID_RESID="$(pwd)/../third_party/libsidplayfp/libresidfp/src"
      CLASSES="$(pwd)/Classes"
      WRAPPERS_DIR="$CLASSES/sid_cores"
      rm -rf "$WRAPPERS_DIR"
      mkdir -p "$WRAPPERS_DIR"
      REL_LIB="../../../third_party/libsidplayfp/libsidplayfp/src"
      REL_RESID="../../../third_party/libsidplayfp/libresidfp/src"

      # libsidplayfp core .cpp files (one wrapper each)
      for f in \
        EventScheduler player psiddrv reloc65 sidemu simpleMixer \
        sidplayfp/sidplayfp sidplayfp/SidConfig sidplayfp/SidInfo \
        sidplayfp/SidTune sidplayfp/SidTuneInfo sidplayfp/sidbuilder \
        sidtune/PSID sidtune/SidTuneBase sidtune/SidTuneTools \
        sidtune/MUS sidtune/prg sidtune/p00 \
        c64/c64 c64/mmu \
        c64/CPU/mos6510 c64/CPU/mos6510debug \
        c64/CIA/mos652x c64/CIA/tod c64/CIA/timer c64/CIA/SerialPort c64/CIA/interrupt \
        c64/VIC_II/mos656x \
        builders/residfp-builder/residfp-builder \
        builders/residfp-builder/residfp-emu \
        builders/sidlite-builder/sidlite-builder \
        builders/sidlite-builder/sidlite-emu \
        builders/sidlite-builder/sidlite/ADSR \
        builders/sidlite-builder/sidlite/Filter \
        builders/sidlite-builder/sidlite/SID \
        builders/sidlite-builder/sidlite/WavGen \
        utils/SidDatabase utils/iniParser utils/STILview/stil; do
        name="$(basename "$f")"
        dir="$(dirname "$f")"
        mkdir -p "$WRAPPERS_DIR/$dir"
        printf '#include "%s/%s.cpp"\n' "$REL_LIB" "$f" > "$WRAPPERS_DIR/${name}.mm"
      done

      # libresidfp chip emulation .cpp files
      for f in "$SID_RESID"/*.cpp; do
        name="$(basename "$f" .cpp)"
        printf '#include "%s/%s.cpp"\n' "$REL_RESID" "$name" > "$WRAPPERS_DIR/resid_${name}.mm"
      done
      for f in "$SID_RESID/resample"/*.cpp; do
        name="$(basename "$f" .cpp)"
        [ "$name" = "test" ] && continue   # skip standalone test harness (has main())
        printf '#include "%s/resample/%s.cpp"\n' "$REL_RESID" "$name" > "$WRAPPERS_DIR/resid_resample_${name}.mm"
      done
      # reSIDfp core engine (residfp/ subdir: residfp.cpp = reSIDfp::residfp class)
      for f in "$SID_RESID/residfp"/*.cpp; do
        name="$(basename "$f" .cpp)"
        printf '#include "%s/residfp/%s.cpp"\n' "$REL_RESID" "$name" > "$WRAPPERS_DIR/resid_residfp_${name}.mm"
      done

      # SID plugin glue (rewamp_assets.c is unity-built in Classes/rewamp_audio.c)
      printf '#include "../../src/rewamp_plugin_sid.cpp"\n' > "$CLASSES/rewamp_sid_impl.mm"
    SH
  end

  # libnsfplay: NES NSF/NSFe decoder; enabled by default.
  if ENV['REWAMP_WITH_NSFPLAY'] != '0'
    preprocessor << 'REWAMP_WITH_NSFPLAY=1'
    preprocessor << 'REWAMP_NSF_OSCILLO_SIZE=4096'
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party'
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/libnsfplay'
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/libnsfplay/..'  # nsfplay-master/ for vcm/

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      NSF_ROOT="$(pwd)/../third_party/libnsfplay"
      REL="../../../../third_party/libnsfplay"
      REL_VCM="../../../../third_party/libnsfplay/../vcm"
      RENAME_HDR="../../../src/nsfplay_symbol_rename.h"
      WRAPPERS_DIR="$CLASSES/nsfplay_cores"
      mkdir -p "$WRAPPERS_DIR"

      # vcm sources (outside xgm/ subdirectory).
      printf '#include "%s"\n#include "%s/value.cpp"\n' "$RENAME_HDR" "$REL_VCM" > "$WRAPPERS_DIR/nsfplay_vcm_value.mm"
      printf '#include "%s"\n#include "%s/group.cpp"\n' "$RENAME_HDR" "$REL_VCM" > "$WRAPPERS_DIR/nsfplay_vcm_group.mm"

      # filter.cpp uses 'pi' which conflicts with deprecated extern double pi in macOS SDK.
      printf '#include "%s"\n#define pi nsfplay_filter_pi_local\n#include "%s/devices/Audio/filter.cpp"\n#undef pi\n' "$RENAME_HDR" "$REL" > "$WRAPPERS_DIR/nsfplay_devices_Audio_filter.mm"

      # ppls.cpp defines static function MAX() which conflicts with Apple SDK MAX macro.
      printf '#include "%s"\n#ifdef MAX\n#undef MAX\n#endif\n#include "%s/player/nsf/pls/ppls.cpp"\n' "$RENAME_HDR" "$REL" > "$WRAPPERS_DIR/nsfplay_player_nsf_pls_ppls.mm"
      printf '#include "%s"\n#include "%s/player/nsf/pls/sstream.cpp"\n' "$RENAME_HDR" "$REL" > "$WRAPPERS_DIR/nsfplay_player_nsf_pls_sstream.mm"

      # Regular C++ sources: include symbol rename header before each source.
      for f in \
        "fileutil.cpp" \
        "devices/Audio/echo.cpp" \
        "devices/Audio/MedianFilter.cpp" \
        "devices/Audio/rconv.cpp" \
        "devices/CPU/nes_cpu.cpp" \
        "devices/Memory/nes_bank.cpp" \
        "devices/Memory/nes_mem.cpp" \
        "devices/Memory/nsf2_vectors.cpp" \
        "devices/Memory/ram64k.cpp" \
        "devices/Misc/detect.cpp" \
        "devices/Misc/log_cpu.cpp" \
        "devices/Misc/nes_detect.cpp" \
        "devices/Misc/nsf2_irq.cpp" \
        "devices/Sound/nes_apu.cpp" \
        "devices/Sound/nes_dmc.cpp" \
        "devices/Sound/nes_fds.cpp" \
        "devices/Sound/nes_fme7.cpp" \
        "devices/Sound/nes_mmc5.cpp" \
        "devices/Sound/nes_n106.cpp" \
        "devices/Sound/nes_vrc6.cpp" \
        "devices/Sound/nes_vrc7.cpp" \
        "player/nsf/nsf.cpp" \
        "player/nsf/nsfconfig.cpp" \
        "player/nsf/nsfplay.cpp"
      do
        name="$(echo "$f" | tr '/' '_' | sed 's/\\.cpp$//')"
        printf '#include "%s"\n#include "%s/%s"\n' "$RENAME_HDR" "$REL" "$f" > "$WRAPPERS_DIR/nsfplay_${name}.mm"
      done

      # Legacy C files need OPLL/PSG symbol renames before the include.
      for src in emu2413.c emu2149.c emu2212.c; do
        base="${src%.c}"
        printf '#include "%s"\n#include "%s/devices/Sound/legacy/%s"\n' "$RENAME_HDR" "$REL" "$src" > "$WRAPPERS_DIR/nsfplay_legacy_${base}.m"
      done

      # Plugin glue
      printf '#include "../../src/rewamp_plugin_nsfplay.cpp"\n' > "$CLASSES/rewamp_nsfplay_impl.mm"
    SH
  end

  # libgbsplay: Game Boy GBS decoder; enabled by default.
  if ENV['REWAMP_WITH_GBSPLAY'] != '0'
    preprocessor << 'REWAMP_WITH_GBSPLAY=1'
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/libgbsplay'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      REL="../../../../third_party/libgbsplay"
      WRAPPERS_DIR="$CLASSES/gbsplay_cores"
      mkdir -p "$WRAPPERS_DIR"

      for src in gbs.c gbhw.c gbcpu.c gblfsr.c mapper.c util.c crc32.c; do
        base="${src%.c}"
        printf '#include "%s/%s"\n' "$REL" "$src" > "$WRAPPERS_DIR/gbsplay_${base}.m"
      done

      printf '#include "../../src/rewamp_plugin_gbsplay.c"\n' > "$CLASSES/rewamp_gbsplay_impl.m"
    SH
  end

  # Highly Experimental: PlayStation PSF/PSF2 decoder; enabled by default.
  if ENV['REWAMP_WITH_HIGHLYEXP'] != '0'
    preprocessor << 'REWAMP_WITH_HIGHLYEXP=1'
    preprocessor << 'EMU_COMPILE'
    preprocessor << 'EMU_LITTLE_ENDIAN'
    preprocessor << 'HAVE_STDINT_H'
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      REL="../../../../third_party/highlyexperimental/Core"
      REL_PSF="../../../../third_party/libpsflib"
      WRAPPERS_DIR="$CLASSES/highlyexp_cores"
      mkdir -p "$WRAPPERS_DIR"

      for src in psx.c ioptimer.c iop.c bios.c r3000dis.c r3000asm.c r3000.c vfs.c spucore.c spu.c mkhebios.c; do
        base="${src%.c}"
        printf '#include "%s/%s"\n' "$REL" "$src" > "$WRAPPERS_DIR/he_${base}.m"
      done
      for src in psflib.c psf2fs.c; do
        base="${src%.c}"
        printf '#include "%s/%s"\n' "$REL_PSF" "$src" > "$WRAPPERS_DIR/he_${base}.m"
      done

      printf '#include "../../src/rewamp_plugin_highlyexp.c"\n' > "$CLASSES/rewamp_highlyexp_impl.m"
    SH
  end

  # vgmstream: 200+ game audio formats catch-all; enabled by default.
  # Requires prebuilt static lib:
  #   packages/rewamp_audio/scripts/build_vgmstream_macos.sh
  if ENV['REWAMP_WITH_VGMSTREAM'] != '0' && File.exist?(File.join(__dir__, 'Libs/libvgmstream.a'))
    vendored_libs << 'Libs/libvgmstream.a'
    need_cpp_stdlib = true
    preprocessor << 'REWAMP_WITH_VGMSTREAM=1'
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/vgmstream/src'
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/vgmstream/ext_includes'

    # FFmpeg (ffmpeg-kit prebuilt frameworks) — libvgmstream.a is built with
    # VGM_USE_FFMPEG (see build_vgmstream_macos.sh) and leaves libav*/swr_ symbols
    # unresolved; link + embed the dynamic frameworks here to satisfy them. Built
    # locally into macos/Libs/ffmpeg-kit (gitignored). Absent → vgmstream still
    # links, but the FFmpeg-only codecs fail to open at runtime.
    if Dir.exist?(File.join(__dir__, 'Libs/ffmpeg-kit'))
      %w[libavcodec libavformat libavutil libswresample
         libavfilter libswscale libavdevice].each do |lib|
        vendored_frameworks << "Libs/ffmpeg-kit/#{lib}.xcframework"
        # vendored_frameworks embeds + sets the search path but does NOT add the
        # link flag → the libvgmstream.a ffmpeg symbols stay unresolved. Link
        # explicitly (Xcode resolves the xcframework's macos slice from the
        # search path CocoaPods already added).
        extra_ldflags << "-framework #{lib}"
      end
    end


    # Vorbis « custom » de vgmstream (Wwise, FSB, OGL…): libvgmstream.a est
    # construit avec VGM_USE_VORBIS et laisse les symboles vorbis_*/ogg_*
    # indéfinis — on les résout ICI en compilant libogg + libvorbis.
    #
    # Les sources viennent de l'arbre vendoré par le SUBMODULE libopenmpt, qui
    # les porte déjà et n'en compile AUCUNE (son .a n'a zéro symbole vorbis,
    # vérifié au nm) — donc pas de doublon possible. On ne les recopie pas.
    # `ogg/config_types.h` est GÉNÉRÉ par le build amont de libogg et absent de
    # cet arbre; il vient de src/vorbis_compat/, puisqu'on ne modifie jamais un
    # submodule.
    #
    # ⚠️ barkmel.c / psytune.c / tone.c sont des OUTILS autonomes avec un main():
    # les compiler ferait deux points d'entrée dans l'app. sharedbook.c en a un
    # aussi mais sous #ifdef _V_SELFTEST, donc sans risque.
    vorbis_root  = '$(PODS_TARGET_SRCROOT)/../third_party/libopenmpt/include'
    header_dirs << '$(PODS_TARGET_SRCROOT)/../src/vorbis_compat'
    header_dirs << "#{vorbis_root}/ogg/include"
    header_dirs << "#{vorbis_root}/vorbis/include"
    header_dirs << "#{vorbis_root}/vorbis/lib"

    prepare_parts << <<-'SH'
      LOM="$(pwd)/../third_party/libopenmpt/include"
      WRAP="$(pwd)/Classes/vorbis_cores"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      REL="../../../third_party/libopenmpt/include"
      for f in "$LOM"/ogg/src/*.c; do
        n="$(basename "$f" .c)"
        printf '#include "%s/ogg/src/%s.c"\n' "$REL" "$n" > "$WRAP/vorbis_$n.c"
      done
      for f in "$LOM"/vorbis/lib/*.c; do
        n="$(basename "$f" .c)"
        case "$n" in barkmel|psytune|tone) continue ;; esac
        printf '#include "%s/vorbis/lib/%s.c"\n' "$REL" "$n" > "$WRAP/vorbis_$n.c"
      done
    SH

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      printf '#include "../../src/rewamp_plugin_vgmstream.cpp"\n' > "$CLASSES/rewamp_vgmstream_impl.mm"
    SH
  end

  # --- Furnace (DivEngine) tracker: .fur / FamiTracker .ftm / DefleMask by magic --
  # Enabled by default; opt out with REWAMP_WITH_FURNACE=0. Mirrors the cmake
  # rewamp_add_furnace(): compiles the exact 298-file engine set listed in
  # third_party/furnace/furnace_sources.cmake, each as its OWN translation unit
  # (file-static name collisions across chip cores), every TU force-included with
  # furnace_chip_rename.h so its bundled cores (Nuked-OPLL/emu2413/opl/opm/opn/
  # SAASound/ymfm/vgsound…) don't clash with libvgm/libgme/nsfplay. On Apple we
  # keep momo + HAVE_LOCALE (momo.c's SDL path is #ifdef ANDROID only).
  if ENV['REWAMP_WITH_FURNACE'] != '0'
    furnace_root = '$(PODS_TARGET_SRCROOT)/../third_party/furnace'
    need_cpp_stdlib = true
    preprocessor << 'REWAMP_WITH_FURNACE=1'
    preprocessor << 'HAVE_MOMO=1'
    preprocessor << 'HAVE_LOCALE=1'
    preprocessor << 'HAVE_DIRENT_TYPE=1'
    preprocessor << 'HAVE_SETLOCALE=1'
    header_dirs  << "#{furnace_root}/extern/fmt/include"
    header_dirs  << "#{furnace_root}/src/momo"
    header_dirs  << "#{furnace_root}/extern/vgsound_emu-modified"
    header_dirs  << "#{furnace_root}/extern/IconFontCppHeaders"
    header_dirs  << "#{furnace_root}/extern/blip_buf"
    header_dirs  << "#{furnace_root}/src/icon"
    header_dirs  << "#{furnace_root}/src/modizer"   # FurnacePlayer.h for the plugin

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/furnace_cores"
      REL="../../../third_party/furnace"
      SRCLIST="$(pwd)/../third_party/furnace/furnace_sources.cmake"
      RENAME="$REL/src/modizer/furnace_chip_rename.h"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      # One wrapper per source file (path flattened → unique name; dup basenames
      # like abstract.cpp live in 3 dirs). Compile as plain C/C++ — NOT ObjC++:
      # furnace has no Objective-C, and .mm pulls Apple's MacTypes.h which #defines
      # legacy keywords like `pascal` that collide with furnace identifiers.
      grep -oE '\}/[^"]+\.(c|cc|cpp)' "$SRCLIST" | sed 's#^\}/##' | while read rel; do
        flat=$(printf '%s' "$rel" | tr '/.' '__')
        case "$rel" in
          *.c) W="$WRAP/${flat}.c" ;;
          *)   W="$WRAP/${flat}.cpp" ;;
        esac
        printf '#include "%s"\n#include "%s/%s"\n' "$RENAME" "$REL" "$rel" > "$W"
      done
      # plugin glue (plain C++, kept inside furnace_cores/ which is gitignored).
      printf '#include "../../../src/rewamp_plugin_furnace.cpp"\n' > "$WRAP/zz_rewamp_furnace_plugin.cpp"
    SH
  end

  # --- libzxtune: ZX Spectrum / AY / many chiptune formats (.ay/.ym/.vtx/.pt3/…) --
  # Enabled by default; opt out with REWAMP_WITH_ZXTUNE=0. Mirrors the cmake
  # rewamp_add_zxtune(): compiles the curated 237-file set from
  # third_party/libzxtune/zxtune_sources.cmake, each as its OWN translation unit
  # (file-static name collisions across cores). Header-only boost 1.57 lives under
  # the lib root (so <boost/...> resolves). zxtune's target-private defines
  # (MODIZER — critical, types.h's non-MODIZER branch is broken; boost flags; z80ex
  # version macros) are emitted INTO each wrapper (#define before #include) so they
  # do NOT leak pod-wide and flip Modizer-gated paths in libvgm/libgme/nsfplay.
  if ENV['REWAMP_WITH_ZXTUNE'] != '0'
    zxtune_root = '$(PODS_TARGET_SRCROOT)/../third_party/libzxtune'
    need_cpp_stdlib = true
    preprocessor << 'REWAMP_WITH_ZXTUNE=1'   # registry gate (rewamp_registry.c, compiled pod-wide)
    header_dirs  << "#{zxtune_root}/include"
    header_dirs  << "#{zxtune_root}/src"
    header_dirs  << "#{zxtune_root}/3rdparty"
    header_dirs  << "#{zxtune_root}"                       # <boost/...> and <3rdparty/zlib/zlib.h>
    header_dirs  << "#{zxtune_root}/3rdparty/z80ex/include"
    header_dirs  << "#{zxtune_root}/emscripten"            # Spectre.h for the plugin TU
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/libchpconv'  # chp2ym.h (.chp → YM3)

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/zxtune_cores"
      REL="../../../third_party/libzxtune"
      SRCLIST="$(pwd)/../third_party/libzxtune/zxtune_sources.cmake"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      # zxtune's target-private defines, prepended to every wrapper.
      DEFS='#define MODIZER 1
#define BOOST_ERROR_CODE_HEADER_ONLY 1
#define BOOST_NO_RTTI 1
#define BOOST_SYSTEM_NO_DEPRECATED 1
#define NO_DEBUG_LOGS 1
#define NO_L10N 1
#define WORDS_LITTLE_ENDIAN 1
#define Z80EX_API_REVISION 1
#define Z80EX_VERSION_MAJOR 1
#define Z80EX_VERSION_MINOR 19
#define Z80EX_RELEASE_TYPE pre1
#define Z80EX_VERSION_STR "1.1.19pre1"'
      # One wrapper per source (path flattened → unique name). Compile as plain
      # C/C++ — NOT ObjC++: zxtune has no Objective-C, and .mm pulls MacTypes.h.
      grep -oE '\$\{ZXTUNE_ROOT\}/[^"]+\.(c|cc|cpp)' "$SRCLIST" | sed 's#^\${ZXTUNE_ROOT}/##' | while read rel; do
        flat=$(printf '%s' "$rel" | tr '/.' '__')
        case "$rel" in
          *.c) W="$WRAP/${flat}.c" ;;
          *)   W="$WRAP/${flat}.cpp" ;;
        esac
        printf '%s\n#include "%s/%s"\n' "$DEFS" "$REL" "$rel" > "$W"
      done
      # plugin glue (plain C++; needs MODIZER for Spectre.h→types.h).
      printf '%s\n#include "../../../src/rewamp_plugin_zxtune.cpp"\n' "$DEFS" > "$WRAP/zz_rewamp_zxtune_plugin.cpp"
      # link stubs for the force-loaded-but-unused subsystems (boost::filesystem,
      # libcurl, AYM dumpers). See rewamp_zxtune_stubs.cpp.
      printf '%s\n#include "../../../src/rewamp_zxtune_stubs.cpp"\n' "$DEFS" > "$WRAP/zz_rewamp_zxtune_stubs.cpp"
      # libchpconv: .chp (Amstrad CPC ChipTracker) → YM3 (plain C).
      printf '#include "../../../third_party/libchpconv/chp2ym.c"\n' > "$WRAP/zz_chp2ym.c"
    SH
  end

  # --- UADE: Amiga custom-chip formats (.ahx/.tfmx/.cust/.fc/.hip/…) via 68k emu --
  # Enabled by default; opt out with REWAMP_WITH_UADE=0. Mirrors
  # the cmake rewamp_add_uade(): compiles libzakalwe + bencode + libuade + the
  # uadecore 68k emulator, each as its OWN translation unit (configure-duplicated
  # file names + file-static collisions; cpuemu.c is compiled ×8 with PART_1..8).
  #
  # Single-process / iOS-safe: every uade TU is built with UADE_IN_PROCESS so
  # uadecore runs in a pthread (no fork) — see the patched ossupport.c/uadestate.c.
  # The emulator TUs are also given uade_inprocess.h (exit()→longjmp shim, defined
  # in uademain.c) so an in-emulator exit() unwinds the thread instead of killing
  # the app. The feature macros are emitted INTO each wrapper (not pod-wide) so they
  # don't leak into the other plugins' translation units.
  # NOTE: UADE's include dirs are NOT added to the pod-wide HEADER_SEARCH_PATHS.
  # src/include/ holds generic-named headers (memory.h, audio.h, custom.h, events.h,
  # options.h, …) that would shadow the system/other-plugin headers for every TU
  # (e.g. nsfplay's `#include <memory.h>` would resolve to UADE's). Instead the
  # include paths are applied per-file to Classes/uade_cores/* in the app Podfiles'
  # post_install (mirrors the zxtune gnu++14 per-file flag), so they stay scoped to
  # UADE translation units only.
  if ENV['REWAMP_WITH_UADE'] != '0'
    need_cpp_stdlib = true
    preprocessor << 'REWAMP_WITH_UADE=1'   # registry + plugin gate (compiled pod-wide)

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/uade_cores"
      REL="../../../third_party/uade"
      SRC="$(pwd)/../third_party/uade/src"
      ZAK="$(pwd)/../third_party/uade/libzakalwe"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      # POSIX/Darwin feature macros + the in-process flag, prepended per wrapper.
      DEFS='#define UADE_IN_PROCESS 1
#define _DEFAULT_SOURCE 1
#define _DARWIN_C_SOURCE 1'

      # libzakalwe (already pruned of *-test.c / configure-*.c).
      for f in "$ZAK"/*.c; do
        n="$(basename "$f" .c)"
        printf '%s\n#include "%s/libzakalwe/%s.c"\n' "$DEFS" "$REL" "$n" > "$WRAP/zak_${n}.c"
      done

      # bencode-tools: bencode.c only.
      printf '%s\n#include "%s/bencodetools/bencode.c"\n' "$DEFS" "$REL" > "$WRAP/bencode.c"

      # libuade = frontends/common/*.c, EXCEPT md5.c (#included by state_detection.c).
      for f in "$SRC"/frontends/common/*.c; do
        n="$(basename "$f" .c)"
        [ "$n" = "md5" ] && continue
        printf '%s\n#include "%s/src/frontends/common/%s.c"\n' "$DEFS" "$REL" "$n" > "$WRAP/fc_${n}.c"
      done

      # uadecore emulator = src/*.c, EXCEPT configure-duplicated (ossupport/uadeipc/
      # uadeutils/unixatomic), sd-sound.c (dup of sd-sound-generic.c), cpuemu.c
      # (×8 below). Force-include the exit()→longjmp shim on these emulator TUs.
      for f in "$SRC"/*.c; do
        n="$(basename "$f" .c)"
        case "$n" in
          ossupport|uadeipc|uadeutils|unixatomic|sd-sound|cpuemu) continue ;;
        esac
        printf '%s\n#include "%s/src/uade_inprocess.h"\n#include "%s/src/%s.c"\n' \
          "$DEFS" "$REL" "$REL" "$n" > "$WRAP/core_${n}.c"
      done

      # cpuemu.c ×8 (PART_1..8) — the 68k opcode emulation, split for compile time.
      for n in 1 2 3 4 5 6 7 8; do
        printf '%s\n#define PART_%s 1\n#include "%s/src/uade_inprocess.h"\n#include "%s/src/cpuemu.c"\n' \
          "$DEFS" "$n" "$REL" "$REL" > "$WRAP/core_cpuemu${n}.c"
      done

      # plugin glue (plain C++; no UADE_IN_PROCESS needed — pure libuade API user).
      printf '#include "../../../src/rewamp_plugin_uade.cpp"\n' > "$WRAP/zz_rewamp_uade_plugin.cpp"
    SH
  end

  # --- NEZplug++: HES (HuC6280) + SGC/SMS (SN76489 + YM2413) -----------------
  # Enabled by default; opt out with REWAMP_WITH_NEZ=0. Mirrors the cmake
  # rewamp_add_nez(): compiles the curated set from third_party/nez/nez_sources.cmake,
  # each as its OWN translation unit (nez device cores reuse identical static fn
  # names — cannot unity-build, like libvgm). Per-voice scope + notes + mute live in
  # the vendored cores (device/s_hes.c, s_sng.c, opl/s_opl.c fill nezChan_output[];
  # format/audiosys.c → m_voice_buff[] + generic_mute_mask). Includes are pod-wide
  # (nez header names are nez-specific: nezplug.h/nestypes.h/kmsnddev.h/s_*.h).
  if ENV['REWAMP_WITH_NEZ'] != '0'
    nez_root = '$(PODS_TARGET_SRCROOT)/../third_party/nez'
    preprocessor << 'REWAMP_WITH_NEZ=1'   # registry gate (rewamp_registry.c, pod-wide)
    header_dirs  << nez_root
    header_dirs  << "#{nez_root}/format"
    header_dirs  << "#{nez_root}/device"
    header_dirs  << "#{nez_root}/device/nes"
    header_dirs  << "#{nez_root}/device/opl"
    header_dirs  << "#{nez_root}/cpu"
    header_dirs  << "#{nez_root}/cpu/wkmz80"
    header_dirs  << "#{nez_root}/cpu/km6502"

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/nez_cores"
      REL="../../../third_party/nez"
      SRCLIST="$(pwd)/../third_party/nez/nez_sources.cmake"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      # One wrapper .c per curated source (path flattened → unique name). The cores'
      # own relative includes (incl. ../../../src/ModizerVoicesData.h) resolve from
      # each real file's location, so no per-file scoping is needed.
      grep -oE '\$\{NEZ_ROOT\}/[^"]+\.c' "$SRCLIST" | sed 's#^\${NEZ_ROOT}/##' | while read rel; do
        flat=$(printf '%s' "$rel" | tr '/.' '__')
        printf '#include "%s/%s"\n' "$REL" "$rel" > "$WRAP/${flat}.c"
      done
      # plugin glue (C++).
      printf '#include "../../../src/rewamp_plugin_nez.cpp"\n' > "$WRAP/zz_rewamp_nez_plugin.cpp"
    SH
  end

  # --- libkss: MSX chiptunes (KSS/MGS/BGM/MPK/MBM/OPX/MUS) --------------------
  # Enabled by default; opt out with REWAMP_WITH_KSS=0. Mirrors the cmake
  # rewamp_add_kss(): the curated C set (kss2vgm / CLI tools pruned), each its OWN
  # TU (the emu cores reuse identical static fn names → no unity build). Per-voice
  # scope + notes + mute live in the vendored cores (kssplay.c + emu2149/emu2212/
  # emu2413/emu8950/emu76489 fill m_voice_buff[] via m_voicesForceOfs, honor
  # generic_mute_mask — grep YOYOFR). Include dirs are scoped per-file to
  # Classes/kss_cores/* in the app Podfiles' post_install (NOT pod-wide): libkss's
  # src/ has generic header names (kss.h/vm.h/filter.h/detect.h/mmap.h) that would
  # shadow other plugins. The three emu cores clashing with libgme's own PSG/SCC/
  # OPLL emulators are namespaced kss_* in the vendored sources (see patches/libkss).
  if ENV['REWAMP_WITH_KSS'] != '0'
    preprocessor << 'REWAMP_WITH_KSS=1'   # registry gate (rewamp_registry.c, pod-wide)

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/kss_cores"
      REL="../../../third_party/libkss"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      # One wrapper .c per curated source (path flattened → unique name). Each
      # core's own quote-includes ("kss.h", "emu2149/kss_emu2149.h", "drivers/…",
      # "../../../src/ModizerVoicesData.h") resolve from the real file's location
      # plus the per-file -Isrc/-Imodules scoping in the app Podfile.
      for rel in \
        src/kssplay.c src/filters/dc_filter.c src/filters/filter.c src/filters/rc_filter.c \
        src/kss/kss.c src/kss/kss2kss.c src/kss/kssload.c src/kss/bgm2kss.c src/kss/mbm2kss.c \
        src/kss/mgs2kss.c src/kss/mpk2kss.c src/kss/opx2kss.c \
        src/rconv/psg_rconv.c src/vm/detect.c src/vm/mmap.c src/vm/vm.c \
        modules/emu2149/kss_emu2149.c modules/emu2212/kss_emu2212.c modules/emu2413/kss_emu2413.c \
        modules/emu8950/emu8950.c modules/emu8950/emuadpcm.c modules/emu76489/emu76489.c \
        modules/kmz80/kmdmg.c modules/kmz80/kmevent.c modules/kmz80/kmr800.c \
        modules/kmz80/kmz80.c modules/kmz80/kmz80c.c modules/kmz80/kmz80t.c ; do
        flat=$(printf '%s' "$rel" | tr '/.' '__')
        printf '#include "%s/%s"\n' "$REL" "$rel" > "$WRAP/${flat}.c"
      done
      # plugin glue (C++).
      printf '#include "../../../src/rewamp_plugin_kss.cpp"\n' > "$WRAP/zz_rewamp_kss_plugin.cpp"
    SH
  end

  # --- Monkey's Audio: .ape lossless (MACLib) ---------------------------------
  # Enabled by default; opt out with REWAMP_WITH_MAC=0. Mirrors the cmake
  # rewamp_add_mac(): curated 26-file set from third_party/monkeyaudio/
  # mac_sources.cmake (NOT a glob — Old/ legacy core + Windows dialogs excluded),
  # one wrapper TU per file, MACLIB_COMPILE emitted into each wrapper. The MACLib
  # include dirs are scoped per-file to Classes/mac_cores/* in the app Podfiles'
  # post_install (NOT pod-wide): src/Shared holds generic-named headers
  # (config.h, MD5.h, All.h) that would shadow libarchive's config.h
  # include-order trick for every other TU.
  if ENV['REWAMP_WITH_MAC'] != '0'
    need_cpp_stdlib = true
    preprocessor << 'REWAMP_WITH_MAC=1'   # registry gate (rewamp_registry.c, pod-wide)

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/mac_cores"
      REL="../../../third_party/monkeyaudio/mac-master"
      SRCLIST="$(pwd)/../third_party/monkeyaudio/mac_sources.cmake"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      grep -oE '\$\{MAC_ROOT\}/[^"]+\.cpp' "$SRCLIST" | sed 's#^\${MAC_ROOT}/##' | while read rel; do
        flat=$(printf '%s' "$rel" | tr '/.' '__')
        printf '#define MACLIB_COMPILE 1\n#include "%s/%s"\n' "$REL" "$rel" > "$WRAP/${flat}.cpp"
      done
      # plugin glue (C++, needs the MACLib headers too → lives in mac_cores/).
      printf '#define MACLIB_COMPILE 1\n#include "../../../src/rewamp_plugin_mac.cpp"\n' > "$WRAP/zz_rewamp_mac_plugin.cpp"
    SH
  end




  # --- V2M: Farbrausch V2 synth (.v2m/.v2mz) ----------------------------------
  # Enabled by default; opt out with REWAMP_WITH_V2M=0. Moteur v2redux
  # (spheenik, CC0): portage C++17 VERSION-NATIVE — il joue chaque .v2m avec le
  # moteur de son époque (formats 0..6) au lieu de convertir vers la dernière.
  # 5 TU. zlib pour .v2mz. ⚠️ Contrat de déterminisme: -ffp-contract=off, jamais
  # de fast-math; V2_RONAN=1 sinon la voie 15 des morceaux parlés fuit en bruit.
  if ENV['REWAMP_WITH_V2M'] != '0'
    preprocessor << 'REWAMP_WITH_V2M=1'
    preprocessor << 'V2_RONAN=1'
    preprocessor << 'V2MPLAYER_SYNC_FUNCTIONS=1'
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/v2redux/src'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      # Sous-dossier VIDÉ à chaque fois. Écrire à plat dans Classes/ laissait
      # les wrappers d'un moteur REMPLACÉ traîner et se faire compiler: le
      # passage de v2mplayer à v2redux a cassé le build sur un
      # `rewamp_v2m_v2mplayer.cpp` orphelin qui incluait un fichier disparu.
      WRAP="$CLASSES/v2m_cores"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      rm -f "$CLASSES"/rewamp_v2m_*.cpp        # reliquats d'avant le sous-dossier
      # Contrat de déterminisme du moteur: pas de contraction FMA. Émis DANS le
      # wrapper plutôt qu'en règle par fichier dans les deux Podfiles — le
      # pragma est standard et reste scopé à cette TU.
      for n in v2player v2load v2core v2seq ronan; do
        { printf '#pragma STDC FP_CONTRACT OFF\n'
          printf '#include "../../../third_party/v2redux/src/%s.cpp"\n' "$n"
        } > "$WRAP/rewamp_v2m_$n.cpp"
      done
      printf '#include "../../../src/rewamp_plugin_v2m.cpp"\n' > "$WRAP/rewamp_v2m_plugin_impl.cpp"
    SH
  end

  # --- SNDH: Atari ST chiptunes (.sndh) ----------------------------------------
  # Enabled by default; opt out with REWAMP_WITH_SNDH=0. Vendored AtariAudio
  # (Arnaud Carré) + Musashi 68000 core, one TU per source (8: 5 top-level .cpp
  # + Musashi's m68kcpu.c/m68kops.c, which #include m68kfpu.c/m68kops.h — NOT
  # compiled standalone — + the ICE depacker). Per-voice scope + notes + mute
  # live in the vendored cores (ym2149c.cpp/AtariMachine.cpp — grep YOYOFR).
  if ENV['REWAMP_WITH_SNDH'] != '0'
    preprocessor << 'REWAMP_WITH_SNDH=1'
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/atariaudio'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      for n in AtariMachine Mk68901 SndhFile SteDac ym2149c; do
        printf '#include "../../third_party/atariaudio/%s.cpp"\n' "$n" > "$CLASSES/rewamp_sndh_$n.cpp"
      done
      printf '#include "../../third_party/atariaudio/external/ice_24.c"\n' > "$CLASSES/rewamp_sndh_ice_24.c"
      printf '#include "../../third_party/atariaudio/external/Musashi/m68kcpu.c"\n' > "$CLASSES/rewamp_sndh_m68kcpu.c"
      printf '#include "../../third_party/atariaudio/external/Musashi/m68kops.c"\n' > "$CLASSES/rewamp_sndh_m68kops.c"
      printf '#include "../../src/rewamp_plugin_sndh.cpp"\n' > "$CLASSES/rewamp_sndh_plugin_impl.cpp"
    SH
  end

  # --- PSG play: 2nd Atari ST .sndh engine -------------------------------------
  # Enabled by default; opt out with REWAMP_WITH_PSGPLAY=0. Vendored psgplay
  # (Fredrik Noring, GPL-2.0): whole Atari ST machine — 68000 + cf2149 YM2149 +
  # cf68901 MFP + cf300588 LMC1992 tone/volume mixer, which AtariAudio does not
  # model. Both engines claim .sndh; psgplay probes one point lower, so
  # AtariAudio stays the default and the user's setting pins the other through
  # rewamp_registry_set_preferred_plugin.
  #
  # EVERYTHING is per-file scoped to Classes/psgplay_cores/* in the app
  # Podfiles: this tree carries a THIRD Musashi (AtariAudio has one,
  # highlytheoritical a second), so both its include dirs (m68k/m68k.h,
  # m68k/m68kcpu.h — the very names the other two use) and its m68k_*/m68ki_*
  # renames would break those engines if they went pod-wide. Same reason, same
  # shape as the highlytheoritical block above.
  if ENV['REWAMP_WITH_PSGPLAY'] != '0'
    preprocessor << 'REWAMP_WITH_PSGPLAY=1'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/psgplay_cores"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      SRC="$(pwd)/../third_party/psgplay/lib"
      # The vendored tree is already the curated set that goes into upstream's
      # libpsgplay.a (its tooling and audio-writer TUs were not copied), so
      # every .c under lib/ is meant to be compiled. Flattened names, prefixed:
      # cf2149.c/psg.c/sound.c/string.c are exactly the kind of generic
      # basenames the pod already collides on.
      find "$SRC" -name '*.c' | while read -r f; do
        rel="${f#$SRC/}"
        out="psgplay_$(printf '%s' "$rel" | tr '/' '_')"
        printf '#include "../../../third_party/psgplay/lib/%s"\n' "$rel" > "$WRAP/$out"
      done
      printf '#include "../../../src/rewamp_plugin_psgplay.cpp"\n' > "$WRAP/zz_rewamp_psgplay_plugin.cpp"
    SH
  end

  # --- libLazyusf: Nintendo 64 .usf/.miniusf -----------------------------------
  # Enabled by default; opt out with REWAMP_WITH_LAZYUSF=0. Vendored, curated
  # ~52-file interpreter-only subset of a Mupen64plus-derived R4300+RSP
  # emulator (third_party/lazyusf/ contains ONLY that curated set — nothing
  # extra to filter out, so a `find` loop wraps every .c it finds; no dynarec:
  # matches the upstream Makefile's non-DYNAREC file list + empty_dynarec.c).
  # Per-voice scope + notes + mute live in the vendored cores (up to 32
  # dynamically-assigned voices tracked by RDRAM sample address — N64 has no
  # fixed voice slots — grep YOYOFR in rsp_hle/alist.c, rsp_hle/musyx.c,
  # usf/usf.c, ai/ai_controller.c). RSP LLE vector-unit code auto-picks NEON
  # via the compiler's __ARM_NEON define; no explicit SSE2 opt on Apple (falls
  # back to a portable scalar path — correctness unaffected either way).
  # libpsflib (USF is PSF-family, magic 0x21) is provided by highlyexp's own
  # wrapper when enabled (default) — same assumption gsf/vio2sf already make.
  if ENV['REWAMP_WITH_LAZYUSF'] != '0'
    preprocessor << 'REWAMP_WITH_LAZYUSF=1'
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/lazyusf'
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party'   # libpsflib/psflib.h
    # zlib (adler32/crc32 utility use in r4300 + libpsflib decompression) is
    # added to `libs` in the end-of-file system-library section below.

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/lazyusf_cores"
      LAZYUSF="$(pwd)/../third_party/lazyusf"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      find "$LAZYUSF" -name "*.c" | while read -r f; do
        rel="${f#$LAZYUSF/}"
        flat=$(printf '%s' "$rel" | tr '/.' '__')
        printf '#include "../../../third_party/lazyusf/%s"\n' "$rel" > "$WRAP/${flat}.c"
      done
      printf '#include "../../../src/rewamp_plugin_lazyusf.cpp"\n' > "$WRAP/zz_rewamp_lazyusf_plugin.cpp"
    SH
  end

  # --- WonderSwan: .wsr rip (beetle-wswan / Mednafen core) ------------------
  # Enabled by default; opt out with REWAMP_WITH_WONDERSWAN=0.
  # third_party/wonderswan is curated (no libretro frontend, no renderer), so
  # wrapping every .c it holds is exact. wswan/ + sound/ are upstream verbatim
  # apart from the capture hooks in sound.c (patches/wonderswan/); the compat
  # headers at the root replace what the frontend used to supply.
  # NO pod-wide header dir: settings.h / state.h / video.h at that root are
  # generic names that already exist in fluidlite, libzxtune and sunvox. All of
  # this core's includes are relative except <boolean.h>/<retro_inline.h>, so
  # the two dirs are scoped per-file to Classes/wonderswan_cores/* in the app
  # Podfiles' post_install — see that block.
  if ENV['REWAMP_WITH_WONDERSWAN'] != '0'
    preprocessor << 'REWAMP_WITH_WONDERSWAN=1'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/wonderswan_cores"
      WS="$(pwd)/../third_party/wonderswan"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      find "$WS" -name "*.c" | while read -r f; do
        rel="${f#$WS/}"
        flat=$(printf '%s' "$rel" | tr '/.' '__')
        printf '#include "../../../third_party/wonderswan/%s"\n' "$rel" > "$WRAP/${flat}.c"
      done
      printf '#include "../../../src/rewamp_plugin_wonderswan.cpp"\n' > "$WRAP/zz_rewamp_wonderswan_plugin.cpp"
    SH
  end

  # --- HighlyQuixotic: Capcom QSound .qsf/.qsflib ------------------------------
  # Enabled by default; opt out with REWAMP_WITH_HIGHLYQUIXOTIC=0. 4-file
  # vendored core (third_party/highlyquixotic: qsound/hq_qsound_ctr/kabuki/z80) —
  # a real Z80 CPU driving the ripped CPS2 program against a QSound DSP.
  # Needs EMU_COMPILE/EMU_LITTLE_ENDIAN/HAVE_STDINT_H (also set pod-wide by
  # the highlyexp block, but added here too in case that one's ever off).
  # ALL of this dir's headers are generic (z80.h/qsound.h/emuconfig.h clash
  # with libzxtune/furnace/highlyexp) — include dir is scoped per-file to
  # Classes/highlyquixotic_cores/* in the app Podfiles' post_install (NOT
  # pod-wide), same as adplug/kss/uade/wonderswan.
  if ENV['REWAMP_WITH_HIGHLYQUIXOTIC'] != '0'
    preprocessor << 'REWAMP_WITH_HIGHLYQUIXOTIC=1'
    preprocessor << 'EMU_COMPILE'
    preprocessor << 'EMU_LITTLE_ENDIAN'
    preprocessor << 'HAVE_STDINT_H'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/highlyquixotic_cores"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      for n in qsound hq_qsound_ctr kabuki z80; do
        printf '#include "../../../third_party/highlyquixotic/%s.c"\n' "$n" > "$WRAP/${n}.c"
      done
      printf '#include "../../../src/rewamp_plugin_highlyquixotic.cpp"\n' > "$WRAP/zz_rewamp_highlyquixotic_plugin.cpp"
    SH
  end

  # --- highlytheoritical: Saturn .ssf (SCSP) / Dreamcast .dsf (AICA) -----------
  # Enabled by default; opt out with REWAMP_WITH_HIGHLYTHEORITICAL=0. 7-file
  # vendored core (third_party/highlytheoritical: sega/satsound/dcsound/arm/
  # yam + m68k/m68kcpu+m68kops) — a real Musashi-derived 68000 (Saturn) or
  # ARM7 (Dreamcast) CPU driving the ripped sound-driver program. USE_M68K
  # selects the only 68000 core actually vendored here (Starscream/c68k
  # aren't present in Modizer's checkout). EMU_COMPILE/EMU_LITTLE_ENDIAN/
  # HAVE_STDINT_H are safe pod-wide (shared Modizer convention); the
  # m68k_*/m68ki_* symbol renames are NOT — they're scoped per-file to
  # Classes/highlytheoritical_cores/* in the app Podfiles' post_install,
  # because applying them pod-wide would ALSO rename SNDH's calls into ITS
  # OWN separate Musashi vendor copy (third_party/atariaudio/external/
  # Musashi), breaking that engine's link. All of this dir's headers are
  # generic too (z80.h wasn't among them, but m68k.h/m68kcpu.h/arm.h etc are)
  # — scoped alongside the renames, same per-file block.
  if ENV['REWAMP_WITH_HIGHLYTHEORITICAL'] != '0'
    preprocessor << 'REWAMP_WITH_HIGHLYTHEORITICAL=1'
    preprocessor << 'EMU_COMPILE'
    preprocessor << 'EMU_LITTLE_ENDIAN'
    preprocessor << 'HAVE_STDINT_H'
    preprocessor << 'USE_M68K'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/highlytheoritical_cores"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      for n in sega satsound dcsound arm yam; do
        printf '#include "../../../third_party/highlytheoritical/%s.c"\n' "$n" > "$WRAP/${n}.c"
      done
      for n in m68kcpu m68kops; do
        printf '#include "../../../third_party/highlytheoritical/m68k/%s.c"\n' "$n" > "$WRAP/${n}.c"
      done
      printf '#include "../../../src/rewamp_plugin_highlytheoritical.cpp"\n' > "$WRAP/zz_rewamp_highlytheoritical_plugin.cpp"
    SH
  end

  # --- TIATracker: Atari VCS 2600 .ttt -----------------------------------------
  # Enabled by default; opt out with REWAMP_WITH_TIATRACKER=0. Our own JSON
  # parser + replayer (src/tiatracker, transcribed from TIATracker's Apache-2.0
  # 6502 routine — the tracker APPLICATION is GPLv2 and none of it is used) on
  # top of Stella's TIA sound core, vendored at third_party/tiasound with its
  # namespace renamed to TttTia.
  #
  # The wrappers for that core need UNIQUE names: furnace ships the very same
  # Audio.cpp / AudioChannel.cpp, and two wrappers of the same basename in the
  # same pod collide. No header dir is added — every include here is either
  # relative to its own real source file or spelled ../third_party/tiasound/…,
  # which is deliberate for a header called "Audio.h".
  #
  # NOTE the accumulator names differ from the iOS podspec (defines /
  # search_paths there, preprocessor / header_dirs here) — copying a block
  # across without renaming makes `pod install` die on an undefined local
  # variable, and the pod then never regenerates.
  if ENV['REWAMP_WITH_TIATRACKER'] != '0'
    preprocessor << 'REWAMP_WITH_TIATRACKER=1'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/tiatracker_cores"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      for n in Audio AudioChannel; do
        printf '#include "../../../third_party/tiasound/%s.cpp"\n' "$n" > "$WRAP/tiasound_${n}.cpp"
      done
      for n in ttt_song ttt_player; do
        printf '#include "../../../src/tiatracker/%s.cpp"\n' "$n" > "$WRAP/${n}.cpp"
      done
      printf '#include "../../../src/rewamp_plugin_tiatracker.cpp"\n' > "$WRAP/zz_rewamp_tiatracker_plugin.cpp"
    SH
  end

  # --- libpt3: ZX Spectrum .pt3 (ProTracker 3) ---------------------------------
  # Enabled by default; opt out with REWAMP_WITH_LIBPT3=0. pt3player.c
  # (Volutar) + ayumi.c (Peter Sovietov, AY-3-8910/YM2149 synth). No
  # libpsflib dependency, no generic header names (ayumi.h/pt3player.h are
  # unique pod-wide) — no per-file include scoping needed, unlike every
  # other engine in this batch.
  if ENV['REWAMP_WITH_LIBPT3'] != '0'
    preprocessor << 'REWAMP_WITH_LIBPT3=1'
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/libpt3'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/libpt3_cores"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      for n in pt3player ayumi; do
        printf '#include "../../../third_party/libpt3/%s.c"\n' "$n" > "$WRAP/${n}.c"
      done
      printf '#include "../../../src/rewamp_plugin_libpt3.cpp"\n' > "$WRAP/zz_rewamp_libpt3_plugin.cpp"
    SH
  end

  # --- Organya: Cave Story .org -------------------------------------------------
  # Enabled by default; opt out with REWAMP_WITH_ORGANYA=0. Single
  # self-contained file (organya.c, Wothke's webPixel adapter of Pixel's
  # engine) + 34 same-directory .inc drum-sample includes. No header of its
  # own, no include-dir needed at all — simplest wiring in this batch.
  if ENV['REWAMP_WITH_ORGANYA'] != '0'
    preprocessor << 'REWAMP_WITH_ORGANYA=1'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/organya_cores"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      printf '#include "../../../third_party/libpixel/organya/organya.c"\n' > "$WRAP/organya.c"
      printf '#include "../../../src/rewamp_plugin_organya.cpp"\n' > "$WRAP/zz_rewamp_organya_plugin.cpp"
    SH
  end


  # --- ProWizard: packed Amiga modules -> Protracker MOD -----------------------
  # Enabled by default; opt out with REWAMP_WITH_PROWIZARD=0. NOT a decoder
  # plugin: a converter rewamp_load_file() calls as a LAST RESORT when no
  # plugin could open a file. libxmp's MIT prowizard set, vendored verbatim
  # except prowiz.h's three include lines; the same flat directory supplies
  # rewamp's own minimal xmp.h/common.h/format.h/hio.h. Flat on purpose: every
  # include is a same-dir quote-include, so NO include dir is needed -- those
  # header names must never reach another TU's search path.
  if ENV['REWAMP_WITH_PROWIZARD'] != '0'
    preprocessor << 'REWAMP_WITH_PROWIZARD=1'   # gates rewamp_audio.c, pod-wide

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/prowizard_cores"
      SRC="$(pwd)/../third_party/prowizard"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      for f in "$SRC"/*.c; do
        n="$(basename "$f")"
        printf '#include "../../../third_party/prowizard/%s"\n' "$n" > "$WRAP/$n"
      done
    SH
  end

  # --- sc68: Atari ST + Amiga .sc68 (emu68 68k + YM-2149/STE/Paula) ------------
  # Enabled by default; opt out with REWAMP_WITH_SC68=0. Curated 50-file set
  # mirroring modizer.xcodeproj (emu68 line*_68.c / lines/*.c / cc68 / table68
  # + io68 ym_*_table.c are #include-only; dial68 / sc68-libc / unice68 CLI not
  # compiled). All include dirs + defines (HAVE_CONFIG_H pulls the pre-baked
  # tree-root config.h carrying FILE68_Z/USE_REPLAY68 -- see its comments;
  # EMU68_MONOLITIC mandatory; REWAMP_SC68 enables scope plumbing + rewamp
  # mute patches) are scoped per-file to Classes/sc68_cores/* in the app
  # Podfiles (NOT pod-wide -- "config.h" and io68's "default.h" are the most
  # collision-prone names in the pod).
  if ENV['REWAMP_WITH_SC68'] != '0'
    preprocessor << 'REWAMP_WITH_SC68=1'   # registry gate (rewamp_registry.c, pod-wide)

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/sc68_cores"
      REL="../../../third_party/sc68"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      for rel in \
        file68/src/endian68.c file68/src/error68.c file68/src/file68.c \
        file68/src/gzip68.c file68/src/ice68.c file68/src/init68.c \
        file68/src/msg68.c file68/src/option68.c file68/src/registry68.c \
        file68/src/replay68.c file68/src/rsc68.c file68/src/string68.c \
        file68/src/timedb68.c file68/src/uri68.c file68/src/vfs68.c \
        file68/src/vfs68_ao.c file68/src/vfs68_curl.c file68/src/vfs68_fd.c \
        file68/src/vfs68_file.c file68/src/vfs68_mem.c file68/src/vfs68_null.c \
        file68/src/vfs68_z.c \
        libsc68/emu68/emu68.c libsc68/emu68/error68.c libsc68/emu68/getea68.c \
        libsc68/emu68/inst68.c libsc68/emu68/ioplug68.c libsc68/emu68/lines68.c \
        libsc68/emu68/mem68.c \
        libsc68/io68/io68.c libsc68/io68/mfp_io.c libsc68/io68/mfpemul.c \
        libsc68/io68/mw_io.c libsc68/io68/mwemul.c libsc68/io68/paula_io.c \
        libsc68/io68/paulaemul.c libsc68/io68/shifter_io.c libsc68/io68/ym_blep.c \
        libsc68/io68/ym_dump.c libsc68/io68/ym_envel.c libsc68/io68/ym_io.c \
        libsc68/io68/ym_puls.c libsc68/io68/ymemul.c \
        libsc68/src/api68.c libsc68/src/conf68.c libsc68/src/libsc68.c \
        libsc68/src/mixer68.c \
        unice68/unice68_pack.c unice68/unice68_unpack.c unice68/unice68_version.c ; do
        flat=$(printf '%s' "$rel" | tr '/.' '__')
        printf '#include "%s/%s"\n' "$REL" "$rel" > "$WRAP/${flat}.c"
      done
      # plugin glue (C++).
      printf '#include "../../../src/rewamp_plugin_sc68.cpp"\n' > "$WRAP/zz_rewamp_sc68_plugin.cpp"
    SH
  end

  # --- SunVox: .sunvox (Alexander Zolotov's modular synth + tracker) -----------
  # Enabled by default; opt out with REWAMP_WITH_SUNVOX=0. Vendored full source
  # (headless SunDog config). The headless defines live INSIDE each generated
  # wrapper (projectM scheme); include dirs are scoped PER-FILE to
  # Classes/sunvox_cores/* in the app Podfile (NOT pod-wide — SunDog's header
  # names file.h/log.h/main.h/memory.h/sound.h/time.h/net.h/misc.h/video.h are
  # about the most collision-prone in the pod). sound.cpp compiles the CoreAudio
  # backend even in OFFLINE mode → Cocoa/Carbon added to s.frameworks.
  if ENV['REWAMP_WITH_SUNVOX'] != '0'
    need_cpp_stdlib = true
    preprocessor << 'REWAMP_WITH_SUNVOX=1'
    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/sunvox_cores"
      REL="../../../third_party/sunvox"
      SRCLIST="$(pwd)/../third_party/sunvox/sunvox_sources.txt"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      DEFS='#define NOMAIN 1\n#define NOGUI 1\n#define NDEBUG 1\n#define MIN_SAMPLE_RATE 44100\n#define SUNVOX_LIB 1\n#define NOVIDEO 1\n#define NOVCAP 1\n#define NOLIST 1\n#define NOFILEUTILS 1\n#define NOIMAGEFORMATS 1\n#define NOMIDI 1\n#define PS_STYPE_FLOAT32 1\n#define COLOR32BITS 1\n#define NOOGGENC 1\n#define NOFLACENC 1\n'
      while IFS= read -r rel; do
        [ -z "$rel" ] && continue
        flat=$(printf '%s' "$rel" | tr '/.' '__')
        case "$rel" in
          *.c) ext=c ;;
          *)   ext=cpp ;;
        esac
        { printf "$DEFS"; printf '#include "%s/%s"\n' "$REL" "$rel"; } > "$WRAP/${flat}.${ext}"
      done < "$SRCLIST"
      # Apple file backend (ObjC++).
      { printf "$DEFS"; printf '#include "%s/lib_sundog/file/file_apple.mm"\n' "$REL"; } > "$WRAP/lib_sundog_file_file_apple__mm.mm"
      # plugin glue (C++; the source sets SUNVOX_STATIC_LIB itself).
      printf '#include "../../../src/rewamp_plugin_sunvox.cpp"\n' > "$WRAP/zz_rewamp_sunvox_plugin.cpp"
    SH
  end

  # --- PxTone Collage: .ptcop/.pttune (Pixel's own tracker) --------------------
  # Enabled by default; opt out with REWAMP_WITH_PXTONE=0. Pixel's official
  # library (Modizer copy — YOYOFR voice capture in pxtnService_moo/pxtnUnit),
  # sibling of Organya in libpixel/. Headers are pxtn*-prefixed (unique
  # pod-wide) → plain pod-wide include dir, no per-file scoping. The vorbis
  # dir is deliberately NOT vendored (pxINCLUDE_OGGVORBIS off, as Modizer).
  if ENV['REWAMP_WITH_PXTONE'] != '0'
    preprocessor << 'REWAMP_WITH_PXTONE=1'
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/libpixel/pxtone'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/pxtone_cores"
      PXT="$(pwd)/../third_party/libpixel/pxtone"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      for f in "$PXT"/*.cpp; do
        n=$(basename "$f" .cpp)
        printf '#include "../../../third_party/libpixel/pxtone/%s.cpp"\n' "$n" > "$WRAP/${n}.cpp"
      done
      printf '#include "../../../src/rewamp_plugin_pxtone.cpp"\n' > "$WRAP/zz_rewamp_pxtone_plugin.cpp"
    SH
  end

  # --- EUP: FM Towns .eup (+ .fmb/.pmb banks) — eupmini EUPHONY player --------
  # Enabled by default; opt out with REWAMP_WITH_EUP=0. Nuked-OPN2 (YM2612) FM
  # + FM Towns PCM. Its Nuked-OPN2/mame YM2612 symbols clash with libvgm's own
  # Nuked-OPN2 → 56 -D renames (SYM=eup_SYM) + the includes are scoped per-file
  # to Classes/eup_cores/* in the app Podfiles (generic header names:
  # stdtype.h/snddef.h/mamedef.h/opn2.h). The plugin reaches eupplayer.hpp by
  # relative path. 8 TUs; opn2.c/ym3438.c/fmopn.c are C, the rest C++.
  if ENV['REWAMP_WITH_EUP'] != '0'
    preprocessor << 'REWAMP_WITH_EUP=1'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/eup_cores"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      for n in eupplayer eupplayer_townsEmulator sintbl TownsFmEmulator TownsFmEmulator2; do
        printf '#include "../../../third_party/eupmini/eupmini/%s.cpp"\n' "$n" > "$WRAP/${n}.cpp"
      done
      printf '#include "../../../third_party/eupmini/eupmini/opn2.c"\n'     > "$WRAP/opn2.c"
      printf '#include "../../../third_party/eupmini/Nuked-OPN2/ym3438.c"\n' > "$WRAP/ym3438.c"
      printf '#include "../../../third_party/eupmini/mame/fmopn.c"\n'       > "$WRAP/fmopn.c"
      printf '#include "../../../src/rewamp_plugin_eup.cpp"\n' > "$WRAP/zz_rewamp_eup_plugin.cpp"
    SH
  end

  # --- FMP: PC-98 .opi/.ovi/.ozi (98fmplayer FMP driver + libopna) ------------
  # Enabled by default; opt out with REWAMP_WITH_FMP=0. A different PC-98 engine
  # from PMD (different driver, different OPNA impl — no symbol clash), sharing
  # only the YM2608 rhythm ROM via bundlePath. libopna/fmdriver/common have
  # generic header names (opna.h/ppz8.h/fmdriver.h/s98gen.h) -> all include dirs
  # scoped per-file to Classes/fmp_cores/* in the app Podfiles; the plugin glue
  # reaches fmpmini.h by relative path. The x86 sse2 / NEON sinc variants are
  # NOT wrapped (libopna defaults to the portable _c one; sse2 breaks arm64).
  if ENV['REWAMP_WITH_FMP'] != '0'
    preprocessor << 'REWAMP_WITH_FMP=1'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/fmp_cores"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      printf '#include "../../../third_party/fmpmini/fmpmini.c"\n' > "$WRAP/fmpmini.c"
      for n in opna opnaadpcm opnadrum opnafm opnassg opnassg-sinc-c opnatimer s98gen; do
        printf '#include "../../../third_party/fmpmini/libopna/%s.c"\n' "$n" > "$WRAP/libopna_${n}.c"
      done
      for n in fmdriver_common fmdriver_fmp fmdriver_pmd ppz8; do
        printf '#include "../../../third_party/fmpmini/fmdriver/%s.c"\n' "$n" > "$WRAP/fmdriver_${n}.c"
      done
      for n in fmplayer_file fmplayer_work_opna fmplayer_drumrom_unix fmplayer_file_unix; do
        printf '#include "../../../third_party/fmpmini/common/%s.c"\n' "$n" > "$WRAP/common_${n}.c"
      done
      printf '#include "../../../src/rewamp_plugin_fmp.cpp"\n' > "$WRAP/zz_rewamp_fmp_plugin.cpp"
    SH
  end

  # --- MDX: Sharp X68000 .mdx (+ its .pdx sample bank) ------------------------
  # Enabled by default; opt out with REWAMP_WITH_MDX=0. mdxplay = YM2151 FM +
  # the PCM8 sample driver + freeverb (mdx_load enables reverb by default).
  # NOTHING goes pod-wide here: the dir has version.h (nine copies live under
  # third_party/), mdx.h and pcm8.h, and freeverb adds comb.hpp/tuning.h — the
  # include dirs and the seek_needed/decode_pos_ms/PLAYBACK_FREQ renames are
  # scoped per-file to Classes/mdx_cores/* in the app Podfiles. The plugin glue
  # reaches mdx.h by relative path, so it needs no include dir at all.
  if ENV['REWAMP_WITH_MDX'] != '0'
    preprocessor << 'REWAMP_WITH_MDX=1'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/mdx_cores"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      # Only the files modizer.xcodeproj compiles: mdxopl3/mdxmml_opl3 are out
      # (mdx_load forces no_opl3), ioaccess/getopt are CLI-only.
      for n in mdxmain mdxfile mdxmml_ym2151 mdx2151 mdx_ym2151 pcm8 pdxfile; do
        printf '#include "../../../third_party/mdxplay/%s.c"\n' "$n" > "$WRAP/${n}.c"
      done
      for n in allpass comb freeverb revmodel; do
        printf '#include "../../../third_party/mdxplay/freeverb/%s.cpp"\n' "$n" > "$WRAP/fv_${n}.cpp"
      done
      printf '#include "../../../src/rewamp_plugin_mdx.cpp"\n' > "$WRAP/zz_rewamp_mdx_plugin.cpp"
    SH
  end

  # --- PMD: PC-98 .m/.m2/.mz (Professional Music Driver, OPNA) -----------------
  # Enabled by default; opt out with REWAMP_WITH_PMD=0. libpmdmini = C60's
  # PMDWin core + ymfm's OPNA emulation, with Modizer's YOYOFR voice capture.
  # Only src/ (which holds pmdmini.h alone) goes pod-wide: pmdwin/ and ymfm/
  # have generic header names (table.h, util.h, opna.h, ifileio.h,
  # portability_*.h) and are scoped per-file in the app Podfiles, which is also
  # where these TUs get -std=gnu++20 (ymfm needs it; Modizer builds it so).
  if ENV['REWAMP_WITH_PMD'] != '0'
    preprocessor << 'REWAMP_WITH_PMD=1'
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/pmdmini/src'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/pmd_cores"
      PMD="$(pwd)/../third_party/pmdmini/src"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      printf '#include "../../../third_party/pmdmini/src/pmdmini.cpp"\n' > "$WRAP/pmdmini.cpp"
      for d in pmdwin ymfm; do
        for f in "$PMD/$d"/*.cpp; do
          n=$(basename "$f" .cpp)
          printf '#include "../../../third_party/pmdmini/src/%s/%s.cpp"\n' "$d" "$n" > "$WRAP/${d}_${n}.cpp"
        done
      done
      printf '#include "../../../src/rewamp_plugin_pmd.cpp"\n' > "$WRAP/zz_rewamp_pmd_plugin.cpp"
    SH
  end

  # --- MIDI: FluidLite (SF2 SoundFont synth) + tml.h sequencer ----------------
  # Enabled by default; opt out with REWAMP_WITH_MIDI=0. 17-file FluidLite
  # core (SF3 disabled, pre-baked fluid_config.h/version.h), one TU each.
  # --- libgsf: GBA .gsf/.minigsf (VBA emulator, per-voice scope patch) ---------
  # Enabled by default; opt out with REWAMP_WITH_GSF=0. psftag.c/memgzio.c are C
  # (psftag's static truncate() must not be C++-mangled). System zlib.
  if ENV['REWAMP_WITH_GSF'] != '0'
    preprocessor << 'REWAMP_WITH_GSF=1'
    preprocessor << 'LINUX=1'                # VBA tree's non-Windows path
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/gsf'
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/gsf/VBA'
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/gsf/libresample/include'
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/gsf/libresample/src'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      GSF_DIR="$CLASSES/gsf_cores"
      rm -rf "$GSF_DIR"
      mkdir -p "$GSF_DIR"
      printf '#include "../../../third_party/gsf/gsf.cpp"\n'              > "$GSF_DIR/gsf.cpp"
      for n in GBA Globals Sound Util bios snd_interp unzip; do
        printf '#include "../../../third_party/gsf/VBA/%s.cpp"\n' "$n" > "$GSF_DIR/vba_$n.cpp"
      done
      printf '#include "../../../third_party/gsf/VBA/memgzio.c"\n'        > "$GSF_DIR/vba_memgzio.c"
      printf '#include "../../../third_party/gsf/VBA/psftag.c"\n'         > "$GSF_DIR/vba_psftag.c"
      for n in filterkit resample resamplesubs; do
        printf '#include "../../../third_party/gsf/libresample/src/%s.c"\n' "$n" > "$GSF_DIR/lr_$n.c"
      done
      printf '#include "../../src/rewamp_plugin_gsf.cpp"\n' > "$CLASSES/rewamp_gsf_plugin_impl.cpp"
    SH
  end

  # --- vio2sf: Nintendo DS .2sf/.mini2sf (Cog melonDS, interpreter-only) --------
  # Enabled by default; opt out with REWAMP_WITH_VIO2SF=0. JIT_ENABLED is left
  # undefined (no JIT/emitter TUs) so no RWX pages are needed -> iOS-safe. Headers
  # are flattened under include/vio2sf/ so <vio2sf/X> resolves. SPU.cpp carries the
  # per-voice scope+mute capture (gated on REWAMP_WITH_VIO2SF). Each melonDS core
  # is its own TU (shared static fn names). libpsflib is shared with highlyexp.
  if ENV['REWAMP_WITH_VIO2SF'] != '0'
    preprocessor << 'REWAMP_WITH_VIO2SF=1'
    # Only the namespaced include root is pod-wide (exposes <vio2sf/X> — safe).
    # melonDS internally quote-includes generic names ("types.h", "version.h",
    # "Utils.h") that collide with other plugins' headers (gsf/types.h, …), so the
    # flat + source dirs are scoped per-file to Classes/vio2sf_cores/* via -iquote
    # in the app Podfiles' post_install (NOT pod-wide). See that block.
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/vio2sf/include'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      VIO_DIR="$CLASSES/vio2sf_cores"
      rm -rf "$VIO_DIR"
      mkdir -p "$VIO_DIR"
      REL="\
        vio2sf/Platform.cpp
        vio2sf/Platform_AAC.cpp
        vio2sf/melonDS/ARCodeFile.cpp
        vio2sf/melonDS/ARDatabaseDAT.cpp
        vio2sf/melonDS/AREngine.cpp
        vio2sf/melonDS/ARM.cpp
        vio2sf/melonDS/ARMInterpreter.cpp
        vio2sf/melonDS/ARMInterpreter_ALU.cpp
        vio2sf/melonDS/ARMInterpreter_Branch.cpp
        vio2sf/melonDS/ARMInterpreter_LoadStore.cpp
        vio2sf/melonDS/ARM_InstrInfo.cpp
        vio2sf/melonDS/CP15.cpp
        vio2sf/melonDS/CRC32.cpp
        vio2sf/melonDS/DMA.cpp
        vio2sf/melonDS/DMA_Timings.cpp
        vio2sf/melonDS/FATIO.cpp
        vio2sf/melonDS/FATStorage.cpp
        vio2sf/melonDS/FreeBIOS.cpp
        vio2sf/melonDS/GBACart.cpp
        vio2sf/melonDS/GBACartMotionPak.cpp
        vio2sf/melonDS/GPU.cpp
        vio2sf/melonDS/GPU2D.cpp
        vio2sf/melonDS/GPU2D_Soft.cpp
        vio2sf/melonDS/GPU3D.cpp
        vio2sf/melonDS/GPU3D_Soft.cpp
        vio2sf/melonDS/GPU3D_Texcache.cpp
        vio2sf/melonDS/GPU_Soft.cpp
        vio2sf/melonDS/MathUtil.cpp
        vio2sf/melonDS/Mic.cpp
        vio2sf/melonDS/NDS.cpp
        vio2sf/melonDS/NDSCart.cpp
        vio2sf/melonDS/NDSCartR4.cpp
        vio2sf/melonDS/ROMList.cpp
        vio2sf/melonDS/RTC.cpp
        vio2sf/melonDS/SPI.cpp
        vio2sf/melonDS/SPI_Firmware.cpp
        vio2sf/melonDS/SPU.cpp
        vio2sf/melonDS/Savestate.cpp
        vio2sf/melonDS/Utils.cpp
        vio2sf/melonDS/Wifi.cpp
        vio2sf/melonDS/WifiAP.cpp
        vio2sf/melonDS/blip-buf/blip_buf.c
        vio2sf/melonDS/fatfs/ff.c
        vio2sf/melonDS/fatfs/ffsystem.c
        vio2sf/melonDS/fatfs/ffunicode.c
        vio2sf/melonDS/sha1/sha1.c
        vio2sf/melonDS/tiny-AES-c/aes.c
        vio2sf/melonDS/xxhash/xxhash.c"
      echo "$REL" | while IFS= read -r rel; do
        rel=$(echo "$rel" | tr -d '[:space:]')
        [ -z "$rel" ] && continue
        flat=$(echo "$rel" | tr '/' '_')
        printf '#include "../../../third_party/vio2sf/src/%s"\n' "$rel" > "$VIO_DIR/$flat"
      done
      printf '#include "../../src/rewamp_plugin_vio2sf.cpp"\n' > "$CLASSES/rewamp_vio2sf_plugin_impl.cpp"
    SH
  end

  # --- NCSF: Nintendo DS .ncsf/.minincsf (SSEQPlayer — SDAT software synth) -----
  # Enabled by default; opt out with REWAMP_WITH_NCSF=0. Same console as vio2sf
  # but a DIFFERENT engine: an NCSF embeds an SDAT sound archive played by a
  # software synth (no ROM, no CPU emulation). Player.cpp carries the per-voice
  # scope+notes+mute capture. libpsflib is shared with highlyexp/vio2sf/gsf.
  # Headers live under include/SSEQPlayer/ so only <SSEQPlayer/X> resolves — the
  # bare names (common.h, consts.h, Player.h, Track.h, SDAT.h…) are far too
  # generic to expose pod-wide, and the sources quote-include none of them.
  if ENV['REWAMP_WITH_NCSF'] != '0'
    preprocessor << 'REWAMP_WITH_NCSF=1'
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/sseqplayer/include'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      NCSF_DIR="$CLASSES/ncsf_cores"
      rm -rf "$NCSF_DIR"
      mkdir -p "$NCSF_DIR"
      for f in ../third_party/sseqplayer/src/*.cpp; do
        [ -e "$f" ] || continue
        base=$(basename "$f")
        printf '#include "../../../third_party/sseqplayer/src/%s"\n' "$base" > "$NCSF_DIR/$base"
      done
      printf '#include "../../src/rewamp_plugin_ncsf.cpp"\n' > "$CLASSES/rewamp_ncsf_plugin_impl.cpp"
    SH
  end

  # --- SNSF: Super Nintendo .snsf/.minisnsf via snsf9x ------------------------
  # Enabled by default; opt out with REWAMP_WITH_SNSF=0. Unlike NCSF this IS full
  # hardware emulation: a stripped snes9x (65c816 + PPU + DMA + SA-1 + S-DD1)
  # driving blargg's SPC700/S-DSP APU. The 8 scope voices are the S-DSP's real
  # channels; the capture lives in snes9x/apu/SPC_DSP.cpp (grep YOYOFR) and its
  # mute rides the DSP's own stereo_switch, which gates the real mix too.
  # libpsflib is shared with highlyexp/vio2sf/gsf/lazyusf/ncsf (PSF magic 0x23).
  #
  # NOTHING goes on the pod-wide header path: the tree carries convert.h,
  # port.h, memmap.h, apu.h, messages.h and XSFCommon.h — all far too generic.
  # Includes AND the three anti-collision renames are scoped per-file to
  # Classes/snsf_cores/* in the app Podfiles (snsf9x and libgme are BOTH blargg
  # codebases and clash on resampler/Resampler/blargg_vector).
  if ENV['REWAMP_WITH_SNSF'] != '0'
    preprocessor << 'REWAMP_WITH_SNSF=1'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      SNSF_DIR="$CLASSES/snsf_cores"
      rm -rf "$SNSF_DIR"
      mkdir -p "$SNSF_DIR"
      printf '#include "../../../third_party/snsf/snsf_drvimpl.cpp"\n' > "$SNSF_DIR/snsf_drvimpl.cpp"
      for n in cpu cpuexec cpuops dma globals memmap ppu sa1 sdd1; do
        printf '#include "../../../third_party/snsf/snes9x/%s.cpp"\n' "$n" > "$SNSF_DIR/snes9x_$n.cpp"
      done
      for n in apu SNES_SPC SNES_SPC_misc SNES_SPC_state SPC_DSP SPC_Filter; do
        printf '#include "../../../third_party/snsf/snes9x/apu/%s.cpp"\n' "$n" > "$SNSF_DIR/apu_$n.cpp"
      done
      printf '#include "../../src/rewamp_plugin_snsf.cpp"\n' > "$CLASSES/rewamp_snsf_plugin_impl.cpp"
    SH
  end

  # --- AdPlug: AdLib OPL2/OPL3 formats (.d00/.hsc/.cmf/.imf/.rol/.a2m/.dro/…) --
  # Enabled by default; opt out with REWAMP_WITH_ADPLUG=0. Latest upstream AdPlug
  # + vendored libbinio, driven by the DOSBox "woody" OPL3 emu in CSurroundopl.
  # Per-voice scope + notes + mute live in the vendored woodyopl.cpp/surroundopl.cpp
  # (write m_voice_buff[], honor generic_mute_mask). One wrapper TU per source
  # (some players share static fn names → cannot unity-build); .c sources get a .c
  # wrapper so Xcode compiles them AS C (adlibemu/fmopl/unl* rely on C void*→T*).
  # Include dirs + `-Dstricmp=strcasecmp` are scoped per-file to Classes/adplug_cores/*
  # in the app Podfiles' post_install (NOT pod-wide): adplug's src/ holds generic
  # header names (player.h, opl.h, debug.h, version.h, database.h) that would shadow
  # other plugins' headers. Registry gate REWAMP_WITH_ADPLUG stays pod-wide.
  if ENV['REWAMP_WITH_ADPLUG'] != '0'
    preprocessor << 'REWAMP_WITH_ADPLUG=1'   # registry gate (rewamp_registry.c, pod-wide)

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/adplug_cores"
      ADPLUG="$(pwd)/../third_party/adplug"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      # One wrapper per real source (flattened name). .cpp→.cpp, .c→.c (C linkage).
      for f in "$ADPLUG"/src/*.cpp "$ADPLUG"/libbinio/*.cpp; do
        b=$(basename "$f"); sub=$(basename "$(dirname "$f")")
        printf '#include "../../../third_party/adplug/%s/%s"\n' "$sub" "$b" > "$WRAP/${sub}_${b}"
      done
      for f in "$ADPLUG"/src/*.c; do
        b=$(basename "$f")
        printf '#include "../../../third_party/adplug/src/%s"\n' "$b" > "$WRAP/src_${b}"
      done
      # plugin glue (needs adplug/src + libbinio includes → lives in adplug_cores/).
      printf '#include "../../../src/rewamp_plugin_adplug.cpp"\n' > "$WRAP/zz_rewamp_adplug_plugin.cpp"
    SH
  end

  if ENV['REWAMP_WITH_MIDI'] != '0'
    preprocessor << 'REWAMP_WITH_MIDI=1'
    preprocessor << 'FLUIDLITE_STATIC=1'
    preprocessor << 'REWAMP_VOICE_CAPTURE=1'   # per-channel scope hooks in fluid_synth.c
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/fluidlite/include'
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/fluidlite/src'
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/tml'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      FL_DIR="$CLASSES/fluidlite_cores"
      rm -rf "$FL_DIR"
      mkdir -p "$FL_DIR"
      for n in fluid_init fluid_chan fluid_chorus fluid_conv fluid_defsfont \
               fluid_dsp_float fluid_gen fluid_hash fluid_list fluid_mod \
               fluid_ramsfont fluid_rev fluid_settings fluid_synth fluid_sys \
               fluid_tuning fluid_voice; do
        printf '#include "../../../third_party/fluidlite/src/%s.c"\n' "$n" > "$FL_DIR/$n.c"
      done
      printf '#include "../../src/rewamp_plugin_midi.c"\n' > "$CLASSES/rewamp_midi_plugin_impl.c"
    SH
  end

  # --- HivelyTracker: .hvl / .ahx (native replayer, beats UADE on these) ------
  # Enabled by default; opt out with REWAMP_WITH_HVL=0. Single vendored TU
  # (Modizer hvl_replay, inline voice-capture patches).
  if ENV['REWAMP_WITH_HVL'] != '0'
    preprocessor << 'REWAMP_WITH_HVL=1'
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/hivelytracker'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      printf '#include "../../third_party/hivelytracker/hvl_replay.cpp"\n' > "$CLASSES/rewamp_hvl_core.cpp"
      printf '#include "../../src/rewamp_plugin_hvl.cpp"\n' > "$CLASSES/rewamp_hvl_plugin_impl.cpp"
    SH
  end

  # --- ASAP: Atari 8-bit POKEY formats (.sap/.cmc/.rmt/.tmc/…) ----------------
  # Enabled by default; opt out with REWAMP_WITH_ASAP=0. Vendored GENERATED C
  # (third_party/asap/asap.c = upstream release + rewamp patches — see
  # patches/asap/ + scripts/sync_asap.sh). Single TU + plugin.
  if ENV['REWAMP_WITH_ASAP'] != '0'
    preprocessor   << 'REWAMP_WITH_ASAP=1'
    header_dirs  << '$(PODS_TARGET_SRCROOT)/../third_party/asap'

    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      printf '#include "../../third_party/asap/asap.c"\n' > "$CLASSES/rewamp_asap_core.c"
      printf '#include "../../src/rewamp_plugin_asap.c"\n' > "$CLASSES/rewamp_asap_plugin_impl.c"
    SH
  end

  # --- projectM (Milkdrop) visualizer, mode 3 --------------------------------
  # Enabled by default; opt out with REWAMP_WITH_PROJECTM=0. Compiles the curated
  # 105-file set (third_party/projectm/projectm_sources.txt = 101 from the Xcode
  # project + 4 SOIL2, folder-synced there), each its OWN TU (Factory.cpp ×3 dirs;
  # cores reuse static fn names). The projectM-specific defines live in each
  # generated wrapper (avoids escaping <filesystem> through the build system).
  # Renderer (rewamp_projectm_render.cpp) is its own TU with the GLES header.
  # CUSTOMSHAPE_FAST_RENDER (GL_EXT_shader_framebuffer_fetch) is ENABLED: our
  # ANGLE build carries patches/angle/0001-metal-EXT_shader_framebuffer_fetch
  # .patch, which exposes the extension on the Metal backend (Apple GPUs'
  # programmable blending — validated by a fetch-semantics harness).
  # NOTE: projectM's include dirs are scoped PER-FILE to Classes/projectm_cores/*
  # in the app Podfile's post_install (NOT pod-wide) — projectM's src/ and
  # vendor/ carry generic header names (Shader.hpp, Factory.cpp, and a
  # "compiler"/filesystem layer) that would shadow other plugins' headers pod-wide
  # (it broke UADE's newcpu.c: compiler_flush_jsr_stack undeclared). Same scheme
  # as uade/kss/sc68. The defines live inside each generated wrapper.
  if ENV['REWAMP_WITH_PROJECTM'] != '0'
    # Preset-load profiling (off by default — its glGetProgramiv after link is a
    # sync point). REWAMP_PM_PROFILE=1 flutter build … to get the pmprof lines.
    preprocessor << 'REWAMP_PM_PROFILE=1' if ENV['REWAMP_PM_PROFILE'] == '1'
    need_cpp_stdlib = true
    preprocessor << 'REWAMP_WITH_PROJECTM=1'
    prepare_parts << <<-'SH'
      CLASSES="$(pwd)/Classes"
      WRAP="$CLASSES/projectm_cores"
      REL="../../../third_party/projectm"
      SRCLIST="$(pwd)/../third_party/projectm/projectm_sources.txt"
      rm -rf "$WRAP"; mkdir -p "$WRAP"
      DEFS='#define USE_GLES 1\n#define SOIL_GLES2 1\n#define PRJM_F_SIZE 8\n#define PROJECTM_USE_THREADS 1\n#define PROJECTM_FILESYSTEM_NAMESPACE std\n#define PROJECTM_FILESYSTEM_INCLUDE <filesystem>\n'
      while IFS= read -r rel; do
        [ -z "$rel" ] && continue
        flat=$(printf '%s' "$rel" | tr '/.' '__')
        case "$rel" in
          *.c) ext=c ;;
          *)   ext=cpp ;;
        esac
        { printf "$DEFS"; printf '#include "%s/%s"\n' "$REL" "$rel"; } > "$WRAP/${flat}.${ext}"
      done < "$SRCLIST"
      # Renderer as its own TU (GLES header first).
      {
        printf '#define REWAMP_GL_GLES 1\n'
        printf '#import <GLES3/gl3.h>\n'
        printf '#include "../../../src/rewamp_projectm_render.cpp"\n'
      } > "$WRAP/zz_rewamp_projectm_render.mm"
    SH
  end

  # GPU oscilloscope: shared render + ObjC++ texture/plugin (OpenGL ES 3.0 / ANGLE).
  prepare_parts << <<-'SH'
    CLASSES="$(pwd)/Classes"
    {
      printf '#define REWAMP_GL_GLES 1\n'
      printf '#import <GLES3/gl3.h>\n'
      printf '#include "../../src/rewamp_viz_render.cpp"\n'
      printf '#include "../../src/rewamp_scope_render.cpp"\n'
      printf '#include "../../src/rewamp_notes_render.cpp"\n'
      printf '#include "../../src/rewamp_pattern_render.cpp"\n'
      printf '#include "../../src/rewamp_spectrum_render.cpp"\n'
      printf '#include "../../src/apple/rewamp_viz_texture.h"\n'
      printf '#include "../../src/apple/rewamp_viz_texture.mm"\n'
      printf '#include "../../src/apple/rewamp_viz_plugin.mm"\n'
    } > "$CLASSES/rewamp_viz_impl.mm"
  SH

  unless prepare_parts.empty?
    # prepend set -e so the whole prepare_command exits on first error
    s.prepare_command = "set -e\n" + prepare_parts.join("\n")
  end

  libs = []
  # rewamp_channel_data.c's rewamp_sjis_to_utf8 (Shift-JIS tags: PxTone, MDX, …)
  # uses iconv unconditionally on Apple, so this can't hang off an engine flag —
  # it used to be added only inside the VGM/GME blocks.
  libs << 'iconv'
  libs << 'c++'   if need_cpp_stdlib
  if ENV['REWAMP_WITH_VGM'] != '0'
    libs << 'iconv'  unless libs.include?('iconv')  # libvgm StrUtils-CPConv_IConv
    libs << 'z'      # libvgm FileLoader/MemoryLoader gzip (.vgz) via zlib
  end
  if ENV['REWAMP_WITH_GME'] != '0'
    libs << 'z'      unless libs.include?('z')       # libgme + libarchive gzip via zlib
    libs << 'iconv'  unless libs.include?('iconv')   # libarchive archive_string.c charset conversion
    libs << 'bz2'                               # libarchive bzip2 (macOS system libbz2)
  end
  if ENV['REWAMP_WITH_GBSPLAY'] != '0'
    libs << 'z'    unless libs.include?('z')   # libgbsplay gzip (.gz GBS) via zlib
  end
  if ENV['REWAMP_WITH_HIGHLYEXP'] != '0'
    libs << 'z'    unless libs.include?('z')   # libpsflib PSF zlib decompression
  end
  if ENV['REWAMP_WITH_LAZYUSF'] != '0'
    libs << 'z'    unless libs.include?('z')   # libpsflib decompression + r4300 adler32/crc32
  end
  s.libraries          = libs          unless libs.empty?
  s.vendored_libraries = vendored_libs unless vendored_libs.empty?
  s.vendored_frameworks = vendored_frameworks unless vendored_frameworks.empty?

  preprocessor << 'GL_SILENCE_DEPRECATION=1'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE'                  => 'YES',
    'HEADER_SEARCH_PATHS'             => header_dirs.join(' '),
    'GCC_PREPROCESSOR_DEFINITIONS'    => preprocessor.join(' '),
    'USE_HEADERMAP'                   => 'NO',
    'CLANG_CXX_LANGUAGE_STANDARD'     => 'c++17',
    'OTHER_LDFLAGS'                   => "$(inherited) #{extra_ldflags.join(' ')}",
  }
end

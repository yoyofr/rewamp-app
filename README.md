<p align="center">
  <img src="app/assets/branding/icon/rewamp_icon_1024.png"
       alt="Rewamp" width="140">
</p>

# Rewamp - Retro Wave Media Player

Rewamp is the successor to Modizer, a demoscene and retrogaming oriented music player that was limited to iOS devices.

It is multiplatform, with a focus on **MacOS/iOS/Android** as primary targets and Linux/Windows as secondary ones. 

Development of Rewamp involves AI usage, mostly as an accelerator to develop the UI part and some of the backend features.
Several playback engines customization are reusing the work I've done previously for Modizer.

## Main features

- **1247 file extensions, 42 decoding engines** — Amiga MOD, C64 SID, NSF, SPC,
  GBS, PSF, VGM, SNDH, ZX Spectrum AY, PC-98, X68000, game streams (Wwise,
  FSB…). Real chip emulation, not renderings: a 6502 runs the NSF driver, a
  68000 runs the Amiga replayers.
- **Subsongs are first-class.** A `.nsf`, `.gbs`, `.sid` or `.sndh` expands
  into its tracks, named with what the file itself carries — NSFe track
  labels, [HVSC](https://www.hvsc.c64.org/)'s STIL, the
  [UADE](https://zakalwe.fi/uade/) song database — rather than numbers.
- **Six visualizers**: stereo oscilloscope, per-voice oscilloscope, spectrum,
  live notation, the tracker's own pattern grid, and
  [Milkdrop](https://www.geisswerks.com/milkdrop/) presets through
  [projectM](https://github.com/projectM-visualizer/projectm).
  All GPU-rendered, and fed with what you are *hearing*.
- **Per-voice control**: mute or solo a single chip channel while it plays, and
  watch each one's waveform and note.
- Queue with shuffle and repeat, playlists, favourites, listening statistics,
  and a library that survives a reinstall.
- **Optional online catalogue** — browse and stream a large preservation
  archive with artwork, demoscene productions and per-subsong lengths. Local
  playback needs no server at all.
- Plays archives (zip/7z/rar/lha) in place, follows an M3U found inside one,
  and takes files dropped on the window or opened from the file manager.
- **18 languages.**

## Current coverage

| Platform | Minimum | Status |
| --- | --- | --- |
| **iOS** | 15.0 | Primary target — beta on TestFlight |
| **Android** | 8.0 (API 26) | Primary target — beta on the Play internal track |
| **macOS** | 13.0 (Ventura) | Primary target — beta as a notarized DMG |
| **Linux** | — | In preparation: it builds and plays, not yet released |
| **Windows** | — | Planned |

Android ships **64-bit only** (`arm64-v8a`, `x86_64`). A 32-bit build links and
runs but silently loses the formats whose codec goes through
[FFmpeg](https://ffmpeg.org/), and only
32-bit-only devices — pre-2018, low end — would ever have received it.

These floors come from what the engine needs, not from taste: API 26 is where
AAudio arrives on Android, and the Apple versions are what the GLES visualizer
stack and the Flutter toolchain require.

## Tech architecture

**[Flutter](https://flutter.dev) for the UI, C/C++ for everything that makes
sound**, joined by FFI.
[miniaudio](https://miniaud.io) drives the output device.

- **A decoder is a plugin.** Each engine exposes one vtable —
  `probe / open / read / seek / length / close` — and the registry picks a
  winner per file by scoring extension *and* header, so a format recognised by
  its magic beats one merely claimed by a generic suffix. The core itself
  knows no formats.
- **Decoding never runs in the audio callback.** A dedicated producer thread,
  in the realtime scheduling band, keeps a ring buffer filled; the callback
  only pops and copies. Audio is immune to UI load by construction rather than
  by politeness.
- **Oscilloscope data is timestamped, not sampled.** Chip cores write
  per-voice samples as a side effect of decoding, keyed by absolute frame; the
  visualizers read at the *consumer* position. That is what keeps the picture
  matching the sound under a two-second look-ahead.
- **Visualizers are native GL** (GLES 3.0) shared across platforms:
  [ANGLE](https://chromium.googlesource.com/angle/angle) over
  Metal on macOS/iOS behind a Flutter
  texture, a `SurfaceView` on Android.
- **The engine is built twice from one source set** —
  [CocoaPods](https://cocoapods.org/) podspecs on Apple,
  [CMake](https://cmake.org/) for Android, Linux and Windows. Keeping the two in step is a
  standing constraint of the project.
- Library, playlists and history live in a local
  [SQLite](https://sqlite.org/) database. The online
  catalogue is a set of HTTPS RPCs, and the app is fully usable without it.

## Building from source

Flutter **3.41 or newer** (Dart 3). Then, per platform:
Xcode for macOS/iOS, the Android SDK +
NDK for Android, and `clang cmake ninja-build pkg-config
libgtk-3-dev libegl1-mesa-dev libgles2-mesa-dev libasound2-dev libsecret-1-dev`
for Linux — plus `libpulse0` at **runtime**, which no `-dev` package pulls in
and miniaudio only `dlopen`s: without it everything compiles, the app starts,
and nothing plays.

### 1. Clone, submodules included

```bash
git clone --recurse-submodules https://github.com/yoyofr/rewamp-app.git
cd rewamp-app
```

Three decoders are git submodules pinned to genuine upstream commits
([libopenmpt](https://lib.openmpt.org/libopenmpt/),
[vgmstream](https://vgmstream.org/),
[libvgm](https://github.com/ValleyBell/libvgm)). If you already cloned
without them:
`git submodule update --init --recursive`.

### 2. Apply the rewamp patches — do not skip this

The submodules point at **unmodified** upstream. Rewamp's changes to them live
in `packages/rewamp_audio/patches/` and are applied as working-tree changes:

```bash
cd packages/rewamp_audio
./scripts/sync_libopenmpt.sh
./scripts/sync_vgmstream.sh
./scripts/sync_libvgm.sh
```

Skipping this compiles fine and misbehaves quietly — no Wwise Vorbis in
vgmstream, XM modules with a broken 16-bit tempo, missing per-voice capture in
libvgm. The other vendored engines are committed already patched; only these
three need the step.

### 3. Bootstrap the platform scaffolding

```bash
./setup.sh          # regenerates the Runner glue, leaves hand-written code alone
```

### 4. Prebuilt libraries

**Apple only.** None of these are committed (they are large binaries), and each
release script checks for them because the failure otherwise surfaces as an
unrelated link error:

```bash
cd packages/rewamp_audio
./scripts/build_angle_macos.sh      # or build_angle_ios.sh — offscreen GLES for the visualizers
./scripts/build_libopenmpt_macos.sh # or _ios.sh
./scripts/build_vgmstream_macos.sh  # or _ios.sh
```

Rebuild the libopenmpt/vgmstream ones after any patch change: a plain
`flutter build` links the previous `.a` and will not see it.

Android and Linux build every decoder from source through CMake — nothing to
prebuild.

### 5. Build and run

```bash
cd app
flutter pub get
cd macos && pod install && cd ..   # Apple only, and AFTER pub get
flutter run -d macos               # or: -d ios, -d android, -d linux, -d windows
```

The manual `pod install` is required on Apple: the Podfile reads the ephemeral
xcconfig that `flutter pub get` generates. `flutter clean` wipes it, so run
`flutter pub get` again before the next `pod install`.

### Pointing at a backend

The catalogue, artwork and account features talk to a server. A build made
here defaults to the project's own instance, `https://api.rewamp.app`, which is
what the published binaries are built against. Point a build at your own server
instead:

```bash
flutter run --dart-define=REWAMP_API_URL=https://your-instance
```

That server is run for the published app, not as a public API: treat it as
something that may rate-limit, change shape or require an authenticated client
without notice. A fork meant for other people should host its own.

Local playback of your own files needs no server at all — the catalogue is
entirely optional.

### Turning engines off

Every decoder is on by default and gated by a flag; set one to `0` to leave it
out:

```bash
REWAMP_WITH_OPENMPT=0 flutter build macos
```

### Known gap

The prebuilt **ffmpeg-kit** slices are not redistributed here. Without them
vgmstream builds without FFmpeg and loses the formats whose codec goes through
it; everything else is unaffected. Drop your own under
`packages/rewamp_audio/third_party/ffmpeg-kit/android-{arm64,x86_64}/ffmpeg/`,
or point CMake at a build with `-DREWAMP_FFMPEG_DIR=…`.

## Licence

Rewamp is **GPL-3.0-or-later**. The app's own code could be more permissive,
but the binary statically links GPL-3 decoders
([ZXTune](https://zxtune.bitbucket.io/),
[sc68](https://sourceforge.net/projects/sc68/),
[vio2sf](https://github.com/losnoco/Cog)), so the whole is GPL-3.

Every bundled engine and library keeps its own licence and authors — see
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md), generated from the same list
the app shows under Settings → About.

Some licences ask for a visible credit; those appear in the app itself:
[SunVox](https://warmplace.ru/soft/sunvox/) (© Alexander Zolotov ·
WarmPlace.ru), the UADE song database (CC BY-NC-SA),
[Milkwave](https://github.com/IkeC/Milkwave)'s transition patterns (BSD-3),
and Jan Mróz's [spectrum shader](https://www.shadertoy.com/view/ttfGzH)
(CC BY 3.0).

[UnRAR](https://www.rarlab.com/license.htm) is included for solid RAR/RSN
archives under its own licence: its source
"may be used in any software to handle RAR archives without limitations free of
charge, but cannot be used to develop RAR (WinRAR) compatible archiver and to
re-create RAR compression algorithm, which is proprietary" — full text in
`packages/rewamp_audio/third_party/unrar/license.txt`.

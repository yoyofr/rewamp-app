#!/usr/bin/env bash
# Run this script once after cloning to bootstrap the Flutter projects.
# Requires flutter to be in PATH.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Creating Flutter app scaffold..."
cd "$SCRIPT_DIR/app"
# Create Flutter project in-place (keeps our lib/ and pubspec.yaml)
flutter create \
  --org com.modizer.rewamp \
  --project-name rewamp \
  --platforms ios,android,linux,windows,macos \
  . 2>&1 | grep -v "^  "

echo ""
echo "==> Creating Flutter FFI plugin scaffold..."
cd "$SCRIPT_DIR/packages"
flutter create \
  --org com.modizer.rewamp \
  --project-name rewamp_audio \
  --template=plugin_ffi \
  --platforms ios,android,linux,windows,macos \
  rewamp_audio_scaffold 2>&1 | grep -v "^  "

# Merge the scaffold's platform glue into our package
# (keeps our src/, lib/, pubspec.yaml and CMakeLists.txt)
echo ""
echo "==> Merging platform glue from scaffold..."
for PLATFORM in android ios linux macos windows; do
  if [ -d "rewamp_audio_scaffold/$PLATFORM" ]; then
    rsync -a --ignore-existing "rewamp_audio_scaffold/$PLATFORM/" "rewamp_audio/$PLATFORM/"
    echo "    merged: $PLATFORM"
  fi
done

rm -rf rewamp_audio_scaffold
echo ""

echo "==> Installing dependencies..."
cd "$SCRIPT_DIR/app"
flutter pub get

echo ""
echo "==> Setting up ios/Libs symlinks..."
mkdir -p "$SCRIPT_DIR/packages/rewamp_audio/ios/Libs"

# libopenmpt xcframework (built by scripts/build_libopenmpt_ios.sh, not committed)
# Nothing to symlink here — the build script writes directly to ios/Libs/.

# ANGLE (OpenGL ES 3.0 -> Metal): the GL visualizers and projectM need it, and
# the podspec links it unconditionally. Not committed (26 MB) — built from
# upstream source by scripts/build_angle_ios.sh, same pinned commit and same
# GL_EXT_shader_framebuffer_fetch patch as the macOS build.
if [ ! -d "$SCRIPT_DIR/packages/rewamp_audio/ios/Libs/angle/ANGLE.xcframework" ]; then
  echo "    MISSING: ios/Libs/angle/ANGLE.xcframework — the iOS build will fail."
  echo "             Build it once (long, needs depot_tools + ~10 GB outside the repo):"
  echo "             packages/rewamp_audio/scripts/build_angle_ios.sh"
else
  echo "    found: ios/Libs/angle/ANGLE.xcframework"
fi

echo ""
echo "==> Setting up macOS Documents symlink..."
if [[ "$(uname)" == "Darwin" ]]; then
  # Replicate what the Mac App Store does automatically:
  # expose the app's sandbox Documents folder as ~/Documents/Rewamp
  BUNDLE_ID="com.modizer.rewamp.rewamp"
  CONTAINER="$HOME/Library/Containers/$BUNDLE_ID/Data/Documents"
  DOCS_LINK="$HOME/Documents/Rewamp"
  mkdir -p "$CONTAINER/online"
  ln -sfn "$CONTAINER" "$DOCS_LINK"
  echo "    ~/Documents/Rewamp -> $CONTAINER"
fi

echo ""
echo "Done! To run the app:"
echo "  cd app && REWAMP_WITH_OPENMPT=1 flutter run"
echo ""
echo "iOS GL visualizers need ANGLE built once:"
echo "  packages/rewamp_audio/scripts/build_angle_ios.sh"

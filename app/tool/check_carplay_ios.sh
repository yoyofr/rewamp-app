#!/usr/bin/env bash
# Type-check the iOS host against the real SDK without building decoder libraries.
# This does not link plugins, run the full app, or replace a simulator/device build.
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_SDK="${FLUTTER_ROOT:-$(python3 -c 'import pathlib, shutil; print(pathlib.Path(shutil.which("flutter")).resolve().parents[1])')}"
FRAMEWORK="$FLUTTER_SDK/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64_x86_64-simulator"
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

cat > "$SCRATCH/Registrant.swift" <<'SWIFT'
import Flutter
final class GeneratedPluginRegistrant {
  static func register(with registry: FlutterPluginRegistry) {}
}
SWIFT

xcrun swiftc -typecheck -target arm64-apple-ios15.0-simulator \
  -sdk "$SDK" -F "$FRAMEWORK" -module-cache-path "$SCRATCH/cache" \
  "$APP_DIR/ios/Runner/AppDelegate.swift" \
  "$APP_DIR/ios/Runner/SceneDelegate.swift" \
  "$APP_DIR/ios/Runner/CarPlaySceneDelegate.swift" \
  "$APP_DIR/ios/Runner/SiriMediaIntentHandler.swift" \
  "$SCRATCH/Registrant.swift"

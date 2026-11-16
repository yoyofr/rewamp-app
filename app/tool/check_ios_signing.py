#!/usr/bin/env python3
"""Check real Xcode entitlement selection without compiling or signing."""

import json
from pathlib import Path
import plistlib
import subprocess


IOS = Path(__file__).resolve().parents[1] / "ios"
CAPABILITIES = ("com.apple.developer.carplay-audio", "com.apple.developer.siri")


def settings(configuration, flag=None):
    command = [
        "xcodebuild", "-project", "Runner.xcodeproj", "-target", "Runner",
        "-configuration", configuration, "-sdk", "iphoneos",
        "-showBuildSettings", "-json",
    ]
    if flag is not None:
        command.append(f"REWAMP_WITH_CARPLAY={flag}")
    result = subprocess.run(command, cwd=IOS, capture_output=True, text=True,
                            check=True, timeout=120)
    return next(row["buildSettings"] for row in json.loads(result.stdout)
                if row["target"] == "Runner")


def check(configuration, flag):
    resolved = settings(configuration, flag)
    enabled = resolved.get("REWAMP_WITH_CARPLAY")
    assert enabled in ("0", "1"), f"{configuration}: invalid flag {enabled!r}"
    if flag is not None:
        assert enabled == flag, f"{configuration}: command-line override lost"
    elif not (IOS / "Flutter/Local.xcconfig").exists():
        assert enabled == "0", f"{configuration}: clean checkout must default off"

    expected = "Runner/CarPlay.entitlements" if enabled == "1" else "Runner/Runner.entitlements"
    selected = resolved.get("CODE_SIGN_ENTITLEMENTS")
    assert selected == expected, f"{configuration}: selected {selected!r}, expected {expected!r}"
    entitlements = plistlib.loads((IOS / selected).read_bytes())
    for capability in CAPABILITIES:
        if enabled == "1":
            assert entitlements.get(capability) is True, f"{configuration}: missing {capability}"
        else:
            assert capability not in entitlements, f"{configuration}: ordinary build requests {capability}"
    for identity in ("application-identifier", "com.apple.developer.team-identifier"):
        assert identity not in entitlements, f"{configuration}: personal signing identity in source"
    print(f"{configuration}, {('default' if flag is None else 'override ' + flag)}: "
          f"CarPlay={enabled}, {selected}", flush=True)


if __name__ == "__main__":
    for configuration in ("Debug", "Profile", "Release"):
        for flag in (None, "0", "1"):
            check(configuration, flag)
    print("All 9 iOS entitlement-selection checks passed.")

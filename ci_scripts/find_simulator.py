#!/usr/bin/env python3
"""
Find an iPhone simulator UDID for xcodebuild on GitHub Actions.

On runners with Xcode 26.x, runtimes are disk images. After
`xcodebuild -downloadPlatform iOS` registers the platform with DVT,
existing devices become reachable by UUID.

Strategy: pick the highest-version available iPhone from simctl list devices.
Prints a single UDID to stdout; exits non-zero on failure.
"""
import json
import subprocess
import sys


def list_available_iphone():
    """Return (version_tuple, name, udid) for the best available iPhone simulator."""
    raw = subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "-j"], text=True)
    data = json.loads(raw)
    candidates = []
    for runtime_key, devs in data.get("devices", {}).items():
        # runtime_key e.g. "com.apple.CoreSimulator.SimRuntime.iOS-26-1"
        key_lower = runtime_key.lower()
        if "ios" not in key_lower:
            continue
        # Extract version digits from key
        ver_part = runtime_key.split(".")[-1]  # e.g. "iOS-26-1"
        digits = [x for x in ver_part.replace("iOS-", "").split("-") if x.isdigit()]
        ver = tuple(int(x) for x in digits) if digits else (0,)
        for d in devs:
            if d.get("isAvailable") and "iPhone" in d.get("name", ""):
                candidates.append((ver, d["name"], d["udid"]))
    if not candidates:
        return None
    return max(candidates)


try:
    result = list_available_iphone()
    if result is None:
        raise SystemExit("No available iPhone simulator found in simctl")
    ver, name, udid = result
    print(f"Selected: {name} (iOS {'.'.join(str(v) for v in ver)}) {udid}",
          file=sys.stderr)
    print(udid)
except SystemExit:
    raise
except Exception as e:
    print(f"Fatal: {e}", file=sys.stderr)
    sys.exit(1)

#!/usr/bin/env python3
"""
Find the best available xcodebuild simulator destination for CI.

Queries xcodebuild -showdestinations (the authoritative source) and picks:
  1. An iOS Simulator with a real UUID (preferred)
  2. A visionOS Simulator "Designed for [iPad,iPhone]" (reliable fallback —
     always pre-registered on Xcode 26 runners even when iOS DVT is broken)

Prints a single UUID to stdout; exits non-zero on failure.
"""
import re
import subprocess
import sys

result = subprocess.run(
    ["xcodebuild",
     "-project", "ScholarsGallery.xcodeproj",
     "-scheme", "ScholarsGallery",
     "-showdestinations"],
    capture_output=True, text=True)
text = result.stdout + result.stderr
print("=== showdestinations output ===", file=sys.stderr)
print(text, file=sys.stderr)

# Strategy 1: iOS Simulator with a real UUID (not the DVT placeholder)
for udid in re.findall(r"platform:iOS Simulator[^}]*?id:([A-F0-9a-f-]{36})", text):
    if len(udid) == 36 and "placeholder" not in udid.lower():
        print(f"iOS Simulator: {udid}", file=sys.stderr)
        print(udid)
        sys.exit(0)

# Strategy 2: visionOS Designed for [iPad,iPhone] — concrete UUID, always registered
for udid in re.findall(
        r"platform:visionOS Simulator[^}]*?Designed for \[iPad,iPhone\][^}]*?id:([A-F0-9a-f-]{36})",
        text):
    if len(udid) == 36:
        print(f"visionOS (Designed for iPad/iPhone): {udid}", file=sys.stderr)
        print(udid)
        sys.exit(0)

print("No usable simulator destination found.", file=sys.stderr)
sys.exit(1)

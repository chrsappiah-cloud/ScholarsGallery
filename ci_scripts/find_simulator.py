#!/usr/bin/env python3
"""
Find the best available xcodebuild simulator destination for CI.

Queries xcodebuild -showdestinations (the authoritative source) and picks:
  1. An iOS Simulator with a real UUID (preferred)
  2. The visionOS Simulator "Designed for [iPad,iPhone]" with the HIGHEST OS
     version (reliable fallback — always pre-registered on Xcode 26 runners).
     Picking the highest OS avoids deployment-target mismatches when the app
     targets iOS/visionOS 26.x.

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

# Parse each destination block { ... }
blocks = re.findall(r'\{[^}]+\}', text, re.DOTALL)

# Strategy 1: iOS Simulator with a real UUID (not the DVT placeholder)
for block in blocks:
    if "platform:iOS Simulator" not in block:
        continue
    m = re.search(r'id:([A-F0-9a-f-]{36})', block)
    if m:
        udid = m.group(1)
        if "placeholder" not in block.lower():
            print(f"iOS Simulator: {udid}", file=sys.stderr)
            print(udid)
            sys.exit(0)

# Strategy 2: visionOS Designed for [iPad,iPhone] — pick highest OS version
# to avoid deployment-target mismatch (visionOS 2.x can't run iOS 26.x targets)
best_udid = None
best_os_key = (-1,)

for block in blocks:
    if "platform:visionOS Simulator" not in block:
        continue
    if "Designed for [iPad,iPhone]" not in block:
        continue
    m_id = re.search(r'id:([A-F0-9a-f-]{36})', block)
    m_os = re.search(r'\bOS:([0-9.]+)', block)
    if not m_id:
        continue
    os_str = m_os.group(1) if m_os else "0"
    try:
        os_key = tuple(int(x) for x in os_str.split('.'))
    except ValueError:
        os_key = (0,)
    if os_key > best_os_key:
        best_os_key = os_key
        best_udid = m_id.group(1)
        best_os_str = os_str

if best_udid:
    print(f"visionOS (Designed for iPad/iPhone), OS:{best_os_str}: {best_udid}", file=sys.stderr)
    print(best_udid)
    sys.exit(0)

print("No usable simulator destination found.", file=sys.stderr)
sys.exit(1)

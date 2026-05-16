#!/usr/bin/env python3
"""
Find the best iOS Simulator UUID for AIFinanceTradingLab Xcode tests (CI).

1. Prefer a concrete UUID from `xcodebuild -showdestinations` (not DVT placeholders).
2. Fall back to `xcrun simctl list devices available -j` — GitHub macOS runners often omit
   real iOS simulators from `-showdestinations` for secondary projects even when runtimes
   are installed (same class of issue as the main app scheme workaround).
"""
import json
import re
import subprocess
import sys
from typing import Optional


def simctl_first_iphone_udid() -> Optional[str]:
    """Return UDID of an available iPhone simulator, preferring newest iOS runtime."""
    try:
        out = subprocess.check_output(
            ["xcrun", "simctl", "list", "devices", "available", "-j"],
            text=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError, OSError):
        return None
    try:
        data = json.loads(out)
    except json.JSONDecodeError:
        return None
    devices = data.get("devices") or {}
    # Newest iOS runtime first (e.g. iOS-26-4 before iOS-18-0)
    runtimes = sorted(
        [k for k in devices if "iOS" in k and "SimRuntime" in k],
        reverse=True,
    )
    for rt in runtimes:
        for d in devices[rt]:
            if not d.get("isAvailable"):
                continue
            name = d.get("name") or ""
            udid = d.get("udid")
            if udid and "iPhone" in name:
                print(f"simctl fallback ({rt} / {name}): {udid}", file=sys.stderr)
                return str(udid)
    return None


result = subprocess.run(
    [
        "xcodebuild",
        "-project",
        "AIFinanceTradingLab/AIFinanceTradingLab.xcodeproj",
        "-scheme",
        "AIFinanceTradingLab",
        "-showdestinations",
    ],
    capture_output=True,
    text=True,
)
text = result.stdout + result.stderr
print("=== AIFinance showdestinations output ===", file=sys.stderr)
print(text, file=sys.stderr)

blocks = re.findall(r"\{[^}]+\}", text, re.DOTALL)

for block in blocks:
    if "platform:iOS Simulator" not in block:
        continue
    m = re.search(r"id:([A-F0-9a-f-]{36})", block)
    if m:
        udid = m.group(1)
        if "placeholder" not in block.lower():
            print(f"iOS Simulator: {udid}", file=sys.stderr)
            print(udid)
            sys.exit(0)

udid = simctl_first_iphone_udid()
if udid:
    print(udid)
    sys.exit(0)

print("No usable iOS Simulator destination found for AIFinanceTradingLab.", file=sys.stderr)
sys.exit(1)

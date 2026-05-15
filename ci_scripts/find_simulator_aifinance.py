#!/usr/bin/env python3
"""
Find the best iOS Simulator UUID for AIFinanceTradingLab Xcode tests (CI).

Same strategy as find_simulator.py but targets the AIFinance project/scheme.
"""
import re
import subprocess
import sys

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

print("No usable iOS Simulator destination found for AIFinanceTradingLab.", file=sys.stderr)
sys.exit(1)

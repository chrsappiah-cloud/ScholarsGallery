#!/usr/bin/env python3
"""
Find or create an iOS simulator compatible with the currently selected Xcode.

Strategy 1: pick the highest-version available iPhone from `simctl list devices`.
Strategy 2: if no device found, find a Ready runtime via `simctl runtime list`
            and create a fresh iPhone device for it.

Prints a single UUID to stdout on success; exits non-zero on failure.
"""
import json
import subprocess
import sys


def find_existing_device():
    devices = json.loads(subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "-j"], text=True))
    candidates = []
    for runtime, devs in devices["devices"].items():
        if "iOS" not in runtime and "iphonesimulator" not in runtime.lower():
            continue
        parts = runtime.split(".")[-1].replace("iOS-", "")
        ver = tuple(int(x) for x in parts.split("-") if x.isdigit())
        for d in devs:
            if d.get("isAvailable") and "iPhone" in d.get("name", ""):
                candidates.append((ver, d["name"], d["udid"]))
    if candidates:
        ver, name, udid = max(candidates)
        print(f"Strategy 1: {name} ({udid})", file=sys.stderr)
        return udid
    return None


def create_from_ready_runtime():
    rt_raw = subprocess.check_output(
        ["xcrun", "simctl", "runtime", "list", "-j"],
        text=True, stderr=subprocess.DEVNULL)
    runtimes = json.loads(rt_raw)
    if isinstance(runtimes, dict):
        runtimes = runtimes.get("runtimes", [])

    ready_id = None
    for rt in runtimes:
        rt_name = rt.get("name", "") or rt.get("platformIdentifier", "")
        state = (rt.get("state") or "").lower()
        if "ios" in rt_name.lower() and state == "ready":
            ready_id = rt.get("identifier") or rt.get("runtimeIdentifier")
            break

    if not ready_id:
        print("Strategy 2: no Ready iOS runtime found", file=sys.stderr)
        return None

    dtypes = json.loads(subprocess.check_output(
        ["xcrun", "simctl", "list", "devicetypes", "-j"], text=True))
    iphone_type = None
    for dt in dtypes.get("devicetypes", []):
        name = dt.get("name", "")
        if "iPhone 16" in name and "Pro" not in name and "Plus" not in name:
            iphone_type = dt["identifier"]
            break
    if not iphone_type:
        for dt in dtypes.get("devicetypes", []):
            if "iPhone" in dt.get("name", ""):
                iphone_type = dt["identifier"]
                break

    if not iphone_type:
        print("Strategy 2: no iPhone device type found", file=sys.stderr)
        return None

    result = subprocess.run(
        ["xcrun", "simctl", "create", "CI-iPhone", iphone_type, ready_id],
        capture_output=True, text=True)
    if result.returncode == 0:
        udid = result.stdout.strip()
        print(f"Strategy 2: created {udid} from {ready_id}", file=sys.stderr)
        return udid
    print(f"Strategy 2 create error: {result.stderr}", file=sys.stderr)
    return None


try:
    udid = find_existing_device()
    if not udid:
        udid = create_from_ready_runtime()
    if not udid:
        raise SystemExit("No iOS simulator could be found or created")
    print(udid)
except SystemExit:
    raise
except Exception as e:
    print(f"Fatal: {e}", file=sys.stderr)
    sys.exit(1)

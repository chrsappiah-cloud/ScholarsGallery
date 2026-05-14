#!/usr/bin/env python3
"""
Create an iOS simulator device from the highest-version Ready iOS 18.x runtime.

Xcode 16.x is selected in CI because it uses traditional CoreSimulator/DVT device
discovery. The runner has iOS 18.6 and 18.5 runtimes (Ready) that are fully
compatible with Xcode 16.x. Pre-existing devices may have stale DVT registration;
creating a fresh device ensures DVT sees it.

Prints a single UUID to stdout on success; exits non-zero on failure.
"""
import json
import subprocess
import sys


def get_ready_ios18_runtimes():
    """Return sorted list of (version_tuple, identifier_string) for Ready iOS 18.x runtimes."""
    try:
        raw = subprocess.check_output(
            ["xcrun", "simctl", "runtime", "list", "-j"],
            text=True, stderr=subprocess.DEVNULL)
        data = json.loads(raw)
        runtimes = data if isinstance(data, list) else data.get("runtimes", [])
        ready = []
        for rt in runtimes:
            name = rt.get("name", "")
            state = (rt.get("state") or "").lower()
            rt_id = (rt.get("identifier") or rt.get("runtimeIdentifier") or "")
            if "ios" not in name.lower() or state != "ready":
                continue
            # Derive identifier string from name if JSON key is missing/wrong
            if not rt_id or rt_id.startswith("{"):
                ios_ver = name.replace("iOS ", "").split(" ")[0].replace(".", "-")
                rt_id = f"com.apple.CoreSimulator.SimRuntime.iOS-{ios_ver}"
            # Only iOS 18.x for Xcode 16 compatibility
            ver_str = name.replace("iOS ", "").split(" ")[0]
            parts = ver_str.split(".")
            try:
                ver = tuple(int(x) for x in parts)
                if ver[0] == 18:
                    ready.append((ver, rt_id, name))
                    print(f"Found Ready iOS 18 runtime: {name} → {rt_id}", file=sys.stderr)
            except (ValueError, IndexError):
                pass
        return sorted(ready, reverse=True)
    except Exception as e:
        print(f"Runtime list failed: {e}", file=sys.stderr)
        return []


def get_iphone_device_type():
    """Return identifier for iPhone 16, iPhone 15, or any iPhone device type."""
    try:
        data = json.loads(subprocess.check_output(
            ["xcrun", "simctl", "list", "devicetypes", "-j"], text=True))
        # Prefer plain iPhone 16, then 15, then any iPhone
        for preference in ["iPhone 16", "iPhone 15", "iPhone SE", "iPhone"]:
            for dt in data.get("devicetypes", []):
                name = dt.get("name", "")
                dt_id = dt.get("identifier", "")
                if (preference in name
                        and "Pro" not in name
                        and "Plus" not in name
                        and "Max" not in name):
                    return dt_id
    except Exception as e:
        print(f"Device type list failed: {e}", file=sys.stderr)
    return None


# Step 1: find a Ready iOS 18.x runtime
runtimes = get_ready_ios18_runtimes()
if not runtimes:
    # Dump full runtime list for diagnostics then fail
    try:
        raw = subprocess.check_output(
            ["xcrun", "simctl", "runtime", "list"], text=True, stderr=subprocess.DEVNULL)
        print(raw, file=sys.stderr)
    except Exception:
        pass
    raise SystemExit("No Ready iOS 18.x runtime found — cannot create compatible simulator")

# Step 2: get an iPhone device type
device_type = get_iphone_device_type()
if not device_type:
    raise SystemExit("No iPhone device type found in simctl")

print(f"Using device type: {device_type}", file=sys.stderr)

# Step 3: create a fresh device from the highest available iOS 18.x runtime
for ver, runtime_id, runtime_name in runtimes:
    print(f"Creating device from {runtime_name} ({runtime_id})…", file=sys.stderr)
    result = subprocess.run(
        ["xcrun", "simctl", "create", "CI-iPhone", device_type, runtime_id],
        capture_output=True, text=True)
    if result.returncode == 0:
        udid = result.stdout.strip()
        print(f"Created: {udid}", file=sys.stderr)
        print(udid)
        sys.exit(0)
    print(f"  create failed: {result.stderr.strip()}", file=sys.stderr)

raise SystemExit("Failed to create a simulator from any Ready iOS 18.x runtime")

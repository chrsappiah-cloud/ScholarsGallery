#!/usr/bin/env bash
set -euo pipefail

# Runs UI tests (XCTest) for the iOS app. Requires Xcode and a matching Simulator.
#
# Parallel test runners often hit Simulator instability (Mach -308, lost connection
# to test runner, mach_msg2_trap noise while waiting). This script forces a single
# worker unless you override IOS_PARALLEL_UI_TESTS=1.
#
# Override destination if needed, e.g.:
#   IOS_TEST_DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro' ./ci_scripts/run_ui_tests.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DEST="${IOS_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17}"

if [[ "$DEST" == *"platform=iOS Simulator"* ]]; then
  SIM_ID=""
  SIM_NAME=""
  SIM_OS=""

  if [[ "$DEST" =~ id=([^,]+) ]]; then
    SIM_ID="${BASH_REMATCH[1]}"
  fi
  if [[ "$DEST" =~ name=([^,]+) ]]; then
    SIM_NAME="${BASH_REMATCH[1]}"
  fi
  if [[ "$DEST" =~ OS=([^,]+) ]]; then
    SIM_OS="${BASH_REMATCH[1]}"
  fi

  if [[ -z "$SIM_ID" && -n "$SIM_NAME" ]]; then
    MATCHED_LINE="$(xcrun simctl list devices available | grep -F "$SIM_NAME" | { [[ -n "$SIM_OS" ]] && grep -F "($SIM_OS)" || cat; } | tail -n 1 || true)"
    if [[ -n "$MATCHED_LINE" ]]; then
      SIM_ID="$(printf '%s\n' "$MATCHED_LINE" | grep -Eo '[A-F0-9-]{36}' | head -n 1 || true)"
    fi
  fi

  if [[ -n "$SIM_ID" ]]; then
    echo "Booting simulator: ${SIM_NAME:-$SIM_ID}${SIM_OS:+ (OS $SIM_OS)}"
    open -a Simulator || true
    xcrun simctl boot "$SIM_ID" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$SIM_ID" -b
  fi
fi

PARALLEL_ARGS=()
if [[ "${IOS_PARALLEL_UI_TESTS:-}" != "1" ]]; then
  PARALLEL_ARGS=(
    -parallel-testing-enabled NO
    -maximum-parallel-testing-workers 1
    -maximum-concurrent-test-simulator-destinations 1
  )
fi

echo "Running UI tests with destination: $DEST"
if [[ "${IOS_PARALLEL_UI_TESTS:-}" == "1" ]]; then
  echo "(IOS_PARALLEL_UI_TESTS=1 — parallel testing left at scheme defaults)"
else
  echo "(Serial test execution — set IOS_PARALLEL_UI_TESTS=1 to allow parallel runners)"
fi

xcodebuild test \
  -project "ScholarsGallery.xcodeproj" \
  -scheme "ScholarsGallery" \
  -configuration Debug \
  -destination "$DEST" \
  -only-testing:ScholarsGalleryUITests \
  "${PARALLEL_ARGS[@]}"

echo "UI tests finished."

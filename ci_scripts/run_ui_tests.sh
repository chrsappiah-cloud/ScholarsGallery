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

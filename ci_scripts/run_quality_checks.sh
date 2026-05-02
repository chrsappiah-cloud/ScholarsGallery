#!/bin/bash
set -euo pipefail

echo "Running package build..."
swift build

echo "Running test suite..."
swift test

if [[ "${RUN_UI_TESTS:-}" == "1" ]]; then
  echo "RUN_UI_TESTS=1 — running iOS UI tests..."
  "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run_ui_tests.sh"
fi

echo "Quality checks passed."

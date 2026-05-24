#!/bin/bash
set -euo pipefail

run_with_safe_bare_repo() {
  GIT_CONFIG_COUNT=1 \
  GIT_CONFIG_KEY_0=safe.bareRepository \
  GIT_CONFIG_VALUE_0=all \
  "$@"
}

echo "Running package build..."
run_with_safe_bare_repo swift build

echo "Running test suite..."
run_with_safe_bare_repo swift test

if [[ "${RUN_UI_TESTS:-}" == "1" ]]; then
  echo "RUN_UI_TESTS=1 — running iOS UI tests..."
  "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run_ui_tests.sh"
fi

echo "Quality checks passed."

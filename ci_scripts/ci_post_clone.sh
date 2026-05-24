#!/bin/zsh
set -euo pipefail

run_with_safe_bare_repo() {
  GIT_CONFIG_COUNT=1 \
  GIT_CONFIG_KEY_0=safe.bareRepository \
  GIT_CONFIG_VALUE_0=all \
  "$@"
}

echo "Resolving Swift packages..."
run_with_safe_bare_repo xcodebuild -resolvePackageDependencies \
  -project "ScholarsGallery.xcodeproj" \
  -scheme "ScholarsGallery"

SIM_JSON=$(xcrun simctl list devices available -j)
SIM_NAME=$(printf '%s' "$SIM_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data['devices'].items():
    if 'iOS' in runtime:
        for d in devices:
            if 'iPhone' in d['name']:
                print(d['name'])
                sys.exit(0)
print('iPhone 17 Pro')
")

echo "Using simulator: $SIM_NAME"

echo "Running Debug build (simulator)..."
run_with_safe_bare_repo xcodebuild build \
  -project "ScholarsGallery.xcodeproj" \
  -scheme "ScholarsGallery" \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,name=$SIM_NAME"

echo "Running Release build (simulator) — catches production-only settings..."
run_with_safe_bare_repo xcodebuild build \
  -project "ScholarsGallery.xcodeproj" \
  -scheme "ScholarsGallery" \
  -configuration Release \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,name=$SIM_NAME"

echo "Post-clone steps completed."

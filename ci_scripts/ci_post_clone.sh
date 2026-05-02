#!/bin/zsh
set -euo pipefail

echo "Resolving Swift packages..."
xcodebuild -resolvePackageDependencies \
  -project "ScholarsGallery.xcodeproj" \
  -scheme "ScholarsGallery"

echo "Running Debug build (simulator)..."
xcodebuild build \
  -project "ScholarsGallery.xcodeproj" \
  -scheme "ScholarsGallery" \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro"

echo "Running Release build (simulator) — catches production-only settings..."
xcodebuild build \
  -project "ScholarsGallery.xcodeproj" \
  -scheme "ScholarsGallery" \
  -configuration Release \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro"

echo "Post-clone steps completed."

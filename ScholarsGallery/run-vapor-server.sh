#!/bin/zsh
# Run from the Xcode app folder: finds the SwiftPM repo root (parent) and starts Vapor.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ ! -f "$ROOT/Package.swift" ]]; then
  echo "Expected Package.swift at: $ROOT/Package.swift" >&2
  exit 1
fi
exec "$ROOT/Scripts/run_local_server.sh"

#!/bin/zsh
# Walk upward from the current directory until Package.swift is found, then start Vapor.
set -euo pipefail
DIR="$(pwd)"
while [[ "$DIR" != "/" ]]; do
  if [[ -f "$DIR/Package.swift" ]]; then
    exec "$DIR/Scripts/run_local_server.sh"
  fi
  DIR="$(dirname "$DIR")"
done
echo "ScholarsGallery: could not find Package.swift above $(pwd)" >&2
exit 1

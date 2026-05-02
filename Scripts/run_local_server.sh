#!/bin/zsh
# From repo root: sync WCS promo assets (if present) and start Vapor.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ROOT/.env"
  set +a
fi

chmod +x Scripts/sync_wcs_promo_assets.sh 2>/dev/null || true
if [[ -d "${WCS_PROMO_SOURCE:-$HOME/Desktop/WCS_Social_Promo_Three_Apps}" ]]; then
  ./Scripts/sync_wcs_promo_assets.sh
else
  echo "Note: WCS promo folder not found; skipping sync (optional)."
fi

PORT="${PORT:-8080}"
BIND_HOST="${BIND_HOST:-127.0.0.1}"
export PORT BIND_HOST
echo "Starting Vapor on http://${BIND_HOST}:${PORT} …"
exec swift run ScholarsGalleryServer

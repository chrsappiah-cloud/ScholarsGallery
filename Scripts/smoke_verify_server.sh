#!/bin/zsh
# Build, start Vapor on a random high port, curl critical routes, exit 0 if healthy.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUILD_PATH="${BUILD_PATH:-.build-isolated}"

swift build --product ScholarsGalleryServer --build-path "$BUILD_PATH"

PORT="${SMOKE_PORT:-$(($RANDOM % 20000 + 20000))}"
export PORT
export BIND_HOST="${SMOKE_BIND:-127.0.0.1}"

swift run --skip-build --build-path "$BUILD_PATH" ScholarsGalleryServer >/tmp/scholarsgallery-smoke.log 2>&1 &
PID=$!

cleanup() {
  kill "$PID" 2>/dev/null || true
  wait "$PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Always curl loopback; BIND_HOST only affects what the server listens on.
BASE="http://127.0.0.1:$PORT"

ok=0
for _ in {1..80}; do
  if curl -sf "$BASE/health" -o /dev/null 2>/dev/null; then
    ok=1
    break
  fi
  sleep 0.35
done
if [[ "$ok" != "1" ]]; then
  echo "Smoke test: /health never became ready on $BASE" >&2
  tail -40 /tmp/scholarsgallery-smoke.log >&2 || true
  exit 1
fi

curl -sfS "$BASE/health" | head -1
curl -sfS "$BASE/api/meta" | grep -q '"persistence"' || {
  echo "Smoke test: /api/meta missing persistence field" >&2
  exit 1
}
curl -sfS "$BASE/api/meta" | grep -q '"catalog"' || {
  echo "Smoke test: /api/meta missing catalog field" >&2
  exit 1
}
curl -sfS "$BASE/api/meta" | grep -q '"checkoutEnabled"' || {
  echo "Smoke test: /api/meta missing checkoutEnabled" >&2
  exit 1
}
curl -sfS "$BASE/api/meta" | grep -q '"generationEnabled"' || {
  echo "Smoke test: /api/meta missing generationEnabled" >&2
  exit 1
}
curl -sfS "$BASE/api/meta" | grep -q '"dolaAssistantEnabled"' || {
  echo "Smoke test: /api/meta missing dolaAssistantEnabled" >&2
  exit 1
}
curl -sfS -X POST "$BASE/api/dola/assist" \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"a quiet cathedral interior at dawn","mood":"dreamlike","intent":"scene"}' \
  | grep -q '"refinedPrompt"' || {
  echo "Smoke test: /api/dola/assist did not return refinedPrompt" >&2
  exit 1
}
curl -sfS "$BASE/api/exhibitions" | grep -q "worlds-written-in-light" || {
  echo "Smoke test: exhibitions JSON missing expected slug" >&2
  exit 1
}
curl -sfS "$BASE/api/exhibitions/worlds-written-in-light/artworks" | grep -q "heroAssetURL" || {
  echo "Smoke test: artworks JSON missing heroAssetURL" >&2
  exit 1
}

echo "Smoke verify OK (port $PORT)."

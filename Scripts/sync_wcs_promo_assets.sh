#!/bin/zsh
# Copies WCS social promo PNGs from your Desktop folder into the Vapor static
# directory so GET /media/wcs-social-promo/*.png serves them to the iOS app.
set -euo pipefail

SRC="${WCS_PROMO_SOURCE:-$HOME/Desktop/WCS_Social_Promo_Three_Apps}"
DEST="$(cd "$(dirname "$0")/.." && pwd)/Server/Public/media/wcs-social-promo"

if [[ ! -d "$SRC" ]]; then
  echo "Source folder not found: $SRC" >&2
  echo "Set WCS_PROMO_SOURCE to the folder that contains promo_*_1080.png" >&2
  exit 1
fi

mkdir -p "$DEST"
for f in promo_ethereal_veil_1080.png promo_explore_wcs_1080.png promo_three_apps_suite_1080.png promo_wcs_platform_1080.png; do
  if [[ ! -f "$SRC/$f" ]]; then
    echo "Missing file: $SRC/$f" >&2
    exit 1
  fi
  cp "$SRC/$f" "$DEST/$f"
  echo "Installed $f ($(wc -c < "$DEST/$f" | tr -d ' ') bytes)"
done
echo "Done. Restart ScholarsGalleryServer, then open the exhibition Works tab."

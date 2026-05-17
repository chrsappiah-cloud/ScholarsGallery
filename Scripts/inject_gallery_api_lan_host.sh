#!/bin/zsh
# After each device build, stamp the Mac LAN IP into Info.plist for physical-device Debug runs.
set -euo pipefail

PLIST="${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}/Info.plist"
if [[ "${PLATFORM_NAME:-}" != "iphoneos" ]] || [[ ! -f "$PLIST" ]]; then
  exit 0
fi

LAN_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)
if [[ -z "$LAN_IP" ]]; then
  exit 0
fi

/usr/libexec/PlistBuddy -c "Set :GALLERY_API_LAN_HOST ${LAN_IP}" "$PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :GALLERY_API_LAN_HOST string ${LAN_IP}" "$PLIST"
echo "Injected GALLERY_API_LAN_HOST=${LAN_IP}"

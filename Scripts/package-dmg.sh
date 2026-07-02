#!/usr/bin/env bash
#
# package-dmg.sh — Create a drag-to-Applications DMG from GW2onMac.app
#
# Usage:
#   ./Scripts/package-dmg.sh path/to/GW2onMac.app [output.dmg]
#
set -euo pipefail

APP_PATH="${1:?Usage: $0 path/to/GW2onMac.app [output.dmg]}"
DMG_PATH="${2:-GW2onMac.dmg}"

[[ -d "$APP_PATH" ]] || { echo "error: app bundle not found: $APP_PATH" >&2; exit 1; }

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "GW2onMac" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Created $DMG_PATH"

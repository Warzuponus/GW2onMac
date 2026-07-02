#!/usr/bin/env bash
#
# gw2-winetricks.sh — Install GW2-required fonts into the GW2onMac prefix.
#
# Usage (after bottle exists):
#   ./Scripts/gw2-winetricks.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=resolve-bundle-id.sh
source "$ROOT/Scripts/resolve-bundle-id.sh"
BUNDLE_ID="$(resolve_bundle_id)"
PREFIX="${WINEPREFIX:-$HOME/Library/Containers/$BUNDLE_ID/GW2}"
LIB="$HOME/Library/Application Support/$BUNDLE_ID/Libraries"
WINE_BIN="$LIB/Wine/bin"
TOOLS="$LIB/tools"

export WINEPREFIX="$PREFIX"
export WINEARCH=win64
export WINEDEBUG=-all
export FREETYPE_PROPERTIES="truetype:interpreter-version=35"
export DYLD_LIBRARY_PATH="$LIB/Wine/lib/native${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
export WINE="$WINE_BIN/wine64"
export PATH="$TOOLS:/usr/local/bin:/opt/homebrew/bin:$WINE_BIN:$PATH"

[[ -d "$PREFIX" ]] || { echo "GW2 prefix not found at $PREFIX"; exit 1; }

WINETRICKS="$LIB/winetricks"
[[ -x "$WINETRICKS" ]] || WINETRICKS="$ROOT/Scripts/winetricks"
[[ -x "$WINETRICKS" ]] || WINETRICKS="/Applications/GW2onMac.app/Contents/Resources/winetricks"
[[ -x "$WINETRICKS" ]] || { echo "winetricks not found; update GW2onMac to v0.1.8+."; exit 1; }

CABEXTRACT="$TOOLS/cabextract"
[[ -x "$CABEXTRACT" ]] || CABEXTRACT="/Applications/GW2onMac.app/Contents/Resources/cabextract"
[[ -x "$CABEXTRACT" ]] || CABEXTRACT="$(command -v cabextract || true)"
[[ -x "$CABEXTRACT" ]] || { echo "cabextract not found; update GW2onMac to v0.1.8+ or run: brew install cabextract"; exit 1; }

mkdir -p "$TOOLS"
if [[ "$CABEXTRACT" != "$TOOLS/cabextract" ]]; then
  cp "$CABEXTRACT" "$TOOLS/cabextract"
  chmod +x "$TOOLS/cabextract"
fi

for verb in corefonts tahoma; do
  arch -x86_64 /bin/bash "$WINETRICKS" -q "$verb"
done

echo "GW2 font dependencies installed."

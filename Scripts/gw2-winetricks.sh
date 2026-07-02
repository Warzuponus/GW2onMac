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
LIB="$HOME/Library/Application Support/$BUNDLE_ID/Libraries/Wine/bin"

export WINEPREFIX="$PREFIX"
export WINEARCH=win64
export PATH="$LIB:$PATH"

[[ -x "$LIB/winetricks" ]] || { echo "winetricks not found in runtime; install fonts manually."; exit 1; }
[[ -d "$PREFIX" ]] || { echo "GW2 prefix not found at $PREFIX"; exit 1; }

"$LIB/winetricks" -q fonts corefonts fonts tahoma
echo "GW2 font dependencies installed."

#!/usr/bin/env bash
#
# apply-gw2-performance.sh — Apply GW2onMac performance tuning to an existing GW2 prefix.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=resolve-bundle-id.sh
source "$ROOT/Scripts/resolve-bundle-id.sh"
BUNDLE_ID="$(resolve_bundle_id)"
PREFIX="${WINEPREFIX:-$HOME/Library/Containers/$BUNDLE_ID/GW2}"
LIB="$HOME/Library/Application Support/$BUNDLE_ID/Libraries/Wine"
WINE="$LIB/bin/wine64"
METADATA="$PREFIX/Metadata.plist"

export WINEPREFIX="$PREFIX"
export WINEARCH=win64
export WINEDEBUG=-all
export WINEMSYNC=1
export WINEESYNC=1
export PATH="$LIB/bin:$PATH"

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ -x "$WINE" ]] || die "Wine runtime not installed."
[[ -f "$PREFIX/system.reg" ]] || die "GW2 prefix not found at $PREFIX"

"$ROOT/Scripts/bundle-native-dylibs.sh" "$LIB" >/dev/null 2>&1 || true
export DYLD_LIBRARY_PATH="$LIB/lib/native:/usr/local/lib:/usr/local/opt/libpng/lib"

wine() { arch -x86_64 env DYLD_LIBRARY_PATH="$DYLD_LIBRARY_PATH" "$WINE" "$@"; }

log "Disabling RetinaMode (avoid 2x internal render resolution)"
wine reg add 'HKCU\Software\Wine\Mac Driver' /v RetinaMode /t REG_SZ /d n /f >/dev/null

if [[ -f "$METADATA" ]]; then
  log "Enabling ROSETTA_ADVERTISE_AVX in Metadata.plist"
  /usr/libexec/PlistBuddy -c "Set :wineConfig:avxEnabled true" "$METADATA" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :wineConfig:avxEnabled bool true" "$METADATA"
fi

log "Performance tuning applied."
log "  RetinaMode=n"
log "  avxEnabled=true (ROSETTA_ADVERTISE_AVX=1 at launch)"
log "  WINEMSYNC=1 WINEESYNC=1 (set by GW2onMac when launching)"

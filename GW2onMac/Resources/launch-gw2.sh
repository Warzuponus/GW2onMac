#!/usr/bin/env bash
#
# launch-gw2.sh — Launch Guild Wars 2 (original TyriaSilicon dev scripts).
#
# Does NOT set CrossOver CX_* env vars. GPTK libraries in Wine/lib/external/
# are picked up from disk. This matches the known-good local workflow.
#
# From repo:  ./Scripts/launch-gw2.sh
# From app:   bundled in GW2onMac.app/Contents/Resources/
#
# Env (optional):
#   GW2ONMAC_BUNDLE_ID — force Application Support bundle id
#   WINEPREFIX         — override prefix path
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/resolve-bundle-id.sh" ]]; then
  # shellcheck source=resolve-bundle-id.sh
  source "$SCRIPT_DIR/resolve-bundle-id.sh"
  BUNDLE_NATIVE="$SCRIPT_DIR/bundle-native-dylibs.sh"
elif [[ -f "$SCRIPT_DIR/../Scripts/resolve-bundle-id.sh" ]]; then
  ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  # shellcheck source=resolve-bundle-id.sh
  source "$ROOT/Scripts/resolve-bundle-id.sh"
  BUNDLE_NATIVE="$ROOT/Scripts/bundle-native-dylibs.sh"
else
  ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  # shellcheck source=Scripts/resolve-bundle-id.sh
  source "$ROOT/Scripts/resolve-bundle-id.sh"
  BUNDLE_NATIVE="$ROOT/Scripts/bundle-native-dylibs.sh"
fi

BUNDLE_ID="$(resolve_bundle_id)"
PREFIX="${WINEPREFIX:-$HOME/Library/Containers/$BUNDLE_ID/GW2}"
LIB="$HOME/Library/Application Support/$BUNDLE_ID/Libraries/Wine"
WINE="$LIB/bin/wine64"
GW2="$PREFIX/drive_c/Program Files/Guild Wars 2/Gw2-64.exe"
ARGS="${*:-}"

export WINEPREFIX="$PREFIX"
export WINEARCH=win64
export WINEDEBUG=-all
export WINEMSYNC=1
export WINEESYNC=1
export ROSETTA_ADVERTISE_AVX=1
export PATH="$LIB/bin:$PATH"

if [[ -x "$BUNDLE_NATIVE" ]]; then
  "$BUNDLE_NATIVE" "$LIB" >/dev/null 2>&1 || true
fi
export DYLD_LIBRARY_PATH="$LIB/lib/native:/usr/local/lib:/usr/local/opt/libpng/lib"

[[ -x "$WINE" ]] || { echo "Wine runtime not installed at $WINE" >&2; exit 1; }
[[ -f "$GW2" ]] || { echo "Gw2-64.exe not found at $GW2" >&2; exit 1; }

wine() {
  arch -x86_64 env -i \
    HOME="${HOME:?}" \
    USER="${USER:-$(id -un)}" \
    TMPDIR="${TMPDIR:-/tmp}" \
    WINEPREFIX="$WINEPREFIX" \
    WINEARCH=win64 \
    WINEDEBUG=-all \
    WINEMSYNC=1 \
    WINEESYNC=1 \
    ROSETTA_ADVERTISE_AVX=1 \
    PATH="$PATH" \
    DYLD_LIBRARY_PATH="$DYLD_LIBRARY_PATH" \
    "$WINE" "$@"
}

echo "Launching GW2 (bundle=$BUNDLE_ID)"
if [[ -n "$ARGS" ]]; then
  wine start /unix "$GW2" $ARGS
else
  wine start /unix "$GW2"
fi

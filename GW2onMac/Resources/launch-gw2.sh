#!/usr/bin/env bash
#
# launch-gw2.sh — Launch Guild Wars 2 the same way as original TyriaSilicon dev scripts.
#
# Does NOT set CrossOver CX_* env vars (those break the CEF login UI). GPTK libraries
# in Wine/lib/external are picked up from disk. For in-game DirectX 11 after login,
# set GW2ONMAC_D3DMETAL=1 or use the in-app toggle.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=resolve-bundle-id.sh
source "$ROOT/Scripts/resolve-bundle-id.sh"
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

"$ROOT/Scripts/bundle-native-dylibs.sh" "$LIB" >/dev/null 2>&1 || true
export DYLD_LIBRARY_PATH="$LIB/lib/native:/usr/local/lib:/usr/local/opt/libpng/lib"

if [[ "${GW2ONMAC_D3DMETAL:-0}" == "1" ]]; then
  export CX_ACTIVE_GRAPHICS_BACKEND=d3dmetal
  export CX_APPLEGPTK_LIBD3DSHARED_PATH="$LIB/lib/external/libd3dshared.dylib"
fi

[[ -x "$WINE" ]] || { echo "Wine runtime not installed." >&2; exit 1; }
[[ -f "$GW2" ]] || { echo "Gw2-64.exe not found at $GW2" >&2; exit 1; }

wine() { arch -x86_64 env DYLD_LIBRARY_PATH="$DYLD_LIBRARY_PATH" "$WINE" "$@"; }

echo "Launching GW2 (D3DMetal env: ${GW2ONMAC_D3DMETAL:-0})"
if [[ -n "$ARGS" ]]; then
  wine start /unix "$GW2" $ARGS
else
  wine start /unix "$GW2"
fi

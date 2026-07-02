#!/usr/bin/env bash
#
# launch-gw2.sh — Launch Guild Wars 2 (TyriaSilicon / GW2onMac).
#
# From repo:  ./Scripts/launch-gw2.sh
# From app:   bundled in GW2onMac.app/Contents/Resources/
#
# Env (optional):
#   GW2ONMAC_BUNDLE_ID   — force Application Support bundle id
#   WINEPREFIX           — override prefix path
#   GW2ONMAC_LIBD3DSHARED=1 — set CX_APPLEGPTK_LIBD3DSHARED_PATH (in-game DX11; app sets this)
#   GW2ONMAC_D3DMETAL=1  — also force CX_ACTIVE_GRAPHICS_BACKEND (breaks CEF login UI)
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
LIBD3D="$LIB/lib/external/libd3dshared.dylib"
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

if [[ -f "$LIBD3D" ]]; then
  if [[ "${GW2ONMAC_D3DMETAL:-0}" == "1" || "${GW2ONMAC_LIBD3DSHARED:-0}" == "1" ]]; then
    export CX_APPLEGPTK_LIBD3DSHARED_PATH="$LIBD3D"
  fi
fi
if [[ "${GW2ONMAC_D3DMETAL:-0}" == "1" ]]; then
  export CX_ACTIVE_GRAPHICS_BACKEND=d3dmetal
fi

[[ -x "$WINE" ]] || { echo "Wine runtime not installed at $WINE" >&2; exit 1; }
[[ -f "$GW2" ]] || { echo "Gw2-64.exe not found at $GW2" >&2; exit 1; }
[[ -d "$LIB/lib/external/D3DMetal.framework" ]] || { echo "D3DMetal.framework missing — run Install GPTK." >&2; exit 1; }
[[ -f "$LIBD3D" ]] || { echo "libd3dshared.dylib missing — run Install GPTK." >&2; exit 1; }

wine() { arch -x86_64 env DYLD_LIBRARY_PATH="$DYLD_LIBRARY_PATH" "$WINE" "$@"; }

echo "Launching GW2 (bundle=$BUNDLE_ID libd3dshared=${GW2ONMAC_LIBD3DSHARED:-0} d3dmetal=${GW2ONMAC_D3DMETAL:-0})"
if [[ -n "$ARGS" ]]; then
  wine start /unix "$GW2" $ARGS
else
  wine start /unix "$GW2"
fi

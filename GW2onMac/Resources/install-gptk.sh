#!/usr/bin/env bash
# install-gptk.sh — Standalone GPTK 4.x helper (also bundled in GW2onMac.app/Contents/Resources).
# Discovers Apple's Game Porting Toolkit download, installs Metal Shader Converter,
# and copies D3DMetal.framework into the GW2onMac Wine runtime.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/resolve-bundle-id.sh" ]]; then
  # shellcheck source=resolve-bundle-id.sh
  source "${SCRIPT_DIR}/resolve-bundle-id.sh"
  GW2ONMAC_BUNDLE_ID="$(resolve_bundle_id)"
else
  GW2ONMAC_BUNDLE_ID="${GW2ONMAC_BUNDLE_ID:-com.gw2onmac.app}"
fi

LIB_ROOT="${HOME}/Library/Application Support/${GW2ONMAC_BUNDLE_ID}/Libraries"
DEST="${LIB_ROOT}/Wine/lib/external/D3DMetal.framework"

die() { echo "error: $*" >&2; exit 1; }

[[ -x "${LIB_ROOT}/Wine/bin/wine64" ]] || die "Wine runtime not installed. Download it in GW2onMac first."

GPTK_ROOT=""
EVAL_ROOT=""
MOUNTED=()

cleanup() {
  for (( i=${#MOUNTED[@]}-1; i>=0; i-- )); do
    hdiutil detach "${MOUNTED[$i]}" -quiet 2>/dev/null || true
  done
}
trap cleanup EXIT

mount_dmg() {
  local dmg="$1"
  local mount
  mount="$(hdiutil attach -plist -nobrowse -readonly "$dmg" | plutil -extract 0.mount-point raw -)"
  MOUNTED+=("$mount")
  echo "$mount"
}

find_gptk_source() {
  local vol
  for vol in /Volumes/*; do
    [[ -d "$vol" ]] || continue
    case "$(basename "$vol")" in
      *Game*Porting*Toolkit*|*Evaluation*environment*)
        echo "$vol"
        return 0
        ;;
    esac
  done

  local dmg
  for dmg in "${HOME}/Downloads/"*Game*Porting*Toolkit*.dmg "${HOME}/Downloads/"*game*porting*toolkit*.dmg; do
    [[ -f "$dmg" ]] || continue
    echo "$dmg"
    return 0
  done

  return 1
}

resolve_eval_root() {
  local root="$1"
  if [[ "$(basename "$root")" == *Evaluation*environment* ]]; then
    EVAL_ROOT="$root"
    return 0
  fi

  for vol in /Volumes/*; do
    [[ -d "$vol" ]] || continue
    if [[ "$(basename "$vol")" == *Evaluation*environment* ]]; then
      EVAL_ROOT="$vol"
      return 0
    fi
  done

  local eval_dmg
  eval_dmg="$(find "$root" -maxdepth 1 -iname 'Evaluation*.dmg' -print -quit)"
  [[ -n "$eval_dmg" ]] || die "Evaluation environment .dmg not found in GPTK folder."
  EVAL_ROOT="$(mount_dmg "$eval_dmg")"
}

install_shader_converter() {
  if [[ -x /usr/local/bin/metal-shaderconverter ]]; then
    echo "Metal Shader Converter already installed."
    return 0
  fi

  local pkg
  pkg="$(find "$GPTK_ROOT" -maxdepth 1 -iname 'Metal Shader Converter*.pkg' -print -quit)"
  [[ -n "$pkg" ]] || die "Metal Shader Converter .pkg not found."

  echo "Installing Metal Shader Converter (admin password required)…"
  osascript -e "do shell script \"installer -pkg \\\"$pkg\\\" -target /\" with administrator privileges"
}

copy_d3dmetal() {
  local src
  src="$(find "$EVAL_ROOT" -name 'D3DMetal.framework' -print -quit)"
  [[ -n "$src" ]] || die "D3DMetal.framework not found in evaluation environment."

  mkdir -p "$(dirname "$DEST")"
  rm -rf "$DEST"
  echo "Copying D3DMetal.framework to $DEST"
  cp -R "$src" "$DEST"
}

SOURCE="${1:-}"
if [[ -z "$SOURCE" ]]; then
  SOURCE="$(find_gptk_source)" || die "GPTK not found. Download Game Porting Toolkit 4.x from Apple Developer, open the .dmg, or pass the .dmg path."
fi

if [[ "$SOURCE" == *.dmg ]]; then
  GPTK_ROOT="$(mount_dmg "$SOURCE")"
else
  GPTK_ROOT="$SOURCE"
fi

resolve_eval_root "$GPTK_ROOT"
install_shader_converter
copy_d3dmetal

echo "GPTK install complete. D3DMetal is at: $DEST"

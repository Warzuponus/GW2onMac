#!/usr/bin/env bash
# resolve-bundle-id.sh — Locate the GW2onMac Wine runtime and GW2 prefix.
#
# The runtime (~/Library/Application Support/<id>/Libraries/Wine) and the prefix
# (~/Library/Containers/<id>/GW2) are resolved independently, because an install
# migrated from TyriaSilicon can have them under different bundle IDs.
# Mirrors GW2Kit/Sources/GW2Kit/AppPaths.swift — keep the two in sync.
#
# Overrides:
#   GW2ONMAC_BUNDLE_ID / TYRIA_BUNDLE_ID — force one bundle ID for both
#   GW2ONMAC_WINE_LIB                    — explicit Wine runtime directory
#   WINEPREFIX                           — explicit prefix directory
#
GW2ONMAC_NEW_BUNDLE_ID="com.gw2onmac.app"
GW2ONMAC_LEGACY_BUNDLE_ID="com.tyriasilicon.app"

_forced_bundle_id() {
  if [[ -n "${GW2ONMAC_BUNDLE_ID:-}" ]]; then
    echo "$GW2ONMAC_BUNDLE_ID"
  elif [[ -n "${TYRIA_BUNDLE_ID:-}" ]]; then
    echo "$TYRIA_BUNDLE_ID"
  else
    return 1
  fi
}

# Bundle ID whose Application Support folder holds the Wine runtime.
# New ID if its runtime exists, else legacy if that exists, else new.
resolve_runtime_bundle_id() {
  _forced_bundle_id && return

  local id
  for id in "$GW2ONMAC_NEW_BUNDLE_ID" "$GW2ONMAC_LEGACY_BUNDLE_ID"; do
    if [[ -x "$HOME/Library/Application Support/$id/Libraries/Wine/bin/wine64" ]]; then
      echo "$id"
      return
    fi
  done
  echo "$GW2ONMAC_NEW_BUNDLE_ID"
}

# Bundle ID whose Containers folder holds the GW2 prefix.
# Prefers a prefix with GW2 installed, then any GW2 prefix (new before legacy), else new.
resolve_prefix_bundle_id() {
  _forced_bundle_id && return

  local id
  for id in "$GW2ONMAC_NEW_BUNDLE_ID" "$GW2ONMAC_LEGACY_BUNDLE_ID"; do
    if [[ -f "$HOME/Library/Containers/$id/GW2/drive_c/Program Files/Guild Wars 2/Gw2-64.exe" ]]; then
      echo "$id"
      return
    fi
  done
  for id in "$GW2ONMAC_NEW_BUNDLE_ID" "$GW2ONMAC_LEGACY_BUNDLE_ID"; do
    if [[ -d "$HOME/Library/Containers/$id/GW2" ]]; then
      echo "$id"
      return
    fi
  done
  echo "$GW2ONMAC_NEW_BUNDLE_ID"
}

# Backwards-compatible name: the bundle ID that owns Libraries/ (runtime, winetricks, GPTK).
resolve_bundle_id() {
  resolve_runtime_bundle_id
}

# Libraries/ directory (parent of Wine/, tools/, winetricks).
resolve_libraries_dir() {
  if [[ -n "${GW2ONMAC_WINE_LIB:-}" ]]; then
    dirname "$GW2ONMAC_WINE_LIB"
  else
    echo "$HOME/Library/Application Support/$(resolve_runtime_bundle_id)/Libraries"
  fi
}

# Wine runtime directory (contains bin/wine64).
resolve_wine_lib() {
  echo "${GW2ONMAC_WINE_LIB:-$HOME/Library/Application Support/$(resolve_runtime_bundle_id)/Libraries/Wine}"
}

# GW2 Wine prefix directory.
resolve_gw2_prefix() {
  echo "${WINEPREFIX:-$HOME/Library/Containers/$(resolve_prefix_bundle_id)/GW2}"
}

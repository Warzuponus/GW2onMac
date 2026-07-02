#!/usr/bin/env bash
# resolve-bundle-id.sh — Pick GW2onMac bundle ID (new default, legacy fallback).
#
# Override with GW2ONMAC_BUNDLE_ID or TYRIA_BUNDLE_ID.
#
resolve_bundle_id() {
  if [[ -n "${GW2ONMAC_BUNDLE_ID:-}" ]]; then
    echo "$GW2ONMAC_BUNDLE_ID"
    return
  fi
  if [[ -n "${TYRIA_BUNDLE_ID:-}" ]]; then
    echo "$TYRIA_BUNDLE_ID"
    return
  fi

  local legacy="$HOME/Library/Application Support/com.tyriasilicon.app/Libraries/Wine/bin/wine64"
  local new="$HOME/Library/Application Support/com.gw2onmac.app/Libraries/Wine/bin/wine64"

  if [[ -x "$legacy" ]] && [[ ! -x "$new" ]]; then
    echo "com.tyriasilicon.app"
    return
  fi

  echo "com.gw2onmac.app"
}

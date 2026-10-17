#!/usr/bin/env bash
#
# migrate-legacy-prefix.sh — Move the TyriaSilicon GW2 prefix to the GW2onMac location.
#
#   ~/Library/Containers/com.tyriasilicon.app/GW2  ->  ~/Library/Containers/com.gw2onmac.app/GW2
#
# Optional: launch scripts and the app find either location on their own.
# Dry run by default; pass --apply to move. Uses a single same-volume `mv`
# (instant, no copy). Never copies or deletes game data, and does not touch
# the Wine runtime in Application Support.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=resolve-bundle-id.sh
source "$SCRIPT_DIR/resolve-bundle-id.sh"

APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1

SRC="$HOME/Library/Containers/$GW2ONMAC_LEGACY_BUNDLE_ID/GW2"
DEST_PARENT="$HOME/Library/Containers/$GW2ONMAC_NEW_BUNDLE_ID"
DEST="$DEST_PARENT/GW2"

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ -d "$SRC" ]] || die "No legacy prefix at $SRC — nothing to migrate."
[[ ! -e "$DEST" ]] || die "$DEST already exists — refusing to overwrite. Resolve manually."

# Must be the same volume so mv is a rename, not a copy of the game install.
src_dev="$(stat -f %d "$(dirname "$SRC")")"
dest_dev="$(stat -f %d "$(dirname "$DEST_PARENT")")"
[[ "$src_dev" == "$dest_dev" ]] || die "Source and destination are on different volumes — refusing to copy."

if pgrep -x wineserver >/dev/null 2>&1; then
  die "wineserver is running — quit Guild Wars 2 / Wine first."
fi

log "Will move: $SRC"
log "       to: $DEST"
if [[ "$APPLY" -ne 1 ]]; then
  log "Dry run — re-run with --apply to move."
  exit 0
fi

mkdir -p "$DEST_PARENT"
mv "$SRC" "$DEST"
log "Moved. Prefix now resolves to: $(WINEPREFIX='' resolve_gw2_prefix)"

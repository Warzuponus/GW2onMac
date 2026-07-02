#!/usr/bin/env bash
#
# setup-gw2-prefix.sh — Create the GW2onMac GW2 Wine prefix.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=resolve-bundle-id.sh
source "$ROOT/Scripts/resolve-bundle-id.sh"
BUNDLE_ID="$(resolve_bundle_id)"
PREFIX="${WINEPREFIX:-$HOME/Library/Containers/$BUNDLE_ID/GW2}"
LIB="$HOME/Library/Application Support/$BUNDLE_ID/Libraries/Wine"
WINE="$LIB/bin/wine64"

export WINEPREFIX="$PREFIX"
export WINEARCH=win64
export WINEDEBUG=-all
export WINEMSYNC=1
export WINEESYNC=1
export PATH="$LIB/bin:$PATH"

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

setup_dyld_path() {
  "$ROOT/Scripts/bundle-native-dylibs.sh" "$LIB"
  local native="$LIB/lib/native"
  export DYLD_LIBRARY_PATH="$native:/usr/local/lib:/usr/local/opt/libpng/lib"
}

wine() { arch -x86_64 env DYLD_LIBRARY_PATH="$DYLD_LIBRARY_PATH" "$WINE" "$@"; }

[[ -x "$WINE" ]] || die "Wine runtime not installed. See README step 3."
[[ -d "$LIB/lib/external/D3DMetal.framework" ]] || die "D3DMetal not found in Wine lib/external."
setup_dyld_path

mkdir -p "$PREFIX"

if [[ -f "$PREFIX/system.reg" ]]; then
  log "Prefix exists — finishing wineboot if needed"
  wine wineboot -u
else
  log "Initializing 64-bit prefix at $PREFIX"
  wine wineboot --init
fi

if ! grep -q 'win10' "$PREFIX/system.reg" 2>/dev/null; then
  log "Setting Windows version to Windows 10"
  wine winecfg -v win10
fi

METADATA="$PREFIX/Metadata.plist"
if [[ ! -f "$METADATA" ]]; then
  log "Writing bottle Metadata.plist for GW2onMac"
  cat > "$METADATA" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>dxvkConfig</key>
	<dict>
		<key>dxvk</key>
		<false/>
		<key>dxvkAsync</key>
		<false/>
		<key>dxvkHud</key>
		<string>off</string>
	</dict>
	<key>fileVersion</key>
	<dict>
		<key>build</key>
		<string></string>
		<key>major</key>
		<integer>1</integer>
		<key>minor</key>
		<integer>0</integer>
		<key>patch</key>
		<integer>0</integer>
		<key>preRelease</key>
		<string></string>
	</dict>
	<key>info</key>
	<dict>
		<key>blocklist</key>
		<array/>
		<key>name</key>
		<string>Guild Wars 2</string>
		<key>pins</key>
		<array/>
	</dict>
	<key>metalConfig</key>
	<dict>
		<key>dxrEnabled</key>
		<false/>
		<key>metalHud</key>
		<false/>
		<key>metalTrace</key>
		<false/>
	</dict>
	<key>wineConfig</key>
	<dict>
		<key>avxEnabled</key>
		<true/>
		<key>enhancedSync</key>
		<string>msync</string>
		<key>wineVersion</key>
		<dict>
			<key>build</key>
			<string></string>
			<key>major</key>
			<integer>11</integer>
			<key>minor</key>
			<integer>0</integer>
			<key>patch</key>
			<integer>0</integer>
			<key>preRelease</key>
			<string></string>
		</dict>
		<key>windowsVersion</key>
		<string>win10</string>
	</dict>
</dict>
</plist>
EOF
fi

log "Applying performance tuning (RetinaMode, AVX)"
"$ROOT/Scripts/apply-gw2-performance.sh"

log "Prefix ready."
log "  WINEPREFIX=$PREFIX"
wine --version

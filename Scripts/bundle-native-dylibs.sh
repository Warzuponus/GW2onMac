#!/usr/bin/env bash
#
# bundle-native-dylibs.sh — Bundle x86_64 Homebrew dylibs Wine dlopen()s at runtime.
#
# Wine links against freetype at build time but does not install the dylib.
# Without DYLD_LIBRARY_PATH, wineboot hangs on "FreeType font library".
#
set -euo pipefail

BUNDLE_ID="${TYRIA_BUNDLE_ID:-com.tyriasilicon.app}"
LIB="${1:-$HOME/Library/Application Support/$BUNDLE_ID/Libraries/Wine}"
NATIVE="$LIB/lib/native"

FREETYPE="${FREETYPE:-/usr/local/opt/freetype/lib/libfreetype.6.dylib}"
LIBPNG="${LIBPNG:-/usr/local/opt/libpng/lib/libpng16.16.dylib}"

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ -f "$FREETYPE" ]] || die "Missing $FREETYPE — run ./Scripts/install-x86_64-build-deps.sh"
[[ -f "$LIBPNG" ]] || die "Missing $LIBPNG — run ./Scripts/install-x86_64-build-deps.sh"

mkdir -p "$NATIVE"
log "Bundling native dylibs into $NATIVE"
cp -f "$FREETYPE" "$NATIVE/libfreetype.6.dylib"
cp -f "$LIBPNG" "$NATIVE/libpng16.16.dylib"

install_name_tool -id "@loader_path/libpng16.16.dylib" "$NATIVE/libpng16.16.dylib"
install_name_tool -id "@loader_path/libfreetype.6.dylib" "$NATIVE/libfreetype.6.dylib"
install_name_tool -change "/usr/local/opt/libpng/lib/libpng16.16.dylib" "@loader_path/libpng16.16.dylib" \
  "$NATIVE/libfreetype.6.dylib" 2>/dev/null || true
install_name_tool -change "/usr/local/opt/freetype/lib/libfreetype.6.dylib" "@loader_path/libfreetype.6.dylib" \
  "$NATIVE/libfreetype.6.dylib" 2>/dev/null || true

log "Bundled: libfreetype.6.dylib, libpng16.16.dylib"

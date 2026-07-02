#!/usr/bin/env bash
#
# build-wine-runtime.sh — Build GW2onMac Wine runtime from CrossOver FOSS sources (Wine 11).
#
# Produces:
#   dist/Libraries.tar.gz              — runtime consumed by GW2onMac at setup
#   dist/GW2onMacWineVersion.plist     — version manifest (legacy TyriaWineVersion.plist alias)
#
# Requirements — install with:
#   ./Scripts/install-build-deps.sh
#
# Or manually:
#   brew install pkgconf bison flex mingw-w64 gnutls sdl2 libpng jpeg-turbo freetype
#
# Usage (Apple Silicon):
#   ./Scripts/install-x86_64-build-deps.sh   # once — x86_64 Homebrew at /usr/local
#   ./Scripts/build-wine-runtime.sh
#
# Usage (Intel Mac):
#   ./Scripts/install-build-deps.sh
#   ./Scripts/build-wine-runtime.sh
#
set -euo pipefail

# On Apple Silicon, Wine must be built x86_64 (runs under Rosetta 2). Re-exec under
# Rosetta when still on the native arm64 slice (hw.optional.arm64), not uname -m.
if [[ "$(sysctl -n hw.optional.arm64 2>/dev/null)" == "1" ]] \
  && [[ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" != "1" ]]; then
  exec arch -x86_64 "$0" "$@"
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ROOT="${BUILD_ROOT:-$ROOT/build/wine}"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"
CROSSOVER_VERSION="${CROSSOVER_VERSION:-26.2.0}"
CROSSOVER_TARBALL="crossover-sources-${CROSSOVER_VERSION}.tar.gz"
CROSSOVER_URL="https://media.codeweavers.com/pub/crossover/source/${CROSSOVER_TARBALL}"

LIBRARY_LAYOUT="$BUILD_ROOT/Libraries"
CROSSOVER_SOURCES="$BUILD_ROOT/sources"
WINE_SRC="$CROSSOVER_SOURCES/wine"
WINE_BUILD="$BUILD_ROOT/wine-build"
WINE_PREFIX="$BUILD_ROOT/wine-install"

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

setup_brew_path() {
  local brew=""

  # Under Rosetta on Apple Silicon, use x86_64 Homebrew at /usr/local.
  if [[ -x /usr/local/bin/brew ]]; then
    brew=/usr/local/bin/brew
  elif [[ -x /opt/homebrew/bin/brew ]]; then
    brew=/opt/homebrew/bin/brew
  elif command -v brew >/dev/null 2>&1; then
    brew="$(command -v brew)"
  else
    return 0
  fi

  eval "$("$brew" shellenv)"

  for formula in bison flex pkgconf mingw-w64 freetype gnutls molten-vk; do
    local formula_prefix
    formula_prefix="$("$brew" --prefix "$formula" 2>/dev/null)" || continue
    export PATH="$formula_prefix/bin:$PATH"
    export PKG_CONFIG_PATH="$formula_prefix/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
  done

  export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}:$("$brew" --prefix)/lib/pkgconfig"

  if command -v pkg-config >/dev/null 2>&1; then
    export PKG_CONFIG="${PKG_CONFIG:-$(command -v pkg-config)}"
  fi
}

require_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    return 0
  fi

  die "Missing required command: $1

Install build dependencies first:
  ./Scripts/install-build-deps.sh

Or manually:
  brew install pkgconf bison flex mingw-w64 gnutls sdl2 libpng jpeg-turbo freetype

Then re-run:
  ./Scripts/build-wine-runtime.sh"
}

setup_brew_path

if [[ "$(uname -m)" == "x86_64" ]] && [[ ! -x /usr/local/bin/brew ]] && [[ ! -x /opt/homebrew/bin/brew ]]; then
  die "No Homebrew found. Run ./Scripts/install-x86_64-build-deps.sh (Apple Silicon) or ./Scripts/install-build-deps.sh (Intel)."
fi

if [[ "$(uname -m)" == "x86_64" ]] && [[ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" == "1" ]]; then
  if ! pkg-config --exists freetype2 2>/dev/null; then
    die "x86_64 freetype not found. On Apple Silicon, install x86_64 Homebrew deps first:

  ./Scripts/install-x86_64-build-deps.sh"
  fi
  FREETYPE_LIB="$(pkg-config --variable=libdir freetype2)/libfreetype.dylib"
  if [[ -f "$FREETYPE_LIB" ]] && file "$FREETYPE_LIB" | grep -qv x86_64; then
    die "Found arm64 freetype at $FREETYPE_LIB but Wine needs x86_64 libraries.

  ./Scripts/install-x86_64-build-deps.sh"
  fi
fi

for cmd in curl tar make bison flex clang; do
  require_cmd "$cmd"
done

# Homebrew provides pkg-config via the pkgconf formula.
require_cmd pkg-config

mkdir -p "$BUILD_ROOT" "$DIST_DIR"

CROSSOVER_ARCHIVE="$BUILD_ROOT/$CROSSOVER_TARBALL"
EXPECTED_SIZE="$(curl -sI "$CROSSOVER_URL" | awk 'tolower($1)=="content-length:" {print $2}' | tr -d '\r')"

if [[ -f "$CROSSOVER_ARCHIVE" ]] && [[ -n "$EXPECTED_SIZE" ]]; then
  ACTUAL_SIZE="$(stat -f%z "$CROSSOVER_ARCHIVE" 2>/dev/null || stat -c%s "$CROSSOVER_ARCHIVE")"
  if [[ "$ACTUAL_SIZE" -lt "$EXPECTED_SIZE" ]]; then
    log "Removing incomplete download ($ACTUAL_SIZE / $EXPECTED_SIZE bytes)"
    rm -f "$CROSSOVER_ARCHIVE"
  fi
fi

if [[ ! -f "$CROSSOVER_ARCHIVE" ]]; then
  log "Downloading $CROSSOVER_URL"
  if [[ -n "$EXPECTED_SIZE" ]]; then
    log "Size: $(( EXPECTED_SIZE / 1024 / 1024 )) MB"
  fi
  curl -L --fail --progress-bar -C - -o "$CROSSOVER_ARCHIVE" "$CROSSOVER_URL"
  echo
fi

if [[ ! -d "$WINE_SRC" ]]; then
  log "Extracting CrossOver sources"
  tar -xzf "$CROSSOVER_ARCHIVE" -C "$BUILD_ROOT"
fi

[[ -d "$WINE_SRC" ]] || die "Wine source not found at $WINE_SRC"

export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-14.0}"

log "Configuring Wine (x86_64, WoW64) — this takes several minutes"
rm -rf "$WINE_BUILD"
mkdir -p "$WINE_BUILD"
pushd "$WINE_BUILD" >/dev/null

# Built x86_64; runs under Rosetta 2 on Apple Silicon.
"$WINE_SRC/configure" \
  --prefix="$WINE_PREFIX" \
  --enable-win64 \
  --enable-archs=i386,x86_64 \
  --without-alsa \
  --without-capi \
  --without-dbus \
  --without-krb5 \
  --without-oss \
  --without-pulse \
  --without-sane \
  --without-udev \
  --without-v4l2 \
  --without-wayland \
  --without-x \
  CC="clang" \
  CXX="clang++"

# CrossOver's win32u/vulkan.c always references SONAME_LIBVULKAN even when Vulkan
# libs aren't detected. GW2 uses D3DMetal (GPTK), but we still need this define.
CONFIG_H="$WINE_BUILD/include/config.h"
if ! grep -q '^#define SONAME_LIBVULKAN' "$CONFIG_H"; then
  if pkg-config --exists molten-vk 2>/dev/null; then
    MOLTEN_SONAME="$(pkg-config --variable=libdir molten-vk)/libMoltenVK.dylib"
    log "Defining SONAME_LIBVULKAN from molten-vk: $MOLTEN_SONAME"
    sed -i '' "s|/\\* #undef SONAME_LIBVULKAN \\*/|#define SONAME_LIBVULKAN \"$MOLTEN_SONAME\"|" "$CONFIG_H"
  else
    log "Warning: molten-vk not found; using default SONAME_LIBVULKAN (install: brew install molten-vk)"
    sed -i '' 's|/\* #undef SONAME_LIBVULKAN \*/|#define SONAME_LIBVULKAN "libMoltenVK.dylib"|' "$CONFIG_H"
  fi
fi

log "Compiling Wine"
make -j"$(sysctl -n hw.ncpu)"

log "Installing Wine into staging prefix"
make install

popd >/dev/null

log "Assembling Libraries/ layout for GW2onMac"
rm -rf "$LIBRARY_LAYOUT"
mkdir -p "$LIBRARY_LAYOUT/Wine"

# Map install tree into Whisky-compatible layout: Libraries/Wine/bin, lib, share
cp -R "$WINE_PREFIX/bin" "$LIBRARY_LAYOUT/Wine/"
cp -R "$WINE_PREFIX/lib" "$LIBRARY_LAYOUT/Wine/"
cp -R "$WINE_PREFIX/share" "$LIBRARY_LAYOUT/Wine/"

# Wine dlopen()s libfreetype.6.dylib at runtime; bundle x86_64 Homebrew copies.
"$ROOT/Scripts/bundle-native-dylibs.sh" "$LIBRARY_LAYOUT/Wine"

# Bundle winetricks helper script (optional; GW2 needs corefonts/tahoma)
if command -v winetricks >/dev/null 2>&1; then
  mkdir -p "$LIBRARY_LAYOUT"
  cp "$(command -v winetricks)" "$LIBRARY_LAYOUT/winetricks"
fi

# Wine 11 ships a single `wine` loader (wine64 was removed). GW2Kit/Whisky expect wine64.
if [[ ! -e "$LIBRARY_LAYOUT/Wine/bin/wine64" ]] && [[ -x "$LIBRARY_LAYOUT/Wine/bin/wine" ]]; then
  ln -sf wine "$LIBRARY_LAYOUT/Wine/bin/wine64"
fi

WINE_VERSION=""
if [[ -x "$LIBRARY_LAYOUT/Wine/bin/wine64" ]]; then
  WINE_VERSION="$("$LIBRARY_LAYOUT/Wine/bin/wine64" --version 2>/dev/null | sed 's/wine-//' | awk '{print $1}')" || true
fi
if [[ -z "$WINE_VERSION" ]] && [[ -x "$LIBRARY_LAYOUT/Wine/bin/wine" ]]; then
  WINE_VERSION="$("$LIBRARY_LAYOUT/Wine/bin/wine" --version 2>/dev/null | sed 's/wine-//' | awk '{print $1}')" || true
fi
WINE_VERSION="${WINE_VERSION:-11.0}"

RUNTIME_VERSION="${RUNTIME_VERSION:-0.1.0}"
RUNTIME_MAJOR="$(echo "$RUNTIME_VERSION" | cut -d. -f1)"
RUNTIME_MINOR="$(echo "$RUNTIME_VERSION" | cut -d. -f2)"
RUNTIME_PATCH="$(echo "$RUNTIME_VERSION" | cut -d. -f3)"
RUNTIME_PATCH="${RUNTIME_PATCH:-0}"
VERSION_PLIST="$DIST_DIR/GW2onMacWineVersion.plist"

cat > "$VERSION_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>version</key>
    <dict>
        <key>major</key>
        <integer>${RUNTIME_MAJOR}</integer>
        <key>minor</key>
        <integer>${RUNTIME_MINOR}</integer>
        <key>patch</key>
        <integer>${RUNTIME_PATCH}</integer>
        <key>preRelease</key>
        <string></string>
        <key>build</key>
        <string></string>
    </dict>
    <key>crossoverSourceVersion</key>
    <string>${CROSSOVER_VERSION}</string>
    <key>wineVersion</key>
    <string>${WINE_VERSION}</string>
</dict>
</plist>
EOF

cp "$VERSION_PLIST" "$LIBRARY_LAYOUT/GW2onMacWineVersion.plist"
cp "$VERSION_PLIST" "$LIBRARY_LAYOUT/TyriaWineVersion.plist"

log "Creating Libraries.tar.gz"
rm -f "$DIST_DIR/Libraries.tar.gz"
tar -czf "$DIST_DIR/Libraries.tar.gz" -C "$BUILD_ROOT" Libraries

log "Done."
log "  Runtime: $DIST_DIR/Libraries.tar.gz"
log "  Version: $DIST_DIR/GW2onMacWineVersion.plist"
log "  Wine:    $WINE_VERSION (from CrossOver sources $CROSSOVER_VERSION)"
log ""
log "Local test install:"
log "  GW2ONMAC_WINE_RUNTIME_URL=file://$DIST_DIR/Libraries.tar.gz \\"
log "  GW2ONMAC_WINE_VERSION_URL=file://$DIST_DIR/GW2onMacWineVersion.plist \\"
log "  open GW2onMac.xcodeproj"

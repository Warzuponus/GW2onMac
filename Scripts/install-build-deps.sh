#!/usr/bin/env bash
#
# install-build-deps.sh — Homebrew packages required to build the GW2onMac Wine runtime.
#
# Run from a normal (arm64) Terminal:
#   ./Scripts/install-build-deps.sh
#
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "error: Homebrew is not installed." >&2
  echo "Install from https://brew.sh then re-run this script." >&2
  exit 1
fi

echo "==> Installing GW2onMac Wine runtime build dependencies via Homebrew..."
echo "    (This may take several minutes — mingw-w64 is large.)"
echo

# Homebrew renamed pkg-config → pkgconf; pkgconf provides the pkg-config binary.
brew install \
  pkgconf \
  bison \
  flex \
  mingw-w64 \
  gnutls \
  sdl2 \
  libpng \
  jpeg-turbo \
  freetype

echo
echo "==> Done. Verify pkg-config:"
if command -v pkg-config >/dev/null 2>&1; then
  pkg-config --version
else
  echo "warning: pkg-config not on PATH; try: export PATH=\"$(brew --prefix pkgconf)/bin:\$PATH\""
fi

echo
echo "Next step:"
echo "  ./Scripts/build-wine-runtime.sh"

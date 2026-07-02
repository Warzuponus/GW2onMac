#!/usr/bin/env bash
#
# install-x86_64-build-deps.sh — x86_64 Homebrew deps for building the Wine runtime on Apple Silicon.
#
# Wine for macOS must be built as x86_64 (runs under Rosetta 2). ARM Homebrew at
# /opt/homebrew only provides arm64 libraries and cannot be linked into x86_64 Wine.
#
# Usage:
#   ./Scripts/install-x86_64-build-deps.sh
#
set -euo pipefail

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

is_apple_silicon() {
  [[ "$(sysctl -n hw.optional.arm64 2>/dev/null)" == "1" ]]
}

if ! is_apple_silicon; then
  log "Not Apple Silicon — use ./Scripts/install-build-deps.sh instead."
  exit 0
fi

# Re-exec under Rosetta so brew and builds see an x86_64 environment.
# Note: uname -m becomes x86_64 under Rosetta — use hw.optional.arm64 above instead.
if [[ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" != "1" ]]; then
  log "Re-launching under Rosetta (arch -x86_64)..."
  exec arch -x86_64 "$0" "$@"
fi

if [[ ! -x /usr/local/bin/brew ]]; then
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    log "CI: Installing x86_64 Homebrew at /usr/local (non-interactive)..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    cat >&2 <<'EOF'
error: x86_64 Homebrew is not installed at /usr/local.

Apple Silicon needs a separate Intel/Rosetta Homebrew for Wine build dependencies.
Install it once (interactive — follow the prompts):

  arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

Then add to your shell (installer prints the exact lines):

  eval "$(/usr/local/bin/brew shellenv)"

Re-run:

  ./Scripts/install-x86_64-build-deps.sh

Docs: https://docs.brew.sh/Installation#macos-11-or-higher-on-arm
EOF
    exit 1
  fi
fi

eval "$(/usr/local/bin/brew shellenv)"

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

log "Installing x86_64 build dependencies via /usr/local Homebrew..."
log "(This can take 15–30 minutes.)"

brew install \
  pkgconf \
  bison \
  flex \
  mingw-w64 \
  gnutls \
  freetype \
  molten-vk \
  sdl2 \
  libpng \
  jpeg-turbo \
  winetricks

log "Done. Verify:"
command -v pkg-config
pkg-config --libs freetype2
file "$(pkg-config --variable=libdir freetype2)/libfreetype.dylib" 2>/dev/null || \
  file /usr/local/opt/freetype/lib/libfreetype.dylib

log ""
log "Next: ./Scripts/build-wine-runtime.sh"

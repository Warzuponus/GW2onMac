#!/usr/bin/env bash
#
# publish-local-runtime.sh — Upload a pre-built dist/Libraries.tar.gz to GitHub Releases.
#
# Usage:
#   RUNTIME_VERSION=0.1.1 ./Scripts/publish-local-runtime.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${RUNTIME_VERSION:?Set RUNTIME_VERSION (e.g. 0.1.1)}"
TAG="runtime-v${VERSION}"
TARBALL="$ROOT/dist/Libraries.tar.gz"
PLIST="$ROOT/dist/GW2onMacWineVersion.plist"

[[ -f "$TARBALL" ]] || { echo "Missing $TARBALL — run ./Scripts/build-wine-runtime.sh first." >&2; exit 1; }
[[ -f "$PLIST" ]] || { echo "Missing $PLIST — run ./Scripts/build-wine-runtime.sh or copy from dist/." >&2; exit 1; }

echo "Publishing $TAG"
echo "  Tarball: $TARBALL ($(du -h "$TARBALL" | awk '{print $1}'))"
echo "  Plist:   $PLIST"
shasum -a 256 "$TARBALL"

if gh release view "$TAG" >/dev/null 2>&1; then
  echo "Release $TAG exists — uploading assets"
  gh release upload "$TAG" "$TARBALL" "$PLIST" --clobber
else
  gh release create "$TAG" \
    --title "Wine Runtime ${VERSION}" \
    --notes "$(cat <<EOF
Pre-built Wine 11 runtime (CrossOver FOSS sources 26.2.0).

Built locally on Apple Silicon and verified with Guild Wars 2 + D3DMetal.

After installing, re-run **Install GPTK** in GW2onMac (D3DMetal is not bundled in the runtime tarball).

\`\`\`
sha256 $(shasum -a 256 "$TARBALL" | awk '{print $1}')
\`\`\`
EOF
)" \
    "$TARBALL" "$PLIST"
fi

echo "Done: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/releases/tag/$TAG"

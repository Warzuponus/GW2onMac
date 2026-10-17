# Wine runtime — build & release guide

This document is for **maintainers and developers** who build or publish the GW2onMac Wine runtime.

Players should use the in-app **Download Runtime** button — see [INSTALL.md](INSTALL.md).

---

## What is the GW2onMac runtime?

A custom Wine bundle built from CodeWeavers' LGPL CrossOver source archives (Wine 11 lineage). We compile from source; we do **not** redistribute commercial CrossOver binaries.

Stock WineHQ builds lack CrossOver's macOS `winemac.drv` Metal path used with Apple's D3DMetal.

## Default version

| Setting | Value |
|---------|--------|
| `CROSSOVER_VERSION` | `26.2.0` |
| Upstream tarball | `crossover-sources-26.2.0.tar.gz` |
| Target CPU | **x86_64** (runs under Rosetta 2 on Apple Silicon) |

Override at build time:

```bash
CROSSOVER_VERSION=26.2.0 RUNTIME_VERSION=0.1.0 ./Scripts/build-wine-runtime.sh
```

## Building locally (Apple Silicon only)

Wine must be built as **x86_64** under Rosetta using **x86_64 Homebrew** at `/usr/local`:

```bash
./Scripts/install-x86_64-build-deps.sh   # once
./Scripts/build-wine-runtime.sh          # re-execs under Rosetta automatically
```

Expect **30–90 minutes** for the compile.

### Homebrew dependencies

Installed by `install-x86_64-build-deps.sh`:

```bash
brew install pkgconf bison flex mingw-w64 gnutls freetype molten-vk sdl2 libpng jpeg-turbo winetricks
```

Also requires **Xcode Command Line Tools**:

```bash
xcode-select --install
```

## Output layout

```
Libraries/
├── Wine/
│   ├── bin/wine64
│   ├── lib/
│   └── share/
├── GW2onMacWineVersion.plist
└── TyriaWineVersion.plist      # legacy alias, same content
```

Packaged as `dist/Libraries.tar.gz` (~450 MB), plus `dist/GW2onMacWineVersion.plist` (uploaded next to the tarball so the app can check for updates without downloading it).

`RUNTIME_VERSION` (default `0.1.0`) is written into the plist — set it to match the release tag.

## Publishing to GitHub Releases

Currently published: **`runtime-v0.1.2`** (the tag the app downloads). Use the next version for a new runtime.

### From CI

```bash
git tag runtime-v0.1.3
git push origin runtime-v0.1.3
```

The `release-runtime` workflow on GitHub Actions (allow **~2.5 hours**):

1. Installs x86_64 Homebrew on the macOS runner
2. Builds Wine with `RUNTIME_VERSION` taken from the tag
3. Uploads `Libraries.tar.gz` + `GW2onMacWineVersion.plist` to the release (not marked *Latest*, so the app release stays the default download)

### From a local build

If you already built `dist/` locally (faster than CI):

```bash
RUNTIME_VERSION=0.1.3 ./Scripts/build-wine-runtime.sh
RUNTIME_VERSION=0.1.3 ./Scripts/publish-local-runtime.sh   # needs the gh CLI, logged in
```

### After publishing

Then bump `runtimeReleaseTag` in `GW2Kit/Sources/GW2Kit/ReleaseConfiguration.swift` and ship an app release — the app only downloads the runtime tag it was built with. Existing users see **Update Runtime** and must re-run **Install GPTK** afterwards (the update replaces `Libraries/`).

## Apple GPTK / D3DMetal

The runtime provides Wine + winemac. **DirectX 11** requires Apple's D3DMetal — users install GPTK separately, and the app's **Install GPTK** copies GPTK's `redist/lib/external/` and `redist/lib/wine/x86_64-{windows,unix}/` into the runtime. We cannot redistribute D3DMetal. See [INSTALL.md](INSTALL.md#step-4--install-apple-game-porting-toolkit-d3dmetal).

## Known build issues

| Issue | Mitigation |
|-------|------------|
| `can't build Wine preloader` | Ensure build runs under Rosetta (`arch -x86_64`) |
| Missing mingw-w64 | `brew install mingw-w64` via x86_64 Homebrew |
| Configure can't find bison/flex | Add formula bins to PATH |
| `wineboot` hangs on FreeType | `bundle-native-dylibs.sh` bundles x86_64 freetype |

## Performance defaults

GW2onMac applies these automatically:

| Tuning | Why |
|--------|-----|
| `WINEMSYNC=1` + `WINEESYNC=1` | msync + D3DMetal compatibility |
| `RetinaMode=n` | Avoid 2× render resolution on Retina |
| `ROSETTA_ADVERTISE_AVX=1` | Better CPU paths under Rosetta |

### In-game settings (16 GB Macs)

- Character model limit → Low or Medium
- Reflections → Off or Low
- Shadows → Low
- Effect limit → Low

First visit to a new zone may stutter while D3DMetal compiles shaders.

## Local testing without GitHub

Either click **Import Runtime…** in the setup wizard and pick `dist/Libraries.tar.gz`, or point the app's downloader at local files before launching it from Xcode:

```bash
export GW2ONMAC_WINE_RUNTIME_URL="file://$(pwd)/dist/Libraries.tar.gz"
export GW2ONMAC_WINE_VERSION_URL="file://$(pwd)/dist/GW2onMacWineVersion.plist"
```

To run the game against a runtime without installing it, set `GW2ONMAC_WINE_LIB` to its `Wine/` directory and run `./Scripts/launch-gw2.sh`.

# GW2onMac Wine runtime build guide

GW2onMac ships a custom Wine runtime built from CodeWeavers' LGPL CrossOver source archives—not from commercial CrossOver binaries.

## Why CrossOver sources?

Stock WineHQ builds lack CrossOver's macOS `winemac.drv` Metal integration path used with Apple's D3DMetal. CrossOver 26.x is based on **Wine 11.0**, which matches current GW2 compatibility reports on CodeWeavers' database.

## Default version

| Setting | Value |
|---------|--------|
| `CROSSOVER_VERSION` | `26.2.0` |
| Upstream tarball | `https://media.codeweavers.com/pub/crossover/source/crossover-sources-26.2.0.tar.gz` |
| Target CPU | **x86_64** (runs under Rosetta 2 on Apple Silicon) |

Override at build time:

```bash
CROSSOVER_VERSION=26.2.0 RUNTIME_VERSION=0.1.0 ./Scripts/build-wine-runtime.sh
```

## Build environment

Run from a **normal arm64 Terminal** with Apple Silicon Homebrew (`/opt/homebrew`):

```bash
./Scripts/install-build-deps.sh   # once
./Scripts/build-wine-runtime.sh
```

You do **not** need `arch -x86_64` or a separate Intel Homebrew install. The script cross-compiles Wine for x86_64 using `clang -arch x86_64`.

### Homebrew dependencies

Installed automatically by `Scripts/install-build-deps.sh`:

```bash
brew install pkgconf bison flex mingw-w64 gnutls sdl2 libpng jpeg-turbo freetype
```

Note: Homebrew renamed `pkg-config` to **`pkgconf`**. The `pkg-config` command comes from that package.

Optional but useful:

```bash
arch -x86_64 /usr/local/bin/brew install winetricks llvm
```

Also install **Xcode Command Line Tools**:

```bash
xcode-select --install
```

## Output layout

The script produces a Whisky-compatible tree consumed by `WineRuntimeInstaller`:

```
Libraries/
├── Wine/
│   ├── bin/wine64
│   ├── bin/wineserver
│   ├── lib/
│   └── share/
└── GW2onMacWineVersion.plist
```

Packaged as `dist/Libraries.tar.gz`. Legacy `TyriaWineVersion.plist` is also included for older installs.

## Apple GPTK / D3DMetal (required for GW2)

The Wine runtime provides Wine + winemac. **DirectX 11** (GW2's default renderer) needs Apple's D3DMetal from GPTK:

1. Download GPTK from Apple Developer
2. Install D3DMetal libraries (Homebrew cask `game-porting-toolkit` is a common community path)
3. Copy `D3DMetal.framework` into `Libraries/Wine/lib/external/` if needed
4. GW2onMac checks common paths via `WineRuntimeInstaller.isD3DMetalAvailable()`

We cannot redistribute D3DMetal—see [NOTICES.md](../NOTICES.md).

## Phase 0 testing checklist

While validating GW2 manually:

- [ ] Wine runtime builds without errors
- [ ] `wine64 --version` reports Wine 11.x
- [ ] D3DMetal detected
- [ ] 64-bit prefix created
- [ ] `Gw2Setup-64.exe` or existing install launches
- [ ] Login + character select + 30 min gameplay
- [ ] Note FPS and any required launch flags (`-dx9single`, etc.)

## Known build issues

| Issue | Mitigation |
|-------|------------|
| `can't build Wine preloader` on arm64 native terminal | Use `arch -x86_64` for configure + make |
| Missing mingw-w64 | Install via Homebrew; ensure `i686-w64-mingw32-gcc` on PATH |
| Configure can't find bison/flex | `brew install bison flex` and add to PATH |
| Very long compile | Expect 30–90 minutes depending on machine |

## Performance

GW2onMac enables these automatically (via `GW2Profile` + `apply-gw2-performance.sh`):

| Tuning | Why |
|--------|-----|
| `WINEMSYNC=1` + `WINEESYNC=1` | msync + D3DMetal compatibility |
| `RetinaMode=n` | Stops winemac rendering at 2× resolution on Retina MacBooks |
| `ROSETTA_ADVERTISE_AVX=1` | Lets GW2 use AVX paths when running under Rosetta |
| No `GST_DEBUG` | Avoids GStreamer debug overhead in the launcher |

Re-apply to an existing prefix:

```bash
./Scripts/apply-gw2-performance.sh
```

### In-game settings (manual)

For M-series Macs with 16 GB RAM in busy maps (e.g. Arborstone):

- Character model limit → Low or Medium
- Reflections → Off or Low
- Shadows → Low
- Effect limit → Low

Stay on **DirectX 11** unless you hit stability issues. First session in an area may stutter while D3DMetal compiles shaders; FPS usually improves on subsequent visits.

Plug in power, disable Low Power Mode, and close heavy background apps before playing.

## CI / releases

The `build` workflow compiles GW2Kit and the GW2onMac app on every push to `main`.

Publish a Wine runtime to GitHub Releases:

```bash
git tag runtime-v0.1.0
git push origin runtime-v0.1.0
```

The `release-runtime` workflow builds `Libraries.tar.gz` on a macOS runner (expect 30–90 minutes) and attaches it to the release. Set `GW2ONMAC_GITHUB_REPO=yourname/GW2onMac` so the in-app downloader finds it.

For local testing without GitHub:

```bash
export GW2ONMAC_WINE_RUNTIME_URL="file://$(pwd)/dist/Libraries.tar.gz"
export GW2ONMAC_WINE_VERSION_URL="file://$(pwd)/dist/GW2onMacWineVersion.plist"
```

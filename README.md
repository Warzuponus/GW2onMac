# GW2onMac

Open-source Guild Wars 2 launcher for **Apple Silicon Macs**. GW2onMac wraps a self-built **Wine 11** runtime (compiled from [CodeWeavers CrossOver FOSS sources](https://www.codeweavers.com/crossover/source)) and a single GW2-tuned Wine prefix.

> **Unsupported by ArenaNet.** This project is community-maintained and not affiliated with ArenaNet or NCSOFT.

## Status

| Phase | Scope |
|-------|--------|
| **Phase 0** | Manual GW2 compatibility testing |
| **Phase 1** | GW2Kit library + Wine runtime build pipeline + app scaffold |
| **Phase 2** | Setup wizard, home launcher UI, prefix create/repair flows |
| **Phase 3** | In-app runtime downloader, Gw2Setup wizard, import existing install, GitHub releases |
| **Phase 4+** | CI polish, notarization, auto-update notifications |

## Requirements

- Apple Silicon Mac (M-series)
- macOS Sonoma 14.0+
- **Rosetta 2** (Wine x86_64 runs under Rosetta)
- **Apple Game Porting Toolkit** with D3DMetal (user-installed; GW2 uses DirectX 11)
- Xcode 16+ (to build the app)

## Quick start (developers)

### 1. Install build dependencies

**Apple Silicon (M-series):** Wine must be built as x86_64 using **x86_64 Homebrew** at `/usr/local` (separate from your normal `/opt/homebrew`):

```bash
./Scripts/install-x86_64-build-deps.sh
```

If you don't have x86_64 Homebrew yet, the script will print the one-time install command.

**Intel Mac:**

```bash
./Scripts/install-build-deps.sh
```

### 2. Build the Wine runtime

```bash
./Scripts/build-wine-runtime.sh
```

On Apple Silicon this automatically re-launches under Rosetta.

This downloads `crossover-sources-26.2.0.tar.gz`, compiles Wine 11, and outputs:

- `dist/Libraries.tar.gz`
- `dist/GW2onMacWineVersion.plist`

See [Docs/RUNTIME.md](Docs/RUNTIME.md) for dependencies and troubleshooting.

### 3. Build the app

```bash
open GW2onMac.xcodeproj
# Set your Development Team, then Build & Run
```

Or:

```bash
xcodebuild -project GW2onMac.xcodeproj -scheme GW2onMac -configuration Debug build
```

### 4. Install runtime (in-app or manual)

**In-app (recommended):** Launch GW2onMac and click **Download Runtime** in the setup wizard.

**Manual / local build:**

```bash
export GW2ONMAC_WINE_RUNTIME_URL="file://$(pwd)/dist/Libraries.tar.gz"
export GW2ONMAC_WINE_VERSION_URL="file://$(pwd)/dist/GW2onMacWineVersion.plist"
```

Or extract directly:

```bash
mkdir -p ~/Library/Application\ Support/com.gw2onmac.app
tar -xzf dist/Libraries.tar.gz -C ~/Library/Application\ Support/com.gw2onmac.app
```

Set `GW2ONMAC_GITHUB_REPO=yourname/GW2onMac` so the app downloads from your GitHub releases once published.

**Legacy installs:** If you previously used the development name *TyriaSilicon* (`com.tyriasilicon.app`), GW2onMac detects that runtime and prefix automatically — no migration required.

### 5. Create GW2 prefix & install game

1. Launch **GW2onMac** → complete the setup wizard
2. **Create Prefix**, then **Install GW2** (downloads and launches `Gw2Setup-64.exe`), or **Import** an existing install folder
3. Optional fonts: `./Scripts/gw2-winetricks.sh`

### GitHub releases (maintainers)

Tag a release to build and publish the Wine runtime:

```bash
git tag runtime-v0.1.0
git push origin runtime-v0.1.0
```

The `release-runtime` workflow uploads `Libraries.tar.gz` and `GW2onMacWineVersion.plist` to GitHub Releases. Users download via the in-app **Download Runtime** button once `GW2ONMAC_GITHUB_REPO` points at your repo.

## Project layout

```
GW2onMac/
├── GW2Kit/                 # Swift package (Wine launcher core, forked from Whisky)
├── GW2onMac/               # SwiftUI app
├── Scripts/
│   ├── build-wine-runtime.sh
│   └── gw2-winetricks.sh
├── Docs/
│   └── RUNTIME.md
└── dist/                   # build output (gitignored)
```

## GW2-specific defaults

Built into `GW2Profile`:

- 64-bit prefix (`WINEARCH=win64`, Windows 10)
- `WINEDEBUG=-all` (prevents fixme memory leak)
- `WINEMSYNC` + esync workaround for D3DMetal
- `ROSETTA_ADVERTISE_AVX=1` on Apple Silicon (better CPU paths under Rosetta)
- `RetinaMode=n` in winemac (avoid 2× render resolution on Retina displays)
- Launcher: `Gw2-64.exe` at `C:\Program Files\Guild Wars 2\`

### Performance tuning

GW2onMac applies performance defaults automatically when you create a prefix or launch the app. To re-apply manually:

```bash
./Scripts/apply-gw2-performance.sh
```

See [Docs/RUNTIME.md](Docs/RUNTIME.md#performance) for in-game graphics settings that help on 16 GB Macs.

## License

GW2onMac application code is **GPL-3.0** (derived from [Whisky](https://github.com/Whisky-App/Whisky)). See [LICENSE](LICENSE) and [NOTICES.md](NOTICES.md) for Wine, CrossOver source, and Apple GPTK attribution.

## Credits

- [Whisky](https://github.com/Whisky-App/Whisky) — SwiftUI Wine wrapper patterns
- [CodeWeavers](https://www.codeweavers.com/) — CrossOver FOSS Wine sources (LGPL)
- [Apple Game Porting Toolkit](https://developer.apple.com/games/game-porting-toolkit/) — D3DMetal (user-installed, proprietary)

# GW2onMac

Open-source Guild Wars 2 launcher for **Apple Silicon Macs** (M1 and newer). GW2onMac uses a pre-built **Wine 11** runtime and Apple’s **Game Porting Toolkit (D3DMetal)** to run GW2 with DirectX 11 on macOS.

> **Community project, early release.** Not affiliated with or supported by ArenaNet or NCSOFT. Expect rough edges — please [open an issue](https://github.com/Warzuponus/GW2onMac/issues) if something breaks.
> **Intel Macs are not supported.**

**Install guide for players:** [Docs/INSTALL.md](Docs/INSTALL.md)

> **macOS security warning:** GW2onMac is **not code-signed** (no paid Apple Developer certificate). macOS will show a “could not verify” warning on first launch — this is expected if you downloaded from [our GitHub Releases](https://github.com/Warzuponus/GW2onMac/releases). See [INSTALL.md — macOS security warning](Docs/INSTALL.md#macos-security-warning-expected).

---

## For players — quick overview

You do **not** need Xcode, Homebrew, or to compile Wine yourself.

1. **Download `GW2onMac-<version>.dmg`** from the [latest release](https://github.com/Warzuponus/GW2onMac/releases/latest) and drag the app to **Applications**
2. **Get past the macOS security warning** — click **Done** (not **Move to Trash**), then **System Settings → Privacy & Security → Open Anyway** ([details](Docs/INSTALL.md#macos-security-warning-expected))
3. **Open the app** and follow the setup wizard:
   1. **Install Rosetta 2** (one click)
   2. **Download Runtime** (~450 MB from GitHub)
   3. **Install GPTK** — download Game Porting Toolkit from Apple first ([how](Docs/INSTALL.md#step-4--install-apple-game-porting-toolkit-d3dmetal))
   4. **Create Prefix** → **Install GW2** (or **Import…** an existing install)
4. Click **Play**

Full step-by-step instructions: **[Docs/INSTALL.md](Docs/INSTALL.md)**

### Requirements

- Apple Silicon Mac (M-series)
- macOS Sonoma 14.0 or newer
- ~100 GB free disk space (Guild Wars 2 is ~80 GB, plus runtime and prefix)
- Free Apple Developer account (to download GPTK)
- ArenaNet account

---

## What you download, and from where

| Component | Where it comes from |
|-----------|---------------------|
| **GW2onMac app** | [GitHub Releases](https://github.com/Warzuponus/GW2onMac/releases) (`GW2onMac-*.dmg`, unsigned, with SHA-256 checksum) |
| **Wine runtime** (`Libraries.tar.gz`) | In-app **Download Runtime**, from the `runtime-v*` GitHub release — built from source in CI |
| **D3DMetal (GPTK)** | You download it from [Apple](https://developer.apple.com/games/game-porting-toolkit/); the app installs it with one click |
| **Guild Wars 2** | ArenaNet’s installer, via in-app **Install GW2** |

**Why not bundle everything?** D3DMetal is Apple proprietary and can’t be redistributed, and Guild Wars 2 belongs to ArenaNet. The Wine runtime is LGPL and built from CodeWeavers’ published sources in this repo’s CI, so we host it for you.

---

## For developers

### Build the app

```bash
git clone https://github.com/Warzuponus/GW2onMac.git
cd GW2onMac
open GW2onMac.xcodeproj
# Build & Run (signs to run locally; set a Development Team if you want)
```

`swift build --package-path GW2Kit` builds the core package on its own.

### Run GW2 from the command line

The app launches the game through the same script you can run by hand:

```bash
./Scripts/launch-gw2.sh
```

It finds the Wine runtime and the GW2 prefix on its own. Override with `GW2ONMAC_WINE_LIB` (runtime directory) and `WINEPREFIX` (prefix directory).

### Build the Wine runtime locally (optional)

Only needed if you are hacking on Wine. On Apple Silicon:

```bash
./Scripts/install-x86_64-build-deps.sh   # once — x86_64 Homebrew at /usr/local
./Scripts/build-wine-runtime.sh          # 30–90 minutes
```

Output: `dist/Libraries.tar.gz` + `dist/GW2onMacWineVersion.plist`. See [Docs/RUNTIME.md](Docs/RUNTIME.md).

### Publish releases (maintainers)

```bash
git tag v1.1.0 && git push origin v1.1.0                  # app → GW2onMac-1.1.0.dmg
git tag runtime-v0.1.3 && git push origin runtime-v0.1.3  # Wine runtime → Libraries.tar.gz
```

The app release stamps the tag’s version into the app. After publishing a new runtime, bump `runtimeReleaseTag` in `GW2Kit/Sources/GW2Kit/ReleaseConfiguration.swift` so the app downloads it.

---

## Project layout

```
GW2onMac/
├── GW2Kit/                 # Swift package (Wine launcher core)
├── GW2onMac/               # SwiftUI app (+ bundled scripts in Resources/)
├── Scripts/                # Launch, prefix, GPTK and Wine build helpers
├── Docs/
│   ├── INSTALL.md          # Player installation guide
│   ├── RUNTIME.md          # Wine runtime build guide
│   └── CODESIGNING.md      # Optional signing / notarization
└── .github/workflows/      # CI + release automation
```

## GW2-specific defaults

- 64-bit Wine prefix (Windows 10)
- DirectX 11 via D3DMetal
- Performance tuning for Apple Silicon (msync, Retina off, AVX under Rosetta)

See [Docs/RUNTIME.md](Docs/RUNTIME.md#performance-defaults) for in-game graphics tips on 16 GB Macs.

## License

GW2onMac application code is **GPL-3.0** (derived from [Whisky](https://github.com/Whisky-App/Whisky)). See [LICENSE](LICENSE) and [NOTICES.md](NOTICES.md).

## Credits

- [Whisky](https://github.com/Whisky-App/Whisky) — SwiftUI Wine wrapper patterns
- [CodeWeavers](https://www.codeweavers.com/) — CrossOver FOSS Wine sources (LGPL)
- [Apple Game Porting Toolkit](https://developer.apple.com/games/game-porting-toolkit/) — D3DMetal (user-installed)

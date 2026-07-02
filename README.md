# GW2onMac

Open-source Guild Wars 2 launcher for **Apple Silicon Macs** (M1 and newer). GW2onMac uses a pre-built **Wine 11** runtime and Apple’s **Game Porting Toolkit (D3DMetal)** to run GW2 on macOS.

> **Unsupported by ArenaNet.** Community-maintained. Not affiliated with ArenaNet or NCSOFT.  
> **Intel Macs are not supported.**

**Install guide for players:** [Docs/INSTALL.md](Docs/INSTALL.md)

---

## For players — quick overview

You do **not** need Xcode, Homebrew, or to compile Wine yourself.

1. **Download GW2onMac** from [GitHub Releases](https://github.com/Warzuponus/GW2onMac/releases)
2. **Open the app** and follow the setup wizard
3. **Install Rosetta 2** (one click in the app)
4. **Download the Wine runtime** (one click — ~450 MB, hosted on GitHub)
5. **Install Apple Game Porting Toolkit** and copy D3DMetal (see [INSTALL.md](Docs/INSTALL.md#step-4--install-apple-game-porting-toolkit-d3dmetal))
6. **Create Prefix** → **Install GW2** → **Play**

Full step-by-step instructions with links: **[Docs/INSTALL.md](Docs/INSTALL.md)**

### Requirements

- Apple Silicon Mac (M-series)
- macOS Sonoma 14.0 or newer
- ~50 GB free disk space (game + runtime)
- Free Apple Developer account (for GPTK download)
- ArenaNet account (for Guild Wars 2)

---

## Pre-built downloads vs building from source

GW2onMac is designed so **players download pre-compiled artifacts** instead of building anything locally.

| Component | Pre-built? | Where users get it |
|-----------|------------|-------------------|
| **Wine runtime** (`Libraries.tar.gz`) | Yes | In-app **Download Runtime** from [GitHub Releases](https://github.com/Warzuponus/GW2onMac/releases) |
| **GW2onMac app** | Planned | GitHub Releases (`.app` / `.dmg`) |
| **D3DMetal (GPTK)** | No — user must install | [Apple Developer](https://developer.apple.com/games/game-porting-toolkit/) |
| **Guild Wars 2** | No — user must install | ArenaNet via in-app **Install GW2** |

### Why not bundle everything?

- **D3DMetal** is Apple proprietary — we legally cannot ship it inside GW2onMac.
- **Guild Wars 2** is ArenaNet’s game — users install it with ArenaNet’s installer.
- **Wine runtime** *can* be pre-built and hosted (LGPL source available in this repo). That is what the `runtime-v*` GitHub releases provide.

### Downsides of pre-built releases (and how we handle them)

| Concern | Impact | Mitigation |
|---------|--------|------------|
| Large download (~450 MB runtime) | Slow on slow connections | In-app downloader with progress; host on GitHub Releases CDN |
| macOS Gatekeeper | “Unidentified developer” warning without signing | Code signing + notarization (planned) |
| Trust | Users must trust release artifacts | Open source, reproducible CI builds, checksums in release notes |
| GPTK still manual | Biggest remaining friction for non-technical users | Detailed [INSTALL.md](Docs/INSTALL.md) with copy-paste paths |
| Updates | Old runtimes may break | In-app **Update Runtime** when a newer release is published |
| GPL/LGPL compliance | Must offer source | This repo + CrossOver FOSS source links in [NOTICES.md](NOTICES.md) |

**Bottom line:** Requiring users to compile Wine locally would exclude most players. Pre-built runtime + app releases are the right model; the main unavoidable manual step is installing Apple’s GPTK.

---

## For developers

### Build the app

```bash
git clone https://github.com/Warzuponus/GW2onMac.git
cd GW2onMac
open GW2onMac.xcodeproj
# Set Development Team, then Build & Run
```

### Build the Wine runtime locally (optional)

Only needed if you are hacking on Wine or testing before a release. On Apple Silicon:

```bash
./Scripts/install-x86_64-build-deps.sh   # once — x86_64 Homebrew at /usr/local
./Scripts/build-wine-runtime.sh          # 30–90 minutes
```

Output: `dist/Libraries.tar.gz` + `dist/GW2onMacWineVersion.plist`

See [Docs/RUNTIME.md](Docs/RUNTIME.md) for build troubleshooting.

### Publish an app release (maintainers)

```bash
git tag v0.1.0
git push origin v0.1.0
```

GitHub Actions builds `GW2onMac-0.1.0.dmg` and attaches it to the release. See [Docs/CODESIGNING.md](Docs/CODESIGNING.md) for signing and notarization.

### Publish a runtime release (maintainers)

```bash
git tag runtime-v0.1.0
git push origin runtime-v0.1.0
```

GitHub Actions builds and attaches `Libraries.tar.gz` to the release. Users download it through the app automatically.

---

## Project layout

```
GW2onMac/
├── GW2Kit/                 # Swift package (Wine launcher core)
├── GW2onMac/               # SwiftUI app
├── Scripts/                # Wine build + prefix helpers
├── Docs/
│   ├── INSTALL.md          # Player installation guide
│   └── RUNTIME.md          # Wine runtime build guide
└── .github/workflows/      # CI + release automation
```

## GW2-specific defaults

- 64-bit Wine prefix (Windows 10)
- DirectX 11 via D3DMetal
- Performance tuning for Apple Silicon (msync, Retina off, AVX under Rosetta)

See [Docs/RUNTIME.md](Docs/RUNTIME.md#performance) for in-game graphics tips on 16 GB Macs.

## License

GW2onMac application code is **GPL-3.0** (derived from [Whisky](https://github.com/Whisky-App/Whisky)). See [LICENSE](LICENSE) and [NOTICES.md](NOTICES.md).

## Credits

- [Whisky](https://github.com/Whisky-App/Whisky) — SwiftUI Wine wrapper patterns
- [CodeWeavers](https://www.codeweavers.com/) — CrossOver FOSS Wine sources (LGPL)
- [Apple Game Porting Toolkit](https://developer.apple.com/games/game-porting-toolkit/) — D3DMetal (user-installed)

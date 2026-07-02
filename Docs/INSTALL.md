# GW2onMac installation guide

This guide is for **players** who want to run Guild Wars 2 on an **Apple Silicon Mac** (M1, M2, M3, M4, etc.).

> **Not supported:** Intel Macs, ArenaNet official support, or Windows installs through this launcher.

---

## What you need before you start

| Item | Why |
|------|-----|
| Apple Silicon Mac | GW2onMac is built for M-series chips only |
| macOS 14 (Sonoma) or newer | Required by the app |
| ~50 GB free disk space | Guild Wars 2 install + Wine runtime |
| ArenaNet account | You install GW2 through ArenaNet’s installer |
| Apple Developer account (free) | Needed to download Apple’s Game Porting Toolkit |

---

## macOS security warning (expected)

GW2onMac is **open source** but **not code-signed** with an Apple Developer certificate (that requires a paid $99/year membership). Because of this, macOS Gatekeeper will block or warn on first launch.

**This is normal.** You are not doing anything wrong.

### How to open GW2onMac

**Method 1 — Right-click Open (easiest)**

1. Download and install from [GitHub Releases](https://github.com/Warzuponus/GW2onMac/releases) only.
2. Open the DMG and drag **GW2onMac** to **Applications**.
3. In **Applications**, **right-click** (or Control-click) **GW2onMac**.
4. Choose **Open** from the menu.
5. Click **Open** in the dialog (not Cancel).
6. GW2onMac launches. You only need to do this once — after that, double-click works.

**Method 2 — System Settings**

1. Try to open GW2onMac normally (double-click).
2. macOS says the app “cannot be opened because it is from an unidentified developer.”
3. Open **System Settings → Privacy & Security**.
4. Scroll down — you should see a message about **GW2onMac** being blocked.
5. Click **Open Anyway**, then confirm **Open**.

**Method 3 — Remove quarantine (Terminal)**

If the above does not work (e.g. after downloading via a browser that flagged the file):

```bash
xattr -dr com.apple.quarantine /Applications/GW2onMac.app
```

Then open the app normally.

### Is it safe?

Only download from the official repo:

**https://github.com/Warzuponus/GW2onMac/releases**

The app is open source — you can inspect the code in this repository. Unsigned distribution is a cost limitation, not a sign the app is malicious.

---

## Step 1 — Get GW2onMac

### Option A: Download a release (recommended)

When available, download the latest **`GW2onMac`** release from:

**https://github.com/Warzuponus/GW2onMac/releases**

1. Open the newest release.
2. Download **`GW2onMac-0.1.0.dmg`** (or the latest version).
3. Open the DMG and drag **GW2onMac** to **Applications**.
4. Follow [macOS security warning (expected)](#macos-security-warning-expected) above to open the app the first time.

### Option B: Build from source (developers)

See [README.md](../README.md#for-developers).

---

## Step 2 — Install Rosetta 2

Wine runs as x86_64 code under Rosetta on Apple Silicon.

1. Open **GW2onMac**.
2. In the setup wizard, find **Rosetta 2**.
3. Click **Install Rosetta** if it is not already installed.

Or install manually in Terminal:

```bash
softwareupdate --install-rosetta --agree-to-license
```

---

## Step 3 — Download the Wine runtime

You do **not** need to compile Wine yourself. GW2onMac downloads a pre-built runtime from GitHub.

1. In the setup wizard, find **Wine runtime**.
2. Click **Download Runtime** (~450 MB).
3. Wait for the download and extraction to finish.

The app stores the runtime at:

`~/Library/Application Support/com.gw2onmac.app/Libraries/`

---

## Step 4 — Install Apple Game Porting Toolkit (D3DMetal)

Guild Wars 2 uses **DirectX 11**. On Mac, that requires Apple’s **D3DMetal** libraries from the Game Porting Toolkit. GW2onMac cannot bundle these files — you must install them yourself under Apple’s license.

### 4a. Download GPTK from Apple

1. Sign in at **https://developer.apple.com/download/all/**
2. Search for **Game Porting Toolkit**
3. Download the latest **Game Porting Toolkit** `.dmg` for macOS (4.x recommended)

### 4b. Install D3DMetal into the Wine runtime

After installing GPTK, copy **D3DMetal** into GW2onMac’s Wine folder:

1. Open Finder.
2. Press **Cmd + Shift + G** and paste:

   `~/Library/Application Support/com.gw2onmac.app/Libraries/Wine/lib/external/`

3. Create the `external` folder if it does not exist.
4. Copy **`D3DMetal.framework`** from your GPTK installation into that `external` folder.

Typical GPTK install locations (one of these usually exists):

- `/Library/Apple/Game Porting Toolkit/D3DMetal.framework`
- Inside the mounted GPTK `.dmg` under a `D3DMetal` or `lib` folder

5. Return to GW2onMac and click **Refresh**. The **D3DMetal (GPTK)** step should show a checkmark.

### Alternative: Homebrew (advanced)

Some users install GPTK via Homebrew’s `game-porting-toolkit` cask. If D3DMetal is on your system, GW2onMac may detect it automatically. Copying the framework into `lib/external/` is the most reliable method.

---

## Step 5 — Create the GW2 prefix

A “prefix” is a Windows-like environment where GW2 runs.

1. In the setup wizard, click **Create Prefix**.
2. Wait until the **GW2 prefix** step shows a checkmark.

---

## Step 6 — Install Guild Wars 2

### Option A: Install through GW2onMac (recommended)

1. Click **Install GW2**.
2. GW2onMac downloads **`Gw2Setup-64.exe`** from ArenaNet and launches it.
3. Follow ArenaNet’s installer (log in, choose install location, wait for download).
4. When finished, click **Refresh** in GW2onMac.

### Option B: Import an existing install

If you already have GW2 on a Windows drive or backup:

1. Click **Import…**
2. Select the folder that contains **`Gw2-64.exe`** (usually `Guild Wars 2`).
3. GW2onMac copies it into the prefix.

### Option C: Install manually

Run ArenaNet’s installer inside the Wine prefix using GW2onMac’s terminal mode (hold **Shift** when launching programs) — only if you are comfortable with Wine.

---

## Step 7 — Play

1. When all setup steps are complete, GW2onMac shows the main launcher.
2. Click **Play**.

### If the game does not start

- Click **Repair launcher** (clears a stale lock file).
- Try lowering in-game graphics settings (see [RUNTIME.md](RUNTIME.md#performance)).
- Hold **Shift** when clicking Play to open in Terminal and see error output.

---

## Troubleshooting

| Problem | What to try |
|---------|-------------|
| “Wine runtime not installed” | Click **Download Runtime** again |
| “D3DMetal not found” | Copy `D3DMetal.framework` to `lib/external/` (Step 4) |
| “Create Prefix” fails | Install Rosetta + D3DMetal first |
| Game installs but Play is disabled | Click **Refresh** |
| Very low FPS on 16 GB Mac | Lower character models, shadows, reflections in-game |
| macOS blocks or warns about GW2onMac | Expected — see [macOS security warning](#macos-security-warning-expected) |

---

## What GW2onMac does not install for you

| Component | Why |
|-----------|-----|
| Guild Wars 2 game files | Licensed by ArenaNet — you install via their setup |
| Apple D3DMetal / GPTK | Apple proprietary — cannot be redistributed |
| Rosetta 2 | Apple system component — one-time install |

---

## Legal note

Guild Wars 2 is © ArenaNet / NCSOFT. Running GW2 through Wine on macOS is **not supported** by ArenaNet. GW2onMac is a community tool — use at your own risk.

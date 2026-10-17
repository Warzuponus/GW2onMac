# GW2onMac installation guide

This guide is for **players** who want to run Guild Wars 2 on an **Apple Silicon Mac** (M1, M2, M3, M4, etc.).

> **Not supported:** Intel Macs, ArenaNet official support, or Windows installs through this launcher.

---

## What you need before you start

| Item | Why |
|------|-----|
| Apple Silicon Mac | GW2onMac is built for M-series chips only |
| macOS 14 (Sonoma) or newer | Required by the app |
| ~100 GB free disk space | Guild Wars 2 (~80 GB) + Wine runtime + prefix |
| ArenaNet account | You install GW2 through ArenaNet’s installer |
| Apple Developer account (free) | Needed to download Apple’s Game Porting Toolkit |

---

## macOS security warning (expected)

GW2onMac is **open source** but **not code-signed** with an Apple Developer certificate (that requires a paid $99/year membership). Because of this, macOS Gatekeeper will block or warn on first launch.

**This is normal.** You are not doing anything wrong.

### How to open GW2onMac

On recent macOS versions (Sonoma, Sequoia, Tahoe), the first launch flow looks like this:

1. Download and install from [GitHub Releases](https://github.com/Warzuponus/GW2onMac/releases) only.
2. Open the DMG and drag **GW2onMac** to **Applications**.
3. Double-click **GW2onMac** in Applications.

macOS shows a security dialog: **“Apple could not verify GW2onMac is free of malware.”**

**Important — read the buttons carefully:**

| Button | What to do |
|--------|------------|
| **Move to Trash** (large blue button) | **Do not click this** — it deletes the app |
| **Done** (smaller button below) | **Click Done** — dismisses the dialog without deleting GW2onMac |

After you click **Done**, the app will not open yet. That is expected. Continue with **System Settings**:

4. Open **System Settings** → **Privacy & Security**.
5. **Scroll down** past the top sections. Near the bottom, look for a message that **GW2onMac** was blocked or prevented from opening.
6. Click **Open Anyway** (wording may be **Allow Anyway** on some macOS versions).
7. Confirm **Open** if macOS asks one more time.
8. GW2onMac launches. You only need to do this once — after that, double-click works normally.

**Method 1 — Privacy & Security (recommended — works on Sonoma and later)**

Steps 1–8 above are the full recommended path. Right-click **Open** alone often does **not** work on newer macOS — you usually need **Privacy & Security → Open Anyway** after dismissing the first dialog with **Done**.

**Method 2 — Right-click Open (may not work on all macOS versions)**

Some older macOS versions let you bypass Gatekeeper from the dialog:

1. In **Applications**, **right-click** (Control-click) **GW2onMac**.
2. Choose **Open** from the menu (not double-click).
3. If the dialog offers an **Open** button, click it.

If you only see “Apple could not verify…” with **Move to Trash** and **Done** (no **Open**), click **Done** and use **Method 1** above.

**Method 3 — Remove quarantine (Terminal)**

If Privacy & Security does not show an **Open Anyway** option (uncommon):

```bash
xattr -dr com.apple.quarantine /Applications/GW2onMac.app
```

Then try opening the app again, or repeat Method 1.

### Is it safe?

Only download from the official repo:

**https://github.com/Warzuponus/GW2onMac/releases**

The app is open source — you can inspect the code in this repository. Unsigned distribution is a cost limitation, not a sign the app is malicious.

---

## Step 1 — Get GW2onMac

### Option A: Download a release (recommended)

Download the latest release from:

**https://github.com/Warzuponus/GW2onMac/releases/latest**

1. Under **Assets**, download **`GW2onMac-<version>.dmg`**.
2. *(Optional)* Check the download against the `.sha256` file next to it: `shasum -a 256 ~/Downloads/GW2onMac-*.dmg`
3. Open the DMG and drag **GW2onMac** to **Applications**.
4. Follow [macOS security warning (expected)](#macos-security-warning-expected) above to open the app the first time.

### Option B: Build from source (developers)

See [README.md](../README.md#for-developers).

---

## Step 2 — Install Rosetta 2

GW2onMac’s Wine runtime is built as **x86_64** (Intel) code — the same approach used by CrossOver and most macOS Wine builds with D3DMetal support. On Apple Silicon, that means Wine runs under **Rosetta 2**, Apple’s one-time system translator.

Rosetta is **not related to your Guild Wars 2 install** — even if you import an existing GW2 folder, Wine still needs Rosetta to run `wine64` and `Gw2-64.exe`.

1. In the setup wizard, find **Rosetta 2**.
2. Click **Install Rosetta** if it is not already installed — or skip this step; GW2onMac **installs Rosetta automatically** when you download the runtime, create the prefix, or install/import GW2.
3. macOS may ask for your password. Wait until the step shows a green checkmark.

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

Already have `Libraries.tar.gz` (e.g. downloaded on another Mac)? Click **Import Runtime…** and select it instead.

---

## Step 4 — Install Apple Game Porting Toolkit (D3DMetal)

Guild Wars 2 uses **DirectX 11**. On Mac, that requires Apple’s **D3DMetal** libraries from the Game Porting Toolkit. GW2onMac cannot bundle these files — you must download them from Apple under their license, but the app can install them for you.

### 4a. Download GPTK from Apple

1. Sign in at **https://developer.apple.com/download/all/** (free Apple Developer account)
2. Search for **Game Porting Toolkit**
3. Download **Game Porting Toolkit 4.x** (e.g. `Game_Porting_Toolkit_4.0_1_beta_1.dmg`)
4. Double-click the downloaded `.dmg` to open it in Finder (leave it open)

### 4b. Install with GW2onMac (recommended)

1. Complete **Step 3** (Wine runtime) first.
2. In the setup wizard, on the **D3DMetal (GPTK)** row, click **Install GPTK**.
3. If auto-detect does not find your download, click **Choose File…** and select the GPTK `.dmg`.
4. Enter your Mac password when prompted — GW2onMac installs **Metal Shader Converter** and copies **D3DMetal.framework** into the Wine runtime.
5. The step should show a green checkmark when finished.

GW2onMac looks for GPTK on mounted volumes (e.g. `/Volumes/Game Porting Toolkit`) and in **Downloads**. It copies **D3DMetal.framework**, **libd3dshared.dylib**, and GPTK’s D3DMetal Wine DLLs (`lib/wine/x86_64-windows` and `x86_64-unix`) into the runtime — all are required for DirectX 11.

> **Re-run Install GPTK after Update Runtime.** Updating the runtime replaces the `Libraries` folder, including the GPTK files. The GPTK row turns unchecked again; click **Install GPTK** once more.

### 4c. Manual install (advanced)

If you prefer to install by hand, see the table below. You only need **Metal Shader Converter** and the GPTK `redist/lib` files — not the full evaluation Wine environment.

| Item in the GPTK folder | Needed for GW2onMac? |
|-------------------------|----------------------|
| **Evaluation environment for Windows games … .dmg** | **Yes** — contains `redist/lib/external/` (D3DMetal) and `redist/lib/wine/` (Wine DLLs) |
| **Metal Shader Converter … .pkg** | **Yes (recommended)** |
| Mac Remote Developer Tools … .pkg | No |
| `gptk-sample`, `metal-cpp` | No |

Copy `redist/lib/external/` and `redist/lib/wine/x86_64-{windows,unix}/` into the matching folders under:

`~/Library/Application Support/com.gw2onmac.app/Libraries/Wine/lib/`

The easier way is the bundled helper script, which does exactly that:

```bash
"/Applications/GW2onMac.app/Contents/Resources/install-gptk.sh"
```

### Alternative: Homebrew (advanced)

Some users install GPTK via Homebrew’s `game-porting-toolkit` cask. If D3DMetal is on your system, GW2onMac may detect it automatically. Copying the framework into `lib/external/` is the most reliable method.

---

## Step 5 — Create the GW2 prefix

A “prefix” is a Windows-like environment where GW2 runs.

1. In the setup wizard, click **Create Prefix**.
2. Wait until the **GW2 prefix** step shows a green checkmark.

### What to expect (this can take a minute)

**Create Prefix** runs Wine’s first-time setup (`wineboot`) in the background. A few things are normal:

- **A Terminal or command window may flash or appear behind GW2onMac** — Wine is initializing the prefix. You can ignore it; it should close on its own.
- **macOS may ask to install Rosetta 2** — Wine runs as x86_64 code on Apple Silicon. If you skipped **Install Rosetta** in Step 2, macOS may pop up its own dialog saying a component is required. Click **Install** (or **Continue**) and wait for Rosetta to finish. The helper window may close and **GW2onMac can look frozen for 30–60 seconds** while Wine finishes — that is normal.
- **The prefix row may stay unchecked for a bit** — do not click **Create Prefix** again. Wait until the checkmark appears, then click **Refresh** if needed.

If prefix creation fails after several minutes, make sure **Rosetta 2** and **D3DMetal (GPTK)** both show green checkmarks first, then try **Create Prefix** again.

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

- Click **Repair launcher** (clears a stale lock file and refreshes display settings).
- Try lowering in-game graphics settings (see [RUNTIME.md](RUNTIME.md#performance)).
- Run the same launch script that **Play** uses from Terminal to see its error output:

  ```bash
  bash "/Applications/GW2onMac.app/Contents/Resources/launch-gw2.sh"
  ```

---

## Troubleshooting

| Problem | What to try |
|---------|-------------|
| “Wine runtime not installed” | Click **Download Runtime** again |
| “Unable to initialize 3D output” / DirectX 11 error | Click **Install GPTK** again (v1.1.0+ also installs GPTK’s Wine DLLs, which older versions skipped). Make sure the D3DMetal row is green |
| D3DMetal row unchecked after updating GW2onMac or the runtime | Expected — click **Install GPTK** again (keep the GPTK `.dmg` in Downloads or mounted) |
| “D3DMetal not found” | Mount the GPTK `.dmg`, then **Install GPTK** or **Choose File…** |
| Launcher UI garbled / missing text | Click **Repair launcher**, then **Play** again |
| **Create Prefix** fails | Install Rosetta and GPTK first (both rows green), then try again |
| **Create Prefix** seems stuck / app frozen | Wait 1–2 min after any Rosetta dialog; Wine is still running `wineboot` |
| “Failed to download Gw2Setup” / HTTP 404 | Use **Import…** with an existing GW2 folder, or download `Gw2Setup-64.exe` from ArenaNet and report the issue |
| Game installs but Play is disabled | Click **Refresh** |
| Very low FPS on 16 GB Mac | Lower character models, shadows, reflections in-game ([tips](RUNTIME.md#in-game-settings-16-gb-macs)) |
| macOS blocks GW2onMac (“could not verify”) | Click **Done** (not **Move to Trash**), then **Privacy & Security** → scroll down → **Open Anyway** |
| Something else | Run the launch script Play uses from Terminal to see its errors (below), and [open an issue](https://github.com/Warzuponus/GW2onMac/issues) with the output |

---------|-------------|
| “Wine runtime not installed” | Click **Download Runtime** again |
| Launcher UI garbled / missing text / wrong click targets | Ensure **DirectX 11 in-game** is **off** (default in v0.1.11). Or launch via `./Scripts/launch-gw2.sh` — matches original TyriaSilicon dev scripts (no CrossOver env vars) |
| “Unable to initialize 3D output” / DirectX 11 error **in-game** (after login) | Turn **on** “DirectX 11 in-game”, or run `GW2ONMAC_D3DMETAL=1 ./Scripts/launch-gw2.sh` |
| “Unable to initialize 3D output” / DirectX 11 error | Re-run **Install GPTK** (needs `libd3dshared.dylib` + D3DMetal.framework). Update to GW2onMac **v0.1.6+** |
| `winetricks` / font install errors on Play or Repair | **v0.1.9+** no longer blocks launch on font install. Update GW2onMac and click **Play** |
| “D3DMetal not found” | Re-run **Install GPTK** or copy GPTK `redist/lib/external/` into Wine `lib/external/` |
| “Create Prefix” fails | Install Rosetta + D3DMetal first |
| **Create Prefix** seems stuck / app frozen | Wait 1–2 min after any Rosetta install dialog; Wine is still running `wineboot` |
| Rosetta popup during **Create Prefix** | Click **Install** in the system dialog, or install Rosetta in Step 2 first |
| “Failed to download Gw2Setup” / HTTP 404 | ArenaNet retired the old `download.guildwars2.com` link — update to GW2onMac **v0.1.5+**, or use **Import…** if you already have GW2 |
| Game installs but Play is disabled | Click **Refresh** |
| Very low FPS on 16 GB Mac | Lower character models, shadows, reflections in-game |
| First launch: “could not verify” dialog | Click **Done** (not **Move to Trash**), then **System Settings → Privacy & Security** → scroll down → **Open Anyway** |
| macOS blocks GW2onMac (“could not verify”) | Click **Done** on the first dialog, then **Privacy & Security** → scroll down → **Open Anyway** |

---

## Where GW2onMac keeps its files

| What | Location |
|------|----------|
| Wine runtime + GPTK files | `~/Library/Application Support/com.gw2onmac.app/Libraries/` |
| GW2 prefix (includes the game install) | `~/Library/Containers/com.gw2onmac.app/GW2/` |
| Logs | `~/Library/Logs/com.gw2onmac.app/` |

Upgraded from the old **TyriaSilicon** builds? GW2onMac finds your existing runtime and prefix under `com.tyriasilicon.app` automatically. To move the prefix to the new location (instant, same-disk move — nothing is copied or deleted), quit the game and run `./Scripts/migrate-legacy-prefix.sh --apply` from a clone of this repo.

### Updating

Download the newer DMG and drag GW2onMac to **Applications**, replacing the old copy. Your runtime, prefix, and game install are kept. If the D3DMetal row turns unchecked, click **Install GPTK** again.

### Uninstalling

1. Drag **GW2onMac** from Applications to the Trash.
2. To free the disk space too, delete the two folders above (`Libraries` and `GW2`). **The `GW2` folder contains your game install (~80 GB).**

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

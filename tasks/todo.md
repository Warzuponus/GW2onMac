# GW2onMac Reset Plan

## Acceptance Criteria
- Preserve the currently working local `Scripts/launch-gw2.sh` path and existing local runtime artifacts.
- Identify regressions introduced by GitHub/release automation and app launch flow.
- Keep changes small and reversible; do not delete working local runtime/prefix data.
- Verify with Swift build and script checks where possible.

## Checklist
- [x] Locate project and inspect known-good script path.
- [x] Compare current app behavior against known-good script behavior.
- [x] Implement minimal reset toward script-first launch/install behavior.
- [x] Verify build/script behavior.
- [x] Record results and remaining blockers.

## Working Notes
- Manual `Scripts/launch-gw2.sh` still works using legacy bundle `com.tyriasilicon.app`.
- Current app launches installed `Gw2-64.exe` via `GW2ShellLauncher`, but `Gw2Setup-64.exe` still uses generic `Wine.runProgram`.
- Avoid deleting `dist/Libraries.tar.gz`, `build/wine`, Appli# GW2onMac Reset Plan

## Acceptance Criteriut
## Acceptance Criteon.

## Results
- Routed both `Gw2-64.exe` and `Gw2Setup-64.exe` through the same shell-script launch environment.
- Added `GW2ONMAC_EXECUTABLE` support to repo and bundled launch scripts while keeping default manual launch behavior unchanged.
- Verified `swift build --package-path GW2Kit` passes.
- Verified `bash -n` passes for repo and bundled `launch-gw2.sh`.

## Remaining Blockers
- I did not launch the actual game/installer from the app during this pass to avoid disturbing your working Wine session.
- Next manual check: build/run app in Xcode, click Install GW2 or Play, confirm it logs/launches through `launch-gw2.sh`.

# Code signing (optional — not used for releases)

GW2onMac is distributed **unsigned** on purpose. A paid [Apple Developer Program](https://developer.apple.com/programs/) membership ($99/year) is required for code signing and notarization, and this project does not use one.

**Players:** see [INSTALL.md — macOS security warning](INSTALL.md#macos-security-warning-expected) for how to open the app. The Gatekeeper warning is expected.

The notes below are only for maintainers who choose to sign builds locally or in CI.

---

## What signing would provide

| Build type | User experience |
|------------|-----------------|
| Unsigned (current) | Gatekeeper blocks first launch — click **Done** on the warning, then **Privacy & Security → Open Anyway** ([INSTALL.md](INSTALL.md#macos-security-warning-expected)) |
| Signed + notarized | Opens without warning |

---

## Optional: sign and notarize locally

### Requirements

- Apple Developer Program ($99/year)
- Developer ID Application certificate
- App-specific password or notary API key

### Create a Developer ID Application certificate

1. Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority
2. [Apple Developer portal](https://developer.apple.com/account/resources/certificates/list) → **Developer ID Application** → upload CSR → install `.cer`

### Sign and notarize a DMG

```bash
# After building GW2onMac.app and creating a DMG:
codesign --force --options runtime --sign "Developer ID Application: Your Name (TEAMID)" \
  --entitlements GW2onMac/GW2onMac.entitlements GW2onMac.app

./Scripts/package-dmg.sh GW2onMac.app GW2onMac.dmg

xcrun notarytool store-credentials "GW2onMac" \
  --apple-id "you@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "your-app-specific-password"

xcrun notarytool submit GW2onMac.dmg --keychain-profile "GW2onMac" --wait
xcrun stapler staple GW2onMac.dmg
```

### Optional: CI signing via GitHub Secrets

The [release-app workflow](../.github/workflows/release-app.yml) supports signing when these secrets are set. They are **not required** — releases build unsigned DMGs by default.

| Secret | Purpose |
|--------|---------|
| `APPLE_CERTIFICATE_BASE64` | Base64 `.p12` export |
| `APPLE_CERTIFICATE_PASSWORD` | `.p12` password |
| `KEYCHAIN_PASSWORD` | CI keychain password |
| `APPLE_SIGNING_IDENTITY` | e.g. `Developer ID Application: Name (TEAMID)` |
| `APPLE_ID` | Apple ID email |
| `APPLE_NOTARY_PASSWORD` | App-specific password |
| `APPLE_TEAM_ID` | Team ID |

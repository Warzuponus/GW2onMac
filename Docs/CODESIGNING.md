# Code signing and notarization

macOS Gatekeeper blocks or warns about apps that are not signed and notarized. For public distribution, you should sign GW2onMac with a **Developer ID Application** certificate and submit it to Apple for notarization.

## What you need

| Requirement | Cost | Purpose |
|-------------|------|---------|
| [Apple Developer Program](https://developer.apple.com/programs/) membership | $99/year | Issue distribution certificates |
| **Developer ID Application** certificate | Included | Sign the `.app` for distribution outside the Mac App Store |
| App-specific password or notary API key | Free | Upload builds to Apple's notary service |
| Team ID | Included | Identifies your developer account |

Personal/free Apple IDs can sign for local development, but **not** for notarized public distribution.

---

## Step 1 — Enroll in the Apple Developer Program

1. Go to [developer.apple.com/programs](https://developer.apple.com/programs/)
2. Enroll with your Apple ID
3. Note your **Team ID** (Developer portal → Membership details)

---

## Step 2 — Create a Developer ID Application certificate

1. Open **Keychain Access** on your Mac
2. Menu: **Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority**
3. Save the `.certSigningRequest` file
4. Go to [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/certificates/list)
5. Click **+** → **Developer ID Application** → upload the CSR → download the `.cer`
6. Double-click the `.cer` to install it in Keychain

Export for CI (GitHub Actions):

1. In Keychain Access, find **Developer ID Application: Your Name (TEAMID)**
2. Right-click → **Export** → save as `.p12` with a strong password
3. Base64-encode for GitHub Secrets:

```bash
base64 -i DeveloperID.p12 | pbcopy
```

---

## Step 3 — Configure Xcode locally

1. Open `GW2onMac.xcodeproj` in Xcode
2. Select the **GW2onMac** target → **Signing & Capabilities**
3. Set **Team** to your Apple Developer team
4. Ensure **Hardened Runtime** is enabled (already set in the project)
5. For Release builds, use **Developer ID Application** as the signing identity

Build and archive locally:

```bash
xcodebuild -project GW2onMac.xcodeproj \
  -scheme GW2onMac \
  -configuration Release \
  -archivePath build/GW2onMac.xcarchive \
  archive

./Scripts/package-dmg.sh build/GW2onMac.xcarchive/Products/Applications/GW2onMac.app GW2onMac.dmg
```

---

## Step 4 — Notarize locally

### Option A: App-specific password (simplest)

1. Go to [appleid.apple.com](https://appleid.apple.com) → **Sign-In and Security** → **App-Specific Passwords**
2. Generate a password for "GW2onMac notarization"

```bash
xcrun notarytool store-credentials "GW2onMac" \
  --apple-id "you@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"

# Sign the app first, then create DMG, then:
xcrun notarytool submit GW2onMac.dmg --keychain-profile "GW2onMac" --wait
xcrun stapler staple GW2onMac.dmg
```

### Option B: App Store Connect API key (better for CI)

1. [App Store Connect](https://appstoreconnect.apple.com) → Users and Access → Integrations → API Keys
2. Create a key with **Developer** role
3. Download the `.p8` file; note **Key ID** and **Issuer ID**

```bash
xcrun notarytool submit GW2onMac.dmg \
  --key "$PATH_TO_AUTHKEY.p8" \
  --key-id "KEYID" \
  --issuer "ISSUER_UUID" \
  --wait
xcrun stapler staple GW2onMac.dmg
```

---

## Step 5 — GitHub Actions secrets (optional)

Add these in **GitHub → Settings → Secrets and variables → Actions** for the `Warzuponus/GW2onMac` repo:

| Secret | Value |
|--------|-------|
| `APPLE_CERTIFICATE_BASE64` | Base64-encoded `.p12` export |
| `APPLE_CERTIFICATE_PASSWORD` | Password used when exporting `.p12` |
| `KEYCHAIN_PASSWORD` | Any random string (CI keychain only) |
| `APPLE_SIGNING_IDENTITY` | e.g. `Developer ID Application: Your Name (TEAMID)` |
| `APPLE_ID` | Your Apple ID email |
| `APPLE_NOTARY_PASSWORD` | App-specific password |
| `APPLE_TEAM_ID` | 10-character Team ID |

The [release-app workflow](../.github/workflows/release-app.yml) signs and notarizes automatically when these secrets are set. Without them, it builds an **unsigned** DMG (users must right-click → Open).

---

## What users see without notarization

| State | User experience |
|-------|-----------------|
| Unsigned | “cannot be opened because the developer cannot be verified” — must use **Open Anyway** in Privacy & Security |
| Signed, not notarized | Same warning on first launch |
| Signed + notarized | Opens normally after download |

---

## Quick checklist

- [ ] Apple Developer Program enrolled
- [ ] Developer ID Application certificate in Keychain
- [ ] Team set in Xcode project
- [ ] App builds and runs locally with Release signing
- [ ] DMG notarized and stapled
- [ ] GitHub secrets configured (for CI releases)
- [ ] Tag `v0.1.0` pushed → [release-app workflow](../.github/workflows/release-app.yml) publishes DMG

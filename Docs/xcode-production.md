# ScholarsGallery — Xcode production process

This document focuses on shipping the **iOS app target** (`ScholarsGallery`) from `ScholarsGallery.xcodeproj`.

## 1. Configuration matrix

| Area | Debug | Release |
|------|--------|---------|
| API base URL | `http://127.0.0.1:8081` | `https://api.scholarsgallery.app` |
| SwiftUI previews | On | Off |
| dSYM / symbols | Limited | Full (`dwarf-with-dsym`) |
| Swift symbol strip | No | Yes |
| Entitlements | `ScholarsGallery.entitlements` (`aps-environment`: **development**) | `ScholarsGallery.Release.entitlements` (`aps-environment`: **production**) |
| Export compliance (ITS) | Declared via build setting | Same (`ITSAppUsesNonExemptEncryption` = NO) |

Override API URL or generation token per environment in **target → Build Settings** (`INFOPLIST_KEY_*`), or use **`.xcconfig`** files if you introduce multi-environment schemes later.

## 2. Versioning (App Store Connect)

1. In Xcode: target **ScholarsGallery → General** (or Build Settings):
   - **Version** → `MARKETING_VERSION` (user-facing version, e.g. `1.0`).
   - **Build** → `CURRENT_PROJECT_VERSION` (monotonic build number for each upload).
2. Every App Store / TestFlight upload must use a **build number** not used before for that bundle ID.

## 3. Archive and upload

1. Select scheme **ScholarsGallery** and destination **Any iOS Device (arm64)** (or a generic iOS device).
2. **Product → Archive**.
3. In the Organizer: **Distribute App → App Store Connect → Upload** (or **Export** if you use Transporter with an export options plist).
4. Optional CLI export (after a successful archive at `build/ScholarsGallery.xcarchive`):

```bash
xcodebuild -exportArchive \
  -archivePath build/ScholarsGallery.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ci_scripts/ExportOptions-appstore.plist
```

Adjust `ExportOptions-appstore.plist` (`method` is `app-store` for iOS App Store IPAs, `signingStyle`, optional `teamID` / `provisioningProfiles`) to match your Apple Developer account and CI.

### TestFlight automation

- GitHub Actions **CD** now runs after CI on `main`, tags `v*`, and manual dispatch.
- CD resolves a GitHub environment: manual dispatch uses the selected `staging` / `production` value, tags default to `production`, and other runs default to `staging`.
- Unsigned release archives are always produced as artifacts.
- When signing secrets are configured in the selected GitHub environment, the workflow also creates a signed archive, exports an IPA with `ci_scripts/ExportOptions-testflight.plist`, and uploads it to **TestFlight** with `xcrun altool`.
- The current TestFlight-ready feature set includes the on-device **Study Coach** powered by `FoundationModels`, quick-start lesson topics, and the hardened dark-mode contrast/background refresh across scholarship and essay surfaces.
- Required GitHub **environment secrets**:
  - `APP_STORE_CONNECT_ISSUER_ID`
  - `APP_STORE_CONNECT_KEY_ID`
  - `APP_STORE_CONNECT_API_KEY_BASE64`
  - `BUILD_CERTIFICATE_BASE64`
  - `P12_PASSWORD`
  - `BUILD_PROVISION_PROFILE_BASE64`
  - `KEYCHAIN_PASSWORD`
  - Optional: `IOS_TEAM_ID`, `IOS_SIGNING_IDENTITY`

Base64 secrets are expected to contain the raw `.p8`, `.p12`, and `.mobileprovision` files.
If a TestFlight upload is requested and any of these secrets are missing, CD now fails immediately instead of silently skipping the upload.

## 4. Install on a physical iPhone

For direct local installs to a tethered development device such as **Christopher’s iPhone (iPhone 17 Pro Max)**:

1. Build the app for the physical device:

```bash
xcodebuild -project ScholarsGallery.xcodeproj \
  -scheme ScholarsGallery \
  -configuration Debug \
  -destination 'id=<DEVICE_IDENTIFIER>' \
  -derivedDataPath build/device \
  build
```

2. Install the built `.app` bundle with `devicectl`:

```bash
xcrun devicectl device install app \
  --device <DEVICE_IDENTIFIER> \
  build/device/Build/Products/Debug-iphoneos/ScholarsGallery.app
```

Use `xcrun devicectl list devices` to confirm the connected identifier before running the install.

## 5. Symbols and crashes

Release builds produce **dSYMs** for symbolicated crash reports. Ensure **Upload your app’s symbols to Apple** is enabled when distributing (Xcode Organizer default for App Store uploads matches `uploadSymbols` in the export plist).

## 6. Privacy

- `ScholarsGallery/PrivacyInfo.xcprivacy` declares **UserDefaults** access (`CA92.1`) for collection/favorites persistence.
- Update this file if you add APIs that require **required reason** disclosures (file timestamp, disk space, etc.).

## 7. Capabilities checklist before submission

- **iCloud / CloudKit**: container `iCloud.$(CFBundleIdentifier)` must exist in the developer portal and match entitlements.
- **Push**: Release uses **production** APS; ensure the App ID has Push enabled and provisioning profiles are regenerated after entitlement changes.
- **Background modes**: `remote-notification` is declared in `Info.plist` only if you actually implement push handling.

## 8. CI / CD

### GitHub Actions

- `.github/workflows/ci.yml` runs SwiftPM builds, server tests, iOS unit tests, UI tests, and the server smoke script on pushes and pull requests.
- `.github/workflows/cd.yml` runs after CI, uploads release artifacts, builds the server release binary, and uploads to TestFlight when the selected GitHub environment has the required signing secrets.

### Xcode Cloud

- **Post-clone**: `ci_scripts/ci_post_clone.sh` resolves packages, builds **Debug** for the iOS Simulator, then builds **Release** for **generic/iOS** to catch production-only issues early.
- Set **Release** `INFOPLIST_KEY_GENERATION_API_TOKEN` (or inject via **Environment variables** in the workflow) for any server that requires `X-Generation-Token`; never commit production secrets into the repo.

## 9. App Store Connect metadata

Prepare outside Xcode: screenshots, description, keywords, support URL, privacy policy URL, age rating questionnaire, and **Data collection** answers consistent with `PrivacyInfo.xcprivacy`.

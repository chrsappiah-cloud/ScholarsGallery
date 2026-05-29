# Apple App Review — Resolution & Resubmission (Build 7)

Use this document when replying in **App Store Connect → App Review → Resolution Center** and when uploading **build 7** (version **1.0**).

---

## Resolution Center reply (copy/paste)

Hello App Review Team,

Thank you for your feedback on build 6. We have addressed both issues in **build 7** (version 1.0).

**Guideline 2.1(b) — Subscription loading failure**

We removed all in-app purchase and subscription functionality from the app:

- Deleted the StoreKit 2 payment service and subscription UI (paywalls, subscription panel).
- Removed all StoreKit imports and purchase gates from Study Coach and Art Generation Studio. Both features are **fully accessible without any purchase**.
- Removed the **In-App Payments** (Apple Pay merchant) entitlement from the app.
- Removed checkout/payment controls from the in-app Administrator panel.

There are **no subscriptions or IAP products** to load or restore in this build. If IAP metadata still appears in App Store Connect for an earlier submission, please disregard it for build 7 — the binary contains no StoreKit or purchase flows.

**Guideline 2.1(a) — App crashes / bugs**

We hardened exhibition loading when the backend is slow or unavailable:

- **Pull-to-refresh** on the Exhibitions home screen.
- A **Retry** button when loading fails and no cache is available.
- **Cached catalog fallback** — API responses are saved locally and served when the network fails.
- **Graceful empty states** on exhibition detail (Experience, Works, Essay) instead of crashing.
- Connection status via `/api/meta` with a clear “backend unavailable” message when appropriate.

**How to verify (no account required)**

1. Open the app → **Exhibitions** tab. With network on or off, the app should **not crash**; you should see exhibitions, cached content, or an error state with **Retry**.
2. Pull down on Exhibitions to refresh.
3. Open **Studio** → generate artwork (no subscription or paywall).
4. Open **Scholarship** → **Study Coach** (no subscription or paywall).

We verified on **iPhone 17 Pro Max** (simulator and physical device): unit tests and core UI workflow tests pass.

Please let us know if you need a demo account or additional information.

Best regards,  
Scholars Gallery Team

---

## Notes for Review (App Store Connect → App Review Information)

```
No login required.

This build has NO in-app purchases, NO subscriptions, and NO StoreKit flows.
Study Coach and Art Generation Studio are free to use.

Network: The app works offline with cached/bundled content. If https://api.scholarsgallery.app
is unreachable, Exhibitions shows cached data or a Retry UI — it does not crash.

Suggested test path:
1. Exhibitions tab → pull to refresh
2. Tap an exhibition (if shown) or use Studio / Scholarship tabs
3. Studio → Generate (no paywall)
4. Scholarship → Study Coach (no paywall)

Administrator panel (optional): Exhibitions → ⋯ menu → Administrator — operator token not required for review.
```

---

## Before you resubmit (checklist)

### App Store Connect (metadata)

- [ ] Upload **build 7** and select it for the version under review.
- [ ] **Remove or clear** any **In-App Purchases** / **subscriptions** attached to this version (Agreements, Tax, and Banking must be active only if you still sell IAP elsewhere).
- [ ] Confirm **App Privacy** and **Pricing** still match a free app with no IAP.
- [ ] Paste the **Resolution Center reply** above and submit for review.

### Binary (this repo)

- [ ] Build **7** includes: IAP removal (build 6) + checkout/Apple Pay entitlement removal + exhibition resilience.
- [ ] Archive: **Product → Archive** in Xcode, or see commands below.
- [ ] Upload via Organizer or Transporter.

### Optional — CLI archive & export

```bash
cd /Users/christopherappiah-thompson/WebstormProjects/untitled1

xcodebuild -project ScholarsGallery.xcodeproj \
  -scheme ScholarsGallery \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/ScholarsGallery.xcarchive \
  archive

xcodebuild -exportArchive \
  -archivePath build/ScholarsGallery.xcarchive \
  -exportPath build/export-appstore \
  -exportOptionsPlist ci_scripts/ExportOptions-appstore.plist
```

Upload `build/export-appstore/ScholarsGallery.ipa` with **Transporter** or Xcode Organizer.

### CI / TestFlight

Push to `main` and run **CD** workflow (or tag `v*`) with signing secrets configured to upload automatically.

---

## Technical summary (for your records)

| Issue | Fix |
|-------|-----|
| 2.1(b) Subscription load failure | Removed StoreKit, paywalls, subscription panel; removed `com.apple.developer.in-app-payments` entitlement; admin checkout toggle removed from app UI |
| 2.1(a) Crashes / bugs | Pull-to-refresh, Retry, cache fallback, graceful exhibition detail states, meta connectivity banner |

**Verification:** 104 unit tests; E2E UI workflow tests on simulator and physical iPhone.

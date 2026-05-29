# Apple Review Response

## Guideline 2.1(b) — Subscription Loading Failure

**Resolution: Removed all In-App Purchase functionality**

We identified that the subscription/IAP system relied on StoreKit 2 `Product.products(for:)` which could fail under certain network or sandbox conditions, causing the subscription panel to hang. To eliminate this failure surface entirely, we have:

- **Deleted** `StoreKitPaymentService.swift` — the entire StoreKit 2 payment service layer
- **Deleted** `UserSubscriptionPanelView.swift` — the subscription UI panel
- **Removed** all StoreKit imports and paywall views from `ContentView.swift`:
  - `CoachSubscriptionPaywallView` — removed paywall for the Study Coach section
  - `StudioPaywallBanner` / `StudioPaywallSheet` — removed paywall for Art Generation Studio
  - `StoreKitPaymentService.shared` references from `ScholarshipHomeView` and `GenerationStudioView`
- **Deleted** associated test files: `StoreKitPaymentServiceLogicTests.swift`, paywall UI tests (`SubscriptionPanelUITests`)
- **Removed** `hasMonitorAccess`, `hasStudioAccess`, and `paymentCancellable` from `GalleryBackendMetaModel`

All features (Study Coach, Art Generation Studio) are now **fully accessible** without any subscription or purchase requirement.

## Guideline 2.1(a) — App Crashes / Bugs

**Resolution: Made exhibition loading resilient to backend unavailability**

We audited the exhibition loading pipeline and added multiple layers of defense against backend failures:

- **Pull-to-refresh** (`.refreshable`) on the exhibitions home screen — users can manually retry loading when connectivity returns
- **Retry button** in the error state — when exhibitions fail to load with no cached data, a prominent "Retry" button appears
- **Meta refresh coordination** — pulling to refresh now also calls `GalleryBackendMetaModel.refresh()` to update the connection status banner in real time
- **Existing protections** (verified intact):
  - All API calls (`fetchExhibitions`, `fetchManifest`, `fetchEssay`, `fetchArtworks`) save to `UserDefaults`-backed cache on success and fall back to cache on failure
  - Exhibition detail view shows graceful "unavailable" states per segment (Experience, Works, Essay) when data cannot be loaded
  - `GalleryBackendMetaModel` shows a "Backend unavailable" banner when `/api/meta` cannot be reached
  - 10-second request timeout with 20-second resource timeout on all API calls

## Build Verification

- Builds successfully with `xcodebuild` (exit code 0)
- 104 unit tests pass (Swift Testing framework)
- All core E2E UI workflow tests pass on iPhone 17 Pro Max simulator

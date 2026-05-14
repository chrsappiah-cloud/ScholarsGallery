# Xcode Workspace Setup

1. In Xcode, choose `File > New > Workspace...` and name it `ScholarsGallery`.
2. Save the workspace at the root of this repository.
3. Add `Package.swift` (root) into the workspace.
4. Let Xcode resolve Swift Package dependencies.
5. Build and run the `ScholarsGalleryServer` scheme to start the backend.
6. Open `ScholarsGallery.xcodeproj` in the same workspace and run the iOS app target.

## Local API Notes

- Default backend URL: `http://127.0.0.1:8081` (override with **`PORT`** and **`BIND_HOST`** env vars on the server process; defaults remain `8081` / `127.0.0.1`. Use **`BIND_HOST=0.0.0.0`** when a physical device on your LAN must reach the Mac’s IP.)
- Quick verify: `./Scripts/smoke_verify_server.sh` (starts Vapor on a high port, curls `/health`, exhibitions, artworks).
- Health check: `GET /health`
- Exhibitions: `GET /api/exhibitions`
- Manifest: `GET /api/exhibitions/:slug/manifest`
- Essay: `GET /api/essays/:id`
- Generation intake: `POST /api/artworks/generate`
- Checkout handoff: `POST /api/checkout/:editionID`

## Image Generation

- App includes a `Studio` tab for prompt-based image generation.
- Server uses `OPENAI_API_KEY` when present and falls back to a mock image URL during local development.
- Generated artwork history is persisted in `Server/Data/generated-artworks.json`.
- Run server with:
  - `OPENAI_API_KEY=<your-key> swift run ScholarsGalleryServer`
  - or without the key for offline/mock development.

### Optional production hardening env vars

- `GENERATION_API_TOKEN` (required header for `POST /api/artworks/generate` and `GET /api/artworks/generated` when set)
- `GENERATION_RATE_LIMIT_PER_MINUTE` (default: `20`)
- `GENERATED_ARTWORKS_STORE_PATH` (default: `Server/Data/generated-artworks.json`)

## Quality checks

- Run local build + tests with:
  - `./ci_scripts/run_quality_checks.sh`
- Run SwiftPM tests **and** iOS UI tests (requires Xcode + simulator):
  - `RUN_UI_TESTS=1 ./ci_scripts/run_quality_checks.sh`
- Run **only** UI tests:
  - `./ci_scripts/run_ui_tests.sh`
  - Optional: `IOS_TEST_DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro' ./ci_scripts/run_ui_tests.sh`

## UI tests (Studio)

- `ScholarsGalleryUITests` uses launch environment variables so Studio flows do not require a running API:
  - `UITEST_GENERATE_MODE=success` — mock successful generation and recent list
  - `UITEST_GENERATE_MODE=error` — mock failure message
  - `UITEST_RECENT_GENERATIONS_JSON` — optional JSON array of `GeneratedArtwork` records (ISO8601 `createdAt`), loaded on Studio appear

### App token header

- iOS app reads `GENERATION_API_TOKEN` from build settings and sends it as `X-Generation-Token`.
- Keep this empty for local dev unless you set `GENERATION_API_TOKEN` on server.

## Environment-specific app API hosts

- `Debug` builds read `GALLERY_API_BASE_URL=http://127.0.0.1:8081` from build settings.
- `Release` builds read `GALLERY_API_BASE_URL=https://api.scholarsgallery.app`.
- You can override these in target build settings without changing source code.

## Localization

- UI strings live in `ScholarsGallery/Localizable.xcstrings` (String Catalog).
- The catalog includes **45 locales** (English plus major world and regional languages). Keys use stable identifiers such as `tab.exhibitions`, `studio.generateArtwork`, `error.networkCached`.
- To regenerate the catalog after editing `Scripts/build_localizable_catalog.py`, run `python3 Scripts/build_localizable_catalog.py`.
- **API content** (exhibition titles, essays, artwork labels) still follows whatever language the server returns; this pass localizes the **app chrome** and system error strings.

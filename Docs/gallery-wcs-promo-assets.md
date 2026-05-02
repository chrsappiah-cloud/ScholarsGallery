# WCS social promo images in the gallery

The exhibition **Worlds Written in Light** loads artworks from `GET /api/exhibitions/worlds-written-in-light/artworks`. Those entries now point at four static PNGs served by the Vapor app:

| File | Artwork title |
|------|----------------|
| `promo_three_apps_suite_1080.png` | WCS — Three Apps Suite |
| `promo_explore_wcs_1080.png` | Explore WCS |
| `promo_wcs_platform_1080.png` | WCS Platform |
| `promo_ethereal_veil_1080.png` | Ethereal Veil |

## Install the binaries (required once per clone)

The repo does not store multi‑MB PNGs by default. Copy them from your **WCS_Social_Promo_Three_Apps** folder (e.g. on the Desktop):

```bash
chmod +x Scripts/sync_wcs_promo_assets.sh
./Scripts/sync_wcs_promo_assets.sh
```

Or start the server in one step (syncs promos when the Desktop folder exists, then runs Vapor):

```bash
chmod +x Scripts/run_local_server.sh
./Scripts/run_local_server.sh
```

Shorter entry points (after `chmod +x` once):

- **Repo root** (`/Applications/ScholarsGallery`): `./dev`
- **Xcode app folder** (`…/ScholarsGallery/ScholarsGallery`): `./run-vapor-server.sh` (finds the parent that contains `Package.swift`)

Or set a custom source directory:

```bash
WCS_PROMO_SOURCE="$HOME/path/to/WCS_Social_Promo_Three_Apps" ./Scripts/sync_wcs_promo_assets.sh
```

Files are written to `Server/Public/media/wcs-social-promo/`. The server uses `FileMiddleware` on `Server/Public/` (see `configure.swift`), so URLs look like:

`http://127.0.0.1:<port>/media/wcs-social-promo/promo_three_apps_suite_1080.png`

Static files are served from **`Server/Public/`** resolved via `ServerPaths` (relative to `Server/Sources/App`), so `swift run ScholarsGalleryServer` works from any working directory as long as the `Server` tree is intact.

The generation “database” defaults to **`Server/Data/generated-artworks.json`** (same path logic); override with **`GENERATED_ARTWORKS_STORE_PATH`** for an absolute file path.

## Optional: commit the PNGs

If you want a self-contained repo, run the script once, then `git add Server/Public/media/wcs-social-promo/*.png` and commit (watch total repo size).

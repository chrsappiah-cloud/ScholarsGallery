# ScholarsGallery

iOS app (`ScholarsGallery.xcodeproj`) plus a **Vapor** backend (`ScholarsGalleryServer` in `Package.swift`).

**Recommended:** open **`ScholarsGallery.code-workspace`** in Cursor (double-click or *File → Open Workspace from File…*) so the workspace folder is the **repo root**. Agent/terminal conventions: see **`AGENTS.md`**.

If you only open the **inner** `ScholarsGallery` app folder in Cursor, use the tasks under **`ScholarsGallery/.vscode/`** (same *Run Task* names); the integrated terminal **`cwd`** is set to the **repo parent** so `make server` and SwiftPM paths work.

## Run the API locally

**Cursor / VS Code:** `Terminal → Run Task…` → **ScholarsGallery: Run Vapor server** (works from repo root or the inner `ScholarsGallery` app folder).

```bash
make server
```

Same as `./dev`: optional WCS promo sync, then `swift run ScholarsGalleryServer` on **http://127.0.0.1:8080** (override with `PORT` / `BIND_HOST`). Optional: copy **`.env.example`** to **`.env`** in the repo root; `Scripts/run_local_server.sh` sources `.env` before starting the server.

### End-to-end API surface

| Client (iOS) | Server route | Notes |
|--------------|--------------|--------|
| Exhibitions list | `GET /api/exhibitions` | Includes `manifestURL` |
| Room manifest | `GET` manifest URL from exhibition | JSON rooms / artwork IDs |
| Scholarship list | `GET /api/essays` | Summaries |
| Essay detail | `GET /api/essays/:id` | Markdown body |
| Exhibition artworks | `GET /api/exhibitions/:slug/artworks` | Hero + thumbnail URLs under `/media/...` |
| Studio generate | `POST /api/artworks/generate` | Optional `X-Generation-Token`, body `{ prompt, artistID }` |
| Studio history | `GET /api/artworks/generated?limit=…` | Same auth header when configured |
| Checkout | `POST /api/checkout/:editionID` | Returns `checkoutURL` |
| Connectivity / ops | `GET /api/meta` | `ok`, `persistence`, `catalog`, `hasOpenAI`, `version`, **`checkoutEnabled`**, **`generationEnabled`**, `announcement`, **`adminPanelConfigured`**, **`dolaAssistantConfigured`**, **`dolaAssistantEnabled`** — no auth |
| Dola assistant | `POST /api/dola/assist` | Body `{ prompt, mood?, intent? }` → `{ refinedPrompt, suggestions[], palette[], provider }` (uses OpenAI when `OPENAI_API_KEY` is set, mock otherwise) |
| Admin overview | `GET /api/admin/overview` | Header **`X-Admin-Token`** (must match server **`ADMIN_API_TOKEN`**); also returns `dolaAssistantConfigured` / `dolaAssistantProvider` |
| Admin policy | `GET /api/admin/policy` · `PUT /api/admin/policy` | Same header; body is `{ checkoutEnabled, generationEnabled, announcement, dolaAssistantEnabled }` (persisted to `Server/Data/admin-policy.json` by default) |

### Operator policy (checkout & Studio access)

The server enforces **payment** and **generation** gates from persisted policy:

- **`POST /api/checkout/…`** returns **403** when `checkoutEnabled` is `false`.
- **`POST /api/artworks/generate`** returns **403** when `generationEnabled` is `false`.
- **`POST /api/dola/assist`** returns **403** when `dolaAssistantEnabled` is `false`.

Set **`ADMIN_API_TOKEN`** in the server environment so **`/api/admin/*`** is enabled. In the iOS app, open **Exhibitions → overflow (⋯) → Administrator…**, paste the same token, **Load server overview**, adjust toggles (including **Dola assistant**), **Save policy to server**. Optional **`announcement`** is shown on the Exhibitions tab when set.

See **`.env.example`** for `ADMIN_API_TOKEN`, optional `ADMIN_POLICY_PATH`, and Dola overrides (`DOLA_ASSISTANT_MODEL`, `DOLA_ASSISTANT_PROVIDER`).

### Dola: Smart AI Assistant (image-generation helper)

Dola refines loose ideas into vivid prompts before the iOS Studio sends them to `POST /api/artworks/generate`. The server route is **`POST /api/dola/assist`** and is gated by the `dolaAssistantEnabled` policy flag (default `true`).

- **Provider:** uses OpenAI Chat Completions when `OPENAI_API_KEY` is set (model from `DOLA_ASSISTANT_MODEL`, default `gpt-4o-mini`); otherwise returns deterministic mock answers so first-runs and tests work offline. Force the mock provider by setting `DOLA_ASSISTANT_PROVIDER=mock`.
- **iOS:** Studio shows an **Ask Dola** button above the *Generate* button. The Dola sheet collects an idea, mood, and intent, returns a refined prompt + suggestion chips + palette swatches, and lets the user commit any choice back into the prompt editor with one tap.
- **Operator gate:** turn Dola off site-wide from the Administrator panel; iOS hides the **Ask Dola** button immediately on next `/api/meta` refresh.

### Optional: Supabase for generation history

By default the server writes `Server/Data/generated-artworks.json`. To use **Supabase Postgres** instead, set:

- `SUPABASE_URL` — project URL (e.g. `https://xxxx.supabase.co`)
- `SUPABASE_SERVICE_ROLE_KEY` — service role key (server only; never ship to the app)

Apply the SQL migrations under `supabase/migrations/` (at minimum `20260501120000_generated_artworks.sql` and `20260501140000_catalog.sql` when using Supabase), e.g. `supabase db push` or paste in the SQL editor. The iOS app keeps talking only to your Vapor host; the server is the only component that calls Supabase.

When `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are set, **catalog** routes (`/api/exhibitions`, manifest, essays, exhibition artworks) are served from Postgres; otherwise they use the same bundled static data as before.

From the **inner** Xcode app folder (`ScholarsGallery/ScholarsGallery`):

```bash
./run-vapor-server.sh
```

From **repo root** (same script):

```bash
./ScholarsGallery/run-vapor-server.sh
```

## Verify the server

```bash
make smoke
```

## Server tests (SwiftPM)

```bash
make test
```

## iOS unit tests (Xcode)

Requires Xcode and an available Simulator (default: **iPhone 17**).

```bash
make ios-test
```

## iOS UI tests (Xcode)

Runs **`ScholarsGalleryUITests`** with **parallel testing disabled** by default (fewer Simulator crashes such as Mach **-308** / lost test-runner connection). Override if you want the scheme’s default parallelism:

```bash
make ios-ui-test
# or: IOS_PARALLEL_UI_TESTS=1 ./ci_scripts/run_ui_tests.sh
```

Run unit tests then UI tests:

```bash
make ios-test-all
```

### Debugger: `mach_msg2_trap`

Seeing **`libsystem_kernel.dylib` `mach_msg2_trap`** while paused in Xcode is normal: the thread is waiting in the kernel for the next Mach message (run loop, IPC, etc.). Inspect frames **above** that symbol if you are diagnosing a real hang.

## Troubleshooting

- **Terminal shows one mangled line** (e.g. `cd ...chmod...swift...` with no spaces): kill that terminal (**Command Palette → “Terminal: Kill Active Terminal Instance”**), open a **new** terminal, then use **`make server`** or **Run Task → ScholarsGallery: Run Vapor server** — do not paste several shell commands as a single word.
- **`Permission denied` on `*.sh`:** from repo root run **`make chmod-scripts`**.
- **`Another instance of SwiftPM is already waiting on .build`:** stop other **`swift test` / `swift build`** jobs (or stuck Xcode builds), or reboot the machine if a zombie `swift` process holds the lock; only one SwiftPM client should use the repo’s **`.build`** at a time. As a workaround, run **`make test-isolated`** or **`make build-server-isolated`** (uses **`.build-isolated`**, gitignored).

## Docs

- [Xcode + API setup](Docs/xcode-workspace-setup.md)
- [WCS promo static assets](Docs/gallery-wcs-promo-assets.md)
- [Production / archive](Docs/xcode-production.md)

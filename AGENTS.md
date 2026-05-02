# Agent / contributor notes

## Shell and terminal

- **Never** paste multiple shell commands as one string (e.g. `cd …chmod…./script…swift run…`). Use **newlines** or **`&&`**, or run **`make server`** / **`make smoke`** from the repo root.
- Prefer **Tasks: Run Task → ScholarsGallery: Run Vapor server** in Cursor/VS Code instead of hand-typing long commands.

## Repo layout

- **SwiftPM root** (where `Package.swift` lives): repository root `ScholarsGallery/`.
- **iOS app**: `ScholarsGallery/ScholarsGallery.xcodeproj` and sources under `ScholarsGallery/ScholarsGallery/`.
- **Vapor server**: target `ScholarsGalleryServer`, sources under `Server/Sources/App/`.

## Quick commands (from SwiftPM root)

```bash
make chmod-scripts   # if *.sh is not executable
make server          # Vapor on http://127.0.0.1:8080 by default
make smoke           # HTTP smoke test
make test            # SwiftPM tests (run one at a time; see README if .build is locked)
make test-isolated   # same tests, build path .build-isolated (bypasses .build lock)
```

Operator **`ADMIN_API_TOKEN`**, persisted policy, the iOS **Administrator** sheet, and the **Dola Smart AI Assistant** (`POST /api/dola/assist`, `DOLA_ASSISTANT_MODEL`, `DOLA_ASSISTANT_PROVIDER`) are documented in **`README.md`** (API table + “Operator policy” + “Dola”).

Open **`ScholarsGallery.code-workspace`** for a stable workspace root, or rely on **`ScholarsGallery/.vscode/settings.json`** when only the inner app folder is opened.

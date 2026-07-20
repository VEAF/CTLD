# 05 — `tui` command + packaging (exe without lupa)

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

Wire the TUI into the CLI and the distribution.

- New **`ctld-tools tui`** sub-command (typer): launches the app; no args needed (embedded
  reference); optional `--yaml` (open a file), optional `--src` (dev override).
- **`pytest-asyncio`** added to dev dependencies (for the Pilot smoke test).
- **`release.yml`**: build the `.exe` with **textual** bundled and the reference bundle present;
  confirm the exe **no longer includes lupa** at runtime. Verify the TUI runs from the one-file build.

## Acceptance criteria

- [ ] `ctld-tools tui` launches the app; `--yaml` / `--src` optional.
- [ ] `release.yml` produces an exe that runs `tui` (textual works from PyInstaller one-file).
- [ ] The exe does not bundle lupa (reference is data-only at runtime).
- [ ] `pytest-asyncio` in dev deps; quality gate green.

## Blocked by

Ticket 04.

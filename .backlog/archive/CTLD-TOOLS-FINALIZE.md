# CTLD-TOOLS-FINALIZE

**Status:** ✅ merged (PR #48). Compacted from `CTLD-TOOLS-FINALIZE/` on 2026-08-01; the ticket files live on in git history.

Finalize `ctld-tools`: **gen-au-build** (`merge_CTLD.ps1` regenerates `CTLD_config_defaults.lua` via `ctld-tools`, now a git-ignored artifact; CI/release gain setup-python; drift check dropped) + build & attach **`ctld-tools.exe`** (separate isolated job, verified) + dedicated MM doc page `ctld-tools.md` (EN+FR).

## Tickets

_No ticket files._

## PRD

Status: ready

## PRD — CTLD-TOOLS-FINALIZE

> Finalisation du programme `ctld-tools` (voir [ADR 0009](../../dev/adr/0009-external-yaml-authoring-ctld-tools.md)),
> demandée par le maintainer après les lots 1–3.

### Problem Statement

Three loose ends after `CTLD-TOOLS-USERCONFIG`:

1. The engine-config workflow used **committed generated Lua + a drift check**. Editing the config
   meant a manual `gen-config` step; forgetting it produced a CI round-trip. The maintainer prefers
   the build to regenerate the Lua itself.
2. `ctld-tools.exe` was wired into `release.yml` but **never actually built/tested**, and only as an
   isolated best-effort step.
3. The Mission Maker had no **dedicated documentation page** for `ctld-tools` — only a tip.

### Solution

- **gen-au-build**: `merge_CTLD.ps1` regenerates `src/CTLD_config_defaults.lua` from
  `CTLD_config.yaml` via `ctld-tools gen-config` on every build. The generated Lua is a git-ignored
  artifact. Consumers that need it (build, busted loader, release) generate it; a `conftest.py`
  fixture does so for the Python tests. The drift check is dropped.
- **`ctld-tools.exe`**: built and verified (PyInstaller with lupa + the datamine bundled), and
  attached to each Release by a **separate `build-exe` job** so a packaging failure never blocks the
  `CTLD.lua` release.
- **Docs**: a dedicated bilingual `mission-maker/ctld-tools.md` page, detailed with examples.

### Implementation Decisions

- `merge_CTLD.ps1` calls `poetry run ctld-tools gen-config` before merging; aborts with a clear
  message if poetry is missing. The build (and the busted job) therefore require Python + poetry.
- `ci.yml` `build` (Windows) and `busted` (Ubuntu) jobs, and `release.yml`, add `setup-python` +
  `poetry install --without dev --without build`; busted also runs `gen-config` before the suite.
- `src/CTLD_config_defaults.lua` removed from git tracking and added to `.gitignore`.
- `release.yml` gains a `build-exe` job (`needs: release`, `windows-latest`): PyInstaller `--onefile
  --collect-all lupa --add-data dcs_types.json`, then `gh release upload`.
- ADR 0009 and the developer build docs updated to describe gen-au-build (superseding committed+drift).

### Testing Decisions

- A `conftest.py` session fixture regenerates `CTLD_config_defaults.lua` from the YAML before the
  Python tests, so the parity/reference/e2e tests keep working without a committed file. The drift
  test (`test_committed_generated_lua_is_up_to_date`) is removed.
- The `.exe` build was validated locally: `scaffold` + `validate` run from the packaged exe (proving
  lupa and the embedded `dcs_types.json` work). The `build-exe` CI job re-verifies on each release.
- The `busted` job proves the loader still loads the freshly-generated defaults.

### Out of Scope

- `.miz` injection, TUI (roadmap).
- Any change to the `user-config.yaml` schema or the runtime API.

### Further Notes

- Closes the `ctld-tools` program. Remaining roadmap items: `.miz` injection, interactive TUI.

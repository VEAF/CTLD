# CTLD-TOOLS-WEBAPP

**Status:** ✅ merged (PR #67). Compacted from `CTLD-TOOLS-WEBAPP/` on 2026-08-01; the ticket files live on in git history.

Lot 3/3 — local web app over the lot-2 core: schema-driven editors, 13 families (FullGas's 12 + Parachute) + Parameters/Data split fully editable (crates/troops/aircraft+datamine picker/zones/lists/weights + JSON fallback), live validate, native file dialogs, `.miz` inject, version-gap popup; single **console** PyInstaller exe that serves + opens the browser on double-click (VMCT `_is_double_clicked`), frontend built at CI. Closes the ctld-tools v2 program.

## Tickets

| Ticket | Status | Title |
|---|---|---|
| `01-backend-skeleton-endpoints` | ✅ done | 01 — FastAPI backend skeleton + endpoint wrappers |
| `02-exe-launcher-double-click` | ✅ done | 02 — exe launcher: double-click → serve |
| `03-frontend-shell-params-data-families` | ✅ done | 03 — frontend shell: Parameters/Data split + 12 families |
| `04a-scalar-editors-families` | ✅ done | 04a — scalar editors + 12 families + coverage gate |
| `04b-crates-editor` | ✅ done | 04b — crates editor (spawnableCrates) |
| `04c-troops-editor` | ✅ done | 04c — troop-groups editor (loadableGroups) |
| `04d-aircraft-editor` | ✅ done | 04d — aircraft capabilities editor (capabilitiesByType) |
| `04e-zones-lists-weights-coverage` | ✅ done | 04e — zones + mission lists + vehicle weights + full coverage gate |
| `05-validate-miz-inject-wiring` | ✅ done | 05 — live validate + .miz inject + native file dialog |
| `06-version-gap-popup` | ✅ done | 06 — version-gap re-migration popup |
| `07-ci-frontend-build-exe-packaging` | ✅ done | 07 — CI frontend build + exe packaging |
| `08-docs-rewrite` | ✅ done | 08 — docs rewrite for the web app |

## PRD

## Lot CTLD-TOOLS-WEBAPP — local web app + single console exe

Status: ✅ merged (PR #67)
Branch: `feature/ctld-tools-webapp` → PR → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`).
ADR: [0011](../../dev/adr/0011-complete-yaml-config-and-webapp-tooling.md).
Lot **3 of 3** in the ctld-tools v2 program. Depends on lot 2 (the core library).

### Problem Statement

ctld-tools needs a modern editing surface for the **complete** catalogue. The TUI and the tkinter
GUI are retired (ADR 0011): the TUI plateaus on ergonomics, tkinter plateaus on capability (menus,
icons, layout). The target is a **local web app**, packaged so a non-dev MM double-clicks one file
and the UI opens — no terminal, no command, no install (the ergonomics missing from the VMCT exes).

### Solution (this lot = presentation only, over lot 2's library)

**Web app**
- Backend: **FastAPI**, **thin endpoints wrapping lot 2's core** (load/edit/save/validate/version
  diff). No business logic here. Far lighter than Walker: single user, ephemeral, **no DB, no auth,
  no migrations**.
- Frontend: **Svelte + Vite + TypeScript** — schema-driven editors (salvage FullGas's editor logic),
  navigation by the **12
  functional families**, top-level split into two screens — **Parameters** (how CTLD behaves) vs
  **Data** (what CTLD operates on).
- **Version-gap popup**: on opening a stale `configUser`, warn that CTLD's version changed and
  present the diffs to review before re-injecting (drives lot 2's version-gap API).
- File open/save via a **native OS dialog** driven by the local backend.

**Distribution (mirrors VMCT `veaf-tools.exe`)**
- A **single console-mode** PyInstaller exe = real CLI **and** GUI launcher.
- Bare invocation / double-click (detected by walking the parent process tree — `explorer.exe` vs a
  terminal process, pattern from VMCT's `_is_double_clicked`) → boot `uvicorn` on `127.0.0.1` + open
  the browser. Console window stays as the server-lifecycle window ("close to quit"). No
  `--noconsole`.
- Frontend **built at CI** (`release.yml`) and bundled as static assets — the MM never needs Node.

### Definition of Done

- Double-clicking the exe opens the web app in the browser with no terminal command; closing the
  console window stops the server.
- Complete-catalogue editing (Parameters + Data, 12 families), live `validate`, `.miz` inject, and
  the version-gap popup all working end to end against the lot 2 core.
- **No editing gaps**: every schema-declared parameter and data family is editable — explicitly
  including `capabilitiesByType` (aircraft types, datamine-backed type picking) and
  `transportPilotNames` (editable name list). A **blocking** schema-coverage test (evolution of
  FullGas's `test_schema_coverage.py`) fails the build if any schema key renders no editor. A
  **generic fallback editor** (typed raw field) guarantees every key renders something, so the gate
  is painless; bespoke editors added progressively. Deliberately hidden keys go on an **explicit,
  reviewed allowlist**, never a silent skip.
- CLI-from-terminal still works (validate / gen / embed with args); CI/build unaffected.
- Frontend built + bundled + exe attached to Releases (isolated job), verified.
- `docs/mission-maker/ctld-tools.{md,fr.md}` rewritten for the web app; `ctld-tools` glossary entry
  in `CONTEXT.md` updated. CHANGELOG `[Unreleased]`; ADR 0011 referenced.

### Out of scope

- Runtime (lot 1) and core library (lot 2).
- DB / auth / multi-user / hosting (explicitly not Walker's stack).

### Tickets

Authored when the lot starts. Expected spine: (a) backend skeleton + endpoint wrappers; (b) exe
double-click→serve launcher (VMCT `_is_double_clicked`); (c) frontend shell + Parameters/Data split
+ 12 families; (d) schema-driven editors; (e) validate + miz-inject wiring; (f) version-gap popup;
(g) CI frontend build + exe packaging; (h) docs rewrite.

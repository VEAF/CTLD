# 05 — live validate + .miz inject + native file dialog

Status: 📋 todo
Type: tool (Python + frontend) + test

Wire the editing surface to lot-2 `validate` and `miz` injection, with a native OS file dialog.

- **Live validate**: the frontend surfaces the lot-2 `validate` findings (errors block export,
  warnings do not), refreshed on edit; clear per-field / per-entry reporting.
- **`.miz` inject**: export the current catalogue as `ctld.configUser` (lot-2 `embed` with
  `--var configUser`) and inject it into a chosen `.miz` (lot-2 `miz.inject_userconfig`), idempotent.
- **Native file dialog** driven by the local backend (which runs as the MM) for open/save/pick-miz —
  a backend endpoint invoking the OS dialog, since the browser cannot pick arbitrary paths.
- Tests: backend endpoints for validate + inject (TestClient); the export→inject round-trip reuses
  lot-2 coverage.

Files: `ctld_tools/web/**`, `tools/ctld-tools/web/**`, `tests/**`. Depends on: 03 (04 for full data).

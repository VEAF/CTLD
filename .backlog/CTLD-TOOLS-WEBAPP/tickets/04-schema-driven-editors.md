# 04 — schema-driven editors + coverage gate

Status: 📋 todo
Type: tool (frontend) + test

Every setting and data family becomes editable, driven by the schema metadata (salvage FullGas's
editor logic). **No editing gaps** (ADR 0011 point 7 / DoD).

- Per-type editors from the schema: bool toggle, enum (`choices`) picker, number, string, and the
  structured **data** editors (crates / troops / zones lists, `capabilitiesByType` with a
  datamine-backed aircraft-type picker, `transportPilotNames` editable name list).
- A **generic fallback editor** (typed raw field) guarantees every key renders *something*, so the
  coverage gate is painless; bespoke editors added progressively over it.
- A **blocking schema-coverage test** (evolution of FullGas's `test_schema_coverage.py`): the build
  fails if any schema key renders no editor. Deliberately hidden keys live on an **explicit,
  reviewed allowlist** — never a silent skip.
- Edits flow through the backend (ticket 01) into the lot-2 `Catalog`.

Files: `tools/ctld-tools/web/**`, coverage test. Depends on: 03. **Blocked on**: FullGas editor
source (external fork — confirm location before starting).

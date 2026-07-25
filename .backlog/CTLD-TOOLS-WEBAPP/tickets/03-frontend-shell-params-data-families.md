# 03 — frontend shell: Parameters/Data split + 12 families

Status: ✅ done
Type: tool (frontend) + test

> Families = the schema `group` values (14: aa/beacon/boarding/crates/fob/general/jtac/mines/
> parachute/recon/smoke/soldier_weights/troops + an `other` fallback). FullGas's exact "12" is
> reconciled when the editor logic lands (ticket 04). Toolchain pinned to vite 7 / plugin-svelte 6 /
> vitest 3 (vite 8 from the scaffold clashed with the test runner).

The **Svelte + Vite + TypeScript** shell (ADR 0011 point 7): the navigation skeleton the editors
plug into. No bespoke editors yet (ticket 04).

- New `tools/ctld-tools/web/` Vite project (Svelte + TS). Dev proxies to the FastAPI backend; the
  production build emits static assets (bundled by ticket 07).
- Top-level split into two screens: **Parameters** (how CTLD behaves) vs **Data** (what CTLD
  operates on). Within each, navigate by the **functional families** (FullGas's 12-family taxonomy;
  reconcile with the schema `group` values from lot 2 — map every group to a family, generic
  bucket for the uncovered).
- Load a catalogue via the backend, show the family list + key list per family (values read-only in
  this ticket — editing is ticket 04). Open/save buttons wired to the backend (native dialog is
  ticket 05).
- Tests: a component/unit test that the family navigation renders every group returned by the
  backend schema (no family silently missing).

Files: `tools/ctld-tools/web/**`. Depends on: 01.

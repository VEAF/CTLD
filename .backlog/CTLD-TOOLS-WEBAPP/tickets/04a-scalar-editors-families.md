# 04a — scalar editors + 12 families + coverage gate

Status: ✅ done
Type: tool (frontend) + test

> Families = FullGas's 12 **+ a Parachute family** (13th, kept for the lot-1 parachute-physics
> settings, on David's call) + an "Other" catch-all. UI labels are English for now (i18n of the app
> UI is a later concern).

Make the **Parameters** screen editable: schema-driven scalar editors over the 12 functional
families (FullGas taxonomy, reconciled into the schema), with a generic fallback so every key
renders an editor.

- **12 families** with bilingual labels (Général / Caisses / Troupes / Embarquement / JTAC /
  Smoke général / Beacon / FOB · FARP / Reconnaissance / Mines / Système AA / Poids soldats) + an
  **Other** catch-all. Within a family, split settings into **Standard** vs **Advanced**
  (schema `standard:` flag).
- **Per-type editors**: bool → checkbox, enum (`choices`) → select, number → number field, string →
  text field; a **generic fallback** (typed text) guarantees every key renders *something*. Edits
  PUT through the backend into the lot-2 `Catalog`. Show the schema `description` as help.
- **Coverage gate**: a pure `editorType(meta, value)` never returns "no editor"; a unit test asserts
  every scalar key resolves to a valid editor type. Deliberately-hidden keys → explicit allowlist
  (none yet).

Files: `tools/ctld-tools/web/**`. Depends on: 03. Data editors are 04b–04e.

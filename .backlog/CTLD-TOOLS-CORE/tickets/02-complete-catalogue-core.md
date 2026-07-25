# 02 — Complete-catalogue core: load / edit / save

Status: ✅ done
Type: tool (Python) + test

A UI-agnostic core that reads, edits and writes the **complete** catalogue YAML (Parameters +
Data), schema-driven. Replaces the ops/diff `editmodel`.

- Load `CTLD_config.yaml` (and an optional `configUser`) via ruamel; keep the `mm_facing`/`advanced`
  sections + top-level keys (`configVersion`) coherent with the runtime loader's merge.
- A model to get/set any setting or catalogue entry by path; add/remove/edit crates, troops,
  arrays, `capabilitiesByType`, etc. — the full catalogue, not a diff.
- Serialise back to YAML (stable, MM-readable, section-preserving). Port FullGas's **expanded schema
  + field metadata** (branch `feature/ux-ctld-tools-v2`, tickets 08/10) — logic only, no tkinter.
- Unit tests: load → edit → save round-trip; schema-driven field coverage (every schema key maps to
  a model path).

Files: new `ctld_tools/catalog.py` (model), `CTLD_config_schema.yaml`, `tests/**`. Depends on: 01.

# ADR 0009 — External YAML authoring for CTLD configuration (ctld-tools)

## Status
Accepted (CTLD-TOOLS-CONFIG, 2026-07-20). **Points 2 & 3 superseded by
[ADR 0011](0011-complete-yaml-config-and-webapp-tooling.md) (2026-07-24)** — the ops/diff config model and
the Textual TUI are retired. **Point 1** (a standalone, offline `ctld-tools` distributed to MMs) and
**point 4** (`.miz` trigger injection) stand, as does the YAML-as-single-source-of-truth intent.

## Implementation notes (as delivered — refinements to the original proposal)

- **Tooling stack follows VMCT** (VEAF-Mission-Creation-Tools), the reference re-tooling model:
  isolated **poetry** sub-project `tools/ctld-tools/`, **typer** CLI, **ruamel.yaml**, **lupa**
  (runs `CTLD_config.lua` in-process to read the defaults; `ctld.tr` stubbed to identity),
  pytest + ruff + mypy, workflow `python-quality.yml`. A **single** package `ctld_tools`.
- **Generated Lua is build-generated (gen-au-build), not committed.** `merge_CTLD.ps1` runs
  `ctld-tools gen-config` before merging, so `src/CTLD_config_defaults.lua` is always fresh from the
  YAML; it is a **git-ignored build artifact**. The build (and the busted CI job, whose loader loads
  it) therefore require Python + poetry. This keeps the dev workflow to "edit the YAML, rebuild" with
  no manual regen step. (An earlier iteration committed the file with a drift check; dropped in
  favour of gen-au-build per maintainer preference.)
- **Merge order**: the generated defaults module evaluates `ctld.tr(...)` at load time, so it is
  merged **after the `CTLD_i18n_*` modules** (not merely after `CTLD_config.lua`).
- **`CTLDConfig:load()`** copies `ctld.__configDefaults` into `self.settings`; the `TEMPLATES`
  block and the user-YAML merge / backward-compat sequence stay untouched.

## Context

CTLD configuration lives in two Lua files hand-edited today:

- `CTLD_config.lua` (~1149 lines) — the engine defaults, a ~900-line `self.settings[...]` block
  inside `CTLDConfig:load()`, merged into the `CTLD.lua` deliverable.
- `CTLD_userConfig.lua` — the Mission Maker (MM) surface. ADR 0008 replaces its broken Section 2
  with a runtime helper API (`ctld.userSetup` + `ctld.addCrate/patchCrate/…`), still hand-edited.

Editing complex Lua tables is hostile to MMs (non-Lua-developers): one missing comma breaks the
mission, and the commented defaults rot. The VMCT project solves the equivalent problem with an
external `veaf-tools.exe`. This ADR decides to bring the same model to CTLD.

The data in `CTLD_config.lua` was audited: it is near-pure literal, with a **single** special
construct — `ctld.tr("key")` i18n wrappers on text fields (`desc`, `name`) — so a YAML↔Lua
round-trip is feasible provided the generator re-emits those wrappers by convention.

## Decision

1. **A standalone tool, `ctld-tools`** — a Python package that validates and generates CTLD
   configuration from YAML. It embeds the default-config reference and the datamined DCS type set,
   so validation is fully offline. Distributed to MMs as a self-contained `ctld-tools.exe`
   (PyInstaller, Windows); the build/CI invoke the **Python package** directly (the merge job is
   already on `windows-latest`). No runtime dependency on VEAF tooling — the tool is autonomous.

2. **Engine config: YAML as the single source of truth (the "X" choice).** The defaults block moves
   out of `CTLD_config.lua` into a `ctld-config` YAML (sectioned MM-facing vs advanced). The build
   regenerates the Lua consumed by `load()`; `CTLDConfig:load()` shifts from *writing* defaults to
   *copying* a generated table, keeping its user-merge / backward-compat sequence unchanged. The
   frontier: **values → YAML**, **load sequence → Lua**.

3. **MM config: YAML compiles to the ADR 0008 API (the "A" choice — layering, not replacement).**
   The MM's `user-config` YAML is a list of **operations** (`add` / `delete` / `edit`) mapping 1:1
   onto the `ctld.userSetup` helpers. ctld-tools validates each operation against the config
   reference (existing `weight` for edit/delete, no collision for add) and the DCS type set (each
   `unit`), then emits a `ctld.userSetup` callback. ADR 0008 stays the runtime contract, unchanged
   and independently testable; the YAML is an authoring layer above it.

4. **Deferred scope** (`dev/roadmap.md`): automatic `.miz` trigger injection and the interactive
   TUI. The first increment ships the core value — reference + validation + generation (incl.
   `gen-user --scaffold` for a commented YAML skeleton).

## Considered alternatives

- **(Y) Lua stays the source, YAML extracted as an artefact.** Rejected: it gives validation/guidance
  but not YAML-based editing of the engine config, which is the intent behind X. Keeps parity risk
  low but does not meet the goal.
- **Declarative `user-config` (full catalogue, tool diffs it).** Rejected: forces the MM to own the
  whole catalogue — the very hostility ADR 0008 removes. Operations keep edits minimal.
- **A `.miz`-manipulation library that rebuilds the mission (e.g. pydcs).** Rejected for injection:
  rebuilding a mission authored in the ME risks dropping anything the model does not represent. A
  surgical home-grown patch is preferred when injection is implemented.

## Consequences

- The build acquires a **Python dependency** (today the merge is pure PowerShell). Consistent with
  the rest of the tooling; the merge job is already on Windows, so `setup-python` suffices.
- A **round-trip parity test** guards the extraction: regenerate the Lua from YAML and diff against
  the current defaults (legacy parity is immutable).
- The generator must re-emit `ctld.tr(...)` on i18n fields (`desc`, `name`) by convention.
- Delivered as **three sequential lots**: (1) `FEAT-USERCONFIG-API` (ADR 0008, unchanged, first);
  (2) the config reference + `gen-config` + build integration; (3) the MM volet (`validate`,
  `gen-user`, `.exe` distribution). Exact filenames pinned per PRD.
- ADR 0008's `logDefaults` / schema-comments become power-user/debug aids rather than the primary
  MM path; its scope is not reduced.

## Note — embedded reference & lupa build-time-only (CTLD-TOOLS-TUI, 2026-07-21)

The interactive TUI (deferred scope point 4) requires the tool to run **without `src/`** — a
non-dev MM only has the `.exe`. This shifts how the reference catalogue is resolved:

- A build step **`gen-reference`** (lupa) freezes the catalogue slice the runtime needs
  (`spawnableCrates` with AA injected, `loadableGroups`) into a JSON bundle,
  `ctld_tools/data/reference.json`, **committed** and kept in sync with `src/` by a golden test —
  the same pattern as the embedded `dcs_types.json`.
- `Reference.from_embedded()` reads the bundle and becomes the **default** for `validate`,
  `gen-user` and the TUI; `--src` → `from_src` stays as a dev override.
- **lupa moves to build-time only** (the `dev` dependency group). The runtime path
  (TUI / `validate` / `gen-user` via the embedded reference) no longer imports it, so the MM `.exe`
  ships without lupa or the native Lua binary. Only `gen-reference` / `gen-config` / `extract`
  (build steps) use lupa. lupa imports are lazy so importing a runtime module never pulls it in.

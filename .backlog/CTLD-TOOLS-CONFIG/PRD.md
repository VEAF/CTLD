Status: ready

# PRD — CTLD-TOOLS-CONFIG

> Lot 2 of the `ctld-tools` program. See [ADR 0009](../../dev/adr/0009-external-yaml-authoring-ctld-tools.md)
> for the architecture, and `FEAT-USERCONFIG-API` (the runtime API socle, delivered first).

## Problem Statement

CTLD's engine defaults live as a ~900-line `self.settings[...]` block hand-written inside
`CTLDConfig:load()` (`src/CTLD_config.lua`, ~1149 lines total). This is the single largest,
most-edited data structure in the project, yet:

- It is **Lua source**, so every default change is a code edit gated by Lua syntax, luacheck and the
  merge build — heavy ceremony for what is fundamentally *data*.
- It is the reference the Mission Maker (MM) tooling must know about to validate and guide a
  `user-config` (the next lot). As long as the defaults are trapped inside a Lua function body, no
  external tool can read them without executing CTLD.
- Its commented mirror in `CTLD_userConfig.lua` drifts out of sync (the very rot `FEAT-USERCONFIG-API`
  documents).

We want the engine defaults to become **data with a single source of truth**, editable without Lua
ceremony and readable by tooling — without any change to CTLD's in-game behaviour.

## Solution

Introduce **`ctld-tools`**, a Python package (distributed to MMs later as a self-contained
`ctld-tools.exe`; here used only via the Python module), and move the engine defaults out of Lua:

- The defaults become **`ctld-config.yaml`** — the single source of truth, sectioned **MM-facing** vs
  **advanced/technical**.
- A **`gen-config`** command regenerates the Lua consumed by `CTLDConfig:load()` from the YAML. This
  command runs as a **build step** before the merge.
- `CTLDConfig:load()` shifts from *writing* the defaults inline to *copying* the generated defaults
  table, keeping its user-YAML merge and backward-compat sequence **unchanged**. Frontier:
  **values → YAML**, **load sequence → Lua**.
- A **one-shot extractor** produces the initial `ctld-config.yaml` from the current
  `src/CTLD_config.lua`, and a **round-trip parity test** proves the regenerated Lua is
  behaviourally identical before the switch-over (legacy parity is immutable).

This lot delivers the **reference + generation + build integration** only. The MM-facing commands
(`validate`, `gen-user`), `.miz` injection and the TUI are out of scope (later lots / roadmap).

## User Stories

1. As a CTLD developer, I want the engine defaults expressed as YAML, so that I change a default
   value without editing Lua, running luacheck, or understanding `CTLDConfig:load()`.
2. As a CTLD developer, I want the YAML sectioned into MM-facing vs advanced/technical groups, so
   that the values a mission maker typically touches are separated from internal tuning constants.
3. As a CTLD developer, I want `gen-config` to regenerate the Lua defaults from the YAML during the
   build, so that the deliverable `CTLD.lua` always reflects the YAML source of truth.
4. As a CTLD developer, I want the generator to re-emit `ctld.tr("…")` wrappers on i18n text fields
   (`desc`, `name`), so that translation keeps working exactly as before.
5. As a CTLD developer, I want the generated Lua to be deterministic (stable ordering, stable
   formatting), so that regenerating without a YAML change produces a byte-identical file and diffs
   stay meaningful.
6. As a CTLD developer, I want a round-trip parity test that loads both the old hand-written config
   and the regenerated one under Lua 5.1 and deep-compares the resulting `settings`, so that I can
   switch over in confidence that in-game behaviour is unchanged.
7. As a CTLD developer, I want the old defaults block removed from `CTLD_config.lua` once parity is
   proven, so that there is exactly one source of truth and no drift between two copies.
8. As a CTLD developer, I want `CTLDConfig:load()` to consume the generated defaults table, so that
   its user-YAML merge and backward-compat logic stay untouched and independently valid.
9. As a CTLD developer, I want the generated Lua to pass `luac5.1 -p` and load without error, so
   that a malformed generation is caught in CI, not in DCS.
10. As a CTLD developer, I want the build to invoke the Python package (not a committed `.exe`), so
    that CI stays reproducible and the repo carries no binary bloat.
11. As a CTLD developer building locally, I want the build to fail with a clear message if Python or
    the generator is missing, so that I understand why `CTLD.lua` cannot be produced.
12. As a CTLD developer, I want the YAML round-trip to preserve every value, type and structure
    currently in the defaults (scalars, nested tables, arrays, mixed key styles, `side`/`weight`
    numeric precision), so that nothing is silently lost or coerced.
13. As a CTLD developer, I want `ctld-tools` to have its own tested Python package with unit tests,
    so that the generator's behaviour is pinned and regressions are caught.
14. As a CTLD maintainer, I want `ctld-config.yaml` to be committed as the source of truth and the
    generated Lua to be a build artefact, so that reviewers diff the YAML, not the generated Lua.
15. As a CTLD maintainer, I want the extractor to be a documented one-shot migration utility, so
    that it is clear it produced the initial YAML and is not part of the ongoing build.
16. As a release engineer, I want `release.yml` and `ci.yml` to run `gen-config` before the merge on
    the Windows job, so that both the CI build and the released deliverable are generated the same
    way.
17. As a CTLD developer, I want the ubiquitous-language docs and developer build docs updated to
    describe the YAML-sourced config, so that the next contributor edits the YAML and not the
    generated Lua.

## Implementation Decisions

- **New Python package `ctld-tools`** (its own directory under `tools/`, co-located tests, its own
  `requirements`/venv like `tools/dcs-bridge`). It is a real package with dependencies — the
  "dependency-free" constraint of the integration runner does **not** apply here. A YAML library is
  a dependency (candidate: `ruamel.yaml` for comment/order-preserving authoring, which the later
  scaffold lot benefits from; `PyYAML` acceptable if the scaffold need is deferred — pinned at
  implementation time).

- **`ctld-config.yaml`** is the source of truth for the engine defaults, sectioned **MM-facing** vs
  **advanced/technical**. It captures every `self.settings[...]` default currently in
  `CTLDConfig:load()` — the values only, not the load sequence.

- **`gen-config` command**: reads `ctld-config.yaml`, emits the Lua defaults consumed by
  `CTLDConfig:load()`. Deterministic output (stable key ordering, stable formatting). Re-emits
  `ctld.tr("…")` on the i18n fields (`desc`, `name`) by field-name convention — the only non-literal
  construct in the data (audited: no other function calls or computed expressions live in the
  defaults).

- **`CTLDConfig:load()` change of shape**: instead of assigning ~900 lines of defaults inline, it
  copies the generated defaults table into `self.settings`, then runs its existing user-YAML merge
  (`ctld.yamlConfigDatas` → `parseYAML`) and backward-compat block unchanged. The generated Lua is
  merged into `CTLD.lua` via `listToMerge.txt` (exact file boundary and global/table name pinned at
  implementation time).

- **One-shot extractor**: a documented migration utility that parses the current
  `src/CTLD_config.lua` defaults block into the initial `ctld-config.yaml`. Not a perennial build
  command; its correctness is validated by the parity test, not by asserting the extractor's own
  output.

- **Build integration**: the merge job (already on `windows-latest` in both `ci.yml` and
  `release.yml`) gains a `setup-python` step and runs `gen-config` before `merge_CTLD.ps1`. The
  generated Lua is a build artefact (git-ignored), not committed. A missing Python/generator fails
  the build with an explicit message (mirrors the existing hard-fail style in `merge_CTLD.ps1`).

- **Generated Lua is an artefact, `ctld-config.yaml` is committed.** Reviewers diff the YAML.

- **No behavioural change.** This lot is a pure refactor of *where the defaults live*; `CTLD.lua`'s
  runtime behaviour is identical (guarded by the parity test). Legacy parity (`migration/source/`)
  is untouched.

- **Naming** (`ctld-config.yaml`, the generated Lua file, the package/command names) is pinned in
  this lot's tickets, consistent with the existing `CTLD_config.lua` / `CTLD_userConfig.lua`.

## Testing Decisions

Good tests here assert **observable behaviour through the highest seam**, not the internals of the
extractor. The seams:

- **`gen-config` (YAML → Lua), the perennial seam** — tested in Python `unittest` (prior art:
  `tools/integration-runner/test_run_scenarios.py`, `test_run_manual_scenario.py`, run via
  `python -m unittest`). Targeted fixtures: a small YAML input → expected Lua, covering the
  `ctld.tr()` re-emission, nested tables, arrays, numeric precision on `weight`/`side`, and
  deterministic ordering. A **golden-file** test: `gen-config` over the committed `ctld-config.yaml`
  matches a committed expected Lua (regenerated deliberately when the YAML changes).

- **Migration parity, the switch-over guard** — a test that executes **both** the old hand-written
  `CTLD_config.lua` and the regenerated Lua under **`lua5.1`** (available in CI: `lua-lint` +
  `busted` jobs install it), calls `CTLDConfig:load()` on each, and **deep-equals** the resulting
  `settings` tables. Invoked via subprocess; **skips cleanly** when `lua5.1` is absent locally, runs
  in CI. The frozen old-defaults snapshot is kept as a reference fixture so the parity assertion
  survives the removal of the inline block.

- **Generated-Lua validity** — the generated Lua passes `luac5.1 -p` (reuses the `lua-lint` gate)
  and smoke-loads without error.

- **Extractor** — lightly tested; its correctness is subsumed by the migration-parity test (its job
  is done once and validated end-to-end).

Not tested here: DCS runtime behaviour (no integration/DCS scenarios — this lot changes no in-game
behaviour), and the MM-facing commands (next lot).

## Out of Scope

- **MM volet** — `validate`, `gen-user --scaffold`, and compiling `user-config.yaml` into
  `ctld.userSetup` calls. That is `CTLD-TOOLS-USERCONFIG` (lot 3), which depends on this lot's
  reference + this-lot-and-`FEAT-USERCONFIG-API` being merged.
- **`.miz` trigger injection** and the **interactive TUI** — `dev/roadmap.md`.
- **`.exe` distribution** (PyInstaller / `release.yml` artefact) — introduced with the MM volet, when
  there is something for an MM to run.
- **Changing any default value** — this lot moves the defaults verbatim; value fixes (e.g. the parity
  bugs) belong to `FEAT-USERCONFIG-API`, not here.

## Further Notes

- Delivery order: `FEAT-USERCONFIG-API` (runtime socle) → **this lot** (reference + build) →
  `CTLD-TOOLS-USERCONFIG` (MM volet).
- The one-shot extractor is the riskiest surface (faithful extraction of ~900 lines incl. the
  `ctld.tr()` wrappers); the migration-parity test is the gate that authorises the switch-over.
- After this lot, the `CONTEXT.md` "Config reference" term becomes concrete; the "advanced vs
  MM-facing" sectioning informs the scaffold in lot 3.
- ADR 0009 moves from *Proposed* to *Accepted* when this lot lands.

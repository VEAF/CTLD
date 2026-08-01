# CTLD-TOOLS-USERCONFIG

**Status:** ✅ merged (PR #47). Compacted from `CTLD-TOOLS-USERCONFIG/` on 2026-08-01; the ticket files live on in git history.

Lot 3 of `ctld-tools` ([ADR 0009](../dev/adr/0009-external-yaml-authoring-ctld-tools.md)): MM volet — `validate` (user-config.yaml against the reference + datamine, clear report with suggestions) + `gen-user` (compile add/remove/patch ops into `CTLD_userConfig.lua` calling the `ctld.userSetup` helpers, targeting crates/troops **by name**) + `gen-user --scaffold`; embedded `dcs_types.json`; `ctld-tools.exe` attached to Releases (isolated). e2e-tested.

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-datamine-machine-readable-export` | 🧑 planned | 01 — Machine-readable DCS type-set export for the validator |
| `02-validate-command` | 🧑 planned | 02 — `validate` command + report |
| `03-gen-user-command` | 🧑 planned | 03 — `gen-user` command: operations → `CTLD_userConfig.lua` |
| `04-scaffold-and-template-reconcile` | 🧑 planned | 04 — `gen-user --scaffold` + reconcile the `dist/` template |
| `05-end-to-end-lua-test` | 🧑 planned | 05 — End-to-end runtime test (lua5.1) |
| `06-exe-distribution-docs-index` | 🧑 planned | 06 — `ctld-tools.exe` distribution + docs, CHANGELOG, index |

## PRD

Status: ready

## PRD — CTLD-TOOLS-USERCONFIG

> Lot 3 of the `ctld-tools` program. See [ADR 0009](../../dev/adr/0009-external-yaml-authoring-ctld-tools.md).
> Depends on `FEAT-USERCONFIG-API` (runtime `ctld.userSetup` socle) and `CTLD-TOOLS-CONFIG` (lot 2:
> the Python package + the `ctld-config.yaml` reference) both merged.

### Problem Statement

`FEAT-USERCONFIG-API` gives the Mission Maker (MM) a safe runtime API (`ctld.userSetup` + helpers) —
but the MM still writes that Lua **by hand**. For an MM who is comfortable with the DCS ME but not a
Lua developer, that is still the wrong surface:

- A typo (missing comma, wrong helper name, bad nesting) is only discovered when the mission is run
  in DCS, with no clear diagnostic.
- The MM has no way to know which crate weights, sections or troop-group names already exist, nor
  which DCS unit type names are valid — the information lives in the engine defaults and the DCS
  database, both out of reach at authoring time.
- A duplicate crate `weight` (fatal per `FEAT-USERCONFIG-API`) or a `delete`/`edit` targeting a
  non-existent entry produces a silent or crashing failure at mission start, not a helpful message
  while editing.

The MM needs to author their configuration in a **simple, validated format**, get a **clear report**
of mistakes with suggested fixes **before** loading the mission, and never hand-write Lua.

### Solution

Deliver the MM volet of `ctld-tools` (the Python package from lot 2), distributed to MMs as a
self-contained **`ctld-tools.exe`**:

- **`validate`** — checks a `user-config.yaml` against the embedded **config reference**
  (`ctld-config.yaml` from lot 2) and the embedded **datamined DCS type set**: YAML syntax, `edit`/
  `delete` target an existing `weight`, `add` does not collide, every `unit` is a known DCS type.
  Produces a clear, actionable report with **suggested fixes**.
- **`gen-user`** — compiles the `user-config.yaml` **operations** (`add` / `delete` / `edit`) into a
  `CTLD_userConfig.lua` that calls the `ctld.userSetup` helpers (`ctld.addCrate`, `removeCrate`,
  `patchCrate`, `addTroopGroup`, `removeTroopGroup`, `addTo`). The MM never writes Lua.
- **`gen-user --scaffold`** — emits a commented `user-config.yaml` skeleton so the MM starts from a
  documented example rather than a blank file. This takes over the role of the hand-edited
  `dist/CTLD_userConfig.lua` template shipped by `USERCONFIG-LOADING`.
- **Distribution** — `release.yml` builds `ctld-tools.exe` (PyInstaller, Windows) and attaches it to
  the GitHub Release, so MMs run the tool with no Python install.

`.miz` injection and the interactive TUI remain out of scope (roadmap).

### User Stories

1. As an MM, I want to describe my config as a list of operations (`add` / `delete` / `edit`) in a
   YAML file, so that I only write what I change, not the whole catalogue.
2. As an MM, I want `validate` to check my `user-config.yaml` before I load the mission, so that I
   fix mistakes at my desk instead of discovering them in DCS.
3. As an MM, I want a clear report that names each error, its location, and a suggested fix, so that
   I can correct it without reading CTLD source.
4. As an MM, I want `validate` to reject an `edit` or `delete` that targets a `weight` which does not
   exist in the defaults, so that I catch a typo in the target.
5. As an MM, I want `validate` to reject an `add` whose `weight` collides with an existing crate, so
   that I avoid the fatal F10-menu corruption described in `FEAT-USERCONFIG-API`.
6. As an MM, I want `validate` to flag any `unit` that is not a known DCS type name, so that I don't
   ship a config that silently spawns the wrong unit (the `M1025 HMMWV Armament` class of bug).
7. As an MM, I want validation to run fully offline, so that I don't need DCS running or network
   access to check my config.
8. As an MM, I want `gen-user` to turn my YAML into a working `CTLD_userConfig.lua`, so that I never
   hand-write Lua or `ctld.userSetup` callbacks.
9. As an MM, I want each `add` operation compiled into `ctld.addCrate` (or `addTroopGroup` / `addTo`)
   in the correct section, so that my custom entries appear where I expect in the F10 menu.
10. As an MM, I want each `delete` compiled into `ctld.removeCrate` / `removeTroopGroup`, so that
    default entries I don't want are gone from the menu.
11. As an MM, I want each `edit` compiled into `ctld.patchCrate` (deep-merge one level), so that I
    change a single field without rewriting the whole entry.
12. As an MM, I want to add entries to array settings (`transportPilotNames`, `troopZones`, `wpZones`,
    `extractableGroups`, `logisticUnits`) via an operation compiled into `ctld.addTo`, so that I
    append to the defaults.
13. As an MM, I want `gen-user --scaffold` to produce a commented starter `user-config.yaml`, so that
    I begin from a documented example, not a blank file.
14. As an MM, I want the scaffold to document the available operations and the fields each entry
    accepts, so that I know what to write without consulting CTLD source.
15. As an MM, I want the generated `CTLD_userConfig.lua` to be valid Lua that loads before CTLD (the
    two-trigger ME setup), so that it plugs into the existing load flow unchanged.
16. As an MM, I want `validate` to run automatically as part of `gen-user`, so that I can't generate
    Lua from an invalid config by mistake.
17. As an MM on Windows with no Python, I want a single `ctld-tools.exe` from the GitHub Release, so
    that I run the tool without installing anything.
18. As an MM, I want the report to distinguish errors (block generation) from warnings (proceed with
    caution), so that I know what must be fixed versus what merely deserves a look.
19. As a CTLD maintainer, I want the embedded DCS type set to come from the vendored datamine (via a
    machine-readable export), so that validation matches the CI type linter and stays in sync.
20. As a CTLD maintainer, I want `gen-user` to reuse the same helper names and semantics as the
    runtime API, so that the compiled Lua and the hand-writable API never diverge.
21. As a release engineer, I want `release.yml` to build and attach `ctld-tools.exe`, so that every
    release ships the MM tool alongside `CTLD.lua`.
22. As a CTLD developer, I want the MM volet tested through the same seams as lot 2 (Python unittest
    + a lua5.1 end-to-end check), so that the compilation is pinned and regressions are caught.
23. As an MM, I want the docs (pilot / mission-maker role) updated to describe the YAML authoring
    flow and `ctld-tools`, so that I learn the recommended workflow.

### Implementation Decisions

- **Extends the `ctld-tools` package** from lot 2 with the `validate` and `gen-user` sub-commands
  (and `--scaffold`). No new package.

- **`validate` inputs**: the `user-config.yaml`, the embedded **config reference** (`ctld-config.yaml`
  from lot 2 — known sections, `weight`s, troop-group names, array settings), and the embedded
  **DCS type set**. Output: a structured report (list of findings with severity, location, message,
  suggested fix). `error`-severity findings block `gen-user`; `warning`s do not.

- **Validation rules**: YAML well-formed; `edit`/`delete` reference an existing `weight` (or troop
  name); `add` `weight` does not collide (fatal per `FEAT-USERCONFIG-API`); every `unit` is a known
  DCS type; array-setting operations target a known array setting. Suggested fixes are heuristic
  (e.g. nearest existing `weight`, closest known type name).

- **`gen-user` compilation**: operations map 1:1 to helpers —
  `add` crate → `ctld.addCrate(section, entry)`; `delete` crate → `ctld.removeCrate(weight)`;
  `edit` crate → `ctld.patchCrate(weight, patch)`; troop `add`/`delete` → `ctld.addTroopGroup` /
  `ctld.removeTroopGroup`; array `add` → `ctld.addTo(setting, entry)`. The generated file registers
  one `ctld.userSetup` callback wrapping the calls, plus the YAML-scalar Section-1 block preserved
  from `FEAT-USERCONFIG-API`'s two-section template. `gen-user` runs `validate` first and refuses on
  any `error`.

- **`gen-user --scaffold`**: emits a commented `user-config.yaml` documenting the operations and per-
  entry fields, with two or three worked examples per operation. **Replaces** the hand-edited
  `dist/CTLD_userConfig.lua` template's role from `USERCONFIG-LOADING`; the build stops shipping a
  hand-maintained Lua template and ships (or documents how to produce) the YAML scaffold instead.

- **Datamine export**: `tools/dcs-data/gen_dcs_types.py` gains a **machine-readable export**
  (JSON/txt) of the type set, embedded in the package, so `validate` reads it directly rather than
  parsing Lua. The Lua `tests/data/dcs_types.lua` (busted linter) and the export stay generated from
  the same source.

- **Distribution**: `release.yml` gains a PyInstaller step producing `ctld-tools.exe` (Windows, the
  merge/release job is already on `windows-latest`) and attaches it to the GitHub Release. The `.exe`
  is a release artefact only; CI/build keep invoking the Python module (per ADR 0009).

- **i18n**: `desc`/`name` in generated entries are wrapped in `ctld.tr("…")` (same convention as lot
  2's generator), so MM-added entries participate in translation.

### Testing Decisions

Good tests assert observable behaviour at the **highest seam** — the report `validate` produces and
the Lua `gen-user` emits — not the internals of the compiler.

- **`validate` (YAML + reference + type set → report)** — Python `unittest` (prior art:
  `tools/integration-runner/test_run_scenarios.py`). Fixtures: valid config → clean report; each
  error class (unknown `weight` on `edit`/`delete`, colliding `weight` on `add`, unknown `unit`,
  malformed YAML, unknown array setting) → expected finding with severity + suggested fix. Warning
  vs error separation asserted.

- **`gen-user` (operations → Lua)** — Python `unittest` golden: operation set → expected helper calls
  (`addCrate`/`removeCrate`/`patchCrate`/`addTroopGroup`/`removeTroopGroup`/`addTo`), `desc`/`name`
  wrapped in `ctld.tr`; output passes `luac5.1 -p`; `gen-user` refuses when `validate` reports an
  error.

- **End-to-end runtime (lua5.1)** — execute the generated `CTLD_userConfig.lua` under `lua5.1`
  against the **real** `ctld.userSetup` helpers (from `FEAT-USERCONFIG-API`) plus the config
  reference, run the init/dispatch, and **deep-equal** the resulting `settings` against the expected
  post-operation state. Reuses lot 2's lua5.1 subprocess pattern; **skips cleanly** without `lua5.1`.
  This proves the whole chain yaml → lua → runtime, and that the compiled calls match the helper
  semantics (which are themselves busted-tested by `FEAT-USERCONFIG-API`).

- **Scaffold** — a smoke test: `gen-user --scaffold` output is itself a `user-config.yaml` that
  `validate` accepts and `gen-user` compiles without error (the documented examples stay valid).

Not tested here: the helper runtime semantics themselves (owned by `FEAT-USERCONFIG-API` busted
specs); the `ctld-config` generation (lot 2); `.miz` injection and TUI (roadmap).

### Out of Scope

- **`.miz` trigger injection** and the **interactive TUI** — `dev/roadmap.md`.
- **The runtime API** (`ctld.userSetup` + helpers) — delivered by `FEAT-USERCONFIG-API`; this lot
  only compiles to it.
- **`ctld-config` extraction/generation** — delivered by `CTLD-TOOLS-CONFIG` (lot 2); this lot
  consumes the reference.
- **New helpers** — this lot compiles only to the helpers `FEAT-USERCONFIG-API` defines; it adds none.
- **Non-Windows `.exe`** — MM distribution targets Windows (the DCS platform), as VMCT does.

### Further Notes

- Depends on `FEAT-USERCONFIG-API` + `CTLD-TOOLS-CONFIG` merged (runtime helpers + reference).
- This lot makes `ctld-tools` genuinely MM-facing; if real usage shows the raw YAML still rebuffs
  non-dev MMs, the TUI (roadmap) becomes the next priority.
- The `dist/CTLD_userConfig.lua` hand-template from `USERCONFIG-LOADING` is superseded by
  `gen-user --scaffold`; the delivery must reconcile the two so there is one documented starting
  point, not two.

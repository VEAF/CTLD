# ASSET-VALIDATION-REVAMP

**Status:** delivered. Compacted from `ASSET-VALIDATION-REVAMP/` on 2026-08-01; the ticket files live on in git history.

Removed `CTLD_modValidator`'s runtime probe-spawn (no more spurious `S_EVENT_BIRTH`/destroy at mission start). Shared `CTLDTypeCollector` (fixes the GROUND `unitType` gate gap); `modTypes` config setting; optional dev-time asset-check companion (`dist/CTLD_asset_check.lua`, no-spawn lookup). ADR [0007](../dev/adr/0007-design-time-asset-validation.md). CTLD PR #27; plugins gate fix PR #3.

## Tickets

| Ticket | Status | Title |
|---|---|---|
| `01-shared-type-collector` | 🧑 planned | 01 — Extract a shared configured-type collector |
| `02-modtypes-config-setting` | 🧑 planned | 02 — modTypes config setting (mission-maker mod whitelist) |
| `03-companion-validator` | 🧑 planned | 03 — Build the dev-time companion validator |
| `04-remove-modvalidator` | 🧑 planned | 04 — Remove CTLD_modValidator (the probe) from the deliverable |
| `05-docs-and-changelog` | 🧑 planned | 05 — Docs + CHANGELOG for the validation revamp |

## PRD

## Lot ASSET-VALIDATION-REVAMP — replace the runtime probe with a dev-time companion validator

Status: ✅ done (CTLD PR #27 merged; plugins gate fix PR #3 merged)
Branch: feature/asset-validation-revamp → PR #27 → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`)
ADRs: [0007 design-time asset validation](../../dev/adr/0007-design-time-asset-validation.md)

### Problem Statement

`CTLD_modValidator` validates DCS type names for crates / troops / AA / registry by **spawning a
probe object** at mission start (there is no DCS API that answers "does type X exist?" without
instantiating it) and destroying it. This:

- wastes resources on every mission start;
- fires real `S_EVENT_BIRTH` / destroy events that **any custom mission handler observes** — with
  unpredictable side effects on mission logic;
- is "spawn and pray".

A mission-maker's custom crate/troop config lives in the mission's own `DO SCRIPT`, in no repo, so
design-time CI cannot see it — the probe is currently its only safety net. But that net is a
**dev-time convenience** (faster feedback to the config author, who is also the person testing the
mission), not a production safety feature for the end player. So it need not run in production, and
certainly not by spawning objects.

### Solution (see ADR 0007)

Remove `CTLD_modValidator` (the probe) from the shipped `CTLD.lua` and replace its dev-time value
with an **optional companion `.lua`** the mission-maker loads **during mission development**:

- The companion bundles the vendored datamine set (`dcs_types.lua`, reused **as-is** — a dev-only
  file, no compaction) + a **passive validator**.
- It reads the **live** config + registry (`spawnableCrates`, `loadableGroups`, AA templates,
  `CTLDObjectRegistry._db`), cross-checks each type against `datamine ∪ declared extras ∪ MM config
  whitelist`, and emits a **WARN** on unknowns. **No instantiation, no events.**
- In production the MM omits the companion → zero overhead, and never a probe.

**Unified whitelist concept** (shared with Lot A, ADR 0007): the known set =
`datamine ∪ union of declared extra unit types`. Each definition declares its extras as
runtime-available metadata:

- a **scene model** carries `modTypes = { ... }` (authored in Lot A; the companion reads the union
  across all registered scene models — built-in and plugin — so plugin-scene mod types no longer
  read as "unknown");
- a **mission-maker** declares their own crate/troop mod types via a **config setting**
  (e.g. `_cfg.settings["modTypes"] = { ... }`), read by the companion.

Because the companion reads the registry (into which scenes register their types), it covers scene
types too, for free — there is **no separate scene path**; the enabler is simply that every
definition exposes its extras at runtime.

### Scope

- Remove `CTLD_modValidator` from `listToMerge.txt` + its call sites in `CTLD_crate`, `CTLD_troop`,
  `CTLD_config`, `CTLD_core`.
- Extract the type-collection logic into a **shared helper** used by both the companion and the
  busted linter (`config_types_lint_spec.lua`) — no third copy.
- Build the companion as a **single `.lua`** (set + validator) via the merge tooling; publish as an
  **optional release asset** alongside `CTLD.lua`.
- Add the `modTypes` config setting (MM mod whitelist) + doc.
- Remove/retool the probe's tests (`modvalidator_spec.lua`, `U-106`/`U-107`/`U-108` DCS scenarios);
  add busted coverage for the companion's validator + shared collector.
- Docs: mission-maker "validating your config during development" page (EN/FR) + CHANGELOG.

### Non-goals

- Scenes design-time validation — already delivered in `SCENE-PLUGINS` (Lot A).
- Making crates/troops **pluggable** — possible future generalisation, not this lot.
- Any production-time asset validation (the companion is dev-time only).

### Dependencies

- Follows `SCENE-PLUGINS` (Lot A): reuses the datamine set, the `modTypes` extras concept, and the
  hard-gate collector pattern. Lot A must land first (it authors `modTypes` on scene models).

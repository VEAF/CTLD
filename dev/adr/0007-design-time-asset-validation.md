# 7. Design-time asset validation over runtime probing

Status: Accepted (supersedes the runtime-scope decision of the DCS-DATAMINE-VENDOR lot)
Date: 2026-07-17

## Context

`CTLD_modValidator` validates that a configured DCS type name exists by **spawning a probe object**
at mission start and checking the result (`coalition.addGroup` then compare `getTypeName()` for
GROUND; `coalition.addStaticObject` returns nil for STATIC), then destroying it. There is no DCS
API that answers "does type X exist?" without instantiating it, so the probe is the only *runtime*
option — and it is intrinsically dirty: it wastes resources, and the spawn/destroy fire real
`S_EVENT_BIRTH`/destroy events that **any custom mission handler observes**. It is "spawn and pray".

The `DCS-DATAMINE-VENDOR` lot (PR #6) vendored a pinned set of ~1143 known stock DCS type names
(`tests/data/dcs_types.lua`, units + statics + heliports) and an offline busted linter, but
**explicitly kept runtime probing unchanged** and made the linter **lenient** (an unknown type may
be a legit mod type the stock set cannot know, so failing on it would be wrong). It also noted a
deferred follow-up: turn the linter into a hard gate via an allow-list of intentional non-stock
(mod) types.

## Decision

Shift asset validation from **runtime probing** to **lookup** against the vendored datamine set
plus a **declared whitelist of extra (non-stock) unit types**, making the check a **hard gate** at
design time.

One unified concept across both lots: the "known set" = `datamine ∪ union of declared extras`. A
definition declares the extra unit types it uses, as **runtime-available metadata**, consumed in two
places: the design-time busted gate (Lot A) and the runtime companion (Lot B). For a scene this is a
list on the scene model (e.g. `modTypes = { "Farp_FG_Petit_Helipad" }`), distinct from the
human-readable `requiresMod` label kept for docs; for a mission-maker's own crate/troop config it is
a **config setting** the MM declares, read by the companion.

Rolled out in two lots:

- **Scenes** (`SCENE-PLUGINS`, Lot A): remove `CTLDSceneManager:_auditAfterModValidator()` and its
  `requiresMod` runtime WARN entirely; replace with a hard-gate busted test that fails if a scene
  spawns a type absent from `dcs_types.lua ∪ whitelist`. All built-in scenes use base-game types
  present in the set; the whitelist covers mod types (e.g. `Farp_FG_Petit_Helipad`) in
  `CTLD_plugins`. `ModValidator` itself is untouched here (crates/troops still use it).
- **Crates / troops / AA / registry** (`ASSET-VALIDATION-REVAMP`, Lot B): remove `CTLD_modValidator`
  (the probe) from the shipped `CTLD.lua`. Its dev-time value is replaced by an **optional companion
  `.lua`** (datamine set + a passive validator) the mission-maker loads **during mission
  development**: it reads the live config + registry, cross-checks types against
  `datamine ∪ declared extras ∪ MM config whitelist`, and emits a WARN on unknowns — **no
  instantiation, no events**. In production the MM omits the companion → zero overhead, and never a
  probe. This is framed as a **dev-time convenience** (faster feedback to the config author), not a
  production safety feature — which is why it need not ship inside `CTLD.lua`. It closes the
  mission-side-config gap (custom config lives in the mission's own `DO SCRIPT`, in no repo) without
  the probe's side effects.

## Consequences

- No more spurious spawn/destroy events at mission start; validation is deterministic.
- **Residual risk (accepted)**: design-time proves the type *string* is known (stock or declared
  mod), not that the end user's DCS install actually has the mod loaded. That is the mission-maker's
  responsibility, made explicit in the docs.
- Scenes and mission-side crate/troop config are **not symmetric**: scene types live in a repo
  (fully design-time-coverable), a mission's custom crate config does not — hence Lot B keeps a
  *runtime* check, but a passive lookup in an opt-in companion, not a probe.
- The type set reaches runtime via the **companion file only** (never bundled in `CTLD.lua`); its
  format is the existing `return { [name]=true }` table reused as-is (a dev-only file, no compaction
  needed).
- Making crates/troops themselves *pluggable* (like scenes) is a possible future generalisation,
  explicitly **out of scope** for Lot B.

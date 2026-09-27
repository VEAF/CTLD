# FEAT-EXTR-GROUP-NAMING-CONVENTION — `EXTR_<name>` auto-discovery for extractable groups

**Status:** 🔄 in-progress (ticket 01 done; ticket 02 pending).

Formalizes the `dev/roadmap.md` entry "extractableGroups — détection automatique par convention de
nommage" and a `grill-with-docs` session held 2026-09-27 that resolved every point the roadmap
entry had left open.

## Problem Statement

Making a pre-placed Mission Editor group extractable at the F10 menu today requires a Mission
Maker to add its name to the `extractableGroups` config list (`CTLDCoreManager:
_initExtractableGroups`, `CTLD_core.lua:378`) — a manual step, separate from placing the group
itself, mirroring the friction `logisticUnits` had before `logisticUnitTypes` existed. A Mission
Maker who wants a group extractable has to remember to edit two places (the Mission Editor and the
config) instead of one.

## Solution

A Mission Maker can now make a pre-placed group extractable purely by naming it `EXTR_<name>` in
the Mission Editor — no config entry needed — the same authoring pattern already used for troop
pickup zones (`TRZ_…`). The existing explicit `extractableGroups` list keeps working exactly as it
does today; the two mechanisms coexist as a deduplicated union, so a group that happens to be both
listed **and** named by convention is registered once, not twice.

## User Stories

1. As a Mission Maker, I want to make a pre-placed group extractable by naming it `EXTR_<name>` in
   the Mission Editor, so that I don't have to also edit the `extractableGroups` config list.
2. As a Mission Maker with an existing mission using the `extractableGroups` config list, I want it
   to keep working exactly as before, so that upgrading CTLD never silently drops a group I
   configured the old way.
3. As a Mission Maker who (by coincidence or migration) has a group both listed in
   `extractableGroups` and named `EXTR_<name>`, I want it registered once, so that it never appears
   twice in the "Extract from field" F10 submenu for the same group.
4. As a Mission Maker placing a group of civilians (coalition NEUTRAL) I want to name it
   `EXTR_<name>` and have it recognized, so that a neutral group is not silently excluded the way
   the narrower RED/BLUE-only JTAC detection would exclude it.
5. As a Mission Maker, I want no metadata required after the `EXTR_` prefix beyond a name, so that
   naming a group extractable is as simple as the `SVNT_` convention, not as involved as `TRZ_`'s
   5-field format.
6. As a Mission Maker, I want to understand that an `EXTR_`-named group must exist at mission start
   to be recognized — a group spawned or activated later in the mission is not picked up — so that
   I'm not surprised when a late-activated group never appears extractable. (Same limitation the
   `extractableGroups` config list already has today, and the same open gap `dev/roadmap.md`'s
   "Zones dynamiques" entry tracks for zones — not solved here, for either mechanism.)
7. As a developer maintaining CTLD, I want `EXTR_` detection to reuse the exact `_droppedGroups`
   registration path the explicit list already uses, so that every downstream consumer (F10 "Extract
   from field", `embarkFromFieldByGroup`) treats a convention-named group identically to a
   config-listed one, with no special-casing anywhere else in `src/`.
8. As a developer maintaining CTLD, I want the startup log to distinguish how many groups came from
   the explicit list versus the `EXTR_` convention, so that a Mission Maker (or a bug report) can
   tell which path registered a given group.

## Implementation Decisions

- **New `CONTEXT.md` term, "Auto-discovered group"** (already added, sibling to the existing
  "Auto-discovered zone"): a DCS group or unit the engine recognizes by a prefix/substring in its
  Mission Editor name, no config entry required. Covers the existing JTAC substring match and
  `SVNT_` servant-unit prefix retroactively, and now `EXTR_`.
- **`EXTR_<name>` is a bare prefix, no positional metadata** — unlike `TRZ_`'s 5 required fields.
  Nothing about an extractable group needs to be configured from its name: coalition is already
  read live from the DCS group object (`group:getCoalition()`), exactly as the explicit-list path
  already does. `<name>` is free-form, used only for logging/identification.
- **`CTLDCoreManager:_initExtractableGroups` (`CTLD_core.lua:378`) is extended**, not replaced: the
  existing explicit-list loop is untouched. After it, a new pass scans `coalition.getGroups(side)`
  for `side` in `{RED, BLUE, NEUTRAL}` (wider than the RED/BLUE-only JTAC scan — covers a neutral
  civilian group), testing `^EXTR` against each group's name (anchored prefix, matching `SVNT_`'s
  style — not a free substring like the JTAC check). A name already present in
  `tm._droppedGroups[coalition]` (from the explicit-list pass) is skipped — this is the
  deduplication the roadmap calls for, and it matters functionally, not just cosmetically:
  `CTLDTroopManager:_findAllNearbyDropped` (`CTLD_troop.lua:1481`) would otherwise list the same
  group twice in the "Extract from field" F10 submenu.
- **Init-only — no late-activation support**, matching both existing precedents this feature sits
  next to: the explicit list itself (`-- No late-activation support (iso-legacy)`, already
  documented at `CTLD_core.lua:376`) and the JTAC group scan. This is a deliberate non-goal, not an
  oversight: the same class of gap is tracked separately for zones in `dev/roadmap.md`'s "Zones
  dynamiques" entry, and extending either mechanism to react to a group/zone appearing mid-mission
  is out of scope here.
- **No architectural mechanism unification with the zone naming conventions** (`TRZ_`/`EXZ_`/
  `LGZ_`/`WPZ_`, which scan `env.mission.triggers.zones`, the static Mission-Editor zone table).
  Groups are scanned via `coalition.getGroups(side)` instead — not a stylistic choice but the only
  live-enumeration API DCS actually offers for each object kind respectively (a trigger zone has no
  "list all zones" runtime API; a group does). No ADR: this isn't a trade-off between genuine
  alternatives, each object kind has exactly one available discovery mechanism.
- **Startup log distinguishes the two sources**: the existing per-group `INFO` log line
  (`"CTLDCoreManager: INIT-E — registered extractable group '%s' (coalition %d)"`) gains a source
  tag (explicit list vs. `EXTR_` convention), and the final summary log
  (`"CTLDCoreManager: INIT-E complete — %d extractable group(s) registered"`) reports both counts
  plus the total after deduplication.

## Testing Decisions

- Only external behavior is tested — what ends up in `CTLDTroopManager._droppedGroups[coalition]`
  after `_initExtractableGroups` runs, and what a Mission Maker sees in the "Extract from field" F10
  submenu — not internal scan mechanics.
- **No prior art exists for this exact call path**: `tests/ci/unit/core_spec.lua` only covers
  `CTLDDCSEventBridge`; nothing in `tests/ci/` exercises `CTLDCoreManager:_initExtractableGroups` or
  any other `INIT-*` function today. The tests this lot adds are the first coverage of this
  function — for both the pre-existing explicit-list behavior (as a natural side effect of testing
  the new dedup logic against it) and the new `EXTR_` scan. A new `tests/ci/unit/core_manager_spec.lua`
  is the natural home, one file per manager matching this project's convention, unless the
  implementer finds a more fitting existing file when they get there.
- Cases to cover: an `EXTR_`-named group registers a group not otherwise listed; a group both
  listed in `extractableGroups` and named `EXTR_<name>` registers once (dedup); a `NEUTRAL`-coalition
  `EXTR_`-named group registers (coalition scope includes civilians); a group whose name merely
  contains "EXTR" without the anchored prefix (e.g. `MyEXTR_Group`) is **not** matched (anchored,
  not substring); an `EXTR_`-named group that does not exist at init is silently skipped (no crash,
  no false registration) — mirrors the explicit list's own not-found handling.
- `CTLDTroopManager:_findAllNearbyDropped` itself needs no test change — it already iterates
  whatever `_droppedGroups` contains; the dedup guarantee belongs entirely to
  `_initExtractableGroups`.

## Out of Scope

- Late-activation support for either the explicit list or `EXTR_` (a group appearing after init) —
  explicitly deferred, same class of gap as `dev/roadmap.md`'s "Zones dynamiques" entry.
- Any positional metadata after the `EXTR_` prefix — settled as unnecessary during the grill
  session; revisit only if a concrete future need for per-group configuration from the name itself
  is identified.
- Retroactively refactoring the JTAC substring match or `SVNT_` prefix check to share a common
  "Auto-discovered group" implementation with `EXTR_` — the `CONTEXT.md` term unifies the concept
  for documentation purposes only; the three mechanisms' actual code stays independent unless a
  future lot finds a concrete reason to converge them.
- Updating `docs/mission-maker/` for the new convention — not scoped in this PRD; add as a ticket
  when this lot is broken down if the implementer judges it needed for release (this feature is
  authoring-surface-visible, unlike e.g. an internal refactor, so it likely does need a doc line —
  left for to-issues to decide as a ticket rather than assumed here).

## Further Notes

No ADR: the zones-vs-groups scanning-mechanism difference is forced by which live-enumeration API
DCS exposes for each object kind, not a deliberate architectural trade-off between real
alternatives — see Implementation Decisions above. `CONTEXT.md`'s new "Auto-discovered group" term
already ships with this PRD (added during the grill session, not deferred to implementation).

# FIX-DROPOFFZONES-PARITY — a v1 config's `dropOffZones` is ignored in silence

**Status:** open.

Opened 2026-07-31, from the documentation audit run for release `2.0.0-rc2` (PR #75). The audit only
removed the false claim from `docs/mission-maker/zones.{md,fr.md}`; the underlying parity gap is
untouched and lands here.

## Why

`dropOffZones` is a v1 setting the legacy monolith really reads. Nothing in `src/` reads it. A mission
migrating from v1 therefore loses behaviour **with no message of any kind** — not an error, not a
NOTICE, not a log line. That silence is the defect this lot is about; whether the behaviour itself
should come back is the question it has to answer.

### What the legacy engine does with it

Declared as a list of `{ zoneName, smokeColour, side }`, ten zones by default
([CTLD.lua:1517-1529](../../migration/source/CTLD.lua#L1517)). Three consumers:

| # | Legacy site | What it does |
|---|---|---|
| 1 | `ctld.inDropoffZone(_heli)` ([:10783](../../migration/source/CTLD.lua#L10783)) | True when the helicopter is inside a drop-off zone of its coalition (or `side == 0`). |
| 2 | `ctld.checkAIStatus()` ([:11067](../../migration/source/CTLD.lua#L11067), [:11075](../../migration/source/CTLD.lua#L11075)) | The only caller of #1. An **AI transport** carrying troops — or carrying a vehicle, in the second branch — auto-unloads when it is in a drop-off zone. |
| 3 | `ctld.refreshSmoke()` ([:10887](../../migration/source/CTLD.lua#L10887)) | Smokes drop-off zones on the periodic refresh, in the same loop as `pickupZones`, in the configured colour (normalised from its string form at init, [:11228](../../migration/source/CTLD.lua#L11228)). |

So the setting carries **two distinct features**, and CTLD 2 covers them unequally.

### What CTLD 2 covers

**The AI auto-unload is replaced.** An `aiZones` entry with `isDropoff: true` becomes a
`CTLDTroopZone` flagged `isAIDropoff` ([CTLD_zone.lua:705](../../src/CTLD_zone.lua#L705)), with
`aiDropMode` (`G` / `P` / `GP`) on top — strictly richer than the v1 behaviour. The replacement exists
and is documented; what is missing is any bridge from the old spelling to the new one.

**The smoke marking is not replaced — established, ticket 01.** The `CTLDTroopZone:new` call in
`_loadAIZonesFromConfig` passes ten fields and **no `smoke`**, so the constructor's default of `-1`
applies, and `-1` is exactly what `_scheduleSmoke` skips (`zone.smoke >= 0`). The schema's `aiZones`
entry has no smoke field either (ten fields, none of them smoke). The global `troopZoneSmokeColor`
setting is read in **one** place, `_discoverTRZ`, so it does not reach an AI zone. **An AI zone is
never marked, by any route that goes through the AI zone itself.**

Two findings that came with it:

- **A superimposed TRZ is a real workaround, with a trap.** A mission maker can put a second, inert
  trigger zone over the AI zone (`TRZ_<name>_<side>_0_nil_0`) and get the coalition smoke from
  `troopZoneSmokeColor`. But `_discoverTRZ` registers a TRZ under its **parsed** name, and
  `_loadAIZonesFromConfig` — which runs after it — skips any entry whose `dcsZoneName` is already a
  known troop zone. So naming the marker `TRZ_dropzone1_B_0_nil_0` next to an AI zone whose
  `dcsZoneName` is `dropzone1` **silently drops the AI entry**: same internal key, first one wins.
  The workaround only works with a different logical name. Nothing warns about this today —
  `_validateZoneNames` checks AIZ entries thoroughly but never against the TRZ/WPZ names, and it runs
  before discovery anyway.
- **Same exclusivity with the legacy `troopZones`.** That pass runs *after* the AI one and guards on
  `not self._troopZones[name]`, so listing the AI zone's name there to obtain smoke does nothing at
  all — the legacy entry is dropped, silently.

**The AI drop-off itself is a superset of v1 — established, ticket 01, though not for the reason this
PRD first assumed.** `onAILand` unloads a virtual vehicle, a physical vehicle *and* troops in a
drop-off zone, gated by `aiDropMode` (`G`/`GP`) and **not** by `aiCargoType` — that setting filters the
*pickup* path only. So a v2 AI drop-off zone unloads at least what v1 unloaded, whatever the entry's
`cargoType` says.

## The question this lot answers

Not "should we reimplement `dropOffZones`" — the answer to that is no, `aiZones` supersedes it and
reintroducing a second spelling would recreate the two-sources-of-truth pattern the recent program spent
four lots removing. The real questions are:

1. **Does a v1 config carrying `dropOffZones` say so?** Today: no. It should.
2. **Is losing the smoke marking acceptable, or is it a gap in `aiZones` worth closing on its own
   merits?** An AI drop-off zone a pilot cannot see on the map is arguably a feature gap independent of
   any migration story.

## Options considered

**A — recognise and report (recommended).** Detect a `dropOffZones` key in a loaded config, emit one
startup `NOTICE` naming it and pointing at `aiZones` + `isDropoff`, and document the transition in the
v1→v2 migration guide (which does not mention `dropOffZones` at all today — verified, zero occurrences
in `docs/developer/migration-v1-v2.{md,fr.md}`). Cheap, honest, consistent with how
`FEAT-JTAC-DRONE-GLOBALS` handled stale `specificParams`.

**B — A, plus an automatic translation at load.** Map each `dropOffZones` entry to a synthetic
`aiZones` entry (`isDropoff: true`, coalition from `side`) so a v1 config keeps working. Tempting, but
it silently rewrites a mission's configuration at runtime, which is exactly what ADR 0011 forbids —
nothing is merged, nothing is inferred. Rejected unless David wants the convenience explicitly.

**C — reimplement `dropOffZones` as a first-class setting.** Rejected: two spellings for one concept.

**Recommendation: A**, with the smoke question split out so it can be judged as a feature rather than as
migration debt.

### The smoke question, answered

**No new `smoke` field on `aiZones`.** The capability is not missing — a superimposed inert TRZ marks
the spot with the coalition colour — only the convenience is, and buying that convenience costs a
schema field, a runtime branch, an editor and a `version-gap` entry for a zone whose whole purpose is
AI routing. An AI drop-off zone is not a place a pilot needs to find. The migration guide states this
as a decision and documents the TRZ workaround **with its naming trap**, rather than leaving the next
reader to re-litigate it.

What the reading did turn up is worth its own ticket, and it is not about smoke: **an AI entry whose
`dcsZoneName` collides with a discovered TRZ/WPZ name is dropped without a word.** That is the same
silent-failure class this lot exists to remove. Deliberately kept out of this lot — it touches
`_validateZoneNames` and the startup report, and it deserves to be judged on its own.

## Definition of done

- A loaded config carrying `dropOffZones` produces exactly one startup NOTICE, naming the replacement.
- The v1→v2 migration guide documents the setting, what it did, and what replaces it, in EN and FR.
- The smoke question is answered in writing: either `aiZones` gains an optional smoke colour, or the ADR
  / migration guide records why AI zones are deliberately unmarked.
- No new configuration key is introduced.

## Out of scope

- Any change to `aiZones` semantics beyond an optional smoke colour, should ticket 03 conclude in favour.
- The legacy `pickupZones` → `troopZones` rename, which is already covered and correctly documented.

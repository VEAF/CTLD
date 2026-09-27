# FIX-ZONE-ANCHOR-DUPLICATION — one shared anchor implementation for `CTLDTroopZone`/`CTLDLogisticZone`

**Status:** 🔄 in review (PR #213).

Formalizes `dev/roadmap.md`'s "Lien générique zone ↔ objet de référence (owner-triggered)" entry —
launched directly to `to-prd` (skipping a dedicated `grill-with-docs` session, per explicit
instruction) with a **narrowed scope**, justified below, compared to the roadmap entry's original
framing.

## Problem Statement

`CTLDTroopZone` and `CTLDLogisticZone` (`CTLD_zone.lua`) each implement the same "anchor" concept —
a zone whose position is either fixed, tied to a live-tracked Mission Editor trigger zone, or
following a linked DCS unit — in **near-identical, independently-maintained code**: `getCenter()`,
`isDynamic()`, and `isAlive()` are the same logic in both classes, verified line-for-line during
this session. The only real difference is field naming (`CTLDTroopZone.dcsName`/`.center` vs
`CTLDLogisticZone._dcsZoneName`/`._center`) — an inconsistency with no functional reason to exist.

## Solution

Extract the shared anchor fields (`_linkedUnit`, `_anchorUnitName`, a real Mission-Editor zone name
for live lookup, a static fallback center) and methods (`getCenter()`, `isDynamic()`, `isAlive()`)
into a common base class, `CTLDAnchoredZone`, that both `CTLDTroopZone` and `CTLDLogisticZone`
inherit from via this codebase's existing `class(base)` single-inheritance mechanism
(`src/core/class.lua`) — the same pattern already used elsewhere in `src/`. `CTLDLogisticZone`'s
private field names (`_dcsZoneName`, `_center`) are reconciled to match `CTLDTroopZone`'s existing
public naming (`dcsName`, `center`) as part of unifying into the shared base — verified narrow
blast radius: only 5 references to the old names, all within `CTLD_zone.lua` itself.

## Scope narrowed from the roadmap entry — and why

The roadmap entry bundled three things under one heading. Only the first is built here:

1. **The anchor logic duplication** (above) — a real, present-tense duplication with exactly two
   consumers today. Built.
2. **A generic owner-registry** (`CTLDZoneManager:linkZonesToOwner(ownerId, {...})` /
   `:unlinkOwner(ownerId)`) letting a composite owner like a FOB register/unregister every zone
   type it's linked to with one call instead of `_destroyFOB`'s current two explicit calls
   (`unregisterLogistic` + `unregisterTroopZone`, verified still exactly this shape today). **Not
   built.** Verified during this session: `FEAT-FARP-TROOP-PICKUP` already confirmed the FARP —
   the roadmap's own candidate second composite owner — does *not* need this pattern (a FARP is a
   binary DCS `Airbase`, not a composite integrity-threshold judgment like a FOB). That leaves
   **exactly one real consumer** (the FOB) for a *generic, multi-owner-type* registry — building
   the general mechanism now, for one caller, is the speculative abstraction `CLAUDE.md` asks not
   to build ("no speculative abstractions... don't design for hypothetical future requirements").
   If a genuine second composite owner appears, that is the moment to build the generic registry,
   not before.
3. **The "camion" (truck-mounted mobile pickup zone) use case** — **not a code gap**, based on
   reading `createTroopZoneAtObject`/`_resolveTroopZoneObject`: it already resolves an arbitrary
   named `Unit` (not restricted to ships) and anchors the created `CTLDTroopZone` via `linkedUnit`
   — the identical mechanism `FIX-SHIP-ZONE-ANCHOR-PARITY` already proved for a ship. A Mission
   Maker can very likely already call `CTLDZoneManager:createTroopZoneAtObject("MonCamion",
   "TRZ_...")` today and get a pickup zone that follows the truck. This needs **live-DCS
   verification**, not new code — out of scope for this PRD, flagged as a follow-up verification
   task instead (see Further Notes).

## User Stories

1. As a developer maintaining `CTLD_zone.lua`, I want `getCenter()`/`isDynamic()`/`isAlive()` to
   exist once, not twice, so that a future bug fix or behavior change to anchor resolution can't
   drift between the two zone types the way two independently-maintained copies risk.
2. As a developer adding a new zone-entity class in the future that also needs anchor behavior
   (fixed / live Mission-Editor lookup / linked-unit tracking), I want to inherit `CTLDAnchoredZone`
   instead of copying the logic a third time.
3. As a developer reading `CTLDLogisticZone`, I want its anchor field names to match
   `CTLDTroopZone`'s (`dcsName`, `center`, not `_dcsZoneName`, `_center`), so that the same concept
   isn't spelled two different ways for no functional reason.
4. As a developer maintaining `CTLDFOBManager:_destroyFOB` (or any future composite-owner teardown
   path), I want this PRD to explicitly record why a generic owner-registry was *not* built now, so
   I don't have to re-derive "is this premature?" from scratch if I'm tempted to build one for a
   second consumer later.

## Implementation Decisions

- **New class `CTLDAnchoredZone = class()`** in `CTLD_zone.lua`, holding: `_linkedUnit`,
  `_anchorUnitName`, `dcsName` (the live-lookup Mission Editor zone name, may be nil), `center`
  (the static fallback vec3) — plus `getCenter()`, `isDynamic()`, `isAlive()` exactly as currently
  implemented (behavior unchanged, verified identical between the two existing copies).
- **`CTLDTroopZone = class(CTLDAnchoredZone)`, `CTLDLogisticZone = class(CTLDAnchoredZone)`** —
  each `init()` calls through to set the inherited fields, then continues with its own
  type-specific fields exactly as today.
- **`CTLDLogisticZone`'s `_dcsZoneName`/`_center` are renamed to `dcsName`/`center`** — matching
  `CTLDTroopZone`'s existing naming, both external references (already checked: none outside
  `CTLD_zone.lua`) and the 5 internal references within the file.
- **No change to any public `CTLDZoneManager` method, event, or the FOB register/unregister call
  shape** — `_destroyFOB` keeps its two explicit calls (`unregisterLogistic` + `unregisterTroopZone`)
  unchanged; this PRD only touches the two entity classes' internals.
- **No ADR** — a straightforward, low-risk refactor (extract-shared-base for a duplication already
  verified line-identical), not a design decision with genuine alternatives weighed for this part;
  the one real trade-off (not building the generic registry) is recorded in this PRD's own "Scope
  narrowed" section, which serves the same purpose without the ceremony.

## Testing Decisions

- Only external behavior is tested — `getCenter()`/`isDynamic()`/`isAlive()`'s observable results
  for a static zone, a zone linked to a unit, and a zone linked to a live Mission-Editor trigger
  zone — not which class in the hierarchy provides the implementation.
- Existing coverage (`ship_troop_zone_anchor_spec.lua` and any `CTLDLogisticZone` anchor-behavior
  specs — to be located when the ticket starts) must keep passing unchanged: this refactor moves
  code, it does not change what any existing test already asserts.
- No new test scenarios are anticipated — nothing about anchor *behavior* changes, only *where* the
  implementation lives. If the refactor is done correctly, the existing suite is the proof.

## Out of Scope

- The generic `linkZonesToOwner`/`unlinkOwner` owner-registry — see "Scope narrowed" above.
- Any change to `_destroyFOB`, `registerFOBAsLogistic`/`registerFOBAsTroopZone`, or any other
  `CTLDZoneManager` registration method.
- The truck-mounted mobile pickup zone use case — see "Scope narrowed" above; a live-DCS
  verification follow-up, not a code change.
- Absorbing the polling-based anchor mechanism (`_linkedUnit`/`_anchorUnitName`) into any
  owner-notification mechanism — moot, since no owner-registry is being built here either.

## Further Notes

**Follow-up outside this PRD**: verify live in DCS whether
`CTLDZoneManager:createTroopZoneAtObject("<truck unit name>", "TRZ_...")` already produces a
pickup zone that follows a moving ground vehicle, as the code strongly suggests. If confirmed, the
roadmap's "cas d'usage additionnel" closes with **no code change** — just a doc note and/or a live
DCS test scenario proving it, mirroring how `FEAT-FARP-TROOP-PICKUP`'s own investigation of the
FARP case played out.

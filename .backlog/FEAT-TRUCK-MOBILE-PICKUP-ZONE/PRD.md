# FEAT-TRUCK-MOBILE-PICKUP-ZONE — confirm a TRZ_ can follow a moving ground vehicle

**Status:** ✅ done — confirmed live in DCS (2026-09-28), `PASS 4/4`, no source change needed.

Formalizes `dev/roadmap.md`'s "Pickup zone mobile sur un camion de transport" entry (requested
2026-08-26) — launched directly to `to-prd` (no dedicated grill, the roadmap entry is already a
fully-reasoned investigation) with an explicitly **verification-first** scope: the code path
already appears to support this use case; what's missing is proof it behaves correctly for a
ground vehicle in live DCS, not new code.

## Problem Statement

A Mission Maker wants a troops pickup zone (`TRZ_`) that follows a moving ground vehicle (a supply
truck), so troops transported by that truck on the ground can be extracted by an aircraft landing
near it — the zone must track the truck's position, not stay fixed at its Mission Editor spawn
point.

Reading `CTLDZoneManager:createTroopZoneAtObject`/`_resolveTroopZoneObject` shows this already
resolves an arbitrary named `Unit` (not restricted to ships) and anchors the created
`CTLDTroopZone` via `linkedUnit` — the identical mechanism already proven for a ship
(`FIX-SHIP-ZONE-ANCHOR-PARITY`). Nothing in the code read so far limits the anchor unit to a naval
type. But this has never been exercised against a real ground vehicle in a live DCS mission: a
truck moves on terrain (elevation, road-following AI), not open water, and the zone's F10 menu,
smoke marker, and extract-detection radius all need to keep working sensibly as the anchor moves —
none of that is proven by reading the code alone.

## Solution

Write and run one live-DCS integration test scenario that anchors a `TRZ_` to a moving ground
`Unit` (a supply truck) via `CTLDZoneManager:createTroopZoneAtObject`, and confirms:

1. `getCenter()` tracks the truck's live position as it moves (not frozen at spawn).
2. `isDynamic()` reports `true` and `isAlive()` reports `true` while the truck exists.
3. If the truck is destroyed mid-test, `getCenter()` freezes at its last known position and
   `isAlive()` becomes `false` — the same degrade-gracefully behavior already proven for a sunk
   ship, applied here to a destroyed truck for the first time.

If the scenario **passes as-is**: this closes the roadmap entry with **no source change** — the
scenario itself becomes the permanent regression proof, and the roadmap entry is resolved to a
formalized-lot comment pointing here, same pattern as `FEAT-EXZ-AUTODISCOVERY`/
`FIX-AUTODISCOVERED-ZONE-FULLNAME-KEY`.

If the scenario **reveals a real gap** (e.g., a ground-vehicle-specific position/height quirk that
a ship never exercises): that becomes its own new `FIX-*` lot, scoped by whatever the failure
actually shows — not pre-designed here, since the nature of a hypothetical gap can't be known in
advance.

## User Stories

1. As a Mission Maker, I want to anchor a `TRZ_` pickup zone to a supply truck the same way I
   already can to a ship, so that ground-transported troops can be extracted near a moving vehicle.
2. As a Mission Maker, I want confidence this works from the project's own test suite, not just
   from reading the source, before I build a mission around it.
3. As a developer maintaining `CTLD_zone.lua`, I want a live-DCS regression test proving the
   ground-vehicle anchor case, mirroring the existing proof for the ship case, so a future change
   to anchor resolution (e.g., `FIX-ZONE-ANCHOR-DUPLICATION`'s `CTLDAnchoredZone`) can't silently
   break it for one anchor type while keeping the other working.
4. As a developer maintaining `dev/roadmap.md`, I want this "requested 2026-08-26" entry resolved
   one way or the other — confirmed-working or turned into a concrete bug ticket — rather than
   left open indefinitely as a suspicion.
5. As a Mission Maker reading this outcome, I want to know whether a truck's destruction leaves the
   pickup zone usable at the wreck (matching the ship's sunk-hull behavior) or removes it, so I can
   design a mission around the actual, confirmed behavior rather than an assumption.

## Implementation Decisions

- **New live-DCS integration test scenario**, `tests/dcs/noPlayer/` (no player/F10 interaction
  needed — every check is a direct `exec_lua` state read), tier `auto` or `auto-check` depending on
  whether the truck's movement is scripted with an immediate re-check or needs a short wait for the
  DCS AI driver to actually move it (decided when the ticket starts, per the `integration-testing`
  skill's tier table).
- **No change to `CTLDZoneManager`, `CTLDTroopZone`, or `CTLDAnchoredZone`** unless the scenario's
  result says otherwise — this PRD's default assumption, per the "Solution" section above, is that
  the existing generic mechanism already works.
- **The test mission (`missions/Test_CTLDNEXT_01.miz`) needs one named ground vehicle unit** (a
  truck) placed and, ideally, given a short scripted route so the scenario can observe real
  movement rather than a stationary check — this is Mission Editor work, done by the Mission
  Maker (the same division of labor already established for `aiZones` config and
  `FEAT-MOVING-ZONE`'s own test-asset additions), not something this session edits into the binary
  `.miz` directly.
- **Scenario calls `CTLDZoneManager:createTroopZoneAtObject(<truck unit name>, "TRZ_...")`
  directly** (the same scripted-API entry point `FEAT-FARP-TROOP-PICKUP`/`FIX-FOB-TROOP-PICKUP`
  already use) — no new public API needed.

## Testing Decisions

- Only external, observable behavior is tested: `getTroopZone(trzName):getCenter()` before and
  after the truck moves, `:isDynamic()`, `:isAlive()` before and after the truck is destroyed
  (`trigger.action.explosion` or similar on the unit, then a re-check).
- Prior art: no existing scenario exercises `createTroopZoneAtObject` or any anchor-tracking
  behavior live in DCS today (checked — `FIX-SHIP-ZONE-ANCHOR-PARITY`'s own proof was at the
  `busted` unit-test level, not a live-DCS scenario). This is the first live-DCS scenario for the
  anchor mechanism, using `tests/dcs/_template_noPlayer.lua` (or `_template_scenario.lua` if a
  short movement wait turns out to be needed) as its starting template.
- `busted tests/ci/` is unaffected (no `src/` change expected) unless the scenario's result forces
  a code fix, in which case standard unit-test coverage accompanies that fix per this project's
  usual TDD rule.

## Out of Scope

- The generic `linkZonesToOwner`/`unlinkOwner` owner-registry — already rejected in
  `FIX-ZONE-ANCHOR-DUPLICATION` for the same "one real consumer" reason; a truck is a third poll-based
  anchor case, not a composite owner, so it doesn't change that conclusion.
- Automatic truck detection by naming convention or vehicle type (the roadmap's "Automatisation"
  open question) — a separate, larger design question (same shape as the FOB/FARP auto-TRZ_
  question), deliberately deferred, not part of confirming the base mechanism works.
- Deciding whether truck destruction *should* explicitly tear down its zone instead of freezing at
  the wreck (the roadmap's "Destruction du camion" open question) — out of scope **unless** the
  scenario itself surfaces a reason the current freeze-at-last-position behavior is actually wrong
  for a ground vehicle specifically (e.g., a wreck being usable for extraction may be more
  surprising on land than at sea). If the live test raises this as a real concern, it's flagged
  back to the user rather than decided unilaterally here.

## Further Notes

This PRD is deliberately narrow — one ticket, one scenario, a binary pass/fail-shaped outcome —
because its entire purpose is to convert a documented suspicion (`dev/roadmap.md`, requested
2026-08-26) into either confirmed-working proof or a concretely-scoped bug, mirroring how
`FEAT-FARP-TROOP-PICKUP`'s own FARP investigation was resolved earlier.

Running this scenario requires a live DCS instance with `dcs-serve` connected and
`Test_CTLDNEXT_01.miz` loaded — per this project's workflow, the agent stops and asks for explicit
confirmation before requiring the user to have DCS running for this test.

## Result (2026-09-28)

Confirmed live in DCS: `tests/dcs/noPlayer/scenario_truck_anchor.lua` returned `PASS 4/4` against
`Test_CTLDNEXT_01.miz`'s `truckai_anchor_test` group (a late-activated `M 818` truck with a short
road route). `createTroopZoneAtObject` + `linkedUnit` already track a moving ground vehicle
correctly — position tracking, `isDynamic()`, and freeze-at-last-position on destruction all
behave identically to the already-proven ship case. **No `src/` change was needed.**

One implementation nuance surfaced during the first run: the template group is late-activated (by
design, per this ticket), so the scenario must call `trigger.action.activateGroup()` on it before
the AI driver will move — omitting this made the truck sit at spawn with `speed=0` indefinitely
(diagnosed live via a throwaway `exec_lua` velocity check, not a CTLD bug). This is now handled in
scenario step S1 and documented in its header comment.

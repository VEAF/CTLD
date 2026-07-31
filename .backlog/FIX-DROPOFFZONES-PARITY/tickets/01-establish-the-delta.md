# 01 — establish the delta, and settle the smoke question

**Status:** todo

No dependency. Blocks 02 and 03.

## Why

The PRD carries one unverified fact: whether an `aiZones` entry can be smoked. Everything else in this
lot depends on the answer — it decides whether ticket 03 documents a deliberate omission or specifies a
new optional field. The reading was interrupted mid-file and must be finished before any code is
written.

## What to establish

1. **Smoke on AI zones.** Read the `CTLDTroopZone:new` call in `_loadAIZonesFromConfig` to its closing
   brace ([CTLD_zone.lua:752](../../../src/CTLD_zone.lua#L752) onward). Does it pass `smoke`? If not,
   confirm the consequence against `_scheduleSmoke` ([CTLD_zone.lua:930-944](../../../src/CTLD_zone.lua#L930)):
   a zone with `smoke == -1` is skipped, so an AI zone is never marked.
2. **Whether an AI zone can be smoked by another route.** An MM can name a trigger zone so it is *also*
   discovered as a TRZ, or list it in the legacy `troopZones`, and get smoke that way. If that works, the
   gap is a convenience gap, not a capability gap — which changes the recommendation. Check that a zone
   registered by discovery is not skipped by `_loadAIZonesFromConfig`'s
   `not self._troopZones[dzn]` guard ([CTLD_zone.lua:732](../../../src/CTLD_zone.lua#L732)); at first
   reading that guard means **the AI entry is dropped** when the zone is already known, which would make
   the two mutually exclusive. Confirm.
3. **Legacy parity on the AI path itself.** v1 unloads troops *and* vehicles in a drop-off zone
   ([CTLD.lua:11067](../../../migration/source/CTLD.lua#L11067), [:11075](../../../migration/source/CTLD.lua#L11075)).
   Confirm the v2 `isAIDropoff` path covers both cargo kinds, via `aiCargoType` (`T` / `V` / `TV`), so the
   replacement really is a superset and the PRD's claim holds.

## Acceptance

- The PRD's "to confirm" paragraph is replaced by a statement of fact, with the line references that
  establish it.
- Point 2 is answered yes or no, because it decides ticket 03's shape.
- If point 3 reveals a hole, this lot's scope grows and the PRD says so — better found here than by an
  MM in a mission.

## Tests

None — this is a reading ticket. Any behaviour it discovers is pinned by the ticket that acts on it.

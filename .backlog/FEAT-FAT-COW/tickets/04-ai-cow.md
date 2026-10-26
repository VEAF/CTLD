# 04 — AI cow: requested by a flight, escorts it, serves it, goes home

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FEAT-FAT-COW](../PRD.md). Decision 1, AI mode.

## What to build

- F10 **Request a Fat Cow** for a player of a flight, only on the ground inside a friendly CTLD logistic zone. CTLD spawns a CH-47 from the configured template next to the zone, with the default AI stock (full fuel, 3 × 800 gal ≈ 7 200 kg, and 6 Hellfires).
- The cow **follows** the flight (DCS `Follow` task on the requesting group).
- When the flight's leader lands, the cow gets a `Land` task (a task on a turning point, not a `Land` waypoint: VMCT measured that a `Land` waypoint goes to the nearest airfield) on open ground near the leader; **60 s** after its own landing, it deploys.
- When the flight's leader takes off, the cow packs, takes off and follows again.
- Empty stock, or F10 **Release the Fat Cow**: it packs if deployed, flies back to its logistic zone, lands and despawns.
- A **mission-placed** AI CH-47 is a cow when a config entry names it with the flight it escorts (the VMCT contract, see the PRD).

## Acceptance criteria

- [ ] Busted: request refused outside a logistic zone or in the air; one cow per flight; land → deploy after the delay; take-off → pack + follow; empty → home + despawn; release → home + despawn; a configured mission cow is picked up at start.

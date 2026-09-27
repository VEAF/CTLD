# 01 — Write and run the live-DCS truck-anchor verification scenario

**Status:** ✅ done — `tests/dcs/noPlayer/scenario_truck_anchor.lua` run live against
`Test_CTLDNEXT_01.miz`, verdict `PASS 4/4` (2026-09-28).

**Blocked by:** none, but requires a **late-activated** ground vehicle group template in
`Test_CTLDNEXT_01.miz` (Mission Editor step — see "What to build") and a live DCS instance with
`dcs-serve` connected before it can actually be run.

## What to build

A new `tests/dcs/noPlayer/` scenario (tag e.g. `SCN-TRUCK-ANCHOR`, tier `auto-check`) that follows
this project's existing clone-at-runtime pattern (already used by e.g. `scenario_mt12_ai_vehicle_
native.lua` for a helicopter template) rather than requiring a permanent live unit in the mission:

1. Finds the late-activated template group in `env.mission.coalition` by name, deep-copies it,
   renames the clone, sets `lateActivation = false`, and spawns it via `coalition.addGroup`
   (`Group.Category.GROUND`) — the clone gets its own short route from the template's
   Mission-Editor-authored waypoints.
2. Calls `CTLDZoneManager:createTroopZoneAtObject("<clone unit name>", "TRZ_truckpickup_B_1_nil_0")`
   against the clone's `Unit`, records `getTroopZone(...):getCenter()` as the initial position.
3. Polls (`waitFor`, a few seconds interval, ~60s timeout) until the clone has moved a meaningful
   distance from its spawn point (its route carries it there), then re-reads `getCenter()` and
   asserts it tracks the clone's live position (not frozen at spawn).
4. Asserts `isDynamic()` is `true` throughout.
5. Destroys the clone (`:destroy()` on the `Unit` or `Group`), waits briefly for the destruction to
   register, then asserts `isAlive()` becomes `false` and `getCenter()` stays frozen at the clone's
   last known position (not nil, not an error).
6. Cleanup destroys the clone unconditionally (pass or fail) — the template itself is never
   activated or consumed, so the scenario is repeatable without any mission reload.
7. Returns the standard `PASS`/`FAIL`/`ABORT` verdict contract (see `integration-testing` skill).

**Mission Editor step (done by the Mission Maker, not this ticket's agent)**: place one
**late-activated** ground vehicle group (a truck-type unit) in `Test_CTLDNEXT_01.miz` with a short
2-3 waypoint road route, never itself activated by any trigger — mirroring how `heliai_mt12` is
set up for `scenario_mt12_ai_vehicle_native.lua`. Confirm the exact template group name with the
Mission Maker before referencing it in the scenario (suggested: `truckai_anchor_test`).

## Watch out

- Follow the `integration-testing` skill's injection loop and return-contract exactly — this is
  the first live-DCS scenario exercising the anchor mechanism at all (checked: none exists today,
  `FIX-SHIP-ZONE-ANCHOR-PARITY`'s own proof was `busted`-level, not live-DCS).
- Per this project's workflow: running this scenario needs DCS running with `dcs-serve` connected
  and the mission loaded — **stop and get explicit confirmation before requiring the user to have
  DCS up**, rather than assuming it's already running.
- Do not touch `CTLDZoneManager`, `CTLDTroopZone`, or `CTLDAnchoredZone` unless the scenario
  actually fails — the PRD's default assumption is the mechanism already works. If it fails,
  stop and report the concrete failure rather than guessing a fix blind.
- Don't build the generic owner-registry, automatic truck detection, or an explicit
  destroy-on-death teardown — all out of scope per the PRD, unless the scenario itself surfaces a
  concrete reason one of these is actually needed (report back rather than deciding unilaterally).

## Acceptance

- New scenario file exists under `tests/dcs/noPlayer/`, tagged and tiered per the
  `integration-testing` skill.
- Scenario has been run against live DCS at least once and returned a definitive `PASS` or `FAIL`
  verdict (not left at `ABORT`/unresolved).
- **If PASS**: `dev/roadmap.md`'s "Pickup zone mobile sur un camion de transport" entry is resolved
  to a formalized-lot HTML comment (same pattern as prior resolved entries), and this PRD/ticket
  close as done — no `src/` change.
- **If FAIL**: the concrete failure is reported back before any fix is attempted; a fix, if one
  follows, is scoped as its own new `FIX-*` lot with its own PRD, not folded into this one.

## Tests

The scenario itself *is* the test — this ticket's deliverable is a `tests/dcs/` integration
scenario, not a `busted tests/ci/` unit test. `busted tests/ci/` is only touched if the live test
forces a `src/` fix, per the PRD's Testing Decisions.

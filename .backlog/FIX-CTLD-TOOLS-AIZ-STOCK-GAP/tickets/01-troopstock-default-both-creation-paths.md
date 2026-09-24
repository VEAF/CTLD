# 01 — `troopStock` default on both zone-creation paths

**Status:** ✅ done

**Blocked by:** none — can start immediately.

## What to build

Whenever a new `aiZones` entry is created — by the `AIZ_` naming-convention silent reconciliation
(`addMissingAizZones`) or by the manual "+ AI zone" button (`addZone`) — and its effective
`cargoType` includes `T` (`T` or `TV`), set `troopStock` to `{All: -1}` (unlimited) instead of
leaving it absent. `vehicleStock` is never given an equivalent default on either path — its
absence stays a legitimate, untouched configuration.

## Watch out

- Both creation paths must behave identically for this rule — a Mission Maker must never see the
  auto-detected and the manually-added path treat the same missing field differently.
- A pickup zone whose cargo is vehicle-only (`cargoType: "V"`) gets no `troopStock` default —
  the rule is keyed on cargo actually including troops, not on `isPickup` alone.
- A dropoff-only entry (`isPickup` false) never gets a `troopStock` default either way.
- Don't touch `vehicleStock` in either creation path — that stays exactly as it is today (absent).
- This ticket does not add any validation check or UI indicator — those are tickets 02 and 03,
  independently.

## Acceptance

- A zone silently added by the naming-convention scan with `cargoType` `T` or `TV` gets
  `troopStock: {All: -1}`; one with `cargoType` `V` gets no `troopStock`.
- Clicking "+ AI zone" seeds the same `troopStock: {All: -1}` default (its current default
  `cargoType` is `T`).
- `vehicleStock` is absent from a newly created entry either way, unchanged from today.
- An existing entry already present is never touched by this default (reconciliation's own
  additions-only rule, `FEAT-CTLD-TOOLS-AIZ-SYNC` ticket 03, is unaffected by this change).

## Tests

`web/src/lib/aizConvention.test.ts` and `web/src/lib/AiZonesEditor.test.ts` (vitest), extending
the existing style: a silently-added troop-cargo entry gets the default; a silently-added
vehicle-only entry does not; "+ AI zone" seeds the same default; an existing entry is untouched.

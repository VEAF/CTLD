# 01 — `createAtPoint` accepts a requested frequency per band

**Status:** 🧑 waiting-human

## Why

`createAtPoint` draws all three frequencies from `_pickFreq`, so a mission that briefs a frequency
cannot place a beacon on it. See the PRD for the full problem statement.

## What changes

- `opts.frequencies` — an optional table, any subset of `{ vhfKHz, uhfMHz, fmMHz }`. Absent bands
  keep drawing at random; an absent or empty table is exactly today's behaviour.
- `CTLDBeaconManager._bands` — the three bands with their option key, unit, Hz multiplier, declared
  range and pool field names. The one place the band's range and unit are stated.
- `_resolveFreqRequest(request)` — validates without mutating; returns the granted entries as
  `{ [band] = { freq = Hz, index = <index in the free pool> } }`, or `nil, reason`.
- `_takeFreq(free, used, index)` — moves one entry from free to used. `_pickFreq` now calls it after
  its recycle-and-random, so both paths leave the pool through the same code.
- `_assignFrequencies(granted)` — granted where the caller asked, `_pickFreq` everywhere else.
- `createAtPoint` validates before anything else and returns `nil, reason` on refusal; on a failed
  spawn it now returns the three drawn frequencies to their pools before returning
  `nil, "beacon spawn failed"`.

## Acceptance

- `createAtPoint(point, coa, country, {})` and calls carrying only `name` / `isFOB` /
  `batteryMinutes` behave exactly as before (the two VEAF call sites, `dropBeacon` and
  `createAtZone`).
- A request for one band is granted; the other two stay random.
- `fmMHz = 45.2` yields exactly `45200000` Hz.
- Each refusal case returns `nil` plus a reason and consumes nothing.
- A retried request after a failed spawn is granted.

## Tests

busted, in `tests/ci/unit/beacon_scripted_api_spec.lua` (reusing its `newManager()` fixture):
default path unchanged, empty request table, all three bands granted, one band granted, fractional
value, pool bookkeeping and release on removal, the four refusal cases, refusal costs nothing,
spawn-failure release, and the `_bands`-versus-pools drift guard.

## Docs

`CHANGELOG.md` `[Unreleased]`; `docs/developer/api-reference.md` + `.fr.md`;
`docs/developer/subsystems/beacons.md` + `.fr.md`.

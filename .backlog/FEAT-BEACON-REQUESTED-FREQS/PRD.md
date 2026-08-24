Status: 🧑 waiting-human

# PRD — FEAT-BEACON-REQUESTED-FREQS : a scripted beacon on the frequency the briefing names

## Problem Statement

`CTLDBeaconManager:createAtPoint(point, coalitionId, countryId, opts)` — the scripted way for a
mission's own code to place a radio beacon, shipped by `FEAT-VMCT-INTEGRATION` ticket 03 — spawns
three beacons (VHF, UHF, FM) and draws all three frequencies at random from the internal pools.
There is no way, public or private, for the caller to ask for a particular one.

That is a hole for the case the API exists to serve. A mission that wants a beacon on an **agreed**
frequency — an FM channel briefed to a helicopter crew, a frequency printed on a kneeboard, a NDB
reused across missions of a campaign — cannot have one. The caller can only read back what the pool
happened to pick and tell the pilots about it after the fact.

The VEAF Mission Creation Tools is the first caller to hit it: its `-beacon` marker command is built
on `createAtPoint`, and today it can only answer *"here is the frequency CTLD picked for you"*.
Usable, and not what a mission designer wants.

## Solution

`opts` gains an optional `frequencies` table. Any subset of the three bands may be named; the bands
left out keep drawing at random, so every existing call is unchanged.

```lua
mgr:createAtPoint(point, coalition.side.BLUE, country.id.USA, {
    name        = "FARP Alpha NDB",
    frequencies = { vhfKHz = 250, fmMHz = 40.5 },   -- UHF stays random
})
```

## Implementation Decisions

- **One key per band, and the unit is in the key name** — `vhfKHz`, `uhfMHz`, `fmMHz`. A bare `freq`
  number could not say which of the three bands it applies to, and a single unit for all three would
  force VHF to be written as `0.25` MHz. The band's own unit is the one a mission maker reads off a
  kneeboard, and the one `CTLDBeacon:freqText()` prints (`"250.00 kHz - 251.00 / 40.50 MHz"`); the
  module keeps storing Hz.

- **A unit mistake cannot pass silently.** Each band's declared range (`200–1250` kHz,
  `220–398.5` MHz, `30–75.9` MHz) is narrow enough that no value expressed in Hz, nor in kHz where
  MHz was meant or the reverse, falls inside any band's range — so the range check *is* the unit
  check. `CTLDBeaconManager._bands` holds those bounds next to the band's unit; a spec asserts they
  still agree with the pools `_buildFreqPools` actually builds, so the two cannot drift apart.

- **A request that cannot be granted refuses the whole call** — `createAtPoint` returns
  `nil, reason` and logs, spawning nothing and consuming no frequency. Four cases, all of them the
  caller's mistake:
  - an **unknown key** (`vhf = 250` instead of `vhfKHz = 250`) — otherwise a typo silently gets a
    random frequency, which is the exact failure the option exists to remove;
  - a value **outside the band** — the shape a unit mistake takes;
  - a value in range but **absent from the pool**: off its step grid, or one of the real-world NDB
    frequencies `_ndbSkip` deliberately withholds because a map beacon already occupies it. Granting
    it would break the pool's one invariant — every frequency in circulation came out of the pool,
    and `_freeFrequencies` puts all three back — so an off-grid frequency granted here would be
    *added* to the pool on removal and later drawn at random for someone else;
  - a value the pool holds but a **live beacon already uses** — the collision the pool exists to
    prevent, and one that also corrupts the bookkeeping: removing the first of two beacons sharing a
    frequency returns to the free pool a frequency the second is still transmitting on.

- **Refusing rather than falling back to a random pick with a warning.** A beacon that answers on a
  frequency other than the briefed one is a failure neither side can see: the mission maker's
  kneeboard still says 250 kHz, and the pilot who tunes 250 kHz simply hears nothing. A refused call
  is something the caller can react to; a substituted frequency is not.

- **Validate first, consume second.** `_resolveFreqRequest` checks the whole request against the
  pools and returns the granted entries with their index in the free pool, mutating nothing;
  `_assignFrequencies` then removes them. So a refusal on the third band cannot leave the first two
  consumed. `_pickFreq` and the new `_takeFreq` share the one place a frequency leaves the free pool.

- **A failed spawn gives the frequencies back** (pre-existing leak, fixed here because the feature
  walks straight into it): the three frequencies were drawn before the spawn, so without this a
  caller retrying the same request would be told its own frequency is already in use by a beacon
  that does not exist.

- **`createAtZone` and `dropBeacon` are untouched.** Both are pilot- or ME-facing paths where nobody
  is holding a briefed frequency; `createAtPoint` is the scripted surface, and it is the one VMCT
  calls.

## Testing Decisions

Added to `tests/ci/unit/beacon_scripted_api_spec.lua`, reusing its `newManager()` fixture (real
frequency pools, stubbed `_spawnBeaconUnit`), as a nested `describe`:

- the default path still draws all three bands at random, and an empty `frequencies = {}` is treated
  as no request;
- a granted request on all three bands, on one band only (the other two staying random), and a
  fractional value (`fmMHz = 45.2`, whose double is inexact) matching the pool's exact Hz entry;
- pool bookkeeping: a granted frequency leaves `_free*` and enters `_used*`, and comes back on
  `removeBeacon` so it can be asked for again;
- one test per refusal case, plus: a refused call costs nothing (pool sizes, `_beaconCount`, spawn
  count and `_beacons` all unchanged), and a failed spawn frees the frequencies so the same request
  can be retried;
- the drift guard on `_bands` versus the built pools.

## Out of Scope

- Exposing the request through `createAtZone`, `dropBeacon` or the legacy `ctld.*` wrappers.
- A configuration setting for fixed beacon frequencies — this is a scripting API, not a catalogue.
- Reserving a frequency ahead of a beacon, or a first-come queue for a contested one.
- The orphaned DCS groups a partially-failed spawn leaves behind (pre-existing; only the frequency
  leak on that path is fixed here, being the one the refusal rule depends on).
- Anything on the VMCT side: its `-beacon` marker command is tracked in that repo.

## Definition of Done

- `createAtPoint` grants a requested frequency per band, leaves unrequested bands random, and every
  existing caller behaves exactly as before.
- Each refusal case returns `nil` plus a reason naming the band and the unit, and consumes nothing.
- busted specs cover the default path, the granted paths and every refusal case.
- `CHANGELOG.md` `[Unreleased]`, the developer API reference and the beacon subsystem page updated in
  EN **and** FR.

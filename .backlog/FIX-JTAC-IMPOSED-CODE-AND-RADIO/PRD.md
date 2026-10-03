# FIX-JTAC-IMPOSED-CODE-AND-RADIO — an imposed laser code taken twice, a supplied radio ignored

**Status:** ⬜ ready — two design decisions to take at the start (below)

Reported by VMCT on 2026-10-02 (VMCT lot `FIX-OPEN-TRAINING-SYRIA-FINDINGS`, ticket 18), validated by
David. Found in game on the Syria Open Training v6 (dcs-serve), checked in the code of 2.0.0-rc11 — the
release VMCT vendors — and still so on `develop` at `576f5411`.

## What happened

The mission's `modules.ASSETS` declares a drone, Reaper 1, with `jtac = 1688`, `freq = "36.0"`, `mod =
"FM"`. VEAF starts it through `CTLDJTACManager:autoLase(groupName, 1688, false, "all", nil, asset)`
(`veafSpawn.JTACAutoLase`, VMCT `veafSpawnAircraft.lua`), the whole ASSETS entry passed as `radio`.
`CTLDJTACManager.jtacs` then held **two** JTACs on 1688: Reaper 1, and VEAF's catalogue template
`veafSpawn-MQ9 - AFAC - JTAC - DRONE`, which `_initMMJTACs` (INIT-C) registers by its name. And Reaper 1
announced itself on about 40.4 FM, not 36.0.

## Causes, in `src/CTLD_jtac.lua` / `src/CTLD_core.lua`

1. **An imposed code never leaves the pool.** `spawnJTAC` (`:447`) and `startLaseTroopUnit` (`:794`) take
   `cfg.laserCode` when given, else `_assignLaserCode()` (`:1399`), which is `table.remove(self._laserPool)`
   — the **highest** free code. An imposed code is not removed from `_laserPool`, so the next automatic
   assignment can hand it out again. `_freeLaserCode` (`:1405`) puts any code back on deregistration or
   death (`:620`, `:688`), imposed ones included, so a second copy of an imposed code can enter the pool.
2. **The order of registration decides who wins.** INIT-C (`CTLDCoreManager:_initMMJTACs`,
   `CTLD_core.lua:346`) registers every active group whose name contains "jtac" at CTLD's start, with an
   automatic code — 1688, the top of the default range — **before** VEAF's `veafAssets.initialize` imposes
   its codes. Removing an imposed code from the pool when it is imposed would not have helped here: it was
   already handed out.
3. **A supplied radio is dropped.** `autoLase` (`:741`) puts `radio` in `cfg`, but `spawnJTAC` does not pass
   it on, and `CTLDJTAC:new` (`:85`) always sets `self.radio = CTLDJTACDetector.calculateFMRadio(...)` from
   the laser code (`:201`) — `nil` for a code outside `[jtacLaserCodeMin, jtacLaserCodeMax]`.
4. **The pool may hold codes DCS refuses.** `_initLaserPool` fills every integer of
   `jtacLaserCodeMin..jtacLaserCodeMax` (1111..1688 by default). The reporter says codes with a 9 or a 0
   (1199) are invalid in DCS — **to verify** against DCS before acting on it.

## Workaround in the Syria mission meanwhile

`jtacLaserCodeMax = 1686` (the catalogue drone takes 1686), the Reapers on 1511 / 1512, and the briefing
announces 35.55 / 35.6 FM — the frequencies CTLD computes for those codes. VMCT carries it as the known
limitation `ctld-jtac-imposed-code-and-radio`.

## Decisions to take at the start

- **a. How an imposed code wins over an automatic one already handed out** (cause 2). Options: a
  `reserveLaserCode(code)` API that a caller (VEAF, from its ASSETS) uses before INIT-C, the pool skipping
  reserved codes; or, when a code is imposed on a JTAC and another JTAC holds it automatically, that other
  one is re-coded. The first needs VMCT to call it at load; the second works whatever the order but changes
  a running JTAC's code.
- **b. The shape of a supplied radio** (cause 3). VEAF passes its ASSETS entry: `freq` a string or a number,
  `mod` `"FM"` upper case, extra fields (`name`, `jtac`, `description`...). CTLD's own is
  `{ name, freq = <string>, mod = "fm" }`. Normalise what is given, or require CTLD's shape and adapt VEAF.

## Done when

- Two JTACs, one imposed on 1688 and one automatic, get distinct codes **in either order of
  registration**; an imposed code is never handed out automatically, and never returned to the pool.
- A JTAC given a radio announces that radio; the code-derived one only when none is given, as today.
- The pool holds only codes DCS accepts, once that rule is verified.
- busted tests for each; `CHANGELOG.md` `[Unreleased]`; a release VMCT vendors, after which VMCT sets the
  known limitation's `fixed_in`.

## Out of scope

- Whether VEAF's catalogue template should carry "JTAC" in its name — a template is late-activated and
  never meant to lase; that is VMCT's call, raised to it separately if the fix above does not settle it.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [An imposed laser code is reserved, whatever the order](tickets/01-imposed-code-reserved.md) | ⬜ |
| 02 | [A supplied radio is kept](tickets/02-supplied-radio-kept.md) | ⬜ |
| 03 | [The laser pool holds valid codes only](tickets/03-valid-laser-codes.md) | ⬜ |

# 01 — widen the FM pool's `s` digit to `0..9`

**Status:** ✅ done

See the PRD for the legacy-parity evidence and full reasoning.

## What changes

1. `src/CTLD_beacon.lua`, `CTLDBeaconManager:_buildFreqPools` (~line 198): widen `s` to `0..9` for
   `f=3..6` only — `f=7` keeps `s=0..5`, since widening it too would push the pool's top past the
   declared 75.9 MHz ceiling (`CTLDBeaconManager._bands.fm.max`) to 79.9 MHz. Update the comment
   above it accordingly.
2. `tests/ci/unit/beacon_scripted_api_spec.lua`:
   - `"refuses a frequency the pool does not offer"` (~line 340): replace `{ fmMHz = 38 }` with
     `{ fmMHz = 38.05 }`, and its comment (`-- 380 needs s=8, and s only runs 0..5`) with one
     explaining it's off the 0.1 MHz step grid (the `t` digit gives the step, not `s`).
   - `"costs nothing when refused"` (~line 376): same replacement, same reasoning, in the
     multi-band refusal request table.
3. `docs/developer/api-reference.md` / `.fr.md`: the `fmMHz` row's step column — drop the five
   sub-range list (`30–35.9`, `40–45.9`, `50–55.9`, `60–65.9`, `70–75.9`), state a plain
   continuous `0.1 MHz` step across `30 – 75.9`, matching how the `vhfKHz`/`uhfMHz` rows read.
4. `CHANGELOG.md` `[Unreleased]`: a **Fixed** entry.

## Watch out

- Do not touch `CTLDBeaconManager._bands`'s `fm` entry (`min=30, max=75.9`) — the range is
  unchanged, only the pool's density within it.
- Do not touch VHF/UHF pool generation, or anything about `_ndbSkip` — unrelated to this bug.
- `beacon_spec.lua`'s existing FM pool tests (non-empty, in-range) need no change — verify they
  still pass rather than assuming; they were written range-based specifically so a density change
  like this wouldn't break them.

## Acceptance

- `_buildFreqPools` produces exactly 460 FM entries (was 300), covering every 100 kHz step from
  30.0 to 75.9 MHz with no gap.
- `mgr:createAtPoint(..., { frequencies = { fmMHz = 38 } })` now succeeds (was refused).
- `busted tests/ci/` green, `luacheck --config .luacheckrc src/` clean, `CTLD.lua` rebuilt.

## Tests

- Add a case to `tests/ci/unit/beacon_spec.lua`'s "FM pool" describe block asserting the pool's
  exact size is 460 (the existing two tests there are deliberately loose — non-empty, in-range —
  this fix is exactly the kind of density regression a count assertion should catch going
  forward).
- Update the two `beacon_scripted_api_spec.lua` cases per "What changes" above; add one new case
  there confirming a previously-gapped frequency (e.g. `fmMHz = 38`) is now granted successfully.

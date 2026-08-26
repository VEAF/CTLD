# FIX-BEACON-FM-POOL-GAP — the FM beacon pool is missing a third of its band

**Status:** ✅ done

Reported by **David "Zip" Pierron** ([GitHub issue #127](https://github.com/VEAF/CTLD/issues/127)),
raised from the VMCT side while building a `-beacon` marker command on `createAtPoint`. Grilled
2026-08-26.

## The deviation

`CTLDBeaconManager:_buildFreqPools` ([CTLD_beacon.lua:196-203](../../src/CTLD_beacon.lua#L196))
builds the FM pool as `for f = 3, 7 do for s = 0, 5 do for t = 0, 9 do ... end end end`, capping
the tens digit (`s`) at 5 instead of 9. Over the documented 30.0–75.9 MHz range this yields 300 of
the 460 possible 100 kHz steps, with four gaps: **36.0–39.9**, **46.0–49.9**, **56.0–59.9**,
**66.0–69.9 MHz** — including 38.00 MHz, an entirely ordinary FM frequency a DCS FM radio tunes
without complaint.

**Confirmed inherited from legacy, not a CTLD2-rewrite regression**:
[`migration/source/CTLD.lua:6171-6188`](../../migration/source/CTLD.lua#L6171)
(`ctld.generateFMFrequencies`) has the identical `_second = 0, 5` shape — so per `CLAUDE.md`'s
legacy-parity rule, fixing this is a deviation that needs explicit sign-off, which issue #127
provides.

**Confirmed as an artefact, not a deliberate exclusion** (unlike VHF's `_ndbSkip` list, a
principled set of real-world NDB frequencies to avoid): the legacy source carries a comment
directly above the function describing an entirely different, never-implemented 4-digit/0.05 MHz
scheme ("fourth digit 0 or 5"), and a dead loop immediately before it
(`local _start = 220000000; while _start < 399000000 do _start = _start + 500000 end` —
increments and discards, populates nothing) that reads as a leftover copy-paste of the UHF
generator's shape, never cleaned up. The four gaps correspond to no real-world FM constraint.

## What changes

- `CTLD_beacon.lua`, `_buildFreqPools`'s FM loop: `s` runs `0..9` for `f=3..6` (closes the four
  internal gaps), but stays `0..5` for `f=7` — widening it there too would push the top of the
  pool to 79.9 MHz, past the documented/declared 75.9 MHz ceiling
  (`CTLDBeaconManager._bands.fm.max`). The FM pool becomes continuous over 30.0–75.9 MHz at its
  existing 0.1 MHz granularity (300 → 460 total steps); the band's own range is unchanged, only
  its density. (Caught during implementation by the existing `beacon_scripted_api_spec.lua` test
  that cross-checks `_bands`' declared min/max against the actual pool — a naive uniform
  `s=0..9` for every `f` would have silently grown the band past its documented ceiling.)
- **Scope, deliberately minimal**: just the digit-range widening the issue itself proposes. The
  4-digit/0.05 MHz idea the dead legacy comment gestures at is explicitly out — nobody asked for
  it, and it would double the pool's resolution for no stated need.
- Two existing tests in `tests/ci/unit/beacon_scripted_api_spec.lua` hard-code the current gap as
  expected behavior and must be updated, not just left to fail:
  - `"refuses a frequency the pool does not offer"` (~line 340): `{ fmMHz = 38 }` — becomes
    reachable once `s` runs to 9, so no longer a valid "off-grid" case.
  - `"costs nothing when refused"` (~line 376): reuses the same `fmMHz = 38` as its "off-grid"
    band in a multi-band refusal scenario.
  - Both replaced with `fmMHz = 38.05` — still off the 0.1 MHz step grid regardless of `s`'s
    range (the step comes from `t`, not `s`), same testing intent as the neighboring VHF (`205`,
    off the 10 kHz step) and UHF (`251.25`, off the 0.5 MHz step) cases in the same test block.
- `docs/developer/api-reference.md` / `.fr.md`: the `fmMHz` row currently documents the five
  sub-ranges (`30–35.9`, `40–45.9`, `50–55.9`, `60–65.9`, `70–75.9`) as if they were the actual
  reachable set — becomes a plain continuous `0.1 MHz` step description matching VHF/UHF's rows.
- `CHANGELOG.md`: a **Fixed** entry — restored/completed behavior, not a new feature (same
  framing as `FIX-SHIP-ZONE-ANCHOR-PARITY`).

## Definition of done

- The FM pool holds all 460 steps from 30.0 to 75.9 MHz; no gap.
- `busted tests/ci/` green (including the two updated `beacon_scripted_api_spec.lua` cases).
- `docs/developer/api-reference.md`/`.fr.md` no longer state the sub-range restriction.
- No migration note: nothing for a mission maker to do — a wider random pool is a strict
  superset of the old one, and `opts.frequencies` requests that were previously refused for
  landing in a gap now succeed instead, which is the point of the fix.

## Out of scope

- The 4-digit/0.05 MHz finer-grid idea — a different, bigger change nobody has asked for.
- `CTLDBeaconManager._bands`'s `fm` entry — its `min`/`max` don't change.
- VHF/UHF pool generation — unaffected, not part of this bug.

## Further Notes

- No ADR: a factual bug fix restoring intended density to an existing range, not a design
  trade-off — same reasoning `FIX-I18N-STALE-COMMENT-PARSING` used to skip one.

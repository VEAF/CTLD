# 02 — `maxSlingloadSpeed` default: 50 → 26

**Status:** done

## Why

The setting is in **metres per second**: `CTLD_crate.lua:1100` compares it to the magnitude of
`Unit:getVelocity()`, and there is no conversion factor anywhere in `src/` (checked for 3.6, 1.94384,
0.539957, 2.23694 — the only hits are an unrelated helper and the JTAC orbit speed).

So the shipped default of `50` meant **~180 km/h / 97 kt**, close to double a UH-1H's sling-load limit,
and reads exactly like a value entered as knots by someone who assumed the API returned knots. The
sibling gate in `CTLD_troop.lua:1266` (`speed < 2.2`) uses the same idiom and is unmistakably m/s.

FullGas reached the same conclusion independently in his review of PR #68 and recommended `26`
(≈ 50 kt). David called it.

## What changed

- `src/CTLD_config.yaml`: `maxSlingloadSpeed: 50` → `26`
- `src/CTLD_crate.lua:1089`: the `or 50` fallback → `or 26`. **Not optional**: leaving it would have
  given the same setting two different defaults depending on whether a user config was loaded — the
  exact divergence class this review turned up for `maximumSearchDistance` and
  `maximumDistanceLogistic`.
- Parity oracle regenerated, `CTLD.lua` rebuilt. All three sources verified at 26.
- A description added to the schema, in both languages, that **states the unit** and spells out what
  50 would have meant — the original mistake was an invisible unit, so the fix includes making it
  visible. Also promoted to `standard: true`: a speed limit pilots feel is not an advanced setting.
- `tests/test_encoding.py` gains a test tying the Lua fallback to the catalogue value, so they cannot
  drift again.

## Consequence to communicate

**This changes in-flight behaviour.** A slung crate is now cut loose at a lower speed than in any
previous build. Missions that relied on hauling fast will need to raise the setting — which is now
documented and sits under Common settings, so a Mission Maker can find it.

## Not fixed here

The other two catalogue/fallback divergences (`maximumSearchDistance` 3000 vs 10000,
`maximumDistanceLogistic` 200 vs 500) are still on `dev/roadmap.md`. They are harmless while a
catalogue is loaded — which it always is — and picking a winner is a behaviour call of its own.

# 03 — Gate "Parachute Troops"/"Parachute All" on `enableParachuteDrop`, new tests

**Status:** ✅ done

**Blocked by:** ticket 01 (the setting must exist before any code reads it).

## What to build

In `CTLD_troop.lua`, add `ctld.gs("enableParachuteDrop")` as an inline `and`-condition alongside
the existing `caps2.canParachuteDrop` check at the single "Parachute Troops"/"Parachute All" build
site (the troop menu section rebuilds fully on every flight-state change rather than toggling
visibility separately, so there is only one call site here, unlike Crates/Vehicles).

No shared helper function — inline, matching ticket 02 and ADR 0019.

## Watch out

- This is the one domain with a single call site instead of two (build + refresh) — don't go
  looking for a second site to patch; there isn't one, because the whole section rebuilds instead
  of toggling.
- `enableParachuteDrop` defaults to `true` (ticket 01) — no change for an existing mission until
  explicitly disabled.
- Don't touch the adjacent `hasTroops`/`inTransitList` logic — this ticket only adds the new
  condition to the existing `caps2.canParachuteDrop` check.

## Acceptance

- `caps2.canParachuteDrop=true` + `enableParachuteDrop=true` (default) + troops onboard + in
  flight: "Parachute Troops" (or "Parachute All" for a multi-group transit list) behaves exactly as
  before this lot.
- `caps2.canParachuteDrop=true` + `enableParachuteDrop=false`: the entry is absent regardless of
  troops onboard or flight state.
- `caps2.canParachuteDrop=false`: the entry stays absent regardless of `enableParachuteDrop`
  (unchanged pre-existing behavior).

## Tests

`tests/ci/functional/parachute_spec.lua` — new describe block mirroring "F-063/F-064 —
canParachuteDrop menu" (ticket 02) but for Troops: build a player menu with troops in transit and
`canParachuteDrop=true`, assert "Parachute Troops" is present at `enableParachuteDrop=true`
(default) and absent at `enableParachuteDrop=false`. This closes the pre-existing gap noted during
the `grill-with-docs` session — no dedicated toggle test exists for this node today, only
incidental coverage at `canParachuteDrop=true` in `menu_gating_spec.lua`/`troop_fastrope_spec.lua`,
which this ticket does not modify.

# 04 — Gate "Parachute Vehicle" on `enableParachuteDrop`, new tests

**Status:** ⬜ ready

**Blocked by:** ticket 01 (the setting must exist before any code reads it).

## What to build

In `CTLD_vehicle.lua`, add `ctld.gs("enableParachuteDrop")` as an inline `and`-condition alongside
the existing `caps.canParachuteDrop` check, at both sites:
- the build-time `menu:addCommand` for "Parachute Vehicle" in `buildMenuSection`,
- `refreshParachuteVehicleSection`'s visibility toggle (`menu:setBranchEnabled`).

No shared helper function — inline, matching tickets 02/03 and ADR 0019.

## Watch out

- Same two-site shape as Crates (ticket 02): both the build-time add and the refresh-time toggle
  need the new condition, or the menu can end up inconsistent.
- Don't touch the adjacent `canCarryVehicles` guard — this ticket only adds the new condition to
  the existing `caps.canParachuteDrop` check.
- `enableParachuteDrop` defaults to `true` (ticket 01) — no change for an existing mission until
  explicitly disabled.

## Acceptance

- `caps.canParachuteDrop=true` + `enableParachuteDrop=true` (default): "Parachute Vehicle" behaves
  exactly as before this lot (present, toggled by flight state + vehicle loaded).
- `caps.canParachuteDrop=true` + `enableParachuteDrop=false`: the node is absent regardless of
  flight state or vehicle loaded.
- `caps.canParachuteDrop=false`: the node stays absent regardless of `enableParachuteDrop`
  (unchanged pre-existing behavior).

## Tests

`tests/ci/functional/parachute_spec.lua` — new describe block mirroring "F-063/F-064 —
canParachuteDrop menu" (ticket 02) but for Vehicles: build a player menu with `canCarryVehicles`
true and `canParachuteDrop=true`, assert "Parachute Vehicle" is present at
`enableParachuteDrop=true` (default) and absent at `enableParachuteDrop=false`. Closes the same
pre-existing coverage gap ticket 03 closes for Troops — no dedicated toggle test exists for this
node today.

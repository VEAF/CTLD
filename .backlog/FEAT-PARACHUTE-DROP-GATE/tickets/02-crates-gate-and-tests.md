# 02 — Gate "Parachute Crates" on `enableParachuteDrop`, extend F-063/F-064

**Status:** ⬜ ready

**Blocked by:** ticket 01 (the setting must exist before any code reads it).

## What to build

In `CTLD_crate.lua`, add `ctld.gs("enableParachuteDrop")` as an inline `and`-condition alongside
the existing `caps.canParachuteDrop` check, at both sites:
- the build-time `menu:addCommand` for "Parachute Crates",
- `refreshCrateFlightSection`'s visibility toggle (`menu:setBranchEnabled`).

No shared helper function — write the condition inline at each site, matching how every other
capability check in this file (and the rest of the codebase) is already written. See **ADR 0019**
for why a shared predicate was rejected.

## Watch out

- Both sites must agree: if only the build-time check gets the new condition and the refresh-time
  toggle doesn't (or vice versa), a stale/inconsistent menu state becomes possible.
- Don't touch `canSlingload`'s adjacent checks in the same functions — this ticket is scoped to the
  parachute condition only.
- `enableParachuteDrop` defaults to `true` (ticket 01) — an existing mission must see zero change
  in "Parachute Crates" visibility until a Mission Maker explicitly disables the new setting.

## Acceptance

- `caps.canParachuteDrop=true` + `enableParachuteDrop=true` (default): "Parachute Crates" behaves
  exactly as before this lot (present, toggled by flight state + cargo onboard).
- `caps.canParachuteDrop=true` + `enableParachuteDrop=false`: "Parachute Crates" node is absent —
  the global switch overrides the per-type capability.
- `caps.canParachuteDrop=false`: "Parachute Crates" stays absent regardless of
  `enableParachuteDrop` (unchanged pre-existing behavior).

## Tests

`tests/ci/functional/parachute_spec.lua`, describe block "F-063/F-064 — canParachuteDrop menu":
add two cases — `enableParachuteDrop=false` + `canParachuteDrop=true` hides the node;
`enableParachuteDrop=true` (default) + `canParachuteDrop=true` still shows it (no regression).
Extend `buildPlayerMenu`'s `ctld.gs` stub to answer `enableParachuteDrop` per case, defaulting to
`true` where not overridden.

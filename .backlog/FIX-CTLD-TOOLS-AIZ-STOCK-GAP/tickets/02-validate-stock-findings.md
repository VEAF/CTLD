# 02 — Validation: two `WARNING` findings for a stockless pickup entry

**Status:** ✅ done

**Blocked by:** none — can start immediately.

## What to build

Two new `WARNING`-severity findings in `ctld_tools/validate.py`'s catalogue-wide `validate()`,
one per affected `aiZones` entry:

- an entry with `isPickup` true, effective `cargoType` including `T`, and `troopStock` still
  nil/empty — reachable in practice mainly for a hand-edited or otherwise-bypassed configuration,
  since ticket 01's default makes it structurally rare through the normal UI paths;
- an entry with `isPickup` true, effective `cargoType` including `V`, and `vehicleStock` absent —
  worded to explain the physical-placement fallback the engine actually uses in that case, not
  phrased as if something were broken.

`WARNING`, not `ERROR`, for both — this matches the engine's own runtime message for the troop
case, which is itself a `WARN`, not a startup failure.

## Watch out

- Each finding must identify its own entry specifically (mirror the existing per-table-entry
  finding shape already used for `spawnableCrates`, e.g.
  `where = f"spawnableCrates.{section}[{entry.get('desc', weight)}]"`) — with several `aiZones`
  entries, a Mission Maker must be able to tell which one a finding is about.
- A dropoff-only entry, or a pickup entry whose cargo doesn't include the relevant type, never
  produces either finding.
- The vehicle-case finding's wording must read as informational (explaining a legitimate mode),
  not alarming — it is not the same class of problem as the troop case, even though both are
  `WARNING` severity in this validator (which has no `INFO` level).
- This ticket does not change either zone-creation path's defaults (ticket 01) or add any UI
  indicator (ticket 03) — purely the backend check.

## Acceptance

- A pickup entry with troop cargo and no `troopStock` produces the troop finding, at `WARNING`.
- A pickup entry with vehicle cargo and no `vehicleStock` produces the vehicle finding, at
  `WARNING`, worded informationally.
- A complete entry, and a dropoff-only entry, produce neither finding.
- Each finding's `where` identifies its own entry, not just "aiZones" generically.
- Neither finding blocks export (both are warnings, not errors) — `has_errors()` stays `False`
  when only these findings are present.

## Tests

`tools/ctld-tools/tests/test_validate.py` (pytest), extending the existing style: the troop case;
the vehicle case; a complete entry produces neither; a dropoff-only entry produces neither; the
`where` correctly identifies the specific entry among several; `has_errors()` is unaffected by
either finding on its own.

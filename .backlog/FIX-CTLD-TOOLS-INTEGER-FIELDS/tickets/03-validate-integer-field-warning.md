# 03 — `validate.py` check for a fractional value on an `integer`-typed field

**Status:** ✅ done

**Blocked by:** tickets 01 and 02 (needs both sets of `integer`-typed fields to exist to check
against).

## What to build

A new `ctld_tools/validate.py` check, `WARNING` severity (not `ERROR` — a fractional value doesn't
structurally break an export the way a missing zone does), that flags **any currently-loaded
value** of any field marked `'integer'` (both ticket 01's scalar settings and ticket 02's table
fields) that carries a fractional value — not only a value edited in the current session. This
catches a hand-edited YAML or a `configUser`/catalogue that predates this lot, which is the whole
point of the check: a value that bypassed the UI entirely.

Follow the same `Finding`/`where`/`key` shape this project's `_validate_ai_zones` already
established (same repo, same day) for the `aiZones` stock checks — one finding per offending
value, identifying exactly which setting or table entry it came from.

## Watch out

- Must not fire on any field confirmed continuous in the PRD (weights, distances/altitudes/radii,
  durations, the two multiplier factors) — a negative test for at least one of these is part of
  this ticket's acceptance, not optional.
- Runs against every value already in a loaded catalogue, not just a freshly-edited one — this is
  the difference between a UI nicety and an actual safety net.

## Acceptance

- A fractional value on any of the 11 scalar settings from ticket 01, or any of the four table
  fields from ticket 02, produces a `WARNING` finding identifying the exact setting/entry.
- A fractional value on a legitimately continuous field (a weight, a distance) never produces this
  finding.
- The finding fires on a catalogue loaded as-is (e.g. a hand-edited YAML), not only on a value
  edited through the UI in the same session.

## Tests

`tools/ctld-tools/tests/test_validate.py` (pytest): one case per field category named in the PRD's
field inventory (a scalar setting, a `loadableGroups` field, a `capabilitiesByType` field,
`cratesRequired`, an `aiZones` stock count) confirming the `WARNING` fires and identifies the right
entry, plus a negative case confirming a continuous field (a weight or a distance) never fires it —
mirroring `_validate_ai_zones`'s own test suite, added the same day for the troopStock/
vehicleStock stock gap.

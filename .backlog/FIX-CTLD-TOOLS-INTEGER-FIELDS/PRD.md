# FIX-CTLD-TOOLS-INTEGER-FIELDS — a real `integer` field type for ctld-tools

**Status:** open.

Closes [GitHub issue #157](https://github.com/VEAF/CTLD/issues/157) ("Fields using decimals
instead of integers", a.lingo, 2026-09-22) on merge. Formalizes a `grill-with-docs` session held
2026-09-24 while investigating that issue — decisions below are settled, not open for
re-derivation; the grill's own trace is in this session's transcript, not duplicated here.

## Problem Statement

A Mission Maker editing `loadableGroups` in `ctld-tools` can type `6.01` into the "Infantry" count
of a troop template — a value CTLD's engine cannot use (a group needs a whole number of soldiers).
Nothing in the tool's UI discourages this, and nothing catches it afterwards: the Mission Maker
only discovers the problem in DCS, if at all, where the engine silently gets a fractional count it
was never designed to handle.

The same gap exists across most of the tool's numeric fields — quotas, limits, laser codes,
launcher counts, stock quantities — because `ctld-tools` has no notion of "this number must be a
whole number" anywhere in its type system. Every numeric field is treated identically, whether it
represents a count of soldiers or a distance in metres.

## Solution

Give `ctld-tools` a real `integer` field type, distinct from a continuous `number`, and use it
everywhere a field genuinely represents a whole-number quantity: soldier/launcher counts, quotas,
limits, laser codes, stock counts, and a few standalone scalar settings. The three UI components
that render numeric inputs enforce the right input behaviour per field (a whole-number step, the
value rounded on edit) instead of applying one blanket rule to every number. A new `validate.py`
check catches a non-integer value that reached the catalogue any other way (a hand-edited YAML, an
older `configUser`), so the UI fix isn't the only line of defence.

Every field confirmed this project needs as a continuous quantity — every weight, every
distance/altitude/radius, every duration, the two multiplier factors — is explicitly left alone;
none of the whole-number defaults they happen to carry today changes their nature.

## User Stories

1. As a Mission Maker editing a troop template's `loadableGroups` entry, I want the soldier-count
   fields (infantry, machine gun, anti-tank, anti-air, mortar, JTAC) to reject a fractional value,
   so that I cannot accidentally configure a group CTLD cannot spawn correctly.
2. As a Mission Maker editing `capabilitiesByType`, I want `maxCratesOnboard`,
   `maxTroopsOnboard` and `maxWholeVehiclesOnboard` to behave as whole-number limits, so that an
   aircraft's onboard capacity is never expressed as a fraction of a crate or a troop.
3. As a Mission Maker editing `spawnableCrates`, I want `cratesRequired` to stay a whole number, so
   that a crate assembly's requirement is never ambiguous about how many crates it actually takes.
4. As a Mission Maker editing an `aiZones` entry's `troopStock`/`vehicleStock`, I want each stock
   count to stay a whole number, so that the available quantity at a zone is never fractional.
5. As a Mission Maker editing a scalar setting that is a quota, limit, code or size
   (`numberOfTroops`, `JTAC_LIMIT_BLUE`/`RED`, `AASystemLimitBLUE`/`RED`, `aaLaunchers`,
   `jtacLaserCodeMin`/`Max`, `JTAC_smokeColour_BLUE`/`RED`, `beaconTextSize`), I want the same
   whole-number enforcement, so that these settings can't silently drift into a value the engine
   was never designed to receive.
6. As a Mission Maker editing a weight, a distance, an altitude, a radius, a duration, or a
   multiplier factor, I want the field to keep accepting decimals exactly as it does today, so
   that a legitimately continuous quantity is never artificially restricted.
7. As a Mission Maker who hand-edits a YAML config outside `ctld-tools` (or reopens a `configUser`
   authored before this fix), I want `ctld-tools validate` to warn me about any integer field that
   already carries a fractional value, so that I find out before exporting rather than in DCS.
8. As a Mission Maker editing a mixed-set crate's coalition (`side`), I want the same RED/BLUE
   dropdown the non-mixed-set crates already use, instead of a free-typed number, so that I cannot
   type a coalition id that doesn't exist.
9. As a developer maintaining `ctld-tools`, I want one shared `integer` field type used
   consistently by every component that renders a numeric input, so that a future numeric field
   only has to declare its kind once instead of every rendering component reimplementing the same
   distinction.
10. As a developer maintaining `ctld-tools`, I want the exception this fix makes to ADR 0011
    Addendum 1's "derive the tier from the value's shape, don't declare new metadata" principle
    written down and justified, so that a future reader doesn't mistake the new `type: integer`
    schema annotation for an unexplained lapse from that principle.
11. As a developer maintaining `ctld-tools`, I want the fix scoped to the fields actually
    confirmed integer-only this session, so that a legitimately continuous field (a weight, a
    distance) is never accidentally coerced to a whole number as a side effect.

## Implementation Decisions

- **A real `integer` value is added to the `EditorType` union** (today `'boolean' | 'enum' |
  'number' | 'string'`), rather than three independent local patches to the three components that
  render numeric fields. The row/field-rendering component that already branches on `'boolean'` vs
  `'enum'` vs the rest branches on `'integer'` the same way, applying a whole-number step and
  rounding the parsed value on every edit.
- **Two distinct, independently-decided mechanisms supply the "this field is an integer"
  metadata** — not one mechanism forced onto both:
  - For scalar settings (driven by the settings schema + its API, arbitrary catalogue keys not
    known at the tool's compile time): an optional `type: integer` annotation added to the schema,
    alongside the existing `unit:`/`label:`/`description:` annotations. Absent means `number`,
    unchanged from today. Threaded through the API response the same way the existing annotations
    already are.
  - For the three bespoke table editors (troop templates, aircraft capabilities, AI zone stock —
    whose field lists are hardcoded, compile-time-known TS arrays, independent of the YAML
    schema): the relevant entries are marked `'integer'` directly in those hardcoded field lists,
    reusing the same `Field.type` mechanism the troop-template fields already use for `'number'`.
    The aircraft-capabilities field list, today a bare array of field names with no per-field type
    at all, is restructured into a typed field list so its integer and continuous fields
    (onboard-capacity limits vs. max vehicle weight) can finally be told apart.
- **Both a UI-side fix and a backend validation check**, mirroring this project's own
  troopStock/vehicleStock stock-gap fix (same day, same repo): the UI prevents a fresh edit from
  landing a fractional value; a new `WARNING`-severity `validate` finding (not `ERROR` — a
  fractional value doesn't structurally break an export the way a missing zone does) catches any
  integer-typed field's value that bypassed the UI — a hand-edited YAML, or a catalogue/config
  loaded from before this fix existed. The check runs against every currently-loaded value, not
  only against a value edited in this session, since catching what already got in is the point.
- **`spawnableCrates.side`'s mixed-set branch gets its own fix, in the same lot but unrelated to
  the integer-type mechanism**: it currently renders a free-typed number for a RED/BLUE coalition
  id, while the ordinary (non-mixed-set) crate editor two lines below already renders the correct
  RED/BLUE dropdown for the same field. The mixed-set branch is made to use that same dropdown.
- **`JTAC_smokeColour_BLUE`/`JTAC_smokeColour_RED` are marked `integer`, not converted to an
  enum**, even though both actually encode a closed, named 0–4 set. Turning them into a real
  dropdown is a separate, smaller idea, explicitly deferred: it does not add to
  `dev/roadmap.md` as a new item on its own, it is the ticket that documents this decision that
  notes it as a "Watch out" for a future contributor, so the observation isn't lost without adding
  a whole new roadmap entry for a two-line idea.
- **No migration of existing data**: every field in scope for the `integer` type already carries a
  whole-number default in the shipped catalogue today. This is a forward-looking prevention fix,
  not a data-repair task.
- **An ADR is written** documenting why the scalar-settings half of this fix (a schema-declared
  `type: integer`) is a deliberate, acknowledged exception to ADR 0011 Addendum 1's principle that
  a config tier is derived from the shape of a value rather than declared as new metadata: shape
  alone cannot distinguish a genuine whole-number count from a value that is legitimately
  continuous but merely happens to be a whole number in today's defaults, so a human declaration is
  unavoidable for this specific distinction. The two-mechanism split (schema-declared for scalar
  settings vs. compile-time-hardcoded for the bespoke table editors) is the trade-off the ADR
  records.

### Full field inventory

**Scalar settings gaining `type: integer` in the settings schema:** `numberOfTroops`,
`JTAC_LIMIT_BLUE`, `JTAC_LIMIT_RED`, `AASystemLimitBLUE`, `AASystemLimitRED`, `aaLaunchers`,
`jtacLaserCodeMin`, `jtacLaserCodeMax`, `JTAC_smokeColour_BLUE`, `JTAC_smokeColour_RED`,
`beaconTextSize`.

**Bespoke table fields gaining `type: 'integer'` in their hardcoded field list:**
- Troop template fields: `inf`, `mg`, `at`, `aa`, `mortar`, `jtac` (the template's `name` field
  stays `'string'`, unchanged).
- Aircraft capability fields: `maxCratesOnboard`, `maxTroopsOnboard`, `maxWholeVehiclesOnboard`
  (`maxVehicleWeight`, in the same list today, stays `'number'`).
- Crate field: `cratesRequired`.
- AI zone field: the `troopStock`/`vehicleStock` per-template/per-type stock count.

**Explicitly out of scope, stays `'number'` — legitimately continuous, several already carry a
decimal default today:** every weight setting (including per-aircraft `maxVehicleWeight`, the
global `defaultVehicleWeight`/`maxTransportWeight`, and the ground-vehicle weight table); every
distance/altitude/radius setting, even the ones whose default happens to be a whole number today
(several siblings in the same family already default to a fractional value); every duration/
interval setting in seconds; the two multiplier-factor settings; a crate's own weight field.

## Testing Decisions

- Only external behaviour is tested — what a Mission Maker can type and what `validate` reports,
  not internal parsing mechanics.
- `tools/ctld-tools/tests/test_validate.py` (pytest): a new `WARNING` finding for a fractional
  value on an integer-typed field, one case per field category (a scalar setting, a troop-template
  field, an aircraft-capability field, `cratesRequired`, an AI-zone stock count), plus a negative
  case confirming a legitimately continuous field (a weight, a distance) never fires it. Prior art:
  this project's own `_validate_ai_zones` tests, added the same day for the troopStock/
  vehicleStock stock gap.
- `web/src/lib/*.test.ts` (vitest): the components rendering the troop-template table, the
  scalar-settings list, and the aircraft-capabilities table apply the whole-number behaviour to an
  `'integer'`-typed field and leave a `'number'`-typed field untouched; the crate editor's
  mixed-set branch renders the RED/BLUE dropdown instead of a free-typed number.

## Out of Scope

- Converting `JTAC_smokeColour_BLUE`/`JTAC_smokeColour_RED` into a real `choices:` enum — noted as
  a "Watch out" on the relevant ticket, not built here.
- Any migration or repair of existing catalogue/mission data — nothing in the shipped defaults
  needs it.
- Any change to a field confirmed continuous in this PRD (every weight, distance, altitude,
  radius, duration, and the two multiplier factors) — these must not regress toward integer
  behaviour as a side effect of a shared component gaining the new type.

## Further Notes

An ADR is required (see Implementation Decisions) — write it referencing this PRD, `ADR 0011`
and its Addendum 1. `CONTEXT.md` is not touched: this fix is an implementation-level type-system
decision, not a new domain-glossary term.

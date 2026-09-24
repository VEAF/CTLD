# 01 — `integer` `EditorType` for scalar settings

**Status:** ⬜ ready

**Blocked by:** none — can start immediately.

## What to build

Add a real `'integer'` value to `EditorType` (today `'boolean' | 'enum' | 'number' | 'string'`),
threaded end to end for scalar settings only:

- `CTLD_config_schema.yaml` gains an optional `type: integer` annotation per setting, alongside
  the existing `unit:`/`label:`/`description:` annotations. Absent means `number`, unchanged from
  today's behaviour.
- The Python backend reads and serves this annotation the same way it already serves `unit:` etc.
- `SchemaKey` (`api.ts`) carries the new field through to the frontend.
- `SettingRow.svelte` branches on `'integer'` explicitly, the same way it already branches on
  `'boolean'`/`'enum'` — applying a whole-number step and rounding the parsed value to a whole
  number on every edit, instead of today's blanket `step="any"`.

Mark these 11 scalar settings `type: integer` in the schema: `numberOfTroops`, `JTAC_LIMIT_BLUE`,
`JTAC_LIMIT_RED`, `AASystemLimitBLUE`, `AASystemLimitRED`, `aaLaunchers`, `jtacLaserCodeMin`,
`jtacLaserCodeMax`, `JTAC_smokeColour_BLUE`, `JTAC_smokeColour_RED`, `beaconTextSize`.

## Watch out

- Every other numeric scalar setting (weights, distances/altitudes/radii, durations, the two
  multiplier factors) stays `'number'` and must keep accepting a decimal exactly as it does
  today — several already default to a fractional value (`fastRopeMaximumHeight: 18.28`,
  `maxDistanceFromCrate: 5.5`, etc.). Don't touch their rendering.
- This is a deliberate, ADR-documented exception to ADR 0011 Addendum 1's "derive the tier from
  the value's shape, don't declare new metadata" principle (ticket 05 writes that ADR, once this
  ticket and ticket 02 both exist) — don't second-guess the schema-annotation approach as a
  violation of that principle; it was weighed and accepted during the `grill-with-docs` session
  behind this lot's PRD.
- `JTAC_smokeColour_BLUE`/`_RED` stay a plain `type: integer` field in this ticket — do NOT turn
  them into a `choices:` enum, even though both actually encode a named 0–4 set. That conversion
  is explicitly out of scope for this lot (see the PRD's Out of Scope section).

## Acceptance

- `SettingRow.svelte` renders a whole-number step for each of the 11 settings above, and rounds a
  typed decimal to a whole number on edit.
- Every other numeric scalar setting is unaffected — still accepts and renders a decimal exactly
  as before.
- `CTLD_config_schema.yaml`'s `type: integer` annotation round-trips through the backend API into
  the frontend's `SchemaKey` for at least one of the 11 settings, verified by a test.

## Tests

`web/src/lib/*.test.ts` (vitest): `SettingRow` applies the whole-number step/rounding to an
`'integer'`-typed setting and leaves a `'number'`-typed one untouched — same seam and pattern as
this project's existing `SettingRow`/settings-list component tests. A backend/schema-side test
(Python) confirming the new annotation is read and served, mirroring how `unit:`/`label:` are
already tested.

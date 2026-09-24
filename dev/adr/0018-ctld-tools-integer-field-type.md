# ADR 0018 — `ctld-tools` gains a declared `integer` field type

**Date:** 2026-09-24
**Status:** Accepted
**Lot:** FIX-CTLD-TOOLS-INTEGER-FIELDS, tickets 01 + 02

## Context

`ctld-tools` had no way to tell an integer-only quantity (a soldier count, a quota, a laser code)
from a continuous one (a weight, a distance, a duration) — every numeric field was rendered
identically. Three components each applied their own blanket rule regardless of the field's real
nature: `RecordListEditor` hardcoded `step="0.01"` on every numeric table field,
`SettingRow` hardcoded `step="any"` on every scalar setting, and three bespoke editors
(`AircraftEditor`, `CratesEditor`, `AiZonesEditor`) applied no `step` at all — none of the three
rounded or rejected a typed decimal. [GitHub issue #157](https://github.com/VEAF/CTLD/issues/157)
reported the concrete symptom: `loadableGroups`' infantry-count field accepting `6.01`.

`ADR 0011`'s Addendum 1 already splits the config in two tiers — **Parameter** (a scalar, must be
present) vs. **List** (a list/map, an omission is a removal) — and states the tier is **derived,
not declared**, from the shape of the default value, specifically to avoid a new piece of metadata
to author and keep in sync. Any new distinction proposed here has to reckon with that precedent
before adding a second piece of declared metadata to the schema.

## Decision

`ctld-tools` gains a real `'integer'` value in its `EditorType` union (`web/src/lib/model.ts`),
alongside `'boolean' | 'enum' | 'number' | 'string'`. Every component that renders a numeric input
branches on it the same way it already branches on `'boolean'`/`'enum'`: a whole-number step, and
the parsed value rounded on every edit.

**This is a deliberate, acknowledged exception to ADR 0011 Addendum 1's derive-don't-declare
principle** — confirmed during the `grill-with-docs` session behind this lot. Shape alone cannot
make this particular distinction: `numberOfTroops: 10` and `crateSpacing: 5` have the identical
shape (a positive whole number) in today's catalogue, yet one is a genuine count and the other is
legitimately continuous and merely happens to be whole today. No mechanical rule separates them;
a human has to say which is which. Unlike the Parameter/List tier — where the shape of the
*default value itself* (scalar vs. list/map) **is** the fact being classified — "is this quantity
divisible" is not recoverable from any value the catalogue carries.

**Two distinct mechanisms supply the "this field is an integer" fact, not one unified
abstraction**, because the two families of numeric field are structurally different:

- **Scalar settings** (`SettingRow`, driven by `CTLD_config_schema.yaml` + `/api/schema`) are
  arbitrary catalogue keys, unknown to the tool at compile time. These get an optional `type:
  integer` annotation in the schema, alongside the existing `unit:`/`label:`/`description:`
  annotations — absent means `number`, unchanged from before this lot. Threaded through
  `Schema.value_type()`, the `/api/schema` response, and `SchemaKey.type` in the frontend.
- **The three bespoke table editors** (`AircraftEditor`/`capabilitiesByType`,
  `CratesEditor`/`spawnableCrates`, `AiZonesEditor`/`aiZones`, and `RecordListEditor`/
  `loadableGroups`) have field lists already known at compile time as hardcoded TS arrays
  (`TROOP_FIELDS`, `AIRCRAFT_NUMS`). These mark the relevant entries `'integer'` directly in those
  arrays, reusing `Field.type` — no schema involvement, because these fields are not arbitrary
  schema-driven keys to begin with.

Paired with a `ctld_tools/validate.py` `WARNING` (`_validate_integer_fields`, ticket 03): the two UI
mechanisms above only prevent a *fresh* edit from landing a fraction. A value that never went
through the UI at all — a hand-edited YAML, or a catalogue/`configUser` authored before this lot —
needs its own check. `WARNING`, not `ERROR`: a fractional count is undesirable but does not
structurally break an export the way a missing zone or an unknown DCS type does.

## Considered options

- **Derive "integer" from the default value's shape**, matching Addendum 1's own principle exactly.
  Rejected: no such signal exists in the data. A whole-number default is equally consistent with
  "this is always a count" and "this happens to be whole today" — the two cases this lot exists to
  tell apart.
- **One unified mechanism for both scalar settings and table fields** (e.g. threading schema
  metadata into the bespoke editors too, or hardcoding scalar settings' types in TS instead of the
  schema). Rejected: scalar settings are schema-driven, arbitrary, and already have a metadata
  channel (`CTLD_config_schema.yaml`) built for exactly this kind of per-field fact; the bespoke
  editors' fields are compile-time-known and were never part of that schema-driven surface to begin
  with (`AIRCRAFT_NUMS` was a bare `string[]` before this lot, with no per-field metadata at all).
  Forcing one onto the other would mean either inventing schema entries for fields the schema never
  described, or dragging the bespoke editors' hardcoded lists through the schema/API round trip for
  no benefit.
- **UI prevention only, no `validate.py` check.** Rejected: `ADR 0011` point 3 deliberately keeps
  the YAML hand-editable outside the tool, so a UI-only fix leaves exactly the class of value this
  lot exists to catch — one that bypassed the editor — with no signal at all.

## Consequences

- `CTLD_config_schema.yaml` carries a new, optional per-setting annotation (`type: integer`) that a
  future contributor must remember to declare for a new whole-number-only setting — nothing enforces
  this automatically, the same way nothing enforces `unit:` today. A missed declaration degrades
  gracefully (the setting behaves as a plain `'number'`, as every setting did before this lot), never
  silently to a worse state.
- `tables.ts`'s `AIRCRAFT_NUMS` changed shape (a bare `string[]` to a typed field list) to carry the
  same per-field distinction the bespoke editors need — any other bare-string-array field list added
  in the future should use this same shape from the start rather than growing a second ad hoc
  convention.
- `validate.py` now has two ways to learn a field is integer-only (`schema.value_type()` for scalar
  settings, `_INTEGER_TABLE_FIELDS` for the table fields) mirroring the split above — a third table
  gaining an integer-only field means adding it to `_INTEGER_TABLE_FIELDS`, not inventing a schema
  entry for it.

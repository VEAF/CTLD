# 01 — carry the unit category in `dcs_types.json`

**Status:** done

First ticket: ticket 02's `AIR` resolution depends on it.

## Why

Resolving `AIR` to `AIRPLANE` or `HELICOPTER` needs a unit-type → category lookup, and one exists nowhere:
`src/` never asks DCS for a type description, and the vendored set is a flat list of 1143 names with no
category.

It is nearly free to add. The datamine layout is `<Category>/<Type>/<TypeName>.lua` — stated in the
generator's own comment — and [`collect_type_names`](../../../tools/dcs-data/gen_dcs_types.py#L63) throws
the category away with `p.stem`.

## What changes

- `tools/dcs-data/gen_dcs_types.py`: keep the category alongside the name. Emit
  `dcs_types.json` as a name → category mapping rather than a list. Keep the pinned `DATAMINE_REF`
  untouched — this is a shape change, not a data refresh.
- `tests/data/dcs_types.lua`: the Lua lookup set feeds the offline config type linter, which only needs
  membership. Keep it a set unless the linter gains a use for the category — do not churn it.
- `tools/ctld-tools/ctld_tools/datamine.py`: `known_dcs_types()` keeps returning a `frozenset` of names so
  `validate` is unaffected; add a second accessor for the category (e.g. `type_category(name)`).
- Regenerate and commit the enriched `dcs_types.json`.

## Watch

The generator is a **manual maintenance tool** — CI does not run it (it needs network). So the committed
JSON and the generator must not drift: if the shape changes, the committed file has to be regenerated in
the same commit.

## Acceptance

- `dcs_types.json` maps every name to a category, and still contains all 1143 names.
- `validate`'s unknown-type check behaves identically (same findings on the same catalogue).
- The categories present in the file cover, at minimum, the ground / helicopter / plane / static
  distinctions ticket 02 needs.

## Tests

- pytest: `known_dcs_types()` is unchanged in content.
- pytest: a known helicopter and a known airplane resolve to different categories; a known ground unit to
  a third.
- pytest: the committed JSON parses and every entry has a non-empty category.

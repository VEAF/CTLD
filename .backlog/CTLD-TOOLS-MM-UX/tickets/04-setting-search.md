# 04 — Setting search

**Status:** done

## Goal

Let a MM find a setting without knowing its family (finding 6): ~136 settings across 16 families.

## Work

- A search field at the top of the content panel, always present.
- `searchSettings(query, keys, schema)` in `src/lib/search.ts` — case-insensitive match over the
  human label, the raw key and the description. Ranked: label prefix > label substring > key >
  description.
- Typing switches the panel to a flat result list showing, per hit, the setting row plus the family
  it lives in (clickable, so the user learns where things are rather than being teleported blindly).
- Clearing the field returns to the selected family. `Esc` clears.
- Results include settings from **every** family, standard and advanced alike — search is the
  escape hatch from the standard/advanced split.

## Done when

- Unit tests cover ranking order, case-insensitivity, description matches and the empty query.
- A component test types a query and asserts a known setting from a non-selected family appears.

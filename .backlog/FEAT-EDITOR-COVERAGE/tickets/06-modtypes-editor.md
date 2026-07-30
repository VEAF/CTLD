# 06 — dispatch `modTypes` to `StringListEditor`

**Status:** ready

Depends on: lot B ticket 03 (the catalogue value must be `[]`, not `{}`).

## Why

`modTypes` fell through to `JsonEditor` for a mechanical reason: the app infers the editor from the value's
shape, and the catalogue shipped an empty **map** where the engine expects a **list**
([CTLD_typeCollector.lua:170](../../../src/core/CTLD_typeCollector.lua#L170)). Once lot B makes it `[]`,
the right editor already exists — `StringListEditor` serves `transportPilotNames` and `extractableGroups`.

`modTypes` is not a plugin feature. It is the only way a Mission Maker can use a modded unit without
`validate` rejecting it as unknown to DCS, so it deserves to be reachable.

## What changes

- `App.svelte`: add `modTypes` to the `StringListEditor` dispatch alongside `transportPilotNames`,
  `extractableGroups` and `logisticUnits`.
- Confirm it lands in a sensible family via the `group` lot B adds to its schema entry — an uncovered
  setting falls into the generic bucket, which is where it was effectively hiding before.
- Nothing else. No new component.

## Acceptance

- `modTypes` renders as an editable list of type names.
- Adding a modded type name and saving produces a YAML list the engine's `ipairs` walk picks up.
- A type listed here stops `validate` reporting it as an unknown DCS type — the end-to-end reason the
  setting exists.

## Tests

- vitest: dispatch resolves `modTypes` to `StringListEditor`.
- vitest: round-trip of a two-entry list.
- pytest: a catalogue with a `modTypes` entry does not raise `validate.crate.unknown_unit` for that type.

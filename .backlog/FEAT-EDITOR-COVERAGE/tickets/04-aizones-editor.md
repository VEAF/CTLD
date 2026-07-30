# 04 — `AiZonesEditor.svelte`

**Status:** done

Depends on: 02 (`tableFields` carries `choices`) and lot B ticket 01 (`tableFields.aiZones` must describe
the real fields and declare the three enums — both the editor's help text and its selects come from there).

## Why

`aiZones` falls through to `JsonEditor`. Its entries are **named records**, so `ZonesEditor` — which
handles the positional `troopZones` / `wpZones` — would corrupt them. This is the largest of the four gaps.

## What changes

A new `AiZonesEditor.svelte`, dispatched from `App.svelte` for `aiZones`, wrapping `RecordListEditor` for
the flat fields and nesting the existing components for the rest:

| Field | Control | Notes |
|---|---|---|
| `dcsZoneName` | text | must exist in the mission editor; the engine WARNs and skips if not |
| `coalition` | select | **`RED` / `BLUE` / `NEUTRAL` as strings** — see the trap below |
| `isPickup` | checkbox | |
| `isDropoff` | checkbox | |
| `cargoType` | select | `T` / `V` / `TV`, default `T` |
| `aiDropMode` | select | `G` / `P` / `GP`, default `GP` |
| `troopStock` | nested `KeyValueEditor` | template name → count |
| `vehicleStock` | nested `KeyValueEditor` | unit type → count |
| `troopTemplates` | inline `StringListEditor` | empty = all |
| `vehicleTypes` | inline `StringListEditor` | empty = all |

**The trap — `coalition` is a string.** Everywhere else in the catalogue a coalition is the numeric `side`
(1 = RED, 2 = BLUE). Reusing the `side` widget here would write a number into a field the engine matches
against `"RED"` / `"BLUE"` / `"NEUTRAL"`, and anything unmatched silently means *both coalitions*
([CTLD_zone.lua:737-742](../../../src/CTLD_zone.lua#L737)). That is the same failure shape as the
`boolean`-typed `jtac` field the previous lot fixed: an editor quietly writing the wrong type into a
Mission Maker's config.

**The two magic values.** `troopStock` / `vehicleStock` accept the key `All` (every template, unlimited)
and the value `-1` (unlimited for that entry) — [CTLD_zone.lua:710-727](../../../src/CTLD_zone.lua#L710).
A bare key-value grid hides both. Surface them: offer `All` as a suggestion, and render `-1` as
"unlimited" rather than as a number the MM must know to type.

**The three selects read their options from the schema**, via the `choices` lot B seeds on
`tableFields.aiZones` from the engine's own tables
([CTLD_zone.lua:1492-1494](../../../src/CTLD_zone.lua#L1492)). Do not retype the vocabularies into the
component: an MM hand-editing the YAML must find them in the schema, and one source means the UI cannot
drift from the engine.

## Acceptance

- `aiZones` no longer reaches `JsonEditor`.
- `coalition` can only be one of the three strings; no numeric value is reachable from the UI.
- A stock entry set to unlimited writes `-1`; `All` is offered without the MM having to know it exists.
- An `aiZones` block authored in the UI loads in DCS and produces the zones the engine logs at INFO.
- Round-trip: an existing `aiZones` config opens, saves and is unchanged.

## Tests

- vitest: each enum select offers exactly the schema's `choices`, and no vocabulary is literal in the
  component.
- vitest: `coalition` round-trips as a string; a numeric value cannot be produced.
- vitest: `All` and `-1` round-trip through the stock editors.
- vitest: an entry with empty `troopTemplates` saves as absent or empty, matching what the engine reads
  as "all".

# 01 — rewrite `tableFields.AIZones` → `tableFields.aiZones`

**Status:** ready

## Why

The block describes `zoneName` / `mode` / `side` ([CTLD_config_schema.yaml:882](../../../src/CTLD_config_schema.yaml#L882)).
The engine reads none of them — not in `src/`, not in the legacy monolith. PR #69 removed the dead
`AIZones` config key but left its schema block behind, so `HelpPanel` still explains a format that
never existed. Fixing it helps the MM immediately, before any editor work.

## What changes

In `src/CTLD_config_schema.yaml`, replace the `AIZones` block under `tableFields` with `aiZones`,
carrying the real fields read by [`_loadAIZonesFromConfig`](../../../src/CTLD_zone.lua#L705), bilingual:

| Field | Description must state |
|---|---|
| `dcsZoneName` | DCS trigger-zone name; must exist in the mission editor |
| `coalition` | **String**: `RED` / `BLUE` / `NEUTRAL`. Anything else means both coalitions |
| `isPickup` | AI loads cargo here |
| `isDropoff` | AI delivers cargo here |
| `cargoType` | `T` troops / `V` vehicles / `TV` both — default `T` |
| `troopStock` | Map template-name → count. `-1` = unlimited; the key `All` = every template, unlimited |
| `vehicleStock` | Map unit-type → count, same conventions |
| `troopTemplates` | Restrict to these `loadableGroups` names; empty = all |
| `vehicleTypes` | Restrict to these DCS unit types; empty = all |
| `aiDropMode` | `G` ground / `P` parachute / `GP` both — default `GP` |

Take the enum vocabularies from the engine's own tables, do not retype them from this ticket:
[CTLD_zone.lua:1492-1494](../../../src/CTLD_zone.lua#L1492) declares `VALID_COALITION`, `VALID_CARGO`
and `VALID_DROP_MODE`.

**Declare them machine-readably.** `coalition`, `cargoType` and `aiDropMode` each get a `choices:` list
as a sibling of `en`/`fr`:

```yaml
  aiZones:
    coalition:
      en: "Coalition that uses this AI zone — a word, not a number: RED, BLUE or NEUTRAL. Any other value means both."
      fr: "Coalition qui utilise cette zone IA — un mot, pas un nombre : RED, BLUE ou NEUTRAL. Toute autre valeur signifie les deux."
      choices: [RED, BLUE, NEUTRAL]
```

This is what a hand-editing MM reads, and what lot D's selects will consume. It is backward-compatible:
`/api/schema` reads only the language key and drops the rest
([app.py:117](../../../tools/ctld-tools/ctld_tools/web/app.py#L117)), so nothing breaks before lot D
lands.

Call out explicitly in the `coalition` description that it is a **word, not a number** — everywhere
else in the catalogue a coalition is the numeric `side` (1 = RED, 2 = BLUE). This is the trap lot D
must not fall into.

Add a top-level `description` to the `aiZones` setting itself with a minimal example, since a bare
field list does not convey the nesting.

## Acceptance

- No `AIZones` (capital A) remains anywhere in `src/`.
- Every field named in the block is read by `_loadAIZonesFromConfig`; every field it reads is in the
  block.
- The three enums match the engine's `VALID_*` tables exactly, and are declared as `choices` lists.
- `/api/schema` still returns the same tooltips as before, in EN and FR — the new key is inert until
  lot D.
- `HelpPanel` shows the new fields with no frontend change.

## Tests

- pytest: a guard asserting the `tableFields.aiZones` field names equal the set the engine reads
  (parse the Lua or pin the list explicitly with a comment pointing at the source line).
- pytest: the three enum lists match the engine's tables.

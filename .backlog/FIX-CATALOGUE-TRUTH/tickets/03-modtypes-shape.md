# 03 — `modTypes`: a list, and a schema entry that says what it is for

**Status:** ready

## Why

[`src/CTLD_config.yaml:965`](../../../src/CTLD_config.yaml#L965) ships `modTypes: {}` — a map — while
the engine iterates it with `ipairs`, which only walks a list
([CTLD_typeCollector.lua:170](../../../src/core/CTLD_typeCollector.lua#L170)). Empty, the two shapes
are indistinguishable once parsed, so nothing breaks today. But an MM who copies the shape shown and
writes `modTypes: {AH-64D: true}` has every entry silently ignored — and then `validate` rejects their
modded units as unknown to DCS, with no way to see why.

It is also why FullGas saw the raw JSON fallback: the app infers the editor from the value's shape, and
an empty map does not look like a list of strings.

The schema entry has a `label` and nothing else ([CTLD_config_schema.yaml:1108](../../../src/CTLD_config_schema.yaml#L1108)).
Note the schema has **no `type:` field** — its vocabulary is `group` / `standard` / `choices` / `unit` /
`label` / `description` / `default` — so the shape is conveyed by the catalogue value plus prose.

## What changes

- `src/CTLD_config.yaml`: `modTypes: {}` → `modTypes: []`.
- `src/CTLD_config_schema.yaml`: add a bilingual `description` stating that it is a **list of DCS unit
  type names** provided by mods, that listing a type here is what stops `validate` rejecting it as
  unknown, and giving a one-line example. Add a `group` so it lands in a family rather than the
  uncovered bucket.
- Nothing else: the engine already tolerates both shapes while empty, and `StringListEditor` dispatch
  follows from the value being a list (wired in lot D).

## Acceptance

- The catalogue value is a list.
- The description explains the purpose, not just the name — an MM reading it alone understands why the
  setting exists.
- The engine's `ipairs` walk is unchanged and still correct.

## Tests

- busted: a config with `modTypes` holding two type names contributes both to the collector's
  `extras` set.
- pytest: the shipped catalogue's `modTypes` is a list, guarding the shape against regression.

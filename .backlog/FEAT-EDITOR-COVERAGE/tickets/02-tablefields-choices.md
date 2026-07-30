# 02 — `tableFields` entries carry `choices`, and the API surfaces them

**Status:** done

Prerequisite for tickets 03 (`spawnAs`) and 04 (`aiZones` enums). Lot B authors the YAML side; this
ticket makes it reach the UI.

## Why

The strict dropdowns need their vocabulary from somewhere. Putting it in the schema rather than in the
frontend means **a Mission Maker editing the YAML by hand sees the allowed values too** — the schema is
the document that explains the config, and a value list that only exists in Svelte helps nobody outside
the app.

Top-level settings already work this way: `Schema.choices(key)` exists and `/api/schema` ships it
([app.py:109](../../../tools/ctld-tools/ctld_tools/web/app.py#L109)). Table *fields* do not — a
`tableFields` entry is just the bilingual description, and the API collapses it to a single localised
string ([app.py:117](../../../tools/ctld-tools/ctld_tools/web/app.py#L117)):

```python
table: {field: (meta or {}).get(language) or (meta or {}).get("en") for field, meta in fields.items()}
```

The frontend contract matches: `tableFields: Record<string, Record<string, string | null>>`
([api.ts:39](../../../tools/ctld-tools/web/src/lib/api.ts#L39)), and `tables.ts` treats the value purely
as a tooltip.

**Good news for sequencing:** because that comprehension reads only the language key and drops every
other, adding `choices:` as a sibling of `en`/`fr` in the YAML is **backward-compatible**. Lot B can ship
the vocabulary immediately; this ticket is the only thing that has to change in step.

## What changes

- `ctld_tools/web/app.py`: stop collapsing a table field to a string. Emit an object per field —
  the localised tip plus `choices` when present. Keep the key names stable and explicit
  (e.g. `{"tip": …, "choices": […]}`).
- `ctld_tools/schema.py`: add an accessor for a table field's `choices`, mirroring the existing
  `Schema.choices()` for top-level settings so the two read alike.
- `web/src/lib/api.ts`: widen the `tableFields` type from `string | null` to the new object.
- `web/src/lib/tables.ts`: the tooltip now comes from `.tip`; `withTips` and the merge helper follow.
  A field with `choices` must be renderable as a select by the consuming editor.
- `App.svelte`: the three `fields={…}` call sites (`spawnableCrates`, `loadableGroups`,
  `capabilitiesByType`) pass the new shape through.
- Fix the fixtures that hardcode the old shape: `App.test.ts`, `model.test.ts`, `search.test.ts`,
  `tables.test.ts`.

## Acceptance

- A `tableFields` field with no `choices` renders exactly as before — same tooltip, same control.
- A field with `choices` exposes them to its editor.
- `/api/schema` is self-describing enough that the FR and EN runs differ only in the tip text.
- No editor reads a vocabulary that is not in the schema.

## Tests

- pytest: `/api/schema` returns tip + choices for a field that has them, tip only for one that does not.
- pytest: the same call in FR returns FR tips and identical choices.
- vitest: `tables.ts` merges the new shape; a field with choices is offered as a select.

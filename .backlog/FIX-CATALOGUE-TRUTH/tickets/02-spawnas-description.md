# 02 — `spawnAs`: stop advertising an invalid value

**Status:** done

## Why

The schema says *"Force spawn category: AIRPLANE, HELICOPTER, GROUND_UNIT, etc."*
([CTLD_config_schema.yaml:770-772](../../../src/CTLD_config_schema.yaml#L770)). `GROUND_UNIT` is in no
table: `_SPAWN_CATEGORY_MAP` knows `AIRPLANE`, `HELICOPTER`, `GROUND`, `SHIP`, `TRAIN`, and unknown
strings fall back to `Group.Category.GROUND` ([CTLD_utils.lua:1255](../../../src/CTLD_utils.lua#L1255)).
So it produces the right result through the error path while teaching a value that does not exist —
and the silent fallback means a typo spawns a ground unit with no message at all.

## What changes

Rewrite the `spawnAs` description under `tableFields.spawnableCrates`, EN + FR, to state:

- The two values a crate may use: **`GROUND`** (default when absent) and **`AIR`**.
- That `AIR` is resolved by ctld-tools to `AIRPLANE` or `HELICOPTER` from the unit's category — the
  YAML that reaches the engine carries the resolved value.
- That DCS can only be asked to build ground units, statics, helicopters and drones from a raw
  definition; a manned aircraft will not spawn. The legacy engine hardcoded the two drone type names
  for exactly this reason ([migration/source/CTLD.lua:10351-10367](../../../migration/source/CTLD.lua#L10351)).
- That `SHIP`, `TRAIN` and `STATIC` are **not** usable on a crate. `STATIC` is broken by construction:
  `buildGroupUnitDef` states it does not handle statics ([CTLD_utils.lua:1274](../../../src/CTLD_utils.lua#L1274))
  yet returns a group definition that then goes to `coalition.addStaticObject`.

**Declare the two values machine-readably**, as a sibling of `en`/`fr`:

```yaml
    spawnAs:
      en: "..."
      fr: "..."
      choices: [GROUND, AIR]
```

That is what a hand-editing MM reads, and what lot D's dropdown consumes instead of a literal in the
component. Backward-compatible: `/api/schema` reads only the language key and drops the rest
([app.py:117](../../../tools/ctld-tools/ctld_tools/web/app.py#L117)).

Do not change `_SPAWN_CATEGORY_MAP` or any engine code. The engine's `STATIC` branch is used
legitimately by `CTLDObjectRegistry` for scene objects.

## Acceptance

- `grep -rn GROUND_UNIT` returns nothing in the repository.
- The description names exactly the values a crate may carry, and says what `AIR` becomes.
- `choices: [GROUND, AIR]` is declared, and `/api/schema` output is unchanged until lot D.
- No `src/*.lua` change in this ticket.

## Tests

- pytest: the shipped catalogue contains no `spawnAs` value outside the documented set.
- pytest: a guard on the description text asserting `GROUND_UNIT` is absent from the schema.

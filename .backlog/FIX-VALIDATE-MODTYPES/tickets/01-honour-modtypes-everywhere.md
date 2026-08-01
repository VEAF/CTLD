# 01 — one known-type set, honoured by every type-aware rule

**Status:** todo

No dependency.

## What changes

- Resolve the known-type set **once** in `validate()`: the datamine set (or the injected `types`) union
  the catalogue's `modTypes`, and pass that to every type-aware rule.
- `_validate_type_lists` drops its local union — it built one because it had to; that reason goes away.
- `_validate_crates` takes the same set, so a modded crate stops being an export-blocking `ERROR`.

Keep `validate()` a pure function: the union is computed from its arguments, never read from disk.

## Answer in writing while you are here

The Lua lint excuses `modTypes` **∪ every scene model's `modTypes`** (`CTLDTypeCollector.collect()`
returns them merged as `extras`). `validate` sees only the config, never the scene models, so it is
narrower by construction. Two ways out, and the ticket picks one:

- **Accept it**, and say so in the module docstring: a scene ships its own asset gate
  (`SCENE-PLUGINS`), so a scene type never reaches a crate `unit` in a config anyway. Verify that claim
  before leaning on it.
- **Close it**, which means the tool needs the scene models — a data path that does not exist today and
  is well beyond this fix.

Expected answer is the first. What matters is that it is written down rather than rediscovered.

## Acceptance

- The PRD's reproduction case validates clean.
- A crate `unit` in neither the datamine nor `modTypes` still errors, with the same message.
- `logisticUnitTypes` / `troopZoneShipTypes` behave exactly as they do today (they already honour
  `modTypes`; this must not regress).
- `modTypes` itself is not validated against the datamine — declaring a type is the whole point.

## Tests

- pytest: modded crate + `modTypes` → no findings; without the `modTypes` entry → one
  `validate.crate.unknown_unit` error.
- pytest: the same union applies to a type list and to a crate in one catalogue (one rule cannot be
  stricter than the other).
- pytest: the shipped `src/CTLD_config.yaml` still validates clean.

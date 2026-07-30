# 03 — delete the ~100 redundant scalar `or <literal>` fallbacks

**Status:** ready

Depends on: 02 (the safety net must exist before the literals go).

## Why

Every `ctld.gs("x") or <literal>` writes a default a second time, next to the one in
`src/CTLD_config.yaml`. Two of them have already drifted, which is `dev/roadmap.md` item 2:

| Parameter | Catalogue | Lua literal |
|---|---|---|
| `maximumSearchDistance` | 3000 | 10000 — [CTLD_troop.lua:1521](../../../src/CTLD_troop.lua#L1521), [:1546](../../../src/CTLD_troop.lua#L1546) |
| `maximumDistanceLogistic` | 200 | 500 — [CTLD_zone.lua:897](../../../src/CTLD_zone.lua#L897) |

Once ticket 02 resolves a missing parameter from the catalogue, the literals are unreachable
duplicates. Deleting them settles the drift by removing the second source rather than picking a
winner.

## What changes

- Audit surface: ~158 `ctld.gs(...) or ...` sites in `src/`. Split them:
  - **~100 scalar literals** (`or 12.0`, `or true`, `or "GP"`, …) → **delete the fallback**.
  - **46 `or {…}`** on collections → **keep**. A missing collection means empty, and `gs()` still
    returns `nil` for those by design.
  - The remainder are `or <variable>` or computed forms — inspect individually, do not sweep blindly.
- Where a literal **disagrees** with the catalogue, the catalogue wins (3000 and 200 above). Both are
  behaviour changes on paper; in practice a catalogue is always loaded, so nothing changes in game.
  Note them in `CHANGELOG.md` anyway — a reader must be able to see that the numbers moved.
- Do not touch the two fixed-arity tuple guards (`nbLimitSpawnedTroops`, `beaconIconColor`): their
  defaults are lists, so `gs()` does not cover them and the guards remain load-bearing.

## Acceptance

- `grep -rE 'ctld\.gs\("[a-zA-Z_]+"\) *or *(-?[0-9]|true|false|")' src/` returns nothing.
- `grep -rn 'ctld.gs("[a-zA-Z_]*") *or *{' src/` still returns 46 sites.
- No default value appears in both `src/CTLD_config.yaml` and a `.lua` file.
- `maximumSearchDistance` resolves to 3000, `maximumDistanceLogistic` to 200.

## Tests

- busted: a test asserting no scalar `or`-literal fallback survives in `src/` (a lint-style guard, so
  the pattern cannot creep back).
- busted: the two formerly divergent parameters resolve to their catalogue values.

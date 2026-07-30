# 03 — delete the ~100 redundant scalar `or <literal>` fallbacks

**Status:** done

Depends on: 02 (the safety net must exist before the literals go).

> **Delivered: 114 fallbacks removed** — 103 scalar literals (scripted) plus 11 that duplicated a code
> constant (`_ROLE_EQUIP_WEIGHTS.*`, `trigger.smokeColor.Red`), removed by hand. 46 `or {…}` list guards
> kept.
>
> **The audit the ticket asked for paid off twice.** Every key with a fallback turned out to exist in the
> catalogue (0 absent), so the sweep could not turn a guard into a `nil`. And it found **three
> divergences the roadmap never listed**: `parachuteMinAltitudeCrates` / `…Troops` / `…Vehicles`, code
> `30` / `50` / `30` against `152` for all three in the catalogue. The schema documents 152 m AGL, and a
> catalogue is always loaded, so 152 is what missions have been flying — dropping the literals changes
> nothing in game.
>
> **One false positive caught only by hand review:** `CTLD_jtac.lua:203` reads
> `code < ctld.gs("jtacLaserCodeMin") or code > ctld.gs("jtacLaserCodeMax")` — that `or` is the boolean
> disjunction of two comparisons, not a fallback. A blind sweep would have broken the laser-code range
> check. Any future sweep of this shape must review non-literal right-hand sides individually.
>
> **Not done, deliberately:** `CTLDTroopManager._ROLE_EQUIP_WEIGHTS` still exists and still duplicates
> the six catalogue weights, because line 403 uses the whole table as a guard for an uninitialised
> manager (`self._roleEquipWeights or …`). That is a code-path guard, not a config default, so it is out
> of this ticket's scope — but it is the same duplication in a different dress and worth its own look.

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

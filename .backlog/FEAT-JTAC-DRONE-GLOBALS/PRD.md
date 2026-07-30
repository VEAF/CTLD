# FEAT-JTAC-DRONE-GLOBALS — drone orbit parameters become global settings

**Status:** done — all three tickets delivered.

> **Delivered.** The four globals rebased on the drones' own values (3000 m, 2000 m, 1000 m, 150 km/h),
> `JTAC_droneRadius` retired, `specificParams` gone from the schema, the catalogue and the engine — the
> `orbitParams` plumbing threaded through `autoLase` / `startLase` / `_setOrbitRoute` / `_setOrbitTask`
> is removed entirely — plus a startup NOTICE naming stale crates and their replacement settings.
>
> **Two in-flight changes, both alignments** (announced in `CHANGELOG.md`): a drone now spawns at 3000 m
> rather than 4000, and at 150 km/h rather than a hardcoded 54 m/s. It used to be born high and fast and
> then change altitude *and* speed when the orbit route landed. The orbit itself is unchanged.
>
> **Verification.** 191 pytest tests + ruff clean; `test_catalogue_truth.py` gains seven guards pinning
> each global to the value it replaced and asserting the crate surface is clear while the troop path is
> not. `luacheck` on the three changed Lua files: 28 warnings before and after. A new
> `tests/ci/unit/jtac_drone_globals_spec.lua` covers the runtime — spawn/orbit agreement and the NOTICE —
> and is CI's to run, since busted is not installed locally.

Lot **C** of the post-review program (2026-07-30). Independent of lots A / B / D — can ship in parallel.

## Why

FullGas's coverage audit listed `specificParams` among the fields `CratesEditor` silently drops, and
proposed a conditional sub-panel for it (four numeric inputs, shown when the crate is a drone JTAC).
David and FullGas decided the opposite: **remove the concept rather than build an editor for it.** Only
two crates in the catalogue have ever used it, and both are the shipped drones.

Taken naively that decision changes how the drones fly. Verified, the resolution chain is
([CTLD_jtac.lua:1192-1197](../../src/CTLD_jtac.lua#L1192), [1286-1293](../../src/CTLD_jtac.lua#L1286)):

| Parameter | Per-crate (both drones) | Global fallback | Hard fallback |
|---|---|---|---|
| `alti` | 3000 | `JTAC_droneAltitude` = 4000 | 4000 |
| `orbitRadiusOnLase` | 1000 | `JTAC_droneRadius` = 1000 | 1000 |
| `orbitRadiusNoLase` | 2000 | `JTAC_droneRadius` = 1000 | 1000 |
| `speed` | 150 | *(none)* | 100 km/h, in code |

So dropping the per-crate values without preparation would raise the drones by 1000 m, halve their
non-lasing orbit radius, and slow them by a third. It would also collapse a deliberate distinction: one
`JTAC_droneRadius` cannot express both the lasing and the non-lasing radius, and the drone tightening
its orbit when it lases is intended behaviour, not an artefact.

The lot therefore creates the missing globals and **rebases every default onto the value the drones use
today**, so the only behaviour change is the one we choose to make and announce.

That change also fixes a divergence nobody was looking for: `buildGroupUnitDef` already reads
`JTAC_droneAltitude` for the **spawn** altitude ([CTLD_utils.lua:1305](../../src/CTLD_utils.lua#L1305))
while the orbit reads `specificParams.alti`. A drone is currently born at 4000 m and then descends to
orbit at 3000. After this lot both read 3000.

## Decisions

1. **Four globals, rebased on today's values.** `JTAC_droneAltitude` **4000 → 3000**; new
   `JTAC_droneRadiusNoLase` = **2000**, `JTAC_droneRadiusOnLase` = **1000**, `JTAC_droneSpeed` = **150**.
   `JTAC_droneRadius` is retired.
2. **`specificParams` leaves the crate surface entirely** — the schema block, the two catalogue entries,
   and the engine's reads. Not kept as a silent back-compat override: that would mean telling MMs the
   values are global while the per-crate ones still win, and would preserve exactly the two-sources-of-truth
   pattern the rest of this program removes.
3. **A startup `NOTICE`** when a loaded config still carries `specificParams` on a crate, naming the
   globals that replace it. Neither existing guard catches it: `validate` only checks DCS unit types
   ([validate.py:71](../../tools/ctld-tools/ctld_tools/validate.py#L71)), and `version-gap` diffs the
   flat top-level `Catalog.keys()` namespace, so a field nested inside a `spawnableCrates` entry is
   invisible to it.
4. **Both consumers read the globals.** Spawn and orbit currently disagree; after this lot they
   resolve from the same keys.

## Not touched

The **troop** path. `specificParams` is also the carrier for Feature I's `specificParams.task`
(`gotoNearestWPZ` / `AttackNearestEnemyOnLos`) on `loadableGroups` templates
([CTLD_troop.lua:1490](../../src/CTLD_troop.lua#L1490)). The schema never declared it there, so removing
the crate block does not reach it, and the engine keeps reading it. Any change to that path is a separate
lot with its own justification.

## Out of scope

- A `specificParams` editor of any kind — this lot exists so that it is never needed.
- Reconciling `alt_type`. Investigated and closed: the orbit path converts the authored AGL value to ASL
  against terrain height and submits `BARO`; the spawn path uses `RADIO`. Both are terrain-relative and
  mutually consistent. The legacy monolith flew at an absolute 4000 m MSL, which is a deviation this lot
  does not introduce and does not need to revisit.

## Definition of done

- The four globals exist with the stated defaults, `JTAC_droneRadius` is gone, and each has a bilingual
  label, unit and description.
- `specificParams` appears nowhere in the crate schema block, the catalogue, or `src/`.
- A drone spawns and orbits at the same altitude, from the same setting.
- A config still carrying `specificParams` produces one startup NOTICE instead of silently different
  flight behaviour.
- `CHANGELOG.md` `[Unreleased]` records the spawn-altitude change (4000 → 3000 m) as an in-flight
  behaviour change, in the same voice as the `maxSlingloadSpeed` entry from the previous lot.

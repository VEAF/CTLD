# Troop + JTAC lifecycle

**Source:** `src/CTLD_troop.lua`, `src/CTLD_jtac.lua`
**Entities:** `CTLDTroopGroup`, `CTLDJTAC`, `CTLDJTACDetector` (static helpers), `CTLDJTACMessage` (static)
**Singletons:** `CTLDTroopManager`, `CTLDJTACManager`

Troops and JTAC are documented together because a JTAC is **not a unit type** — it is a
capability that can ride on three different carriers, one of which is an infantry soldier inside a
composite troop group. The troop state machine and the JTAC registry are therefore tightly
coupled: deploying, extracting or losing a troop group has to start, freeze or tear down the JTAC
instances that live inside it.

Both managers follow the singleton idiom described in [Architecture](../architecture.md): one
instance per domain, obtained via `CTLDTroopManager.getInstance()` / `CTLDJTACManager.getInstance()`,
each built on `class()` from `src/core/class.lua`. Cross-cutting notifications are published on the
event bus (`EventDispatcher`) — see [Events](../events.md) for the full `OnJTAC*` /
`OnTroops*` catalogue.

Two diagrams accompany this page:

- [Troop + JTAC lifecycle state machine](../../assets/troops_jtac_lifecycle.svg) — every state and transition.
- [Troop transport flows](../../assets/troops_transport_flows.svg) — load / deploy / parachute paths.

## The three JTAC flavours

A JTAC descriptor drives lasing regardless of its DCS category. What differs between flavours is
whether the carrier can be **packed** (destroyed back into crates) and whether it can be **loaded**
(embarked onto a transport).

| Flavour | DCS category | Spawned by | Packable | Loadable | Registry key |
| --- | --- | --- | --- | --- | --- |
| **Troop** (infantry with `jtac=N`) | GROUND group | `embarkFromTroopZone()` → `disembark()` | No | Yes — held virtually in `_inTransit` | `unitName` (unit-keyed) |
| **Vehicle** (Hummer / SKP-11) | GROUND group | `spawnJTACVehicleForTransport()` or crate unpack | Yes — `packVehicle()` → `deregisterJTAC()` | Yes — `loadVehicle()` (virtual or DCS-native) | `groupName` (group-keyed) |
| **Drone** (MQ-9 / RQ-1A) | AIRPLANE | `deployAirJTAC()` or drone crate (`spawnAs = "AIRPLANE"`) | No (aircraft) | No — aircraft are not cargo in CTLD | `groupName` (group-keyed) |

Detection is by descriptor flag only: a crate descriptor with `isJTAC == true` becomes a JTAC on
unpack. There is no separate `JTAC_unitTypeNames` table — that legacy setting was removed, and
drones now reach the map through the standard Request Equipment crate menu
(`spawnAs = "AIRPLANE"`), not a dedicated vehicle-spawn menu.

The vehicle- and drone-side spawn/pack/load methods live in the crate and vehicle managers
(`CTLDVehicleSpawner:registerJTACVehicle()`, `CTLDVehicleSpawner:packVehicle()`,
`CTLDJTACManager:deployAirJTAC()`); this page describes how they call into `CTLDJTACManager`, not
their internals.

## Troop group state machine

A `CTLDTroopGroup` tracks troops from load to final disposal. It is **not a DCS object** — it lives
entirely in Lua memory, inside `CTLDTroopManager._inTransit[unitName]` (a list, so a transport can
carry several groups) or, once on the ground, as a name in `CTLDTroopManager._droppedGroups[coalition]`.

`CTLDTroopGroup.STATE` declares five constants:

```lua
CTLDTroopGroup.STATE = {
    TRZ_LOADED      = "TRZ_LOADED",    -- onboard, loaded from a TroopZone
    DEPLOYED        = "deployed",      -- on the ground as a live DCS group
    FIELD_LOADED    = "FIELD_LOADED",  -- onboard, recovered from the field
    DEPLOYED_EXZ    = "DEPLOYED_EXZ",  -- (declared; see note below)
    RETURNED_TO_TRZ = "RETURNED_TO_TRZ",
}
```

The transitions actually driven by the current code:

```
                 embarkFromTroopZone()                    disembark()
   (pickup TRZ) ─────────────────────► TRZ_LOADED ───────────────────────► DEPLOYED
                                            │                              (DCS group spawned)
                                            │                                   │
                     returnToTroopZone()    │                                   │ embarkFromField()
              (instance discarded, stock    │                                   ▼
               restored, JTACs freed)  ◄─────┘                              FIELD_LOADED
                                                                                │
                                                     disembark() (re-deploy)    │
                                            DEPLOYED ◄──────────────────────────┘

   disembark() while inside an extract zone with objectiveFlag:
              troops counted into the flag, group:deploy(nil), no DCS group, no JTAC
```

- On a **new load** (`embarkFromTroopZone()`) the group is stored in `_inTransit` with
  `_aliveUnits` / `_jtacUnits` pre-built from the template role composition. **No DCS group and no
  JTAC exist yet.**
- On **deploy** (`disembark()`) the DCS group is spawned by `CTLDObjectRegistry.spawnObject()`,
  `group:disembark(dcsGroup)` runs `_syncFromDCSGroup()` to rebuild `_aliveUnits` / `_jtacUnits`
  from the real DCS unit names, the group name is pushed into `_droppedGroups`, and its
  template/weight/total are cached in `_droppedTemplates` for accurate re-deploy after a field
  pickup.
- On **field pickup** (`embarkFromField()`) the nearest friendly dropped group is turned back into a
  `FIELD_LOADED` `CTLDTroopGroup` and its DCS group is destroyed.

**Note — declared-but-unassigned states.** `DEPLOYED_EXZ` and `RETURNED_TO_TRZ` are declared in the
`STATE` table but the current paths do not assign them. An objective-zone drop reuses `DEPLOYED`
(via `group:deploy(nil)` — no DCS group, the extract zone's `objectiveFlag` is simply incremented by
`group.unitTotal`), and `returnToTroopZone()` discards the instance outright
(`_inTransit[unitName] = nil`) rather than parking it in a terminal state.

### `CTLDTroopGroup` unit tracking

```lua
self._aliveUnits = {}  -- [unitName] = dcsUnit (DCS Unit reference, not an index)
self._jtacUnits  = {}  -- [unitName] = true (subset of _aliveUnits flagged as JTAC)
```

`_syncFromDCSGroup()` fully rebuilds both maps from the live DCS group. JTAC soldiers are
identified by the **`JTAC` name prefix** (`name:match("^JTAC")`), set by `_registerOneTemplate()`
for every `jtac`-role unit; the prefix is exclusive to that role — all other roles use
`INF` / `MG` / `AT` / `AA` / `MORTAR` / custom prefixes. Mortar servant crew (`SVNT` prefix) are
excluded from both maps and from `unitTotal`. Keying by `unitName` (never by group index) means DCS
re-indexing surviving units after a death cannot corrupt the tracking.

## JTAC instance model

`CTLDJTAC.STATE` has five values: `IDLE`, `LASING`, `ORBITING` (flying, implies lasing),
`IN_TRANSIT` (ground JTAC embarked), and `DEAD`. The manager keeps **one `CTLDJTAC` per alive JTAC
unit**, not one per group — a composite troop group with two JTAC soldiers holds two entries.

Two registry conventions coexist in `CTLDJTACManager.jtacs`, distinguished by the entity's
`unitName` field:

| JTAC type | Entry point | Key in `jtacs` | `unitName` field | Loop resolves unit via |
| --- | --- | --- | --- | --- |
| Drone / vehicle JTAC | `startLase(groupName)` → `autoLase()` → `spawnJTAC()` | `groupName` | `nil` | `Group.getByName(groupName):getUnits()[1]` |
| Infantry JTAC in a troop group | `startLaseTroopUnit(unitName)` | `unitName` | set | `Unit.getByName(unitName)` |

The distinction is critical on death. A **group-keyed** JTAC whose DCS group has vanished is cleaned
up by `killJTAC(groupName)`, which destroys the group and publishes `OnJTACDead`. A **unit-keyed**
infantry JTAC must **never** call `killJTAC` — doing so would destroy the whole composite group and
kill its surviving infantry. Instead its `_autoLaseLoop` simply returns `nil` (stops) when
`Unit.getByName()` fails, and cleanup is done by `S_EVENT_DEAD → onUnitDead → deregisterJTAC(unitName)`.

Each JTAC is assigned a laser code from a sequential pool (`LASER_CODE_MIN = 1111` …
`LASER_CODE_MAX = 1688`), freed on death/deregister. `CTLDJTACDetector.calculateFMRadio()` derives
an FM guidance frequency from the code (`30 + floor((code-1000)/100) + ((code-1000) mod 100) * 0.05`),
giving roughly 31.5–40.4 MHz across the pool.

## JTAC spawn entry points per flavour

| Flavour | Path | JTAC registered by | Resulting state |
| --- | --- | --- | --- |
| Troop — load via TRZ then deploy | `embarkFromTroopZone()` → `disembark()` | `disembark()` loops `_jtacUnits`, calls `startLaseTroopUnit(unitName)` for each | `IDLE` → `LASING` |
| Troop — parachute drop | `parachuteTroops()` | landing callback maps `_jtacUnits` slot names (`_u<idx>`) to spawned units by position, calls `startLaseTroopUnit()` | `IDLE` → `LASING` |
| Vehicle — Request JTAC Equipment | `spawnJTACVehicleForTransport()` | `registerJTACVehicle()` + `startLase()` | `IDLE` → `LASING` |
| Vehicle — unpack `isJTAC` crate (GROUND) | `_spawnUnpacked()` → `_dispatchPostSpawn()` | `_dispatchPostSpawn()` sees `desc.isJTAC`, calls `startLase()` + `registerJTACVehicle()` | `IDLE` → `LASING` |
| Drone — unpack crate (`spawnAs = "AIRPLANE"`) | `_spawnUnpacked()` → `_dispatchPostSpawn()` | `_dispatchPostSpawn()` checks `desc.isJTAC` with no air/ground distinction, calls `startLase()` | `ORBITING` |
| Drone — `deployAirJTAC()` | direct menu path → `spawnFromDescriptor("AIRPLANE")` | `deployAirJTAC()` calls `startLase()` directly | `ORBITING` |

`embarkFromTroopZone()` deliberately does not spawn anything — it stores a virtual `CTLDTroopGroup`
in `_inTransit`. This is why a JTAC soldier lases nothing while riding a transport (its DCS unit
does not exist yet). `startLaseTroopUnit()` tolerates a not-yet-alive unit: the first `_autoLaseLoop`
is delayed +1 s and simply re-polls.

## Troop-JTAC transition rules per exit path

| Exit path | State | JTAC action required |
| --- | --- | --- |
| `embarkFromTroopZone()` | → `TRZ_LOADED` | None — no JTAC instances exist yet |
| `disembark()` (first deploy) | → `DEPLOYED` | `startLaseTroopUnit(unitName)` for every key in `_jtacUnits` |
| `parachuteTroops()` | → dropped group | On landing, `startLaseTroopUnit()` per JTAC slot mapped to a spawned unit |
| `embarkFromField()` | → `FIELD_LOADED` | **`deregisterJTAC(unitName)` for every key in `_jtacUnits` BEFORE `group:destroy()`** |
| `disembark()` (re-deploy after field) | → `DEPLOYED` | `startLaseTroopUnit(unitName)` for every key in `_jtacUnits` |
| `returnToTroopZone()` | instance discarded | `deregisterJTAC(unitName)` for every key in `_jtacUnits` |
| disembark into extract zone with `objectiveFlag` | → `DEPLOYED` (no DCS group) | None — no group spawned, no JTAC ever instantiated |
| Transport destroyed while `FIELD_LOADED` | entry removed | All `_jtacUnits` orphans → `deregisterJTAC()` in `cleanupDeadTransports()` |

The **deregister-before-destroy** ordering in `embarkFromField()` is the key correctness invariant:
`group:destroy()` fires `S_EVENT_DEAD` for each JTAC unit, and without prior deregistration that
event would falsely trigger `killJTAC()` on a JTAC that is actually being recovered, not killed.

## Vehicle & drone transitions

Ground-vehicle and drone JTACs are group-keyed, so their load/unload/pack transitions call the
group-keyed `CTLDJTACManager` methods directly. Summary of the states they drive:

| Transition | Trigger | State before → after | `jtacs[]` | JTAC action |
| --- | --- | --- | --- | --- |
| Load (menu) | `loadVehicle(method = menu_ctld)` | `LASING`/`IDLE` → `IN_TRANSIT` | freed to `nil` | `setJTACInTransit()` → `setInTransit()` (stop lase, free code retained on entity) |
| Load (DCS native) | vehicle enters transport bbox | `LASING`/`IDLE` → `IN_TRANSIT` | freed to `nil` | `setJTACInTransit()`; DCS unit stays alive, linked inside the aircraft |
| Unload (menu) | `unloadVehicle(method = menu_ctld)` | `IN_TRANSIT` → `IDLE` | recreated | `resumeJTAC()` → `startLase()` |
| Unload (DCS native) | vehicle exits transport bbox | `IN_TRANSIT` → `IDLE` | recreated | `resumeJTAC()` → `startLase()` |
| Parachute vehicle | `parachuteVehicle()` | `LOADED` → `WAITING` | recreated | `resumeJTAC()` in the landing callback |
| Pack | `packVehicle()` | `LASING`/`IDLE` → removed | freed to `nil` | `deregisterJTAC()` — silent, no `OnJTACDead` |
| Destroyed (combat) | `S_EVENT_DEAD` | any → `DEAD` | freed to `nil` | `killJTAC()` publishes `OnJTACDead` |
| Drone destroyed | `S_EVENT_DEAD` | `ORBITING`/`LASING` → `DEAD` | freed to `nil` | `killJTAC()` |

`setJTACInTransit()` calls the entity's `setInTransit()`, which stops the laser and sets state
`IN_TRANSIT`; while in transit `_autoLaseLoop` returns the search interval without probing DCS unit
existence, because the unit is intentionally absent from the map (destroyed on virtual load, or
hidden inside the aircraft on DCS-native load). `deregisterJTAC()` is the **silent** path
(vehicle packed back into crates): it stops lasing, releases target claims, frees the laser code,
removes the registry entry, and does **not** publish `OnJTACDead` — packing is not a combat death.
Drones cannot be loaded, so `IN_TRANSIT` never applies to them.

## `S_EVENT_DEAD` synchronisation

Every death of a unit in a deployed troop group is routed from `CTLDDCSEventBridge` to
`CTLDTroopManager:onUnitDead(unitName)`:

1. `_findGroupByAliveUnit(unitName)` locates the owning `CTLDTroopGroup` (searching `_inTransit`
   first, then reconstructing from `_droppedGroups`).
2. `wasJtac` is captured **before** mutation (`grp._jtacUnits[unitName] ~= nil`).
3. `_removeDeadUnit(unitName)` drops the unit from `_aliveUnits` and `_jtacUnits` and recomputes
   `unitTotal`.
4. If `wasJtac`, `CTLDJTACManager:deregisterJTAC(unitName)` is called — the unit-keyed cleanup that
   frees the laser without touching the surviving composite group.

## Transport kill with FIELD_LOADED troops

When a transport carrying `FIELD_LOADED` troops is shot down, the `_jtacUnits` those troops held are
still referenced in `CTLDJTACManager.jtacs` and would become orphan zombies (the DCS units no longer
exist, but the JTAC entries and their laser codes are still allocated). `cleanupDeadTransports()`
handles this: for every stale `_inTransit` entry whose transport `Unit.getByName()` no longer
exists, it iterates each group's `_jtacUnits` and calls `deregisterJTAC()` before clearing the
`_inTransit` slot. `onTransportDead()` triggers this cleanup immediately on the transport's death
event rather than waiting for the next poll tick.

## Legacy terminology (v1 → v2)

The v2 rewrite renamed the troop lifecycle vocabulary to make the load/deploy/recover semantics
explicit. See [Migration v1 → v2](../migration-v1-v2.md) for the wrapper layer.

| v1 name | v2 name |
| --- | --- |
| `loadFromZone()` | `embarkFromTroopZone()` |
| `deploy()` / `unload()` | `disembark()` |
| `extract()` | `embarkFromField()` |
| `returnToBase()` | `returnToTroopZone()` |
| `LOADED` state | `TRZ_LOADED` |
| `EXTRACTED` state | `FIELD_LOADED` |
| `hasJtac` (boolean) | `_jtacUnits` (map) |
| group index-based tracking | `unitName`-based map tracking |

`CTLDTroopGroup.deploy` is kept as an alias of `disembark` for backward compatibility during the
transition.

## Multi-JTAC target deconfliction

When several JTACs are active at once — any mix of infantry, vehicle and drone — `CTLDJTACManager`
stops them from all lasing the same target through a shared claim table:

```lua
self._claimedTargets = {}  -- { [enemyUnitName] = jtacKey }
-- jtacKey = unitName (unit-keyed infantry) or groupName (group-keyed vehicle/drone)
```

**Claim lifecycle:**

| Event | Action |
| --- | --- |
| JTAC locks a new target | `_claimTarget(jtacKey, enemyUnitName)` |
| Lasing stops (any reason) | `_releaseTarget(enemyUnitName)` — from `_stopLaseAndPublish()` |
| JTAC deregistered / killed | `_releaseTarget()` + `_releaseAllTargetsFor(jtacKey)` (belt-and-suspenders) |
| `cleanup()` | `_claimedTargets = {}` |

**Target selection** (search phase of `_autoLaseLoop`), gated by `ctld.gs("JTAC_targetDeconfliction")`
(enabled unless explicitly `false`):

1. `CTLDJTACDetector.findAllVisibleEnemies()` returns every LOS-visible enemy within
   `JTAC_maxDistance`, sorted by priority then distance. Priority tiers: `hpriority` (1) >
   `priority` (2) > Air Defence (3) > standard (4). LOS uses `land.isVisible` with a +2 m height
   offset on both endpoints.
2. Iterate the candidates, skipping any `candidate.unitName` already in `_claimedTargets`.
3. The first unclaimed candidate is claimed **before** DCS spots are created — preventing a
   concurrent JTAC loop from grabbing the same target within the same scheduler tick — then lasing
   starts.

With deconfliction disabled, the loop simply takes `candidates[1]`.

**Target renewal** (the critical case — target destroyed or LOS lost): `_stopLaseAndPublish()`
releases the claim on the lost target, and execution falls straight through to the search phase in
the same `_autoLaseLoop` tick, so the JTAC immediately picks the next unclaimed candidate from a
fresh `findAllVisibleEnemies()` call. Several JTACs losing their target simultaneously (e.g. one
explosion) therefore each acquire a **different** next target instead of converging on the same one.

`CTLDJTACDetector.findNearestVisibleEnemy()` is now a thin wrapper returning
`findAllVisibleEnemies()[1]`, kept for callsites that only need the single best candidate and do not
require deconfliction.

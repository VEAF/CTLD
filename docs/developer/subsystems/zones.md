# Zone management

**Source:** `src/CTLD_zone.lua`
**Entities:** `CTLDTroopZone`, `CTLDLogisticZone`
**Singleton:** `CTLDZoneManager`

Zones are the spatial anchors of CTLD: where troops board and deploy, where mission
objectives are counted, where crates and vehicles can be serviced, and where AI transports
pick up and drop off cargo. A single manager owns every zone; entities carry the per-zone
state and geometry tests.

`CTLDZoneManager` follows the singleton idiom described in
[Architecture](../architecture.md) — `CTLDZoneManager = class()`, a private `_instance`, and a
`getInstance()` factory that runs `init()` on first access. The two entity classes are plain
`class()` types instantiated with `:new(data)`.

## Zone types

| Type | Prefix / source | Entity | Purpose |
| --- | --- | --- | --- |
| TRZ | `TRZ_` DCS trigger zone | `CTLDTroopZone` | Troop pickup, extract objective, mixed, or inert marker |
| WPZ | `WPZ_` DCS trigger zone | `CTLDTroopZone` (`isWaypoint`) | March destination for deployed troops |
| LGZ | `LGZ_` DCS trigger zone | `CTLDLogisticZone` | Crate / vehicle logistic services |
| AIZ | `aiZones` config table | `CTLDTroopZone` (`isAIPickup` / `isAIDropoff`) | AI-transport-only pickup / dropoff (Feature S/T) |
| Legacy | `troopZones` / `wpZones` / `logisticUnits` config | `CTLDTroopZone` / `CTLDLogisticZone` | Backward-compat for the old PKZ/IAZ/WPZ/EXZ conventions |
| EXZ (dynamic) | `createExtractZone()` at runtime | `CTLDTroopZone` | Extract zone created from a mission `DO SCRIPT` |

TRZ, WPZ and LGZ are discovered by scanning `env.mission.triggers.zones` at init. AIZ zones
are loaded from `ctld.gs("aiZones")` and reference an existing Mission Editor trigger zone by
name (`dcsZoneName`), resolved via `trigger.misc.getZone`. Legacy zones come from the
`ctld.gs(...)` config tables and are loaded last so that a modern `TRZ_`/`LGZ_` definition
always wins: **existing entries are never overwritten**.

## TRZ naming convention

A troop zone encodes all of its behaviour in the trigger-zone name — a strict positional
scheme with **all five fields required**:

```
TRZ_<name>_<A|R|B|N>_<stock>_<flag>_<target>
```

| Position | Field | Type | Values | Meaning |
| --- | --- | --- | --- | --- |
| 1 | `TRZ_` | prefix | literal | Zone type identifier |
| 2 | `name` | string | any, no underscores, not a reserved word | Zone identifier (`zoneName`) |
| 3 | `coalition` | enum | `A` `R` `B` `N` | **A**=all, **R**=RED, **B**=BLUE, **N**=NEUTRAL |
| 4 | `stock` | integer 0–999 | `0`=no pickup, `1–998`=limited, `999`=unlimited | Troop boarding capacity |
| 5 | `flag` | string | DCS flag name, or `nil` | Objective flag incremented on extract; `nil`=no objective |
| 6 | `target` | integer ≥0 | `0`=no win condition, `N≥1`=soldier threshold | Soldiers needed to complete the objective |

Reserved words that may not be used as `name`: `nil`, `A`, `R`, `B`, `N`.

### Field semantics

The parser maps the on-screen field values to internal storage that intentionally differs, so
that `nil` can mean "capability absent":

| `stock` value | Internal `pickMaxStock` | Meaning |
| --- | --- | --- |
| `0` | `nil` | Zone cannot board troops |
| `1–998` | `1–998` | Limited stock, decrements on load |
| `999` | `0` | Unlimited pickup |

| `flag` value | Internal `objectiveFlag` | Meaning |
| --- | --- | --- |
| `nil` | `nil` | No objective flag |
| any string | the string | DCS flag name, incremented by soldier count on extract |

| `target` value | Internal `objectiveTarget` | Meaning |
| --- | --- | --- |
| `0` | `nil` | No win threshold defined |
| `N≥1` | `N` | Soldier count required for objective completion |

> Use `999` for unlimited pickup — **not** `0`. `0` means "this zone cannot board troops".

For coalition, `A→0`, `R→coalition.side.RED` (1), `B→coalition.side.BLUE` (2),
`N→coalition.side.NEUTRAL` (0). `A` and `N` both store `0`; internally CTLD treats `0` as
"accept all coalitions", and DCS multiplayer has no NEUTRAL players, so the two behave
identically.

### Zone roles

A TRZ can act as any combination of:

- **Pickup** (`stock > 0`): troops board here; boarding decrements stock.
- **Extract** (`flag ≠ nil`): troops deployed here increment the objective flag by the soldier
  count.
- **Mixed** (both): supports boarding and objective extract.
- **Inert** (`stock=0`, `flag=nil`): parsed but functionless — a named marker.

### Examples

| Zone name | Role | Boarding | Objective |
| --- | --- | --- | --- |
| `TRZ_base_B_50_nil_0` | Pickup | 50 soldiers | — |
| `TRZ_depot_A_999_nil_0` | Pickup ∞ | unlimited | — |
| `TRZ_exfil_R_0_rescue_0` | Extract | — | flag `rescue`, no threshold |
| `TRZ_lz_B_0_secure_100` | Extract | — | flag `secure`, 100 soldiers |
| `TRZ_fob_N_30_defend_50` | Mixed | 30 soldiers | flag `defend`, 50 soldiers |
| `TRZ_marker_B_0_nil_0` | Inert | — | — |

```
TRZ  _  fob  _  N   _  30     _  defend  _  50
 │       │      │      │          │          │
 │       │      │      │          │          └─ target: 50 soldiers for the objective
 │       │      │      │          └──────────── flag: "defend" (DCS flag name)
 │       │      │      └─────────────────────── stock: 30 troops max (limited)
 │       │      └────────────────────────────── coalition: NEUTRAL
 │       └───────────────────────────────────── name: "fob"
 └───────────────────────────────────────────── prefix TRZ
```

### Parser validation

`CTLDZoneManager:_parseTRZ(name)` returns a parsed table on success, or `nil` plus an error
string on failure:

| Violation | Error message |
| --- | --- |
| Prefix ≠ TRZ | `"not a TRZ"` |
| Missing or empty name | `"missing zoneName"` |
| Name is a reserved word | `"zoneName cannot be a reserved word: <word>"` |
| Missing coalition | `"missing coalition (A|R|B|N)"` |
| Coalition not A/R/B/N | `"invalid coalition '<x>' — expected A, R, B or N"` |
| Stock missing / non-integer / outside 0–999 | `"invalid stock '<x>' — expected integer 0-999 …"` |
| Missing flag | `"missing flag (DCS flag name or 'nil')"` |
| Flag is a number | `"flag must be a string or 'nil', not a number"` |
| Target missing / negative / non-integer | `"invalid target '<x>' — expected integer ≥0 …"` |

`WPZ_` and `LGZ_` use the simpler `<PREFIX>_<name>_[R|B|N]` form (coalition optional, default
`0`); `_parseWPZ` shares `_parseSimpleZone` and `_parseLGZ` is standalone.

## Discovery algorithm

`CTLDZoneManager:init()` registers `S_EVENT_DEAD` on the DCS event bridge, then runs the
following phases **in this order**:

1. `_validateZoneNames()` — scans every trigger zone and the `aiZones` config, accumulates
   errors and warnings (see below), and reports them once to the DCS log and on-screen.
2. `_discoverTRZ()` — for each trigger zone starting with `TRZ_`, parse the name with
   `_parseTRZ`; on success construct a `CTLDTroopZone` (geometry from the trigger zone,
   `smoke` from `troopZoneSmokeColor[coalition]`) and reset any `objectiveFlag` to 0.
3. `_loadAIZonesFromConfig()` — reads `ctld.gs("aiZones")`; each valid entry becomes a
   `CTLDTroopZone` marked `isAIPickup` / `isAIDropoff`, with per-template/per-type stock.
4. `_discoverWPZ()` — trigger zones starting with `WPZ_` become waypoint troop zones
   (`isWaypoint = true`).
5. `_discoverLGZ()` — trigger zones starting with `LGZ_` become `CTLDLogisticZone` objects
   (radius from `dynamicZoneRadius`, default 200 m).
6. `_loadLegacyZones()` — backward-compat pass over the `troopZones`, `wpZones` and
   `logisticUnits` config tables.
7. `_scheduleSmoke()` — starts the recurring smoke refresh loop.

Finally `init()` publishes an initial `OnLogisticZoneUpdated` and logs the zone counts. Each
discovery phase guards on `if not self._troopZones[name]` / `_logisticZones[name]`, so the
precedence order above is what makes modern definitions win over legacy ones.

### Legacy fallback details

- `troopZones` entries support both DCS trigger zones and **ship unit names** — if
  `trigger.misc.getZone` misses, the loader falls back to `Unit.getByName`, snapshotting the
  ship's position at init as a mobile pickup point. Legacy troop zones auto-derive a
  `stockFlagName` of `<zoneName>_count`, mirroring `pickCurrentStock` to that DCS flag.
- `logisticUnits` entries resolve via `StaticObject.getByName` or `Unit.getByName` and become
  **dynamic** logistic zones linked to that object (radius from `maximumDistanceLogistic`,
  default 500 m).

## `CTLDTroopZone`

Constructed from a `data` table. Required: `dcsName`, `zoneName`, `coalition`, `center`
(vec3), `radius`. Optional: `verticies`, `pickMaxStock`, `objectiveFlag`, `objectiveTarget`,
`stockFlagName`, `smoke` (a `trigger.smokeColor.*` value or `-1`), `active`, the role flags
`isWaypoint` / `isDropoff` / `isAIPickup` / `isAIDropoff`, and the AI fields `aiDropMode`,
`aiCargoType`, `troopTemplates`, `vehicleTypes`, `_aiTroopStock`, `_aiVehicleStock`.

### Role predicates

| Method | True when |
| --- | --- |
| `zone:hasPickup()` | `pickMaxStock ~= nil` |
| `zone:hasExtract()` | `objectiveFlag ~= nil` |
| `zone:hasWaypoint()` | `isWaypoint == true` |
| `zone:hasDropoff()` | `isDropoff == true` (IAZ legacy auto-drop) |
| `zone:hasAIPickup()` | `isAIPickup == true` (AIZ P role) |
| `zone:hasAIDropoff()` | `isAIDropoff == true` (AIZ D role) |

### Geometry

`zone:isInZone(point)` tests polygonal zones (`verticies` with ≥3 corners) via a Jordan
ray-cast on the private static `CTLDTroopZone._raycast`, otherwise falls back to a circular
radius test. Note that `verticies[i].x/.y` are mission-file coordinates where mission `Y`
equals world `Z`. `zone:getCenter()` returns the stored `center`.

### Stock management

```lua
zone:consumeStock(n)   -- decrement pickCurrentStock by n; true on success, unlimited always true
zone:restoreStock(n)   -- restore up to pickMaxStock; no-op for unlimited or non-pickup zones
```

Both call `_syncStockFlag()`, which writes `pickCurrentStock` to `stockFlagName` via
`trigger.action.setUserFlag` when that flag is set. Unlimited stock (`pickMaxStock == 0`) means
`consumeStock` always succeeds and `restoreStock` is a no-op.

### AI per-template / per-type stock (Feature T)

AIZ zones can carry granular stock instead of a single count. `_aiTroopStock` and
`_aiVehicleStock` are tables of the shape `{ isAll = bool, init = {name=N}, current = {name=N} }`,
where `N = -1` means unlimited. The special config key `"All"` sets `isAll = true` (every
template/type, unlimited).

```lua
zone:aiPickTroopTemplate(teams, typeName, unitName, tm)  -- best eligible template, or nil
zone:aiConsumeTroopStock(templateName)                   -- decrement one troop unit
zone:aiRestoreTroopStock(templateName, n)                -- restore n (default 1), capped at init
zone:aiPickVehicleEntry()                                -- { type, isScene, isAASystem } or nil
zone:aiConsumeVehicleStock(typeName)                     -- decrement one vehicle
zone:aiRestoreVehicleStock(typeName)                     -- restore one, capped at init
```

`aiPickTroopTemplate` filters templates that are in stock **and** fit the transport's capacity
(`tm:_canEmbark`), then prefers the highest current stock, choosing randomly among ties.
`aiPickVehicleEntry` resolves each type's provider in priority order
`CTLDSceneManager` (scene) > `CTLDCrateAssemblyManager` (AA system) > DCS native, returning
`nil` when `isAll` is set (the caller then uses the legacy physical-scan path).

### Objective

```lua
zone:incrementObjective(soldierCount)  -- → incremented(bool), valueBefore, valueAfter
```

Adds `soldierCount` to `objectiveFlag` (mode: **+N per soldier**, not per group or per
operation) and logs an `INFO` line when `objectiveTarget` is reached. CTLD only ever
increments the flag; it resets `objectiveFlag` to 0 once at discovery, and the mission maker
defines the win condition in the DCS Editor with a trigger such as `if flag >= target → victory`.

`zone:activate()` / `zone:deactivate()` toggle the `active` flag.

## `CTLDLogisticZone`

Constructed from `data`. Required: `name`, `coalition`, `center`, `radius` (default 200).
Optional: `linkedUnit` (the zone then follows this DCS unit/static), `active`, and a `services`
table which defaults to `{ cratesPickup = true, cratesDropoff = true, vehicleSpawn = true }`.

| Method | Behaviour |
| --- | --- |
| `zone:getCenter()` | Linked unit's live point if it still exists, else the stored center |
| `zone:isDynamic()` | True if anchored to a moving DCS unit (`_linkedUnit ~= nil`) |
| `zone:isAlive()` | True unless the linked unit no longer exists (always true for static) |
| `zone:isInZone(point)` | Circular radius test only — logistic zones are always circular |
| `zone:activate()` / `zone:deactivate()` | Toggle `active` |

## Smoke scheduler

`_scheduleSmoke()` re-arms itself every `smokeRefreshInterval` seconds (default 300). When
`disableAllSmoke` is set it re-schedules without doing anything. Otherwise it smokes every
active troop zone whose `smoke >= 0` and every active logistic zone that has a colour in
`logisticZoneSmokeColor[coalition]`, then publishes `OnZoneSmokeRefreshed` with a snapshot of
both zone sets (positions, stock, objective progress, colours).

## Events

Published through `EventDispatcher` (see [Architecture](../architecture.md)):

| Event | Published when |
| --- | --- |
| `OnZoneSmokeRefreshed` | Every `smokeRefreshInterval` seconds by the smoke loop |
| `OnLogisticZoneUpdated` | At init, on dynamic-unit death, and on FOB / logistic register / unregister / (de)activate |

The manager registers `onDead` for `S_EVENT_DEAD` via `CTLDDCSEventBridge`: when a dynamic
logistic zone's linked unit dies, the zone is removed and an `OnLogisticZoneUpdated` is
published with the removal.

## Query API — troop zones

```lua
zm:getTroopZone(zoneName)                     -- → CTLDTroopZone | nil
zm:getTroopZonesForCoalition(coalition)       -- active zones for coalition (0 = both)
zm:getTroopZoneAtPoint(point, coalition)      -- containing zone; excludes AI-only pickup zones
zm:getTroopZoneForUnit(unitName)              -- zone under a live unit's position
zm:getWaypointZoneAt(point, coalition)        -- active WPZ containing point
zm:getNearestWaypointZone(point, coalition)   -- nearest WPZ (point need not be inside)
zm:getDropoffZoneAt(point, coalition)         -- active IAZ-legacy auto-drop zone at point
zm:getAIPickupZoneAt(point, coalition)        -- active AIZ P zone at point (smallest radius wins)
zm:getAIDropoffZoneAt(point, coalition)       -- active AIZ D zone at point (smallest radius wins)
```

Coalition filtering everywhere follows the same rule: a zone matches when
`coalition == 0` (caller accepts all), or `zone.coalition == 0` (zone serves all), or the two
sides are equal. `getNearestWaypointZone` backs Feature I (`gotoNearestWPZ`), and the AI
pickup/dropoff getters back the AI transport loop (`_checkAIStatus`).

## Query API — logistic zones

```lua
zm:getLogisticZone(name)                             -- → CTLDLogisticZone | nil
zm:getLogisticZonesForCoalition(coalition)           -- active + alive zones for coalition
zm:getLogisticZoneAtPoint(point, coalition)          -- first containing zone
zm:getLogisticZoneForUnit(unitName)                  -- zone under a unit / static
zm:getLogisticZonesAtPoint(point, coalition, key)    -- ALL containing zones; optional services filter
```

`getLogisticZonesAtPoint` returns every matching zone (not just the first). The optional
`serviceKey` (e.g. `"cratesPickup"`) keeps only zones where `zone.services[key]` is not
`false`.

## Runtime registration and legacy-compatible API

```lua
zm:registerFOBAsLogistic(fobName, point, radius, coalitionId)  -- add a built FOB as an LGZ
zm:unregisterLogistic(name)                                     -- remove a dynamic LGZ (FOB destroyed)
zm:deactivateLogisticZone(name)                                 -- reversible disable (capture / loss)
zm:activateLogisticZone(name)                                   -- re-enable
zm:setTroopZoneActive(zoneName, active)                         -- enable / disable a TRZ

-- Legacy-compatible (called by the legacy API wrappers):
zm:isUnitInZone(unitName, zoneType)     -- zoneType: "extract" | "pickup" | nil (any active zone)
zm:createExtractZone(zoneName, flag, smoke)   -- runtime EXZ from a DCS trigger zone
zm:removeExtractZone(zoneName, flag)          -- flag accepted but ignored
zm:activateWaypointZone(zoneName)             -- delegates to setTroopZoneActive(…, true)
zm:deactivateWaypointZone(zoneName)           -- delegates to setTroopZoneActive(…, false)
zm:changeRemainingGroups(zoneName, amount)    -- adjust pickCurrentStock by ±amount (floored at 0)
```

Deactivated logistic zones are ignored by every getter until reactivated, which lets a mission
simulate a captured or temporarily lost resupply point without destroying it.

## Unload priority: extract before RTB

When a player unloads troops, the containing zone is evaluated in this order (handled by the
troop subsystem, not the zone manager itself):

1. TRZ with `objectiveFlag` → **extract** (deploy troops, increment the flag).
2. TRZ with pickup only → **RTB** (troops return, stock restored).
3. Otherwise → **combat deploy** (troops deployed, no flag, no stock change).

This ordering ensures a mixed zone triggers its objective when used as an extract point rather
than merely returning the troops to stock.

## F10 menu behaviour

The troop-command menu is rebuilt on `S_EVENT_LAND` / `S_EVENT_TAKEOFF` from the player's
current position and cargo state:

- In flight: the "Troop Commands" submenu is empty.
- On the ground inside a pickup TRZ: a "Load from `<zoneName>`" option appears.
- On the ground with troops onboard: an "Unload / Extract" option appears.
- On the ground outside any TRZ: no load options.

## Zone-name validation

`_validateZoneNames()` runs first in `init()` and produces a single grouped report
(`trigger.action.outText` + DCS log + `env.warning`). It covers:

- **TRZ / WPZ / LGZ**: any trigger zone with the prefix that fails its parser is reported as an
  error.
- **AIZ config (Features S/T)**: per-entry checks accumulate errors and warnings, keyed by
  `dcsZoneName` so that only invalid entries are skipped in `_loadAIZonesFromConfig`.

| Rule | Severity | Condition |
| --- | --- | --- |
| — | error | missing `dcsZoneName`, duplicate `dcsZoneName`, zone absent from the Mission Editor, or missing/invalid `coalition` |
| G1 | error | neither `isPickup` nor `isDropoff` — the zone would do nothing |
| G5 | error | vehicle `cargoType` (`V`/`TV`) on a pickup zone but no aircraft has `canTransportWholeVehicle` |
| — | warn | invalid `cargoType` (defaults to `T`) or invalid `aiDropMode` (defaults to `GP`) |
| G3 | warn | pickup + troop cargo but `troopStock` undefined — troop pickup disabled |
| G6 | warn | pickup + vehicle cargo but `vehicleStock` undefined — vehicle pickup disabled |
| G2 | warn | every entry in `troopTemplates` is unknown (per-name warnings also emitted) |
| G4 | warn | every entry in `vehicleTypes` is unknown in the loadable-vehicle lists |
| — | warn | a pickup zone overlaps a dropoff zone of the same coalition — risk of an instant pickup/dropoff loop |

When there are no findings it logs `CTLDZoneManager: zone config valid` instead.

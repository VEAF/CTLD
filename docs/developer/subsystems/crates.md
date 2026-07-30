# Crate spawn pipeline

Crates are the physical currency of CTLD logistics: a transport requests equipment as a
crate (or a set of crates), flies it to a destination, drops or slingloads it, and unpacks
it into a vehicle, a JTAC, or a scene. The whole domain lives in `src/CTLD_crate.lua`, which
defines the `CTLDCrate` entity and the `CTLDCrateManager` singleton.

This page follows a crate from configuration to deployed contents. For the manager's public
method signatures see the [API reference](../api-reference.md); for the events it publishes see
[Events](../events.md); for the scenes and vehicles it feeds, see [Scenes](scenes.md) and
[Vehicles](vehicles.md).

## The `CTLDCrate` entity

`CTLDCrate = class()` models one cargo static and its lifecycle. A crate is created with
`CTLDCrate:new(data)` (never `CTLDCrateManager` internals directly) and carries its descriptor,
position, coalition, spawn method, and the DCS `StaticObject` handle.

The lifecycle is a small state machine held in `crate.state`, drawn from `CTLDCrate.STATE`:

| State | Meaning |
| --- | --- |
| `spawned` | On the ground, freshly created, never moved |
| `loaded` | Inside / attached to a transport |
| `falling` | In the air, descending (drop or parachute) |
| `landed` | On the ground after a transport cycle |
| `unpacked` | Contents deployed — terminal state |

Transitions are driven by entity methods, each of which sets `state` and the relevant fields:
`load(transport)`, `unload(position)`, `drop(position)`, `startParachute(altitude)`,
`land(position)`, and `unpack()`. `destroy()` removes the backing DCS static.

Two predicates gate menu actions. `isOnGround()` returns true only in `spawned` or `landed`
state **and** verifies `dcsStatic:isExist()` when a static handle is present — this guards
against crates destroyed by combat before an `S_EVENT_DEAD` could unregister them.
`canUnpack()` combines `isOnGround()` with the `canBeUnpacked` flag. `isLoadedByCTLD()` returns
true whenever the crate is `loaded`, covering both CTLD-menu loads and DCS-native loads migrated
into CTLD; use `loadedByDCSNative` to distinguish the two.

Each crate records its origin in `crate.spawnMethod`, one of `CTLDCrate.SPAWN_METHOD`:

| Value | Origin |
| --- | --- |
| `crate_spawn` | Spawned from the F10 Request Equipment menu |
| `vehicle_pack` | Result of packing a vehicle |
| `mission_maker` | Pre-placed by the mission maker (detected via INIT-B) |
| `menu_ctld` | Spawned via a CTLD menu action |

## Configuration pre-processing: `_processSpawnableCrates`

`CTLDCrateManager.getInstance()` calls `_processSpawnableCrates()` once at first access. It reads
the raw `ctld.gs("spawnableCrates")` config and transforms it into two internal structures the menu
builder and every descriptor lookup rely on:

- `self._processedCrates[category] = { singleCrates = { {singleCrate, singleTypeSet?}, … }, mixedSets = { … } }`
- `self._weightIndex[weight] = descriptor` — an O(1) index used by all `findDescriptorBy*` methods
  (single crates only; mixed sets have no `weight` field).

Before the main loop, `CTLDCrateAssemblyManager.injectAACrates(spawnableCrates)` injects the AA
system part/repair crate entries so they flow through the same passes. The transform then runs in
three passes per category:

1. **Separation.** Each entry with a `weight` field becomes a single crate (indexed into a
   per-category `catWeightIdx` and into `self._weightIndex`); each entry with a `mixedSet` field
   becomes a mixed set. Entries with neither are logged as a warning and skipped.
2. **`singleTypeSet` generation.** For each single crate whose `cratesRequired > 1`, when
   `enableAllCrates` is not `false` and the crate's `showSets` is not `false`, an auto-generated
   `singleTypeSet` is stored next to it: `multiple` is the weight repeated `cratesRequired` times,
   and `desc` is the crate description plus an i18n-aware `" - " .. ctld.tr("All crates")` suffix.
   Setting `showSets = false` on a crate suppresses this entry even when `enableAllCrates` is on.
3. **Mixed-set validation.** Every weight in a `mixedSet` is checked against the per-category index.
   Any unresolved weight invalidates the entire set (excluded from the menu) and queues a
   mission-maker warning shown via `trigger.action.outText` at startup. Valid sets are copied with
   `mixedSet` aliased to `multiple` for spawn compatibility.

Scene crates registered before init are merged in afterward via `_injectSceneCrate`; scenes
registered later are injected incrementally by `CTLDSceneManager:registerSceneModel`. Weight
collisions during injection are resolved by walking to the next free slot in the same `1001.xx`
range and logging a `WARN`. Scenes disabled by the mod audit are purged by `_purgeDisabledScenes`.

## From menu to ground: `spawnCrate`

A spawn request funnels through `spawnCrate(descriptor, position, coalitionId, spawnedBy,
spawnMethod, countryId, modelKey)`. It delegates static creation to `_spawnStatic`, which:

- resolves the crate model from `ctld.gs("spawnableCratesModels")` by `modelKey`, falling back to
  `"load"`;
- derives the country from the coalition when `countryId` is nil;
- builds a sanitised unique name (`CTLD_<label>_<uid>` or `CTLD_Crate_<uid>`); and
- calls `ctld.utils.dynAddStatic` (never `coalition.addStaticObject` directly) inside a `pcall`,
  returning the name and the `StaticObject` handle.

`spawnCrate` then wraps the static in a `CTLDCrate`, registers it, publishes `OnCrateSpawned`, and
schedules a near-immediate `_refreshNearbyPlayers` so nearby transports see the new crate in their
Load Crate submenu. `spawnCratesAligned` is the batch entry point: it picks a random spawn axis
(front sector for standard transports, rear sector for native-cargo-capable ones), computes
non-overlapping positions avoiding other dynamic-cargo aircraft bounding boxes, and calls
`spawnCrate` for each descriptor. The model key is chosen by `_crateModelKey`: `"sling"` when
`slingLoad` is set, `"dynamic"` for native-cargo-capable transports, otherwise `"load"`.

## Lifecycle transitions on the manager

The manager mirrors the entity transitions and owns event publication:

| Method | Transition | Publishes |
| --- | --- | --- |
| `loadCrate(crateName, transport)` | `spawned`/`landed` → `loaded` (destroys the static) | `OnCrateLoaded`, `OnCrateCleared` |
| `unloadCrate(crateName, position, method)` | `loaded` → `landed` (respawns the static) | `OnCrateUnloaded`, `OnCrateSpawned` |
| `unpackCrate(crateName, unpacker)` | `spawned`/`landed` → `unpacked` (destroys + unregisters) | `OnCrateUnpacked`, `OnCrateCleared` |
| `destroyCrate(crateName)` | destroy + unregister | `OnCrateCleared` |

Loading and unloading both call `ctld.utils.updateTransportWeight` so the transport's mass reflects
its cargo. Because the DCS static is destroyed on load, `unloadCrate` recreates it via
`_respawnStatic`, which mints a fresh unique name and re-indexes `self.crates` under it.

## The unpack pipeline: `_spawnUnpacked`

Every unpack outcome — ground vehicle, air JTAC, or static — is deployed through a single
three-step pipeline in `_spawnUnpacked(desc, pos, coa, cId, playerName)`:

```
_spawnUnpacked(desc, pos, coa, cId, playerName)
  ├── spawnAs ≠ "GROUND"/"STATIC" (air) + JTAC_dropEnabled == false → skip
  ├── desc.isJTAC → CTLDJTACManager:_consumeJTACSlot(coa)   ← quota gate (definitive)
  │     └── limit reached → notify player + return (no spawn)
  ├── ctld.utils.buildGroupUnitDef(desc, pos, gname, gid, uid)
  │     ├── spawnAs == "GROUND"   → minimal {name, task, units[{x,y,heading}]}
  │     └── spawnAs == "AIRPLANE" → full {groupId, units[{alt,speed}], route[orbit+EPLRS]}
  │           (orbit + EPLRS embedded only when isJTAC = true)
  ├── ctld.utils.spawnFromDescriptor(desc, cId, unitDef)
  │     ├── spawnAs == "STATIC"   → coalition.addStaticObject
  │     └── otherwise             → coalition.addGroup(Group.Category[spawnAs])
  └── _dispatchPostSpawn(desc, gname)
        └── isJTAC = true → CTLDJTACManager:startLase(gname)
```

Ground spawns additionally publish `OnGroundUnitSpawned`. On success, when a `playerName` is
supplied, the vehicle spawner's load and pack submenus are refreshed.

**Key rules:**

- `coalition.addGroup` and `coalition.addStaticObject` must only be reached via
  `ctld.utils.spawnFromDescriptor` — never called directly.
- `ctld.utils.buildGroupUnitDef` is the single builder for GROUND and AIR unit definitions.
  STATIC objects use a separate schema and go straight to `addStaticObject`.
- Post-spawn role activation belongs exclusively in `_dispatchPostSpawn`. That method starts JTAC
  lasing for `isJTAC` descriptors and registers both JTAC and plain ground vehicles with
  `CTLDVehicleSpawner` so the Load/Unload menu can track them. Do not add role logic elsewhere in
  the unpack path.
- The JTAC quota (`JTAC_LIMIT_RED`/`JTAC_LIMIT_BLUE`) is consumed **before** spawn, both here and in
  the Request Equipment path (`spawnJTACFromDescriptor`). The quota is definitive — it is never
  refilled when a JTAC is killed. Mission-maker JTACs and infantry JTAC soldiers do not consume it.

## Descriptor fields driving the pipeline

| Field | Effect on pipeline |
| --- | --- |
| `spawnAs` (string, default `"GROUND"`) | Selects the `addGroup` category or routes to `addStaticObject` |
| `isJTAC` (boolean) | **Source of truth for the JTAC role.** Adds the orbit route to an air unit definition and triggers `startLase` post-spawn. The unit type name (`unit`) is never used for JTAC detection in the OOP stack. |
| `specificParams` (table, air only) | Orbit tuning passed to `startLase` / `deployAirJTAC`: `speed`, `alti`, `orbitRadiusNoLase`, `orbitRadiusOnLase` |
| `cratesRequired` (number) | Guards unpack — the count must be met before the pipeline runs |
| `showSets` (boolean, default `true`) | When `false`, suppresses the auto-generated "All crates" `singleTypeSet` entry even if `enableAllCrates` is on |

### JTAC detection rules (do not invert)

| Context | Rule |
| --- | --- |
| Request Equipment menu population | `getJTACDescriptors(coalition)` iterates `_processedCrates` and returns single-crate entries with `isJTAC = true` for the player's coalition (or `side = nil`) |
| Request Equipment spawn | `CTLDVehicleSpawner:spawnJTACFromDescriptor(desc, spawner, zone)` — quota check → ground: `spawnVehicleForTransport` + `startLase`; air: `deployAirJTAC` |
| Post-unpack activation | `_dispatchPostSpawn`: `if desc.isJTAC → CTLDJTACManager:startLase()` |
| Pre-placed MM group detection | Group name contains `"jtac"` (case-insensitive) — unit type not used |
| Troop deploy with JTAC soldier | `tmpl.hasJtac == true` (computed from `jtac > 0`) → `startLase` after deploy |

> Do not add new JTAC detection paths. If a new unit type needs JTAC behaviour, set `isJTAC = true`
> on its crate descriptor — never add it to a type-name list. `JTAC_unitTypeNames` has been removed:
> the crate catalogue is the single source of truth for both the crate menu and the Request
> Equipment menu.

## F10 menu integration

`buildMenuSection(playerObj, menu)` builds the **Request Equipment** submenu (`order = 25`, between
Troop and Vehicle commands) and the **Crate Commands** submenu (`order = 40`), gated on the
player's `capabilitiesByType[typeName].cratesEnabled`. The dynamic submenus are rebuilt on demand:

- `refreshRequestEquipmentSection` renders each category's `singleCrates` (each immediately followed
  by its `singleTypeSet` when visible) then its `mixedSets`, with per-player coalition/JTAC filtering
  and a stable order counter.
- `refreshLoadCrateSection` groups crates within 50 m by descriptor type with a count; loading picks
  the nearest matching crate and enforces the transport's `maxCratesOnboard`.
- `refreshUnpackSection` lists assembleable sets (count ≥ `cratesRequired`) within 300 m, delegating
  AA sets to `CTLDCrateAssemblyManager:tryUnpackOrRepair` and scene crates to
  `CTLDSceneManager:playScene` (or a model's own `crate.unpack`), and standard vehicles to
  `_spawnUnpacked`.
- `refreshPackEquiptSection` shows the unified **Pack Equipt** submenu (FARP scenes and packable
  vehicles) only on the ground, when `enableFARPRepack` or `enablePackingVehicles` is set.

A ground-position poller (10 s) refreshes Request Equipment only when the player's logistic-zone set
changes, avoiding a fixed-cadence rebuild that would eject players from open sub-menus. Crate spawn
and clear events refresh the Load Crate and Unpack submenus for every transport within range.

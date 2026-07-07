# Player tracking

CTLD tracks connected human players **without MIST**. Two cooperating singletons cover the
concern:

| Singleton | Source | Responsibility |
| --- | --- | --- |
| `CTLDPlayerTracker` | `src/CTLD_core.lua` | Lightweight identity index — who occupies which slot |
| `CTLDPlayerManager` | `src/CTLD_player.lua` | Per-player state (`CTLDPlayer` entities), F10 menu, cargo tracking |

Both follow the `X = class()` + `getInstance()` idiom described in
[Architecture](../architecture.md) and consume DCS slot events through the single
`CTLDDCSEventBridge` handler rather than registering with `world` directly.

## `CTLDPlayerTracker` — slot identity index

`CTLDPlayerTracker` maintains a double index of connected humans, with **no dependency on
MIST**:

```lua
self._byUnit   = {}   -- unitName   → playerName
self._byPlayer = {}   -- playerName → { unitName, coalition }
```

It is populated from three sources, in order of authority:

| Source | Role |
| --- | --- |
| `S_EVENT_PLAYER_ENTER_UNIT` / `S_EVENT_PLAYER_LEAVE_UNIT` | Primary, event-driven add/remove |
| `S_EVENT_BIRTH` | Backup — catches the first joiner if `PLAYER_ENTER_UNIT` was missed |
| `coalition.getPlayers()` scan | Safety net; `_scanAllSlots()` runs immediately at init, then every 30 s for the first 3 minutes |

The scan is idempotent (it only inserts slots not already indexed), so the three sources never
conflict. After 3 minutes the event stream is considered sufficient and the periodic scan stops.

### Public API

| Method | Returns |
| --- | --- |
| `getPlayerByUnit(unitName)` | `playerName` occupying the unit, or `nil` if AI/unoccupied |
| `getUnitByPlayer(playerName)` | `{ unitName, coalition }`, or `nil` if not connected |
| `getAllPlayers()` | list of `{ playerName, unitName, coalition }` |
| `isPlayerUnit(unitName)` | `true` if the unit is currently occupied by a human |

`CTLDPlayerTracker.getInstance()` requires `CTLDDCSEventBridge` to be initialised first, because
`init()` registers its handlers on the bridge.

## `CTLDPlayer` — per-player entity

`CTLDPlayer = class()` is an identity snapshot plus mutable cargo state, constructed by
`CTLDPlayerManager` when a human enters a slot. Its fields, set in `CTLDPlayer:init(data)`:

```lua
{
    unitName         = "UH-1H-1",   -- DCS unit name (the map key in CTLDPlayerManager)
    groupId          = 9901,        -- group:getID()  (used for F10 menu ops)
    groupName        = "Grp_1",     -- group:getName()
    coalition        = 2,           -- coalition.side.BLUE
    typeName         = "UH-1H",     -- unit:getTypeName()
    isTransport      = true,        -- detected capability (see below)
    canCarryVehicles = false,       -- detected capability (see below)
    loadedTroops     = {},          -- list
    loadedCrates     = {},          -- list of CTLDCrate
    loadedVehicles   = {},          -- list of CTLDVehicle
}
```

Cargo lists are mutated by identity-matched helpers on the entity:

- `addLoadedCrate(crate)` / `removeLoadedCrate(crate)`
- `addLoadedVehicle(vehicle)` / `removeLoadedVehicle(vehicle)`

`loadedTroops` is initialised but not maintained by these helpers — troops in transit are owned
by `CTLDTroopManager` and queried via `getInTransit(unitName)` (see the "Check Cargo" command
below).

### Capability detection

`CTLDPlayerManager:_detectCapabilities(unit)` derives the two capability flags from
`ctld.gs("capabilitiesByType")` keyed by `unit:getTypeName()`:

- `isTransport` — `true` when the type has an entry in `capabilitiesByType`.
- `canCarryVehicles` — `true` when that entry sets `canTransportWholeVehicle == true`.

## `CTLDPlayerManager` — lifecycle & menu owner

The manager keeps its own map, distinct from the tracker's identity index:

```lua
self._players = {}   -- unitName → CTLDPlayer
```

### Lifecycle

| DCS event | Handler | Action |
| --- | --- | --- |
| `S_EVENT_PLAYER_ENTER_UNIT` | `onPlayerEnterUnit(event)` | Skip AI (no `getPlayerName()`), apply the pilot-name gate, build a `CTLDPlayer`, store it, call `buildMenu(playerObj)` |
| `S_EVENT_PLAYER_LEAVE_UNIT` | `onPlayerLeaveUnit(event)` | Remove the player's DCS menu items and drop it from `_players` |
| `S_EVENT_TAKEOFF` | `onTakeoff(event)` | Set `_isFlying = true`, refresh flight-dependent menu sections |
| `S_EVENT_LAND` | `onLand(event)` | Clear `_isFlying`, refresh menu sections after a 1 s settle delay |

`getPlayer(unitName)` returns the tracked `CTLDPlayer`, or `nil`.

`_scanExistingPlayers()` is a multiplayer safety net: it runs once at the end of
`ctld.initialize()` and reschedules every 30 s, synthesising `onPlayerEnterUnit` for any occupied
slot not yet in `_players` (slot switches, AI takeover, late joiners).

**Pilot-name gate:** when `ctld.gs("addPlayerAircraftByType") == false`, only unit names listed in
`ctld.gs("transportPilotNames")` receive a CTLD menu; all others are logged and skipped.

### Flight-state poller

Because `S_EVENT_TAKEOFF` / `S_EVENT_LAND` fire with a 3–5 s delay for helicopters, `init()` also
starts a 0.5 s `timer.scheduleFunction` poller. It reads `ctld.utils.inAir(unit)` per tracked
player and, once a new state holds for two consecutive ticks (`DEBOUNCE_TICKS`, ~1 s), commits it
to `playerObj._isFlying` and runs the same menu-refresh chain. The `onTakeoff` / `onLand` handlers
still fire, but by then `_isFlying` already matches and the refresh is a fast no-op.

### Cargo state via the event bus

The manager subscribes to `EventDispatcher` (see [Events](../events.md)) to keep each
`CTLDPlayer`'s cargo lists current, then refreshes the affected menus:

| Subscribed event | Effect |
| --- | --- |
| `OnVehicleLoaded` | `addLoadedVehicle`, then `refreshForUnit` |
| `OnVehicleUnloaded` | `removeLoadedVehicle`, then `refreshForUnit` |
| `OnCrateLoaded` | `addLoadedCrate`, `refreshForUnit`, and refresh the crate's Unpack section |
| `OnFOBDeployed` | Refresh Request Equipment / JTAC sections for every grounded player |

`CTLDPlayerManager` **publishes no events**.

### F10 menu

`CTLDPlayerManager` owns the CTLD F10 menu. Managers contribute sections through
`registerMenuSection(sectionDef)` (idempotent by `key`); scene files loaded before the singleton
exists may pre-queue sections with `deferMenuSection(sectionDef)`, flushed during `init()`.

`buildMenu(playerObj)` wipes and reconstructs the menu atomically via `ctld.MenuManager`. It
always adds a **Check Cargo** command that sums the transport's current load — crates (grouped by
descriptor), troops in transit (`CTLDTroopManager:getInTransit`), and whole vehicles
(`CTLDVehicleSpawner:findLoadedVehicles`, weighted from `ctld.gs("groundVehicleWeights")`, default
2500 kg) — and reports a per-type breakdown plus a total in kilograms. Registered sections are
then rendered in ascending `order`, each gated by its optional `configKey`
(`ctld.gs(configKey) == true`).

`refreshForUnit(unitName)` and `refreshAll()` request a deferred menu refresh through
`ctld.MenuManager` for one or all tracked players. Cargo weight is only ever **displayed** — there
is no per-transport weight cap or load rejection in this subsystem.

# Beacon system

**Source:** `src/CTLD_beacon.lua` · **Singleton:** `CTLDBeaconManager` · **Entity:** `CTLDBeacon`

The beacon system lets a transport crew drop a navigation beacon at its current position (or a
mission maker place one at a trigger zone). Every beacon is a **triple radio transmitter** — one
DCS group per band (VHF, UHF, FM) — that broadcasts an audible homing tone for ADF/radio-compass
navigation. Beacons run on a battery, are refreshed on a fixed schedule, and can be drawn on the
F10 map as a per-player toggleable layer.

There are **no separate "beacon types"** (no distinct TACAN or IR beacon path in the current
code): every beacon is the same three-`TACAN_beacon`-group construct described below.

## The two classes

`CTLD_beacon.lua` defines an entity and a manager, following the class idiom described in
[Architecture](../architecture.md):

```lua
CTLDBeacon = class()                 -- one deployed beacon (three DCS groups)
CTLDBeaconManager = class()          -- singleton owning all beacons + frequency pools
CTLDBeaconManager._instance = nil
CTLDBeaconManager.getInstance()      -- factory, builds freq pools on first access
```

`CTLDBeaconManager:init()` builds the frequency pools, schedules the refresh loop (only if
`ctld.gs("enabledRadioBeaconDrop")` is true), and registers its F10 menu section with
`CTLDPlayerManager` under the key `"beacons"` at `order = 60`.

### `CTLDBeacon` fields

A beacon instance carries the three group names, the three assigned frequencies (in Hz), and its
battery/lifecycle state:

| Field | Meaning |
| --- | --- |
| `beaconName` | Unique key — equals `vhfGroupName` |
| `name` | Display name, e.g. `"Beacon #3"` |
| `coalitionId` | Owning coalition |
| `position` | `{x, y, z}` world position |
| `vhfGroupName` / `uhfGroupName` / `fmGroupName` | The three DCS group names |
| `vhf` / `uhf` / `fm` | Assigned frequencies in Hz |
| `batteryEndTime` | `timer.getTime()` deadline, or `-1` for infinite |
| `spawnTime` | `timer.getAbsTime()` at drop |
| `isFOB` | FOB beacons are infinite (`batteryEndTime == -1`) |

Helper methods: `isBatteryAlive()`, `countAliveUnits()` (0–3), `batteryRemaining()`
(`math.huge` when infinite), `freqText()` (`"245.00 kHz - 350.50 / 45.20 MHz"`), and
`mgrsCoords()`.

## Radio transmission

Each of the three groups is a single `TACAN_beacon` DCS unit spawned via `ctld.utils.dynAdd`.
`_startTransmissions()` sets each group's ROE to `WEAPON_HOLD` and calls
`trigger.action.radioTransmission` with band-specific settings:

| Band | Mode | Sound |
| --- | --- | --- |
| VHF | `0` (AM) | `ctld.gs("radioSound")` (default `beacon.ogg`) |
| UHF | `0` (AM) | `ctld.gs("radioSoundFC3")` (default `beaconsilent.ogg`) — silent for FC3 aircraft |
| FM | `1` (FM) | `ctld.gs("radioSound")` |

Transmissions are started **1 second after spawn** via `timer.scheduleFunction`: DCS leaves a
freshly-added group's units uninitialised for roughly a second, so calling `radioTransmission`
immediately would broadcast from a stale or zero position.

## Frequency pools

Three free/used pool pairs are built once in `_buildFreqPools()`:

| Pool | Range | Step |
| --- | --- | --- |
| VHF | 200–840 kHz, then 850–1250 kHz | 10 kHz below 850, 50 kHz above |
| UHF | 220 MHz up to (not including) 399 MHz | 0.5 MHz |
| FM | 30–76 MHz band | `(100*f + 10*s + t) * 100 kHz` for `f=3..7`, `s=0..5`, `t=0..9` |

Frequencies are stored in Hz. The VHF pool skips a hard-coded set of real-world NDB frequencies
(`CTLDBeaconManager._ndbSkip`) that already exist on DCS maps, to avoid interference.

`_assignFrequencies()` draws one frequency per band with `_pickFreq(free, used)`, which picks a
random entry and moves it to the used pool. When a pool drops to **3 or fewer** free entries it
recycles the entire used pool back into free before picking. `_freeFrequencies(beacon)` returns
all three frequencies to their free pools when a beacon is removed or destroyed.

## Lifecycle

```
dropped   → 3 TACAN_beacon groups spawned, transmissions start after 1s
active    → _refreshAll() runs every beaconRefreshInterval seconds
destroyed → battery depleted OR fewer than 3 units alive → cleanup + free frequencies
removed   → manual removal by a player within 500m
```

**Drop paths.** `dropBeacon(transport, player, isFOB, overridePosition)` is the transport path:
when the aircraft is on the ground it offsets the spawn point behind the aircraft (heading + π,
using the bounding-box width plus 5 m, falling back to 20 m) so the ground unit is not spawned
inside the aircraft's collision box; airborne, it spawns at the aircraft position.
`createAtZone(zoneName, coalitionStr, batteryLife, name)` is the legacy/mission-maker path
(no transport): it resolves a DCS trigger zone, maps `"red"`/`"blue"` to a coalition and country
(`RUSSIA`/`USA`), and otherwise follows the same spawn flow.

**Manual removal.** `removeClosestBeacon(transport, player)` finds the nearest same-coalition
beacon within `BEACON_REMOVAL_RADIUS` (500 m); if none is in range it reports
`"No Radio Beacons within 500m."`.

**Listing.** `listBeacons(transport)` prints the coalition's active beacons (name + `freqText()`)
to the requesting group.

### Battery and refresh

Battery life is **minutes**, read from `ctld.gs("deployedBeaconBattery")` (default `30`). At drop
time a normal beacon's `batteryEndTime` is set to `timer.getTime() + minutes * 60`; FOB beacons
(`isFOB = true`) get `-1`, meaning infinite.

The refresh loop, scheduled by `_scheduleRefresh()`, runs `_refreshAll()` every
`ctld.gs("beaconRefreshInterval")` seconds (default `60`). For each beacon it checks
`countAliveUnits() == 3` **and** `isBatteryAlive()`:

- Both true → re-run `_startTransmissions()` (keeps the tone alive across DCS's transmission
  timeouts).
- Otherwise → destroy the beacon's groups, free its frequencies, remove it from map layers, drop
  it from `_beacons`, and publish `OnBeaconDestroyed` with `reason` = `"battery_depleted"` or
  `"unit_destroyed"`.

The refresh loop uses a singleton guard: if `CTLDBeaconManager._instance` is no longer the
instance that scheduled it, the scheduled function returns `nil` and stops, preventing a zombie
loop after a re-init. The scheduler id is registered under `"beacon_refresh"` via
`ctld.scheduler.register`.

## Map draw layer

The draw layer is a **per-player toggle** gated by `ctld.gs("beaconLayerEnabled")`.
`toggleLayer(player, transport)` flips `_layerState[player].enabled`; when enabled it draws every
same-coalition beacon, when disabled it removes the player's marks.

Each beacon icon is three primitives drawn by `_drawBeaconIcon(beacon, markId)`:

- an outer circle (`beaconIconRadius`, default `25`; `beaconIconColor`, default orange
  `{1.0, 0.5, 0.0, 1.0}`),
- an inner solid circle at half radius,
- a text label (`beaconName` + MGRS coords, size `beaconTextSize`, default `12`).

### Mark ID allocation

Mark IDs come from the **application-wide monotonic counter**, not a beacon-local scheme:

```lua
ctld.utils.getNextMarkId()   -- ctld._markIdCounter starts at 10000, increments and returns
```

Each beacon icon consumes **one** id from `getNextMarkId()` (wrapped locally as `_nextMark()`),
then derives its three DCS mark ids from it: `markId*10 + 1` (outer circle), `markId*10 + 2`
(inner circle), `markId*10 + 3` (text). `_removeMarkId(markId)` calls `trigger.action.removeMark`
on all three. The same `getNextMarkId()` counter is shared with the recon layer and
`ctld.utils.drawQuad()` (see [Recon system](recon.md)); ids are never reused.

When `ctld.gs("beaconAutoRefreshLayer")` is true, `_addBeaconToLayers()` pushes a newly-dropped
beacon into every currently-enabled layer, and `_removeBeaconFromLayers()` strips its marks when
it is removed or destroyed.

## Events

The beacon manager publishes on the internal event bus (see [Events](../events.md)):

| Event | When |
| --- | --- |
| `OnBeaconDropped` | A beacon is dropped or created at a zone |
| `OnBeaconRemoved` | A player manually removes the closest beacon (`reason = "manual"`) |
| `OnBeaconDestroyed` | Refresh finds the battery depleted or fewer than 3 units alive |
| `OnBeaconRefreshed` | A refresh tick touched at least one beacon (no-op ticks are silent) |
| `OnBeaconLayerToggled` | A player toggles the map layer |

## F10 menu

`buildMenuSection(playerObj, menu)` builds the **Radio Beacons** submenu (order 60) under the CTLD
root. It returns early unless `playerObj.isTransport`, and the whole section is gated by the
`enabledRadioBeaconDrop` config key (the `configKey` passed to `registerMenuSection`). Commands:

- **Drop Beacon** → `dropBeacon(transport, nil, false)`
- **Remove Closest Beacon** → `removeClosestBeacon(transport, nil)`
- **List Beacons** → `listBeacons(transport)`

## Query API

| Method | Returns |
| --- | --- |
| `getBeaconsForCoalition(coalitionId)` | Array of `CTLDBeacon` for the coalition |
| `getBeacon(beaconName)` | The `CTLDBeacon` for a name, or `nil` |

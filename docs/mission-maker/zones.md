# Zone setup

CTLD zones are declared directly in the **DCS Mission Editor** by naming your trigger zones
with a structured convention. For most zones no scripting is required: CTLD reads every trigger
zone name at mission start, parses those that match a known prefix, and registers them
automatically. AI transport zones are the one exception — they are declared in your CTLD
configuration (see [AI transport zones](#ai-transport-zones-aiz) below).

For how pilots actually *use* these zones from the cockpit, see the
[Pilot guide](../pilot/index.md).

## Naming convention

A zone name encodes its type and all of its parameters, separated by `_`:

```
TYPE_name_param1_param2_..._paramN
```

> **Rule:** `_` is the field separator. It is **forbidden inside any field value** (zone name,
> flag name, etc.). Use `farmmain`, not `farp_main`.

## Zone types at a glance

Three prefixes are auto-discovered from DCS trigger zone names:

| Prefix | Zone type | Schema |
| --- | --- | --- |
| `TRZ` | Troop zone — player pickup and/or extract objective | `TRZ_<name>_<A\|R\|B\|N>_<stock>_<flag>_<target>` — **all 5 fields required** |
| `WPZ` | Waypoint zone — troops deployed inside march to the zone centre | `WPZ_<name>_[R\|B\|N]` |
| `LGZ` | Logistic zone — crate and vehicle services | `LGZ_<name>_[R\|B\|N]` |

A fourth kind — **AI transport zones (AIZ)** — is not name-discovered. It is declared entirely
in config; see [AI transport zones](#ai-transport-zones-aiz).

> There is no separate `EXZ` prefix. Extract objectives are a **function of a TRZ** (a troop zone
> with `stock = 0` and an objective flag), described under [Troop zones](#troop-zones-trz).

**Coalition parameter:**

| Value | Coalition |
| --- | --- |
| `A` | All coalitions (TRZ only) |
| `R` | RED only |
| `B` | BLUE only |
| `N` | Neutral |
| *(omit)* | All coalitions (WPZ / LGZ only — TRZ requires an explicit `A`) |

> **Uniqueness:** two zones of the same prefix cannot share the same `name`. A zone name already
> registered is never overwritten by a later one.

---

## Troop zones (TRZ)

A troop zone provides **player pickup** and/or an **extract objective**.

**Schema:** `TRZ_<name>_<A|R|B|N>_<stock>_<flag>_<target>`

**All 5 fields are required.** The parser rejects any TRZ name with a missing or invalid field —
a warning is written to `CTLD.log` and the zone is ignored.

| Field | Position | Values | Meaning |
| --- | --- | --- | --- |
| `name` | 2 | any (no underscores, not a reserved word) | Zone identifier used in logs and F10 menus |
| `coalition` | 3 | `A` `R` `B` `N` | Who can interact: **A**=all, **R**=RED, **B**=BLUE, **N**=NEUTRAL |
| `stock` | 4 | integer 0–999 | `0`=no pickup · `1–998`=limited · `999`=unlimited |
| `flag` | 5 | DCS flag name or `nil` | Flag incremented by soldier count on extract; `nil` = no objective |
| `target` | 6 | integer ≥0 | `0`=no threshold · `N≥1`=soldier-count goal for a DCS victory trigger |

> **Reserved words** — forbidden as `name` or `flag`: `nil`, `A`, `R`, `B`, `N`.

### Stock values

| `stock` | Pickup capability | What the pilot sees |
| --- | --- | --- |
| `0` | **None** — no pickup | No "Load from" entry in the F10 menu |
| `1–998` | Limited — decrements on each load | "Load from `<name>` (N remaining)" |
| `999` | **Unlimited** — never exhausted | "Load from `<name>`" |

> Use `999` for unlimited pickup — **not** `0`. `0` means *no pickup capability*.

### Flag and target values

| `flag` | `target` | Behaviour |
| --- | --- | --- |
| `nil` | any | Zone has no objective. Troops deployed here spawn as a DCS ground group. |
| a flag name | `0` | Objective active, no threshold. CTLD increments the flag by the soldier count each time troops are deployed inside. |
| a flag name | `N≥1` | Objective with a threshold. CTLD increments the flag; **you** write the DCS victory trigger `flag >= N`. CTLD initialises the flag to `0` at mission start and never ends the mission itself. |

### Examples

| Zone name | Coalition | Stock | Flag | Target | Behaviour |
| --- | --- | --- | --- | --- | --- |
| `TRZ_base_B_50_nil_0` | BLUE | 50 (limited) | — | — | **Pickup** — 50 soldiers, restock on RTB |
| `TRZ_depot_A_999_nil_0` | All | unlimited | — | — | **Pickup** — unlimited, all coalitions |
| `TRZ_exfil_B_0_rescue_0` | BLUE | no pickup | `rescue` | none | **Extract-only** — deploying troops here increments flag `rescue` |
| `TRZ_lz_R_0_secure_100` | RED | no pickup | `secure` | 100 | **Extract with win condition** — RED objective at 100 soldiers |
| `TRZ_fob_N_20_defend_50` | Neutral | 20 (limited) | `defend` | 50 | **Mixed** — pickup (20) + extract objective |
| `TRZ_marker_B_0_nil_0` | BLUE | no pickup | — | — | **Inert** — named marker, no function |

Annotated:

```
TRZ  _  fob  _  N   _  20     _  defend  _  50
 │      │       │      │          │          │
 │      │       │      │          │          └─ target : 50 soldiers complete the objective
 │      │       │      │          └──────────── flag   : "defend" (DCS flag name)
 │      │       │      └─────────────────────── stock  : 20 troops max (limited pickup)
 │      │       └────────────────────────────── coalition: NEUTRAL
 │      └────────────────────────────────────── name   : "fob"
 └───────────────────────────────────────────── prefix TRZ
```

> **Extract-only zone** (`stock = 0`): no "Load from" entry appears in the F10 menu. The zone only
> serves as an objective trigger when troops are deployed inside it.
>
> **Mixed zone** (`stock > 0` and `flag ≠ nil`): supports both boarding and objective scoring.
> When a pilot lands inside with troops aboard, **the objective takes priority** — the flag is
> incremented and **no** DCS group is spawned. Stock restore on RTB happens only in pickup-only
> zones.
>
> **Smoke:** troop-zone smoke colour is set globally per coalition via the `troopZoneSmokeColor`
> setting (see [Configuration](configuration.md)), not per zone name.

See [Troop transport](../pilot/troop-transport.md) for the pilot-side workflow (boarding,
deploying, extracting).

---

## Waypoint zones (WPZ)

When troops are deployed (fast-rope or ground drop) at a point that falls **inside** an active
WPZ, they automatically march toward the **centre** of that zone instead of searching for the
nearest enemy.

**Schema:** `WPZ_<name>_[R|B|N]`

| Example name | Meaning |
| --- | --- |
| `WPZ_hill47_B` | BLUE waypoint zone "hill47" |
| `WPZ_bridge` | All-coalition waypoint zone |

The zone radius is taken from the DCS trigger zone editor.

> WPZ zones do **not** appear in the F10 menu — they act silently at deploy time.

---

## Logistic zones (LGZ)

A logistic zone defines a base where pilots can spawn and pack crates and vehicles from the F10
menu. A pilot must be inside a logistic zone to use these services.

**Schema:** `LGZ_<name>_[R|B|N]`

| Example name | Meaning |
| --- | --- |
| `LGZ_depot1_B` | Logistic zone "depot1", BLUE only |
| `LGZ_farmmain_R` | Logistic zone "farmmain", RED only |
| `LGZ_shared` | Logistic zone open to all coalitions |

> **Radius:** an `LGZ_` zone is a **circle** centred on the trigger zone, with a radius taken
> from the `dynamicZoneRadius` setting (default **200 m**). The trigger zone's own editor radius
> is **not** used for LGZ. Set `dynamicZoneRadius` in [Configuration](configuration.md) to change
> it globally.

See [Crate catalogue](crates-catalogue.md) for what can be spawned, and
[Crates](../pilot/crates.md) for the pilot workflow.

### Logistic zones created at runtime

The only way to add a new logistic zone during a live mission is to **deploy a FOB**. When the
FOB build completes, CTLD automatically registers a circular logistic zone centred on the FOB
site (radius = `fobLogisticZoneRadius`, default 150 m, under the FOB's name). No `LGZ_` trigger
zone or config entry is required. See [Scenes & FOB](scenes-fob.md) for the full FOB lifecycle,
including how a destroyed FOB removes its logistic zone.

### Deactivating and reactivating a logistic zone

Use the `CTLDZoneManager` API from a **DO SCRIPT** trigger to simulate zone capture or a temporary
loss. This works for both `LGZ_` trigger zones and `logisticUnits`-based zones:

```lua
-- Deactivate — zone is ignored by all pilots until reactivated
CTLDZoneManager.getInstance():deactivateLogisticZone("depot1")

-- Reactivate — zone becomes available again
CTLDZoneManager.getInstance():activateLogisticZone("depot1")
```

The zone stays registered and can be toggled any number of times.

---

## AI transport zones (AIZ)

AIZ zones control the automatic behaviour of **AI transports** (units listed in
`transportPilotNames`). Human players are never affected by them.

> **AIZ zones have no naming convention.** Any DCS trigger zone can be an AIZ zone — you reference
> it by name in the `aiZones` config array. Both pickup and drop-off fire on landing
> (`S_EVENT_LAND`): the AI unit must physically land inside the zone radius.

### Roles

| Role | Trigger | Behaviour |
| --- | --- | --- |
| **Pickup** | AI transport lands inside the zone | Loads troops and/or a whole vehicle |
| **Drop-off** | AI transport lands inside the zone | Deploys troops and/or unloads a whole vehicle |

A zone may be pickup only, drop-off only, or both.

### Config declaration

`aiZones` is a list of entries in your configuration. `ctld-tools` gives it a dedicated editor under
the **Zones** family; in a hand-written snapshot it lives under `mm_facing`:

```yaml
mm_facing:
  aiZones:
  # Troops-only pickup: two templates with per-template stock
  - dcsZoneName: my_base
    coalition: BLUE
    isPickup: true
    cargoType: T
    troopStock:
      Standard Group: 5
      Anti Tank: 2

  # Troops-only pickup: every compatible template, unlimited
  - dcsZoneName: depot_alpha
    coalition: BLUE
    isPickup: true
    cargoType: T
    troopStock:
      All: -1

  # Vehicle-only pickup (vehicles must be physically in the zone)
  - dcsZoneName: armor_depot
    coalition: BLUE
    isPickup: true
    cargoType: V
    vehicleStock:
      Hummer: 3
      M1045 HMMWV TOW: -1

  # Troops + vehicle pickup
  - dcsZoneName: hub_tv
    coalition: BLUE
    isPickup: true
    cargoType: TV
    troopStock:
      All: -1
    vehicleStock:
      Hummer: 5

  # Ground-only drop-off
  - dcsZoneName: lz_front
    coalition: BLUE
    isDropoff: true
    aiDropMode: G

  # Ground + parachute drop-off (default)
  - dcsZoneName: lz_rear
    coalition: BLUE
    isDropoff: true
```

!!! warning "`coalition` here is a word, not a number"
    Every other coalition field in the CTLD configuration is the numeric `side` (`1` = RED,
    `2` = BLUE). In an `aiZones` entry it is the string `RED`, `BLUE` or `NEUTRAL`. Writing a number
    here means "any coalition", silently.

### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `dcsZoneName` | string | ✅ | Exact name of the DCS trigger zone |
| `coalition` | `"RED"` / `"BLUE"` / `"NEUTRAL"` | ✅ | Which AI transports use this zone |
| `isPickup` | `true` | one of the two | Marks the zone as a pickup zone |
| `isDropoff` | `true` | one of the two | Marks the zone as a drop-off zone |
| `cargoType` | `"T"` / `"V"` / `"TV"` | pickup only | Troops, whole vehicle, or both. Default `"T"` |
| `troopStock` | table `{ [name] = N }` | pickup + troops | Per-template stock. `N = -1` unlimited, `N > 0` limited. Special key `All` = every compatible template. **Must be present to enable troop pickup.** |
| `vehicleStock` | table `{ [type] = N }` | pickup + vehicles | Per-type stock, same `-1` / `N` / `All` rules. **Must be present to enable vehicle pickup.** |
| `aiDropMode` | `"G"` / `"P"` / `"GP"` | drop-off | `G` ground, `P` parachute, `GP` either. Default `"GP"` |
| `troopTemplates` | `{ "Name1", ... }` | optional | Whitelist of troop templates eligible at this zone |
| `vehicleTypes` | `{ "TypeName", ... }` | optional | Whitelist of DCS vehicle type names eligible for loading |

> `troopStock` and `vehicleStock` are **tables**, not plain integers. Per-template / per-type
> stock replaced the old single-integer form.

### AI transport setup

1. Create trigger zones in the ME (any name, any radius suitable for landing).
2. Declare them in `aiZones` (above).
3. Add each AI unit's **exact DCS unit name** to `transportPilotNames`, which is a **plain list** of
   names:

   ```yaml
   mm_facing:
     transportPilotNames:
     - heliai_supply
     - heliai_medevac
   ```

4. Route the AI unit so it lands inside the zones (waypoints with a "Landing" task).

> A whole vehicle is only loaded if its weight does not exceed the transport's `maxVehicleWeight`
> and at least one aircraft has `canTransportWholeVehicle = true`. See
> [Configuration](configuration.md) for weights and capabilities.

### Validation report

At mission start CTLD validates every `aiZones` entry and, if there is anything to report,
displays a grouped list of errors and warnings on screen (30 s) and in `CTLD.log`, in the mission
language. If everything is valid, a single `INFO` line is logged and nothing pops up.

An entry is **ignored** (error) when it has no `dcsZoneName`, a duplicate `dcsZoneName`, a zone
absent from the Mission Editor, a missing or invalid `coalition` (must be `RED` / `BLUE` /
`NEUTRAL`), neither `isPickup` nor `isDropoff`, or vehicle cargo (`V` / `TV`) while no aircraft
can carry a whole vehicle. Common **warnings** (the zone is still created): an invalid `cargoType`
falls back to `"T"`, an invalid `aiDropMode` falls back to `"GP"`, a pickup zone missing the
matching `troopStock` / `vehicleStock` has that pickup disabled, unknown `troopTemplates` /
`vehicleTypes` names, and a pickup zone overlapping a drop-off zone of the same coalition (risk of
an instant pickup+drop-off loop).

---

## Legacy zone configuration

Missions built the classic CTLD v1 way — zone names listed in config tables rather than parsed
from trigger names — are still supported. The `_` character **is** allowed in the names here,
because these are plain DCS trigger (or unit) names, not parsed schemas.

These are ordinary configuration settings, and their entries are **positional arrays**: the meaning
of a value comes from its place in the list. `ctld-tools` edits them as named fields under the
**Zones** family, which is the safest way to touch them; written by hand they look like this:

```yaml
mm_facing:
  # Troop pickup zones — v1 called this pickupZones.
  # [ DCS zone name, smoke colour, limit, active, side ]
  #   smoke colour : none | green | red | white | orange | blue
  #   limit        : -1 = unlimited, or any integer >= 1
  #   active       : yes | no
  #   side         : 0 = both, 1 = RED, 2 = BLUE
  troopZones:
  - - pickzone1
    - blue
    - -1
    - yes
    - 0
  - - USS Tarawa      # a ship unit name is also accepted
    - blue
    - 10
    - yes
    - 2

  # Waypoint zones (deployed troops march to the centre)
  # [ DCS zone name, smoke colour, active, side ]
  wpZones:
  - - wpzone1
    - green
    - yes
    - 2

  # Logistic units: unit or static names placed in the ME.
  # If the named object is destroyed, its logistic zone is removed automatically.
  logisticUnits:
  - logistic1
  - logistic2
```

!!! warning "`dropOffZones` is not read in CTLD 2.x"
    v1's `dropOffZones` table (AI auto-deploy points) has no equivalent setting in CTLD 2. AI
    drop-off is configured with [AI transport zones](#ai-transport-zones-aiz) — an `aiZones` entry
    with `isDropoff: true`. A v1 config carrying `dropOffZones` will have that table ignored.

> Legacy zones and auto-discovered zones (TRZ / WPZ / LGZ) coexist without conflict: a zone already
> registered from trigger-name discovery is never overwritten by legacy config.

For the full v1 `ctld.*` compatibility surface, see [Legacy API](legacy-api.md).

# Fat Cow

A Fat Cow is a CH-47 that lands in the field and opens a FARP stocked with what it carries.
The pilot side is described in [Fat Cow (pilots)](../pilot/fat-cow.md); this page covers the settings and how to place a cow in a mission.

## What CTLD lays out

When a cow deploys, CTLD plays the **Fat Cow FARP** scene at the cow:

| Object | Where | Role |
|---|---|---|
| Invisible FARP | at the cow | the airbase whose warehouse holds the cow's stock |
| FARP Fuel Depot | 25 m behind the ramp | the supplier the ground crews need |
| 2 ammo crates, 1 set of barrels | 15–18 m behind | dressing, never loadable |
| 3 soldiers | 20 m behind, to the left | standing by |

No vehicle, no tent, no ammo dump.
This was measured in DCS 2.9.30.28738: a FARP spawned during a mission serves a player already in game, but only with a supplier in range, and the FARP Fuel Depot alone supplies both fuel and weapons (fuel trucks, ammo trucks and the ammo dump are not needed; cargo crates and barrels supply nothing).

The FARP's warehouse is set to the cow's stock and nothing else: jet fuel, and each ammunition item the cow carries.
DCS serves it until it runs out.
When a player joins the server, CTLD writes every open cow's warehouse again, with the quantities the server holds: whether DCS shares a scripted warehouse with clients was not measured.

## Settings

All in the `fob` family of the configuration.

| Setting | Default | Meaning |
|---|---|---|
| `fatCowEnabled` | `true` | The F10 **Fat Cow** menu and the cow crates. |
| `fatCowTypes` | `[CH-47Fbl1]` | Types a player can fly as a cow. Each must also be a transport in `capabilitiesByType`. |
| `fatCowCrates` | fuel tank, Hellfires, 30 mm | What a player cow can load (see below). |
| `fatCowDeployDelay` | `60` | Seconds an AI cow stays on the ground before its FARP opens. |
| `fatCowAIType` | `CH-47Fbl1` | Type of the helicopter brought in when a flight requests a cow. Empty removes **Request a Fat Cow**. |
| `fatCowAIFuelKg` | `7200` | Jet fuel an AI cow carries (three 800 gal ERFS tanks). |
| `fatCowAIItems` | 6 × `weapons.missiles.AGM_114K` | Ammunition an AI cow carries. |
| `fatCowAICows` | `[]` | Cows placed in the mission (see below). |

### Cow crates

Each `fatCowCrates` entry is one crate a player cow can request:

```yaml
fatCowCrates:
- desc: Fat Cow fuel tank (800 gal)
  weight: 2400            # kg in the hold; also the crate's catalogue key
  fuelKg: 2400            # jet fuel it holds
- desc: Fat Cow Hellfires (x4)
  weight: 250
  item: weapons.missiles.AGM_114K   # DCS warehouse item name
  count: 4
```

An entry has either `fuelKg`, or `item` and `count`.
`item` is the name DCS gives the weapon in a warehouse: `weapons.missiles.AGM_114K` was checked in game for the Hellfire.
The 30 mm entry (`weapons.shells.M230_HEDP M789`) is the name DCS gives the Apache's rounds, not yet checked as a warehouse item.

Cow crates never show in **Request Equipment** nor in **Unpack Crate**: they are requested from the Fat Cow menu, and deployed from the hold.

## Placing an AI cow in a mission

A flight can request an AI cow in a logistic zone during the mission.
To give a flight its cow from the start instead, place the cow in the Mission Editor and declare it:

1. Place a **CH-47F** group, **late activation** ticked, where the cow should start (usually the flight's base).
   Its first waypoint is a take-off from the ground; it needs no other waypoint.
2. Declare it, with the group it escorts:

```yaml
fatCowAICows:
- group: Fat Cow Gunfighter      # the CH-47 group, exact name
  escort: Gunfighter             # the flight it escorts, exact group name
```

CTLD activates the cow as soon as the escorted group is in the world: at mission start for an AI flight, or when the first player takes a slot of a client flight.
The cow then behaves as a requested one: it follows, lands next to the leader, deploys after `fatCowDeployDelay`, packs when the leader takes off, and flies back to where it started once empty.

This declaration is the contract the VEAF Mission Creation Tools rely on to add a cow escorting a named flight: a late-activated helicopter group, and one `fatCowAICows` entry `{ group, escort }`.
CTLD never recognises a cow by its name.

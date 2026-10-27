# Fat Cow

A Fat Cow is a CH-47 that lands in the field and opens a FARP stocked with what it carries.
The pilot side is described in [Fat Cow (pilots)](../pilot/fat-cow.md); this page covers the settings and how to place a cow in a mission.

## What CTLD lays out

When a cow deploys, CTLD plays the **Fat Cow FARP** scene at the cow:

| Object | Where | Role |
|---|---|---|
| Invisible FARP | at the cow | the airbase whose warehouse holds the cow's stock |
| FARP Fuel Depot | 25 m behind the ramp | the supplier the ground crews need |
| 2 ammo crates, 1 set of barrels | 20 m behind, to the right | dressing, never loadable |
| 3 soldiers | 25 m behind, to the left | standing by |

No vehicle, no tent, no ammo dump.
This was measured in DCS 2.9.30.28738: a FARP spawned during a mission serves a player already in game, but only with a supplier in range, and the FARP Fuel Depot alone supplies both fuel and weapons (fuel trucks, ammo trucks and the ammo dump are not needed; cargo crates and barrels supply nothing).

Each cow has one FARP of its own, named `CTLD_FatCow_FARP_<n>`.
Packing removes the depot, the dressing and the crew and empties the FARP's warehouse, but leaves the FARP itself: a heliport destroyed during a mission stays on the F10 map, and an AI cow sitting on its FARP blew up when the FARP was destroyed under it.
The next deployment adds the FARP again under the same name, where the cow now is.
So an emptied FARP stays on the map where each cow last deployed; with no supplier next to it, it serves nothing.

The FARP's warehouse is set to the cow's stock and nothing else: jet fuel, and each ammunition item the cow carries.
DCS serves it until it runs out.
When a player joins the server, CTLD writes every open cow's warehouse again, at once and two seconds later, with the quantities the server holds: whether DCS shares a scripted warehouse with clients was not measured.
CTLD also reads and writes them every 10 seconds.
A quantity that went up was refilled by another script (the VEAF Mission Creation Tools refill every FARP when a player joins): CTLD keeps the cow's own count and puts it back, and removes any weapon the cow does not carry.
What was taken in the few seconds before such a refill can come back, and ammunition a helicopter hands back while rearming is not added to the cow's stock.
A cow FARP that is not open is emptied at the same moments.
The FARP of an AI cow gone home is reused by the next one, so the map does not gain an empty FARP with each cow requested.

## Settings

All in the `fob` family of the configuration.

| Setting | Default | Meaning |
|---|---|---|
| `fatCowEnabled` | `true` | The F10 **Fat Cow** menu and the cow crates. |
| `fatCowTypes` | `[CH-47Fbl1]` | Types a player can fly as a cow. Each must also be a transport in `capabilitiesByType`. |
| `fatCowCrates` | fuel tank; Hellfires and 30 mm (Apache); Vikhr and 2A42 rounds (Ka-50); Ataka, Shturm and GSh-30 rounds (Mi-24P) | The crates a player cow carries its stock in (see below). |
| `fatCowLoadouts` | four Apache, four Russian and two mixed loadouts, each with 4 800 kg of fuel | What a cow carries: loaded by a player cow, picked by a flight requesting an AI cow (see below). |
| `fatCowDeployDelay` | `60` | Seconds an AI cow stays on the ground before its FARP opens. |
| `fatCowAIType` | `CH-47Fbl1` | Type of the helicopter brought in when a flight requests a cow. Empty removes **Request a Fat Cow**. |
| `fatCowAICows` | `[]` | Cows placed in the mission (see below). |

### Loadouts

Each `fatCowLoadouts` entry is what a cow carries: jet fuel in kg, and DCS warehouse items with their counts.

```yaml
fatCowLoadouts:
- desc: 40 Hellfires (25 laser, 15 radar), 2400 rounds
  fuelKg: 4800                          # two 800 gal tanks
  items:
  - item: weapons.missiles.AGM_114K     # laser Hellfire
    count: 25
  - item: weapons.missiles.AGM_114      # radar Hellfire (AGM-114L)
    count: 15
  - item: weapons.shells.M230_HEDP M789 # 30 mm
    count: 2400
```

A player cow finds them under **Load**, in a logistic zone; a flight requesting an AI cow picks one under **Request a Fat Cow**.
A loadout with `menu: russian` or `menu: mixed` shows in the **Russian** or **Mixed** submenu, one without at the top.
The cow is always a CH-47 (`fatCowAIType`), whatever the loadout and whatever the requester flies: it is the module players fly as a cow.

The defaults all carry two 800 gal tanks (4 800 kg):

| Menu | Loadout | Weapons | Total |
|---|---|---|---|
| top | Apache | 40 Hellfires (25 laser, 15 radar), 2 400 rounds of 30 mm | 7 868 kg |
| top | Apache | 60 Hellfires (38 laser, 22 radar), 1 200 rounds | 8 199 kg |
| top | Apache | 40 laser Hellfires, 2 400 rounds | 7 812 kg |
| top | Apache | 60 laser Hellfires, 1 200 rounds | 8 118 kg |
| Russian | Ka-50 | 40 Vikhr, 460 rounds of 2A42 HE and 460 AP | 7 382 kg |
| Russian | Ka-50 | 60 Vikhr, 230 rounds of 2A42 HE and 230 AP | 7 891 kg |
| Russian | Mi-24P | 32 Ataka, 500 rounds of GSh-30 | 6 809 kg |
| Russian | Mi-24P | 32 Shturm, 500 rounds of GSh-30 | 6 358 kg |
| Mixed | Apache + Ka-50 | 20 Hellfires (12 laser, 8 radar), 20 Vikhr, 1 200 rounds of 30 mm, 460 of 2A42 | 7 627 kg |
| Mixed | Apache + Mi-24P | 20 laser Hellfires, 16 Ataka, 1 200 rounds of 30 mm, 500 of GSh-30 | 7 523 kg |

All are under the 8 837 kg a CH-47F lifts with 80 % of its internal fuel (22 680 kg at most, 11 400 kg empty, 2 444 kg of fuel, from DCS's units database); an AI cow is given those 80 %.
Missile masses are the DCS data mine's (AGM-114K 45.3 kg, AGM-114L 49 kg, Vikhr 45 kg, Ataka 49.5 kg, Shturm 35.4 kg); rounds are counted 0.5 kg (30 mm Apache) and 0.85 kg (30 × 165 Russian) with their packing, an estimate.

`item` is the name DCS gives the weapon in a warehouse.
`weapons.missiles.AGM_114K` was checked in game for the laser Hellfire.
The others come from the DCS data mine and are not yet checked as warehouse items: `weapons.missiles.AGM_114` (AGM-114L), `weapons.shells.M230_HEDP M789` (the Apache's rounds), `weapons.missiles.Vikhr_M`, `weapons.missiles.Ataka_9M120`, `weapons.missiles.AT_6` (Shturm), `weapons.shells.2A42_30_HE` and `2A42_30_AP` (Ka-50), `weapons.shells.GSh_30_2K_HE` (Mi-24P).

### Cow crates

A player cow carries its loadout in crates: **Load** splits it into the `fatCowCrates` that carry each part, every crate full but the last of each kind.

```yaml
fatCowCrates:
- desc: Fat Cow fuel tank (800 gal)
  weight: 2400            # kg in the hold when full; also the crate's catalogue key
  fuelKg: 2400            # jet fuel a full crate holds
- desc: Fat Cow laser Hellfires (x20)
  weight: 906             # 20 x 45.3 kg
  item: weapons.missiles.AGM_114K
  count: 20
```

An entry has either `fuelKg`, or `item` and `count`; a part-full crate weighs its share.
The defaults are an 800 gal tank (2 400 kg); 20 laser Hellfires (906 kg), 20 radar Hellfires (980 kg), 1 200 rounds of 30 mm (600 kg); 20 Vikhr (900 kg), 460 rounds of 2A42 HE or AP (391 kg each); 16 Ataka (792 kg), 16 Shturm (566 kg), 500 rounds of GSh-30 (425 kg).
Every default loadout fits in 5 to 8 crates; a loadout that would exceed the aircraft's `maxCratesOnboard` (8 for the CH-47F) is refused, and so is one carrying an item no crate carries.
**Request a crate** brings one full crate at a time.
Cow crates never show in **Request Equipment** nor in **Unpack Crate**.

## Placing an AI cow in a mission

A player can request an AI cow from anywhere, on the ground or in the air: it comes airborne from the friendly logistic zone on land nearest to the requester, and goes back there to despawn.
The flight then commands it from F10 (Land here, Take off, Hold here, Join us, RTB): a player flight's cow never moves on its own.
To give a flight its cow from the start instead, place the cow in the Mission Editor and declare it:

1. Place a **CH-47F** group, **late activation** ticked, where the cow should start (usually the flight's base).
   Its first waypoint is a take-off from the ground; it needs no other waypoint.
2. Declare it, with the group it escorts:

```yaml
fatCowAICows:
- group: Fat Cow Gunfighter      # the CH-47 group, exact name
  escort: Gunfighter             # the flight it escorts, exact group name
  loadout: 2                     # optional: the fatCowLoadouts entry it carries, 1 by default
```

CTLD activates the cow as soon as the escorted group is in the world: at mission start for an AI flight, or when the first player takes a slot of a client flight.
If the escorted flight is an AI flight, the cow lands next to the leader when it lands, deploys after `fatCowDeployDelay`, packs and follows when the leader takes off, and flies back to where it started once empty: an AI flight cannot use the menu.
If it is a client flight, its players command the cow from F10, as a requested one.

At start, CTLD logs what DCS reports for the warehouse of the mission's FARPs (`FARP warehouse '<name>': jet fuel …`): a measurement before **FARP status** covers every FARP, and not only Fat Cow ones.

This declaration is the contract the VEAF Mission Creation Tools rely on to add a cow escorting a named flight: a late-activated helicopter group, and one `fatCowAICows` entry `{ group, escort, loadout }` (`loadout` optional).
CTLD never recognises a cow by its name.

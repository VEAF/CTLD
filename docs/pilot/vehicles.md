# Vehicles

Some transport aircraft can carry a **whole ground vehicle** — a HMMWV, a fuel truck, an AAA
piece — instead of breaking it down into [crates](crates.md). You still fly it to where it is
wanted and set it down, but there is no assembly step at the far end: the vehicle drives off ready
to fight.

Whole-vehicle carry is a capability of the airframe. Only aircraft the mission enables for it (the
`canTransportWholeVehicle` capability) show the vehicle menus below. Everything else — including the
UH-1H — moves vehicles the crate way instead: [pack them into crates](pack.md), sling or menu-load
the crates, and unpack at the destination. See [Crates](crates.md).

Vehicles you can carry have to already be on the ground near you — placed by the mission maker, or
[unpacked](crates.md) from crates you delivered. There is no F10 action that conjures a vehicle out
of the air at a logistics zone; **Request Equipment** always hands you crates, never a finished
vehicle.

## Load a vehicle (menu)

**Utility:** Picks up a nearby ground vehicle whole, so you can fly it out without packing it into
crates first.

**How it works:** Land within `maximumDistancePackableUnitsSearch` (default 200 m) of the vehicle.
CTLD lists the vehicles you can lift — filtered to your coalition and to the types your airframe is
cleared for (`loadableVehiclesRED` / `loadableVehiclesBLUE`). Pick one and it is loaded virtually:
the vehicle disappears from the map, its weight is added to your aircraft, and it rides with you
until you unload it. You must be on the ground to load — try it in the hover and you get **"Land to
load vehicles"**. How many vehicles you can carry at once is capped per airframe by
`maxWholeVehiclesOnboard` (default 1); at the limit you get **"Cannot load more vehicles (%1/%2)."**

**Activation:** F10 → CTLD → **Vehicle Commands** → **Load / Extract Vehicles** → *[vehicle name]*
(requires landing; the submenu is greyed out in the air and shows **"No vehicles nearby"** when none
are in range).

## Load a vehicle (dynamic cargo)

**Utility:** Lets a C-130 or Il-76 swallow a vehicle through the cargo ramp the way DCS handles its
own dynamic cargo — no menu click needed.

**How it works:** Drive the vehicle into the aircraft's cargo bay. CTLD watches the bay's bounding
box; when the vehicle is inside it is loaded automatically and DCS manages the weight natively (the
per-airframe count and weight limits above do **not** apply to this path). Unload happens the same
way in reverse — the vehicle reappears on the ground when it leaves the bay.

**Activation:** Automatic when the vehicle enters the cargo bay. Only C-130 / Il-76-class airframes
(dynamic-cargo capable) use this path; other capable transports load via the menu above.

## Unload a vehicle

**Utility:** Sets a carried vehicle back down where you are.

**How it works:** For a menu-loaded vehicle, CTLD re-spawns it on the ground near the aircraft under
its original name. For a dynamic-cargo vehicle, it drives back out of the bay. Either way the vehicle
returns ready to be re-loaded later.

**Activation:** F10 → CTLD → **Vehicle Commands** → **Unload Vehicles** → *[vehicle name]* (requires
landing; airborne with a vehicle aboard shows **"Land to unload vehicles"**, and the submenu is
hidden entirely when nothing is loaded). To drop a vehicle by air instead, see [Parachute](parachute.md)
— **Parachute Vehicle** appears in the same menu when you are airborne with a vehicle loaded.

## Pack a vehicle into crates

**Utility:** Turns a ground vehicle back into crates so any transport — including aircraft that
cannot carry whole vehicles — can move it. This is the reverse of unpacking.

**How it works:** Land near a packable vehicle (within `maximumDistancePackableUnitsSearch`, 200 m).
The vehicle is removed and its `cratesRequired` crates appear around you: in the **front** sector
(±45°) for a helicopter, in the **rear** sector for a C-130 / Il-76. From there, move the crates by
sling-load or menu and [unpack](crates.md) them at the destination. Packing is available only when
the mission enables it (`enablePackingVehicles`).

**Activation:** F10 → CTLD → **Crate Commands** → **Pack Equipt** → *[vehicle name]* (appears on the
ground when a packable vehicle is nearby). See also [Pack](pack.md).

## For mission makers

Which aircraft can carry whole vehicles, which vehicle types each may lift, how many at once, and
their weights are all set in the aircraft capability configuration. See the
[crates catalogue](../mission-maker/crates-catalogue.md).

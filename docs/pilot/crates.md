# Crates

Crates are the workhorse of CTLD logistics. You request a crate at a friendly logistics
zone, carry it to where it is needed, and unpack it into a vehicle, an air-defence system,
or a FARP/FOB structure. This page covers the crate actions you drive from the cockpit —
loading, dropping, unpacking, listing and packing.

Everything lives under **F10 → CTLD → Crate Commands**. What you can pick up, spawn and
assemble comes from the crate catalogue your mission maker configured — see
[Crate catalogue](../mission-maker/crates-catalogue.md).

## Menu visibility — ground vs airborne

The **Crate Commands** submenu is context-sensitive: entries appear or disappear
automatically depending on whether you are on the ground or in the air, and on your
aircraft's capabilities. You never see an action you cannot use right now.

| State | Visible entries |
| --- | --- |
| **On the ground** | Load Crate · Drop Crate(s) · Unpack Crate · List Nearby Crates · Pack Equipt |
| **Airborne** | Parachute Crates · Release Slingload · Cut Slingload |

- **Load Crate** appears only when your mission uses menu-based loading. If your mission
  relies on hover pickup instead, you load by hovering — see [Sling-load](slingload.md).
- **Pack Equipt** appears only when there is a packable vehicle or FARP scene nearby.
- **Parachute Crates** appears only when your aircraft can air-drop and you actually have
  CTLD crates on board — see [Parachute](parachute.md).
- **Release Slingload** and **Cut Slingload** appear only when your aircraft can sling-load
  and a virtual sling-load is active — see [Sling-load](slingload.md).

## Load Crate

**Utility:** Attaches a nearby crate to your transport so you can carry it.

**How it works:** Land next to the crate. Crate Commands lists every crate type within
50 m, grouped by kind with a count (e.g. `M1043 HMMWV Armament (2)`). Pick a type and the
nearest matching crate is loaded, up to your aircraft's `maxCratesOnboard` capacity. If
nothing is in range you see `No crates within 50m`; if you are airborne you are told to
land first.

**Activation:** F10 → CTLD → Crate Commands → Load Crate → *[crate type]*

> Menu loading is one of two pickup methods. The other is hover pickup (fly a steady hover
> over the crate), covered in [Sling-load](slingload.md).

## Drop Crate(s)

**Utility:** Sets every CTLD crate you are carrying back down on the ground.

**How it works:** On the ground, this unloads all CTLD-managed crates on board at once,
spread out in front of the aircraft. You are told how many were dropped and at what clock
position. If you are airborne you are told to land first; if you carry nothing you are told
there is nothing to drop.

**Activation:** F10 → CTLD → Crate Commands → Drop Crate(s)

## Unpack Crate

**Utility:** Consumes a complete set of crates and deploys its contents — a vehicle, an
air-defence system, or a FARP/FOB structure.

**How it works:** On the ground, Crate Commands lists every crate set within 300 m that has
enough crates to assemble, showing progress as `count/required` (e.g. `2/3`). Selecting an
entry destroys the crates and spawns the vehicle a short distance away. Some kinds need
several crates of the same type (`cratesRequired`); until you have gathered enough, the set
shows as incomplete and cannot be unpacked. If no set is complete you see
`No complete crate sets nearby`.

**Activation:** F10 → CTLD → Crate Commands → Unpack Crate → *[crate set]*

**Conditions:** On the ground, with the required number of matching crates within 300 m.

## List Nearby Crates

**Utility:** Prints a readout of every crate within 300 m without touching anything.

**How it works:** Crates are grouped by type and shown as `count/required`, flagged
`READY` when a set is complete or `incomplete` when it is not — a quick check of what you
can unpack before you commit. If there is nothing in range you see `No crates within 300m`.

**Activation:** F10 → CTLD → Crate Commands → List Nearby Crates

## Pack Equipt

**Utility:** Turns a deployed vehicle or FARP scene back into crates you can carry away.

**How it works:** On the ground, Pack Equipt lists packable vehicles and FARP scenes near
you; picking one converts it back into the right number of crates on the ground. The
submenu is hidden when nothing packable is nearby.

**Activation:** F10 → CTLD → Crate Commands → Pack Equipt → *[vehicle or FARP]*

> Packing has its own page covering vehicles and FARP/FOB scenes in detail — see
> [Pack](pack.md). Requesting and loading whole vehicles is on [Vehicles](vehicles.md).

## Airborne actions

These appear once you are flying, and only if your aircraft supports them:

- **Parachute Crates** — air-drops every CTLD crate on board by virtual parachute. See
  [Parachute](parachute.md).
- **Release Slingload** / **Cut Slingload** — drop or jettison a crate you picked up by
  hover. See [Sling-load](slingload.md).

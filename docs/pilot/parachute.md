# Parachute

Sometimes you cannot — or do not want to — land. The zone is hot, the terrain is bad, or
you are simply moving too fast to bother setting down. The parachute drop lets you deliver
crates, troops and vehicles while still in the air: overfly the drop point, pull the right
F10 entry, and CTLD floats the cargo down for you.

## Utility

A parachute drop is a **fly-over delivery**. Anything you are carrying — CTLD crates, embarked
troops, or a loaded vehicle — leaves the aircraft the instant you trigger the drop and settles
onto the ground a few seconds later, offset ahead of and around your track. Use it to resupply
a contested position, insert infantry without exposing the helicopter to a hover, or seed
equipment across an area from altitude.

The delivery is *virtual*: for helicopters CTLD computes where the cargo lands and places it
there after a short descent, so you will not see a 3D canopy under the aircraft. (Some
fixed-wing transports use the DCS native parachute instead, with a real animated canopy — see
[How it works](#how-it-works).)

## How it works

When you trigger a drop, each item is removed from the aircraft immediately and scheduled to
touch down after a simulated descent. The landing point is not straight below you:

- **Inertia** carries the cargo forward along your flight path — the faster you are flying,
  the further ahead it lands.
- **Lateral drift** scatters each item by a random distance and direction, so an 8-man squad
  lands spread around the drop zone rather than stacked on one spot.

Higher and faster means a longer, more scattered fall; low and slow drops tighter. Plan your
run so the computed footprint falls where you want it.

Two things are worth knowing before you drop:

- **Altitude gate.** Each payload type has a minimum height above ground. If you trigger a drop
  below it, the action is refused and you get an on-screen message
  (`Altitude too low for parachute drop. Minimum: <n>m AGL (current: <n>m AGL)`); the cargo
  stays onboard. Climb and try again. The exact minimums are set by the mission maker — see the
  [Mission Maker guide](../mission-maker/index.md).
- **Crates auto-assemble on landing.** When several crates of the same vehicle land close
  together, CTLD unpacks them automatically into the finished vehicle at the centre of the
  group — no ground crew and no F10 unpack step needed. Drop the full set of crates over the
  same point and the vehicle builds itself where they land.

For fixed-wing transports such as the C-130, Il-76 and Hercules, crates use the **DCS native
parachute** instead: load them, climb to drop altitude, and use the aircraft's own DCS
parachute function (not the CTLD menu). DCS animates a real canopy and CTLD claims the crates
when they touch down. Which aircraft behave which way is a mission-maker setting.

> **DCS native cargo cannot be parachuted from the CTLD menu.** Crates loaded through the DCS
> standard cargo UI (rather than the CTLD **Load Crate** menu) are excluded from **Parachute
> Crates**. This is a DCS limitation — there is no way to free an aircraft cargo slot in
> flight. If you intend to parachute crates, load them via the CTLD F10 menu. See
> [Crates](crates.md).

## Activation

Parachute entries live under the **F10 → CTLD** menu and appear only when three conditions are
met at once:

1. your aircraft type is cleared for parachute drops (a mission-maker setting),
2. you are **in flight** (they vanish on the ground), and
3. you actually have the matching cargo onboard.

When those hold, up to three entries become available:

| Menu path | Drops |
| --- | --- |
| **F10 → CTLD → Crate Commands → Parachute Crates** | All CTLD-loaded crates (crates in an active virtual sling-load are excluded) |
| **F10 → CTLD → Troop Commands → Parachute Troops** | Your embarked troops |
| **F10 → CTLD → Vehicle Commands → Parachute Vehicle** | The loaded vehicle |

**Multiple troop groups onboard.** If you are carrying more than one troop group, **Parachute
Troops** becomes a submenu:

- **Parachute All** — drops every group in one pass.
- **[1] <group>**, **[2] <group>**, … — drops one named group at a time.

Each group still lands with its own inertia and scatter.

Related cockpit operations: [Troop transport](troop-transport.md) ·
[Crates](crates.md) · [Vehicles](vehicles.md) · [Sling-load](slingload.md). For altitude gates,
descent rates, drift tuning and per-aircraft enablement, see the
[Mission Maker guide](../mission-maker/index.md).

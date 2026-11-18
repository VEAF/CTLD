# ADR 0029 — Dropped groups act on their own by default; the unpack guard stays optional

**Date:** 2026-11-18
**Status:** Accepted
**Lot:** `FIX-LEGACY-MOVE-AND-DEPLOY-SETTINGS` (issue #309).

## Context

Two CTLD v1 settings had no key in CTLD 2: `maximumMoveDistance` and `minimumDeployDistance` (reported by VMCT, whose missions set them to 100 m on 28 parts and 50 m on 25 parts).
Reading the legacy source showed that neither was only a missing key; both behaviours were gone.

- **A dropped group acted on its own in v1.** Every group unloaded or spawned by a script (troops, and whole vehicles) went for the nearest enemy within `maximumSearchDistance` (4000 m), and with none in range walked to a random point within `maximumMoveDistance` (2000 m) of where it was dropped. In CTLD 2 it stayed where it was dropped, unless a waypoint zone or a task of its template said otherwise. No decision had retired this; the documentation of `maximumSearchDistance` even described the v1 behaviour, and the catalogue default had slipped from 4000 to 3000 without a note.
- **Unpacking was guarded in v1.** No crate could be unpacked in a friendly logistic zone, nor within `minimumDeployDistance` (1000 m) of its centre. In CTLD 2 only the FOB keeps a guard of its own (`fobMinDistanceFromZones`).

The project rule is legacy parity: identical in-game behaviour unless a deviation is explicitly requested. For the first behaviour nothing had requested the deviation. For the second, the maintainer wants CTLD 2's absence of blocking kept unless a mission maker asks for it.

## Decision

1. **A dropped group acts on its own by default, as in v1.** The behaviour applies to every dropped group: troops and whole vehicles, dropped on the ground, by fast-rope, by parachute, by an AI transport, or spawned by a mission script. A waypoint zone, or a task the troop template declares, keeps priority over it. Setting both distances to 0 leaves the group where it was dropped; there is no separate switch.
2. **`maximumMoveDistance` is a setting again** (2000 m), and the default of `maximumSearchDistance` goes back to its v1 value, 4000 m.
3. **The deprecated `ctld.spawnGroupAtTrigger` and `ctld.spawnGroupAtPoint` keep the v1 meaning of their last argument**, the enemy search distance, through a new optional parameter of the v2 methods. The v2 methods keep their own `radius`, the placement circle.
4. **The unpack guard is optional.** A boolean setting `forbidUnpackInLogisticZone`, off by default, forbids unpacking an ordinary crate (vehicle, AA system, a parachuted crate unpacking by itself) inside a friendly logistic zone. A numeric distance around the zone's centre was dropped: the zone's own extent is enough, and a centre is ambiguous for a zone anchored to a moving unit. The FOB and the scenes keep their own rules. A snapshot that still carries `minimumDeployDistance` gets a start-up notice naming the new setting.

## Alternatives considered

- **Declare the dropped-group behaviour retired.** Keeps CTLD 2 as it shipped, but breaks parity for a behaviour nobody decided to remove, and leaves a documented setting that does nothing.
- **Restore it behind an option, off by default.** No existing v2 mission would change, at the cost of a deliberate parity deviation. Rejected for the dropped groups (the maintainer chose parity), accepted for the unpack guard.
- **A numeric `minimumDeployDistance`, as in v1.** Exact parity when enabled, but it needs a defined centre and a second criterion next to the zone test. Rejected for the boolean.

## Consequences

- A CTLD 2 mission that relied on dropped groups staying put changes behaviour at the next release: it must set both distances to 0. This is stated in the changelog and in the settings' descriptions.
- A vehicle unloaded from a transport now drives away unless a waypoint zone orders otherwise, which can take it out of the 200 m in which it can be loaded or packed again, as it did in v1. JTAC vehicles are not exempt.
- The catalogue gains two keys (`maximumMoveDistance`, `forbidUnpackInLogisticZone`), so its version goes up and its shape is recorded; `ctld-tools` offers both.
- `minimumDeployDistance` is not read: the start-up notice replaces it, as `dropOffZones` does.

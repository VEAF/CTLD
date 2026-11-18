# FIX-LEGACY-MOVE-AND-DEPLOY-SETTINGS — dropped groups stay put, and crates unpack next to a logistic zone: two CTLD v1 behaviours are gone

**Status:** ✅ done (PR #315) — decisions taken in the grill of 2026-11-18, recorded in [ADR 0029](../../dev/adr/0029-dropped-groups-act-alone-and-the-unpack-guard-is-optional.md) and the `Dropped group` term of `CONTEXT.md`.

GitHub issue #309 (reported by VMCT).

## Problem Statement

VMCT's missions set two CTLD v1 settings, `maximumMoveDistance` (100 m on 28 of its parts) and `minimumDeployDistance` (50 m on 25 of them), and found no key for either in CTLD 2. The issue takes it for a missing key. Reading the legacy source shows that **the behaviours are gone too**:

- **A dropped group acted on its own in v1.** Every group unloaded from a transport or spawned by a script — troops, and whole vehicles — went for the nearest enemy within `maximumSearchDistance`, and with none in range walked to a random point within `maximumMoveDistance` of where it was dropped. In CTLD 2 it stays where it was dropped, unless a waypoint zone or a task its template declares says otherwise. No decision retired this: the documentation of `maximumSearchDistance` still describes the v1 behaviour ("deployed AI troops search for enemies"), and the catalogue default slipped from 4000 m to 3000 m without a note.
- **Unpacking was guarded in v1.** No crate could be unpacked inside a friendly logistic zone, nor within `minimumDeployDistance` of its centre. In CTLD 2 only the FOB keeps a guard of its own.

A mission maker who moves over to CTLD 2 loses both rules **without a word**: a snapshot that still carries the two keys is simply ignored.

## Solution

- **A dropped group acts on its own by default, as in v1.** The troops a pilot drops, a whole vehicle he unloads, a group a script spawns, whatever the way down (ground, rope, parachute, an AI transport), goes for the nearest enemy in range, and walks at random when there is none. A waypoint zone or a template task keeps priority. Setting both distances to 0 leaves the group where it was dropped.
- **`maximumMoveDistance` is a setting again** (2000 m), and `maximumSearchDistance` goes back to its v1 value (4000 m).
- **The deprecated scripted spawns keep the v1 meaning of their last argument**, the search distance.
- **A new option, `forbidUnpackInLogisticZone`**, off by default, forbids unpacking an ordinary crate inside a friendly logistic zone. Off keeps CTLD 2's absence of blocking.
- **A snapshot that still carries `minimumDeployDistance` is told**, at start-up, which setting replaces it.

## User Stories

1. As a pilot, I want the troops I drop to go for the nearest enemy, so that they fight without my ordering them.
2. As a pilot, I want troops with no enemy in range to wander near the drop point, so that they are not sitting targets on the landing spot.
3. As a pilot, I want the same behaviour for troops dropped by fast-rope or by parachute.
4. As a pilot, I want a whole vehicle I unload to act on its own, as in v1.
5. As a pilot, I want a troop template with its own task (go to the nearest waypoint zone, attack the nearest enemy in sight) to keep following it, so that mission makers' choices are not overridden.
6. As a pilot, I want troops dropped inside a waypoint zone to march to its centre, as today.
7. As a pilot, I want troops dropped into an extraction zone to count for its objective, as today.
8. As a mission maker, I want `maximumMoveDistance` in my configuration, so that I can set how far dropped groups wander (VMCT: 100 m).
9. As a mission maker, I want `maximumSearchDistance` at its v1 value by default, so that a v1 mission behaves the same.
10. As a mission maker, I want to keep my dropped groups where they are dropped by setting both distances to 0, so that I can have CTLD 2's old behaviour.
11. As a mission maker, I want the two settings described in `ctld-tools`, in English and French, with that tip, so that I find them.
12. As a mission maker, I want the scripted `ctld.spawnGroupAtTrigger` / `ctld.spawnGroupAtPoint` to take their last argument as the enemy search distance, as in v1, so that my scripts are unchanged.
13. As a mission maker calling the CTLD 2 spawn methods directly, I want `radius` to remain the placement circle, so that my calls do not change meaning.
14. As a mission maker, I want a way to forbid unpacking crates inside a friendly logistic zone, so that equipment is built where it is needed (VMCT, 25 parts).
15. As a mission maker, I want that option off by default, so that CTLD 2 does not start blocking unpacking on its own.
16. As a pilot refused an unpack in a logistic zone, I want the v1 message "You can't unpack that here! Take it to where it's needed!".
17. As a mission maker, I want the option to also stop a parachuted crate from unpacking by itself in a logistic zone, so that the rule has no back door.
18. As a mission maker, I want the FOB and the FARP scenes to keep their own rules, so that nothing else changes.
19. As a mission maker whose snapshot still carries `minimumDeployDistance`, I want a start-up notice naming `forbidUnpackInLogisticZone`, so that I know CTLD 2 no longer reads it.
20. As a mission maker, I want the migration guide to cover the two v1 settings, so that I know what each became.
21. As a mission maker, I want the changelog to say that dropped groups now act on their own, so that I am not surprised by the release.
22. As a VMCT maintainer, I want to set `maximumMoveDistance: 100` and `forbidUnpackInLogisticZone: true` to get my v1 behaviour back.
23. As a CTLD developer, I want the behaviour decided at one place for every way a group reaches the ground, so that none is forgotten.
24. As a CTLD developer, I want tests that fail when a dropped group stays idle with an enemy in range.
25. As a CTLD developer, I want the catalogue's new version and shape recorded, so that `ctld-tools` completes older configurations.

## Implementation Decisions

- **One decision point for the behaviour of a dropped group.** The order a dropped group receives (toward the nearest enemy in range, else toward a random point near where it was dropped) is worked out in one place that every drop path calls: the drop by the pilot, by fast-rope and by an AI transport, the parachute landing, the vehicle unload, and the scripted spawns. Priority: a waypoint zone first, then a template task, then this default.
- **The default follows v1.** The nearest enemy is the nearest alive leader of an enemy ground group within `maximumSearchDistance` of the drop point, with **no line-of-sight requirement**. With none, the destination is a random point within `maximumMoveDistance` of the drop point, in the horizontal plane. The route is two waypoints, off road, as v1 ordered it. Both distances at 0 give no order.
- **Vehicles.** A whole vehicle unloaded from a transport gets the same behaviour, a JTAC vehicle included (v1 parity, no exception). A vehicle that comes out of a crate being unpacked does not (v1 did not move it either).
- **Scripted spawns.** The CTLD 2 methods gain a new optional search-distance parameter; `nil` means `maximumSearchDistance`. The deprecated `ctld.*` wrappers pass their last argument through it (a negative value counts as 0). The methods' own `radius` stays the placement circle.
- **Settings.** `maximumMoveDistance` (2000, metres) and `forbidUnpackInLogisticZone` (boolean, false) join the catalogue; `maximumSearchDistance` goes from 3000 to 4000. The catalogue version goes up and its shape is recorded. The schema of `ctld-tools` gets both new settings (label and description in English and French, unit, group) and the clarified description of `maximumSearchDistance`, with the "both at 0" tip.
- **The unpack guard.** When `forbidUnpackInLogisticZone` is on, the menu unpack of an ordinary crate (vehicle, AA system) and the automatic unpack of a parachuted equipment crate are refused inside a friendly logistic zone, with the v1 message (its translations exist and come back to life; the Korean one is checked). The FOB and the scenes keep their own rules. It reuses the zone test the FOB guard already uses.
- **The retired key.** `minimumDeployDistance` in a snapshot produces a start-up notice, built the way the `dropOffZones` one is.
- **Documentation.** The settings tables (EN and FR), the migration guide (EN and FR), the changelog.

## Testing Decisions

- A good test observes the order a dropped group receives (or none) and what an unpack does, not how the code is organised.
- **Seams.** The troop manager's functional specs, with the transport, the zones and the object registry doubled and the random source stubbed (prior art: the drop and the post-spawn task cases). The vehicle spawner's unload and its specs. The crate manager's unpack specs, the same ones that carry the FIX-UNPACK cases. The configuration specs for the retired-settings notice (prior art: `dropOffZones`). The catalogue shape test of `ctld-tools`.
- **Cases:** an enemy in range gets the group ordered toward it; none in range gives a random destination within `maximumMoveDistance`; both distances at 0 give no order; a waypoint zone and a template task keep priority; a pilot's drop, a fast-rope drop, a parachute landing and a scripted spawn each behave so; a whole vehicle and a JTAC vehicle too, a crate-unpacked vehicle not; the legacy wrappers pass the search distance (0 means no search), the CTLD 2 methods keep `radius` as the placement circle; the guard refuses in a logistic zone with the message, is off by default, spares the FOB and the scenes and binds the automatic unpack; the notice appears for `minimumDeployDistance`.
- **Live check in DCS** (last ticket): a mock transport 3 km from the player drops a group with an enemy group in range, then one with none; the first gets a route to the enemy, the second moves within `maximumMoveDistance`.

## Out of Scope

- Any other legacy setting.
- The behaviour of vehicles spawned from crates.
- The logic of the AI drop zones.
- The DCS-native cargo path.
- A master switch to turn the behaviour off (both distances at 0 does it).

## Further Notes

- VMCT's `minimumDeployDistance` of 50 m never mattered in v1: the logistic zone's own 200 m radius always dominated it, so their effective rule was "not inside the zone", which is exactly `forbidUnpackInLogisticZone`.
- The default behaviour of dropped groups changes in this release for every CTLD 2 mission; a mission that relied on groups staying put sets both distances to 0. The changelog and the settings' descriptions say so.
- The author of the issue must be told what each key became.

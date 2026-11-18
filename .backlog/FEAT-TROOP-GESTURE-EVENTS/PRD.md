# FEAT-TROOP-GESTURE-EVENTS — four troop gestures publish no event

**Status:** ⬜ ready — no open decision.

GitHub issue #308 (reported by VMCT, 2026-11-18), decided with the maintainer on 2026-11-18 on the recommendation below.

## Problem Statement

A layer that follows what players do with troops (VMCT, for instance: a troop drop counts in its scoring and keys the JTAC fire) subscribes to CTLD's events. For troops, only one gesture speaks: the **parachute drop** (`OnTroopsDeployed`, `OnTroopsParachuteLanded`).

Four gestures publish nothing:

- **dropping a troop group** on the ground, by fast-rope, or into an extraction zone;
- **loading** troops in a pickup zone;
- **extracting** a dropped group in the field;
- **returning** troops to the pickup zone.

CTLD v1 announced all four through its callbacks (`dropped_troops`, `load_troops`, `extract_troops`, `unload_troops_zone`). The move to CTLD 2 replaced the callbacks by the event bus, so a layer that moved over loses four of its twelve gestures. VMCT wraps the four methods on its side in the meantime.

Two signs show the events were meant to exist: `OnTroopsDeployed` already carries a `trigger` field (always "parachute" today) and a `destination` with a troop zone, and the migration guide uses `OnTroopsDeployed` for "Troops landed!" as if it covered a ground drop. It does not.

The vehicle and crate gestures do have their events (`OnVehicleLoaded`, `OnVehicleUnloaded`, `OnCrateLoaded`, …). Troops are the odd one out.

## Solution

Four new events, on the model of the vehicle ones, published when the gesture really happened:

- **`OnTroopsLoaded`**: troops loaded in a pickup zone.
- **`OnTroopsUnloaded`**: a troop group dropped, with how (on the ground or by fast-rope) and where (into combat or into an extraction zone).
- **`OnTroopsExtracted`**: a dropped group picked up in the field.
- **`OnTroopsReturned`**: troops given back to the pickup zone.

They fire for AI transports as well, with no player name; a consumer tells them apart from player transports by that field. `OnTroopsDeployed` is unchanged. The migration guide says what it really covers and points at `OnTroopsUnloaded` for a ground drop.

## User Stories

1. As a mission maker, I want an event when troops are dropped on the ground, so that my script can score the drop.
2. As a mission maker, I want the event to say whether the drop was on the ground or by fast-rope, so that I can tell them apart.
3. As a mission maker, I want the event to say whether the troops went into combat or into an extraction zone, and which zone, so that I can score an objective.
4. As a mission maker, I want an event when troops are loaded in a pickup zone, so that my script can follow the stock and the load.
5. As a mission maker, I want an event when a dropped group is extracted in the field, so that my script knows the troops are carried again.
6. As a mission maker, I want an event when troops are returned to the pickup zone, so that my script can give the stock back.
7. As a mission maker, I want to tell an AI transport from a player's by the `player` field, so that my scoring counts only players.
8. As a mission maker, I want one event per group when the pilot unloads several at once, so that my count is right.
9. As a mission maker, I want no event for a gesture that was refused (no troops on board, too high to fast-rope, zone not available), so that my script never records something that did not happen.
10. As a layer author (VMCT), I want these events on the bus, so that I can remove my wrappers of the four methods.
11. As a layer author, I want the same payload shape as the vehicle events (the group, the carrier, the player, a timestamp), so that I handle them alike.
12. As a mission maker, I want the load made by the scripted API to publish too, so that scripted and menu loads look the same.
13. As a mission maker moving from v1, I want each v1 callback to have an event, so that I port every gesture.
14. As a mission maker, I want the migration guide to tell the truth about `OnTroopsDeployed`, so that I do not wait for a ground drop on it.
15. As a CTLD developer, I want each event published at the one place its gesture ends, so that the menu, the AI and the scripted paths are all covered.
16. As a CTLD developer, I want tests that fail when a gesture stays silent, so that it cannot regress.
17. As a CTLD developer, I want `OnTroopsDeployed` and `OnTroopsParachuteLanded` untouched, so that no existing consumer breaks.

## Implementation Decisions

- **Four new events, additive.** `OnTroopsLoaded`, `OnTroopsUnloaded`, `OnTroopsExtracted`, `OnTroopsReturned`. The existing troop events are not changed.
- **One shape.** Every event carries the troop group, the carrier unit's name, the player, and the time of the gesture; a zone when the gesture has one.
- **`player`** is the slot unit name of the player when the transport is player-controlled (as `OnVehiclePacked` does), and empty for an AI transport. AI transports are included.
- **`OnTroopsUnloaded`** adds the **method** (on the ground, or by fast-rope: the drop already works out which) and a **destination** shaped like the one of `OnTroopsDeployed` (into combat, or into an extraction zone, with the zone's name).
- **Loaded and Returned** carry the pickup zone when there is one.
- **Published at the end of the gesture, on success only**: the group is in transit, spawned or restored. A refusal publishes nothing.
- **Publication points**: the four troop manager methods that perform the gestures. The menu, the AI transports, "Unload All" (one event per group) and the scripted load all go through them.
- **Migration guide (EN and FR)**: its example is corrected to say that `OnTroopsDeployed` covers the parachute drop, and to use `OnTroopsUnloaded` for a ground drop.
- No translation key, no configuration or catalogue change.

## Testing Decisions

- A good test observes what is published and what is not, with which payload, not how the manager is organised.
- Seam: the troop manager's existing unit specs, which double the transport unit, the zone manager and the object registry. For each event: published once with the documented payload on success; not published on a refusal; empty `player` for an AI unit. "Unload All" with several groups publishes one event per group. The parachute events keep passing unchanged.
- The events documentation is checked by reading: the troop section lists six events, with the method that publishes each.

## Out of Scope

- Repairing `unloadTransport` and `unloadInProximityToEnemy` (see Further Notes).
- Any change to `OnTroopsDeployed` or `OnTroopsParachuteLanded`.
- Events for crates and vehicles (they exist).
- A v1 `addCallback` compatibility layer: the migration guide already sends v1 code to the event bus.

## Further Notes

While reading the code for this lot, two scripted entry points turned out to be broken independently of it: `unloadTransport` and `unloadInProximityToEnemy` call a troop manager method named `deploy`, which no longer exists (the drop is `disembark`). `ctld.unloadTransport` and `ctld.unloadInProximityToEnemy` therefore raise an error when called. Not fixed here; a separate task is opened. The scripted **load** (`loadTransport`) works and will publish `OnTroopsLoaded`.

The events are additive, so VMCT can keep its own wrappers until it has moved over.

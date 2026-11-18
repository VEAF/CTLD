# 01 — A dropped troop group is announced (`OnTroopsUnloaded`)

**Status:** ✅ done (PR #311) · **Type:** AFK

## Parent

[PRD — FEAT-TROOP-GESTURE-EVENTS](../PRD.md). Stories 1, 2, 3, 7, 8, 9, 11, 15, 16, 17. GitHub issue #308.

## What to build

When a troop group is dropped — on the ground, by fast-rope, or into an extraction zone — CTLD publishes `OnTroopsUnloaded`, on the model of `OnVehicleUnloaded`.

The event is published at the end of a **successful** drop, from the one place every drop goes through (the menu, "Unload All", the choice of a group, the AI transports). A drop of several groups at once publishes one event per group.

Payload: the troop group, the carrier unit's name, the player (the slot unit name for a player transport, empty for an AI transport), the **method** (on the ground, or by fast-rope), the **destination** (into combat, or into an extraction zone, with the zone's name) shaped like the one of `OnTroopsDeployed`, and a timestamp.

A refused drop publishes nothing: no troops on board, too high or too fast to fast-rope, the group could not be spawned.

The events documentation (EN and FR) gets the event in its troop section and its count.

## Acceptance criteria

- [ ] A successful ground drop publishes one `OnTroopsUnloaded` with the group, the carrier, the player, method "ground", destination "combat", and a timestamp.
- [ ] A fast-rope drop carries method "fast_rope"; a drop into an extraction zone carries destination "extraction zone" and the zone's name.
- [ ] "Unload All" with several groups publishes one event per group; choosing a group by index publishes one event for that group.
- [ ] An AI transport's drop publishes the event with an empty player.
- [ ] No event on a refusal (no troops, too high, too fast, spawn failure).
- [ ] The parachute events are unchanged.
- [ ] The new cases fail before the change and pass after it; the existing troop specs pass unchanged.
- [ ] `events.md` and `events.fr.md` list the event in the troop section, with the method that publishes it.
- [ ] `busted tests/ci/` green; luacheck clean; no new translation key.

## Blocked by

None - can start immediately.

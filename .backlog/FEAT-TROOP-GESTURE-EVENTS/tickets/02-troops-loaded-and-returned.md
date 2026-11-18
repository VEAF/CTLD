# 02 — Loading in a pickup zone and returning to it are announced (`OnTroopsLoaded`, `OnTroopsReturned`)

**Status:** ✅ done (PR #311) · **Type:** AFK

## Parent

[PRD — FEAT-TROOP-GESTURE-EVENTS](../PRD.md). Stories 4, 6, 7, 9, 11, 12, 15, 16, 17. GitHub issue #308.

## What to build

The two gestures that bracket a pickup zone publish an event.

- **`OnTroopsLoaded`**: troops loaded in a pickup zone, at the end of a successful load. It covers the player's menu load, the AI transports and the scripted `loadTransport`, which all go through the same place.
- **`OnTroopsReturned`**: troops given back to the pickup zone, once the stock has been restored.

Payload of both: the troop group (for a return, every group handed back, one event each), the carrier unit's name, the player (the slot unit name for a player transport, empty for an AI one), the pickup zone's name, and a timestamp.

A refused gesture publishes nothing: the zone is not available to the coalition, no stock, the aircraft cannot carry them, no troops to return.

The events documentation (EN and FR) gets both events in the troop section.

## Acceptance criteria

- [ ] A successful load in a pickup zone publishes one `OnTroopsLoaded` with the group, the carrier, the player, the zone's name and a timestamp.
- [ ] The AI load and the scripted `loadTransport` publish it too, the AI one with an empty player.
- [ ] A successful return publishes one `OnTroopsReturned` per group returned, with the zone's name.
- [ ] No event on a refusal (zone not available, stock exhausted, transport limit, no troops on board).
- [ ] The new cases fail before the change and pass after it; the existing troop specs pass unchanged.
- [ ] `events.md` and `events.fr.md` list both events in the troop section, with the method that publishes each.
- [ ] `busted tests/ci/` green; luacheck clean; no new translation key.

## Blocked by

- [01 — A dropped troop group is announced](01-troops-unloaded.md) (the shared payload conventions and the documentation section)

# FIX-TROOP-UNLOAD-TRANSPORT — the scripted troop drops call a method that no longer exists

**Status:** ⬜ ready — no open decision.

Found on 2026-11-18 while preparing FEAT-TROOP-GESTURE-EVENTS (PR #311), decided with the maintainer the same day (the v1 rules are kept).

## Problem Statement

A mission maker's script makes a transport unload its troops: a trigger that fires on arrival (`ctld.unloadTransport`), or a continuous trigger that makes an AI transport unload as soon as an enemy is in sight (`ctld.unloadInProximityToEnemy`). Both are v1 functions CTLD 2 keeps as deprecated wrappers.

Both fail on the first call: they end by asking the troop manager to `deploy` the troops, a method that no longer exists (the drop is now `disembark`). The script raises "attempt to call method 'deploy' (a nil value)" and nothing is dropped. A v1 mission that relies on them breaks without a word of explanation in the briefing.

What v1 did (the immutable reference):

- **`unloadTransport`**: no troops on board, nothing to do. Standing in a **pickup zone**, the troops go back to the zone's stock ("Dropped troops back to base"). Anywhere else, they are **dropped**.
- **`unloadInProximityToEnemy`**: an **AI** transport only; when an enemy is in sight within the distance, it drops its troops, with no zone logic.

v1 carried one troop group at a time; CTLD 2 can carry several.

## Solution

Both functions drop the troops again, with the v1 rules, for every group on board:

- `unloadTransport`: in an extraction zone the troops are dropped to the objective (as the *Disembark* menu entry does, an extraction zone coming before a pickup zone); otherwise in a pickup zone they go back to its stock; otherwise every group is dropped. No troops, or an unknown unit: nothing happens and it answers false.
- `unloadInProximityToEnemy`: an AI transport with an enemy in sight drops every group; a player-controlled transport is left alone.

The deprecated wrappers work again. The events of FEAT-TROOP-GESTURE-EVENTS follow: `OnTroopsUnloaded` for a drop, `OnTroopsReturned` for a return to the zone.

## User Stories

1. As a mission maker, I want `ctld.unloadTransport` to drop the troops of a transport, so that my arrival trigger works again.
2. As a mission maker, I want it to give the troops back to the zone's stock when the transport stands in a pickup zone, so that the stock is right, as in v1.
3. As a mission maker, I want it to drop every group on board, so that none is left in the hold.
4. As a mission maker, I want a drop inside an extraction zone to count for its objective, so that the objective flag moves.
5. As a mission maker, I want `ctld.unloadInProximityToEnemy` to make an AI transport unload when an enemy is in sight, so that my ambush trigger works.
6. As a mission maker, I want a player-controlled transport left alone by the proximity trigger, as in v1.
7. As a mission maker, I want nothing to happen, and no error, when there are no troops on board or the unit does not exist.
8. As a mission maker moving from v1, I want these two functions to keep their v1 behaviour, so that I change nothing in my scripts.
9. As a mission maker, I want the drop and the return to publish their events, so that my scoring sees them.
10. As a CTLD developer, I want a test that fails when either function raises, so that a renamed method cannot break them silently again.

## Implementation Decisions

- The troop manager's two scripted drops use the existing drop and return operations instead of the method that no longer exists: the drop of every group (`disembarkAll`) and the return to a pickup zone (`returnToTroopZone`).
- `unloadTransport` picks between them by the zone the unit stands in, extraction zone first, then pickup zone, as the *Disembark* menu entry already does.
- `unloadInProximityToEnemy` drops directly, as v1 did, whatever the zone.
- The deprecated wrappers are unchanged; they only needed their target to work. `ctld.unloadTransport` still returns nothing, as in v1.
- No new message, no translation key, no configuration or catalogue change.

## Testing Decisions

- A good test observes what is dropped, returned or published, and that nothing raises, not how the manager is organised.
- Seam: a new functional spec of the scripted drops, with the transport unit, the zone manager and the object registry doubled (the troop manager specs are the prior art). Cases: the drop, every group, the return to a pickup zone (stock restored, nothing spawned), an extraction zone before a pickup zone, no troops and an unknown unit, the deprecated wrappers; for the proximity drop: an AI transport with an enemy, none in sight, a player's transport left alone, the wrapper.
- The new cases fail before the change (the method does not exist) and pass after it; the existing troop specs pass unchanged.
- Not run in DCS: it needs a mission script calling the function; the logic is covered with doubles, and the gestures it calls were checked in game by FEAT-TROOP-GESTURE-EVENTS.

## Out of Scope

- The **vehicles** half of v1 `unloadTransport` (it also unloaded vehicles): v2 vehicles belong to the vehicle spawner, and these functions never covered them.
- Any other legacy function.
- The return value of the deprecated `ctld.unloadTransport` wrapper.

## Further Notes

The old `deploy` method was renamed `disembark` in the rewrite; its two callers were not updated. The repository history only shows the bootstrap commit, so the exact moment is not recorded.

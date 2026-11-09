# FIX-SCENE-PACK-WHILE-LAYING-OUT — packing a FARP before it has finished laying out leaves orphan objects

**Status:** ⬜ ready — no open decision.

Found while checking an observation of the live check of FIX-CREATE-BEFORE-DESTROY (2026-11-09, DCS 2.9.30.28738), decided with the maintainer the same day.

## Problem Statement

A scene (a FARP, for instance the Countryside FARP) takes 15 to 20 seconds to lay itself out: the heliport and the flags first, the trucks five seconds later, the tent, the ammunition box, then the guards, the lights, the windsock.
The scene is in the *Pack* list from its very first tick.

A pilot who packs the FARP during that window gets the crates, and the objects already in place are destroyed. The steps that have not run yet keep going: the repair truck, the tent, a guard group, the lights and the windsock appear after the pack, on the spot where the FARP was.
Nothing tracks them any more, since the scene has left the active set, so nothing ever destroys them. They stay in the mission until it restarts.

Measured in game: packed three seconds after it started, a Countryside FARP left six objects it had not yet created (a guard group, a repair truck, a tent, lights, a windsock, a shooter marker). Packed sixty seconds after, the same pack was clean: thirteen objects out of thirteen destroyed, nothing left.

The Fat Cow already guards this case for its own FARP (it stops a scene that is still deploying before packing it). The pack of a scene does not.

## Solution

Packing a scene stops it first if it has not finished laying out. The steps that have not run are never run, so the pack leaves exactly what was packed: no orphan object after it.

A scene that has finished is packed as before, and so is one already stopped.

## User Stories

1. As a pilot, I want a FARP I pack while it is still being laid out to leave nothing behind, so that no tent, truck, guard or light stays on the spot.
2. As a pilot, I want a FARP packed after it finished to behave exactly as it does today, so that I relearn nothing.
3. As a mission maker, I want no orphan object that nothing tracks, so that the mission does not accumulate groups and statics over a long session.
4. As a mission maker, I want a pack that stops a scene to leave a single WARN line in the log naming the scene, so that I can see it happened.
5. As a CTLD developer, I want the stop to live where the scene is destroyed, so that every caller of the pack is covered and none has to remember it.
6. As a CTLD developer, I want the stop to be safe when the scene is already stopped (the Fat Cow stops its own first), so that the two guards do not fight.
7. As a CTLD developer, I want a test that fails when a step runs after the pack, so that the orphan cannot come back.

## Implementation Decisions

- A scene records that it **completed** when its last step finished.
- The scene manager's destroy of a scene stops it, with a reason, when it has neither completed nor been stopped, before destroying its objects. Stopping is idempotent: a scene already stopped is left as it is.
- Every pack goes through that destroy (the FARP pack command, the Fat Cow, the other callers of the scene manager's pack), so all are covered by the one change.
- The scene's steps already honour a stop: a step scheduled for later returns at once when the scene was stopped.
- No change to the menus: the *Pack* entry still appears from the first tick. Hiding it until the scene is complete would be a user-interface change with its own decision.
- No new message, no translation key, no configuration or catalogue change.

## Testing Decisions

- A good test observes what is left in the world and which steps ran, not how the scene is organised.
- Seam: the scene execution unit spec (a model with several steps, the unit and the scheduler doubled; the scheduler holds the timer so the test decides when it fires). New cases: a scene packed while a step is still waiting never runs that step, and its objects are destroyed; the same through the pack entry point; control: a scene that finished is destroyed without being stopped.
- The Fat Cow specs, which pack scenes through doubles, keep passing unchanged.
- Live check: the Countryside FARP packed three seconds after it starts leaves nothing after sixty seconds (the diagnostic that found it).

## Out of Scope

- Hiding the *Pack* entry until the scene has finished laying out (a user-interface decision of its own).
- What a half-laid-out FARP's warehouse holds when its crates take the snapshot.
- Any other behaviour of the scenes or of the FARP pack.

## Further Notes

The observation first looked like a FARP whose guard and repair truck survive any pack. The second measurement showed it is the premature pack only.

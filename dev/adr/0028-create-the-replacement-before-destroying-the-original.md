# ADR 0028 — An action that replaces one thing by another creates the new one first, and destroys the old one only if that worked

**Date:** 2026-11-09
**Status:** Accepted
**Lot:** `FIX-CREATE-BEFORE-DESTROY` (issue #293).

## Context

Several actions turn one object into another: packing a vehicle, a FARP or a Fat Cow FARP into crates, unpacking crates into a vehicle, rearming or repairing an AA system.
Each of them destroyed the original first and asked DCS for the replacement second.
DCS can refuse a creation (a static or a group it cannot add, no position computed), and then the original was already gone: a pilot clicked *Pack*, watched his Humvee disappear and read "packed into 1 crate(s)." with neither a vehicle nor a crate left.

PRs #267 and #268 made the *message* honest about a lost original.
Both left the *order* of the operations to a separate decision, because it changes when a destructive action happens.

## Decision

**Create the replacement first. Destroy the original, and run every side effect that presupposes it is gone, only once the creation fully succeeded.**

- **All or nothing.** A batch of crates is a success only when every crate was created. If only some were, those are removed again (through the crate manager's own destroy, so `OnCrateCleared` still fires for each) and the action fails. `CTLDCrateManager:spawnCratesAllOrNothing` is the one place that does it.
- **On failure the original is untouched.** The vehicle is still there and still a registered JTAC, the FARP still open with its stock, the crates still on the ground, the damaged AA system still standing. The pilot is told the action failed and an ERROR is logged. No event announces a pack or an unpack that did not happen.
- **Non-destructive reads happen before the creation.** The warehouse snapshot of a FARP and the stock of a Fat Cow FARP need the live object, so they are taken first; the destruction follows the creation.
- **`OnVehiclePacked.cratesSpawned` is the number of crates created**, not the number requested.

## Alternatives considered

- **Keep destroy-then-create, announce what was created** (PRs #267, #268). Honest, but the original is lost for an incomplete result.
- **Accept a partial creation** (destroy the original, announce "X of Y"). Rejected by the maintainer (2026-11-09): an incomplete result is not worth the original.

## Exception

An unpack that starts a *stepped scene* (a FOB, a FARP, any scene) consumes its crates up front and the scene's objects appear over about two minutes.
The creation is asynchronous, so "create then destroy" cannot apply literally; the scene has its own failure path (`onSceneFailed`).
Keeping the crates until the scene's last step would be a different design (a deferred consume) and its own lot.

## Consequences

- A refused creation costs the pilot nothing: he can try again from a better spot.
- The AA system is respawned on top of the group it replaces for the instant before that group is destroyed; DCS accepting it is checked on the live check of the lot.
- A scene's pack splits into *capture* (the repack hook reads the live warehouse) and *destroy*, so the crates can receive the snapshot before the scene goes.
- On the success path nothing changes for the pilot: same messages, same placement of the crates (ADR 0024).

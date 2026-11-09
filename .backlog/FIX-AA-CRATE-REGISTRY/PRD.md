# FIX-AA-CRATE-REGISTRY — repairing or rearming an AA system leaves its crate behind as a ghost

**Status:** ✅ done (PR #302)

Found on the live check of FIX-CREATE-BEFORE-DESTROY (PR #300, 2026-11-09, DCS 2.9.30.28738), decided with the maintainer the same day. The faulty call predates that lot (it is in `dba0410`).

## Problem Statement

A pilot repairs a damaged AA system with a repair crate, or rearms it with a launcher crate. The system comes back and the crate's object disappears from the ground, but CTLD still lists the crate as one of its crates: it is only the DCS object that was destroyed, not the crate's entry in the registry.

A crate whose object is gone and whose state is still "spawned" is treated as on the ground (the rule is "no DCS reference: trust the state"). The consumed crate is therefore a ghost: other actions that count crates on the ground can find it again (the unpack menu, the AA assembly, the pack counts), and no `OnCrateCleared` event tells the nearby pilots' menus that it is gone.

The assembly of a new AA system does not have the problem: it consumes its crates through the crate manager, which destroys the object, removes the entry and announces it.

## Solution

Repair and rearm consume their crate the way the assembly does. Once the new system exists, the crate is destroyed through the crate manager: the object goes, the entry is removed from the registry, and `OnCrateCleared` is published (reason "destroyed") so the F10 unpack menu refreshes for the pilots nearby.

Nothing else changes: the order of the operations (the new group first, ADR 0028), the messages, the events of the repair and the rearm.

## User Stories

1. As a pilot, I want a repair crate I used to be gone for good, so that no phantom crate appears in the unpack menu or in the crate counts.
2. As a pilot, I want a launcher crate I used to rearm a system to be gone for good, so that it cannot be used a second time.
3. As a pilot nearby, I want my unpack menu to refresh when a crate is consumed by a repair or a rearm, so that I do not read a stale list.
4. As a mission maker, I want `OnCrateCleared` for the crate a repair or a rearm consumes, so that my scripts see the same event as for every other consumed crate.
5. As a CTLD developer, I want one way to consume a crate in the AA manager, so that the three paths (assemble, rearm, repair) behave alike.
6. As a CTLD developer, I want the test of a repair and a rearm to fail when the crate stays in the registry, so that the ghost cannot come back.

## Implementation Decisions

- The AA manager's rearm and repair consume their crate through the crate manager's destroy, by crate name, exactly as the assembly already does for its parts.
- The consumption stays after the creation of the new group: if DCS refuses the group, the crate is kept (ADR 0028).
- The crate's own destroy (object only) is left as it is: it is correct for the callers that want only that.
- No new message, no new translation key, no configuration change, no catalogue change.

## Testing Decisions

- A good test observes what is left in the world and what is published, not how the manager is organised.
- Seam: the existing AA manager specs in the deployment managers unit spec (a crate stand-in registered in the crate manager, a double of the group creation). New assertions on the existing success cases of a repair and of a rearm: the crate is no longer in the registry, and `OnCrateCleared` was published for it once. The refusal cases already there keep asserting that the crate stays.
- The live scenario of FIX-CREATE-BEFORE-DESTROY (checks 4.3 and 5.2) is tightened to assert the registry entry is gone, replacing the weaker "static destroyed" check and its comment.

## Out of Scope

- The guard and repair-truck groups of a Countryside FARP that survive its pack (observed once, not confirmed as a defect).
- The semantics of "on the ground" for a crate with no DCS reference.
- Any other site that destroys before creating (all handled by FIX-CREATE-BEFORE-DESTROY).

## Further Notes

Seen on the live check as two failures, "repair crate still registered" and "launcher crate still registered", while the DCS statics were gone. The unit specs of FIX-CREATE-BEFORE-DESTROY only counted calls to the crate's own destroy, which is why they passed.

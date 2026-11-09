# FIX-CREATE-BEFORE-DESTROY — an action that replaces one thing by another creates the new one first, and destroys the old one only if that worked

**Status:** ✅ done (PR #300) — live check passed 2026-11-09 (automated scenarios and a hand test by the maintainer); both decisions confirmed by the maintainer on 2026-11-09 (see "Decisions (Zip, 2026-11-09)").

GitHub issue #293 (automated review of `develop` at `1b61b10`: "Pack Vehicle" destroys the vehicle, then announces the crates *requested*,
never the crates *created*), widened by the maintainer on 2026-11-09 to every destructive situation: "Créer avant de détruire", for all of them.

Precedents: FIX-FARP-PACK-FALSE-SUCCESS (PR #268) and FIX-UNPACK-FALSE-SUCCESS (PR #267) made the *message* honest and explicitly left the
*order* of the operations to a separate decision. This lot takes that decision.

## Problem Statement

Several actions turn one object into another: a pilot packs a vehicle or a FARP into crates, unpacks crates into a vehicle, a mechanic rearms or
repairs an AA system. Each of them destroys the original first and creates its replacement second. DCS can refuse the creation (a static or a
group that cannot be added, no position computed), and when it does the original is already gone.

The pilot who clicks *Pack* next to his Humvee watches it disappear and reads "Humvee MG packed into 1 crate(s)." — there is neither a vehicle
nor a crate, and the only trace is a `WARNING` in the server log. The same holds for a FARP (its warehouse stock goes with it), a Fat Cow FARP
(its fuel and ammunition go with it), crates that unpack into nothing, and an AA system that is destroyed and fails to respawn.

Two honest messages (PRs #267, #268) tell the pilot *that* something was lost. Nothing gives it back.

The `OnVehiclePacked` event also publishes the number of crates *requested* as `cratesSpawned`: wrong by construction for any future consumer
(statistics, scoring, an external plugin).

## Solution

Every replace action follows one rule: **create the replacement first; destroy the original only once the creation succeeded.**

If DCS refuses the creation, in whole or in part, the pilot is told the action failed and **the original stays exactly where it was**: the
vehicle is still there, the FARP still open with its stock, the crates still on the ground. Nothing is lost, nothing is duplicated.

When the creation succeeds, what the pilot sees is unchanged.

## Decisions (Zip, 2026-11-09)

1. **Create before destroying**, for every action that replaces one thing by another (stated twice by the maintainer).
2. **Partial creation is all or nothing** (confirmed). If only some of the crates were created (say 1 of 2), the crates already created are
   removed again and the original is kept. The alternative — accept the partial result, destroy the original, announce "X of Y" as PR #268
   does today — was rejected: it loses the original for an incomplete result.
3. **Out of scope (confirmed): an unpack that starts a stepped scene (FOB, FARP, and every other scene), where the crates are consumed up
   front and the objects appear over about two minutes.** The creation is asynchronous, so "create then destroy" cannot apply literally; the
   scene has its own failure path (`onSceneFailed`). The ADR notes it. Keeping the crates until the scene's last step would be a different
   design (a deferred consume) and its own lot.

## User Stories

1. As a pilot, I want my vehicle to stay where it is when DCS refuses to create its crates, so that a failed pack costs me nothing.
2. As a pilot, I want to be told the pack failed and why nothing happened, so that I can try again from a better spot.
3. As a pilot, I want a successful pack to look exactly as it does today, so that I do not relearn anything.
4. As a pilot, I want a FARP I pack to stay open, with its warehouse stock, when its crates cannot be created, so that a failed pack does not erase a base.
5. As a pilot, I want the stock of a FARP I pack to travel in the crates that exist when the pack succeeds, so that nothing is lost on the way.
6. As a Fat Cow pilot, I want a Fat Cow FARP that cannot be packed into crates to stay open, so that its fuel and ammunition are not lost.
7. As a Fat Cow pilot, I want the crates a pack sets down to carry exactly the stock that was read back, so that the numbers I am told are the numbers I get.
8. As a pilot, I want crates I unpack to remain on the ground when DCS refuses the vehicle they should become, so that I can unpack again.
9. As a pilot, I want crates that unpack by parachute landing to remain when the equipment cannot be created, so that an air-dropped load is not wasted.
10. As a mechanic of an AA system, I want a system I rearm or repair to remain, damaged as it was, when its replacement cannot be created, so that a failed repair does not remove the site's defence.
11. As a mechanic of an AA system, I want the rearm or repair crate kept when the repair did not happen, so that I can use it again.
12. As a pilot, I want a crate request that created only part of the crates to leave nothing behind when the action needs all of them, so that I never carry half a vehicle.
13. As a mission maker, I want the `OnVehiclePacked` event to publish the number of crates actually created, so that my scoring counts what exists.
14. As a mission maker, I want no `OnVehiclePacked` event and no "ground unit removed" event when the pack failed, so that my scripts do not record a vehicle that is still there.
15. As a mission maker, I want a JTAC to stay registered and lasing when its pack failed, so that a failed pack does not silently cancel a laser designation.
16. As a mission maker, I want a failed action to leave a single ERROR line in the server log naming the object and the pilot's unit, so that I can find the cause.
17. As a CTLD developer, I want one shared way to create crates all-or-nothing, so that the five sites do not each reinvent the rollback.
18. As a CTLD developer, I want the ordering rule written down in an ADR, so that the next replace action starts from it.
19. As a CTLD developer, I want the snapshot and read-back steps that must see the live object to run before the creation, so that the destructive step can safely follow.
20. As a CTLD developer, I want the tests to fail when a refused creation destroys the original, so that the order cannot regress.
21. As a pilot, I want no change to the menus, the distances or the placement of the crates (ADR 0024), so that this lot is invisible when nothing fails.

## Implementation Decisions

- **The rule.** Create the replacement first. Destroy the original and run every side effect that presupposes its disappearance only after the
  creation reported full success.
- **All-or-nothing creation.** A crate batch is a success only when the number created equals the number required. Otherwise the crates already
  created are removed through the crate manager's own destroy (so `OnCrateCleared` fires for them, reason `destroyed`), and the action is a
  failure. One shared helper owns this, taking the same arguments as the existing aligned crate creation and returning the created crates, or
  nothing after the rollback.
- **Failure behaviour, common to all sites.** The original is untouched; one ERROR line is logged; the pilot reads the existing message
  "Pack failed: the crates could not be created." for the pack sites, and the message each site already has for its own refusal otherwise. The
  only new messages are the ones a site lacks; they go through the translation function, with FR/ES/KO translated for the maintainer to review.
- **Side effects move after the success point.** Vehicle pack: the JTAC deregistration, the unit's destruction and the "ground unit removed"
  event happen after the crates exist. The unit's position is captured beforehand, as today.
- **Non-destructive reads happen before creation.** FARP pack: the scene's warehouse snapshot is taken first (it needs the live warehouse),
  then the crates are created and receive the snapshot, then the scene is destroyed and removed from the active set. The scene manager's pack
  therefore splits into "capture" and "destroy". Fat Cow FARP pack: the warehouse is read back into the cow's stock before the crates are
  created; the FARP is emptied, its name freed and the piloted cow forgotten only after the crates exist.
- **Events.** `OnVehiclePacked` is published only on success, with the number of crates actually created (equal to the number required, by the
  rule above).
- **Unpack to a unit and AA system.** The crates, or the damaged group, are destroyed only once the replacement exists. For the AA system the
  replacement is created at the positions of the original, so the two overlap for the instant before the original is destroyed; DCS accepts
  that for ground units, to be confirmed on the live check. If the respawn fails, the damaged system and the repair crate remain.
- **ADR 0028** records the rule, the all-or-nothing choice, and the stepped-scene exception (decision 2). It supersedes the "own decision and ADR if
  wanted" notes of FIX-FARP-PACK-FALSE-SUCCESS.
- **Unchanged:** the placement of crates (ADR 0024), the menus, the messages of a successful action, the Fat Cow deploy (its crates are already
  consumed only once the FARP is laid out), the loading of crates and troops (no replacement is created).

## Testing Decisions

- A good test observes what the pilot reads, what is left in the world, what is logged and which events are published; it does not observe how
  an action is organised.
- Seams, highest first. (1) **The real command callbacks** with a double of the crate creation that makes none, some, or all of the crates:
  the existing pack specs (vehicle: `deploy_managers_spec`; FARP: `crate_scene_pack_placement_spec`; Fat Cow: the Fat Cow spec) — one new
  case per site "DCS refuses the creation": the original is still there, the message and ERROR are out, no event. (2) **The shared helper** on its
  own: all created → crates returned; some created → rolled back and nothing returned; none → nothing returned. (3) **The unpack and AA
  managers** with a double of the group/unit creation.
- The existing case that freezes `cratesSpawned` to the *requested* count is rewritten to the *created* count.
- Each new case fails before the change and passes after it; the success-path cases pass unchanged.
- Live check in DCS (one ticket): DCS can only be made to refuse a creation by tampering, so the check is the **success path** on each site
  (pack a vehicle, pack a FARP, pack a Fat Cow FARP, unpack, repair an AA system) and the overlap of the AA respawn.

## Out of Scope

- An unpack that starts a stepped scene (decision 2).
- Giving back an original already lost before this lot ships.
- Any change to what a successful action does, says or places.
- Fat Cow deploy, crate and troop loading.

## Further Notes

The sites, as found in `develop` at `dba0410`:

| Site | Destroyed first | Created second |
|---|---|---|
| Pack a vehicle | the vehicle (and its JTAC registration) | its crates |
| Pack a FARP scene | every object of the scene (after a warehouse snapshot) | its crates |
| Pack a Fat Cow FARP | the FARP (after a warehouse read-back) | cow crates |
| Unpack crates to a unit, by menu and by parachute | the crates | the vehicle, static or JTAC |
| Rearm / repair an AA system | the damaged group | the respawned system |

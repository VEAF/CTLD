# 01 — The Fat Cow asks the shared helper whether it is on the ground

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-FAT-COW-GROUND-TEST](../PRD.md). Stories 1 to 12. GitHub issue #295.

## What to build

The Fat Cow code asks `ctld.utils.inAir`, as the rest of CTLD does, instead of DCS's raw `inAir()`, at its three places. A landed CH-47 is then on the ground for the cow, whatever DCS's raw answer.

- **Deploying the FARP.** A cow that has landed deploys, AI or piloted. A cow really in the air is still refused with the reason "airborne".
- **Land here.** A flight whose cow is already on the ground reads "The Fat Cow is already on the ground." and the cow is not re-tasked. A cow really in the air is still sent to land.
- **Release the Fat Cow.** A landed cow stays where it is, its FARP open, with no orbit task. A cow really in the air still orbits where it stands.
- **Nothing else changes.** Messages, labels and order are unchanged, and so is the mine field scene (two raw calls of its own, out of scope). The shared helper and its threshold are not touched.
- **The tests.** The existing AI cow and piloted cow specs stub DCS's `inAir()` and the shared helper on the same flag, so they cannot tell them apart. The new cases use a unit for which they disagree, the CH-47 at rest: its raw `inAir()` says "in the air" while the helper says "on the ground".
- **The CHANGELOG** records it under *Fixed*. No text, no dictionary, no configuration key, no catalogue shape. No live check and no probe: the pull request says that DCS's behaviour for the CH-47 was not re-measured.

## Acceptance criteria

- [ ] An AI cow that has landed deploys its FARP when the delay expires, with a unit whose raw `inAir()` says "in the air" and whose helper says "on the ground".
- [ ] A piloted cow, landed, with cow crates in its hold, deploys its FARP from **Deploy the Fat Cow FARP** and the pilot does not read "The Fat Cow FARP could not be deployed.".
- [ ] **Land here** on a landed cow answers "The Fat Cow is already on the ground." and gives the cow no new landing task.
- [ ] **Release the Fat Cow** on a landed cow gives it no orbit task and leaves its FARP open.
- [ ] A cow really in the air (both answers say so) is still refused by the deployment as "airborne", is still sent to land by **Land here**, and still orbits when released.
- [ ] The new cases fail before the change, for the right reason (the landed cow is taken for airborne), and pass after it; the other Fat Cow specs pass unchanged.
- [ ] The `CHANGELOG` entry is there; no dictionary, text or configuration change.
- [ ] `busted tests/ci/` green; luacheck clean.

## Blocked by

None - can start immediately.

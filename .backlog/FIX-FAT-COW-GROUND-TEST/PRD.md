# FIX-FAT-COW-GROUND-TEST — the Fat Cow tests for the ground with DCS's raw `inAir()`, the case `ctld.utils.inAir` exists for

**Status:** ✅ done (PR #320) — decisions taken in the grill of 2026-11-18 (no ADR, no `CONTEXT.md` term).

GitHub issue #295 (found by an automated review of `develop`; the code has moved since, the analysis holds).

## Problem Statement

DCS gives every unit an `inAir()` answer. For a high-chassis helicopter such as the CH-47, which is the cow of the whole feature (`fatCowTypes` and `fatCowAIType` are both `CH-47Fbl1`), it can answer "in the air" while the aircraft sits landed and stationary. CTLD has a replacement for exactly this, `ctld.utils.inAir`: when DCS says "in the air" but the unit is below the configured `groundAglThreshold` and nearly still (under 0.5 m/s), it counts as on the ground. The helper's own header names the CH-47, and the rest of the code goes through it. This is inherited knowledge from v1, and it was not re-measured on the current DCS for this lot.

The Fat Cow code calls DCS's raw `inAir()` at three places:

1. **Deploying the FARP.** A landed CH-47 is refused with "airborne": its FARP never opens.
2. **Land here.** The guard "The Fat Cow is already on the ground." never fires for a landed CH-47, so the cow is told to land while it is on the ground.
3. **Release the Fat Cow** (not in the issue, found in the grill). A landed cow is taken for an airborne one and given an orbit task: on release it **lifts off from its open FARP** and leaves it behind. The pilot guide says the opposite: on the ground its FARP stays open, in the air it orbits there.

What a pilot sees:

- **AI cow.** The deployment timer gets "airborne". Since the previous lot (FIX-FAT-COW-DEPLOY-REFUSALS) that refusal is no longer silent: the flight reads "The Fat Cow FARP could not be deployed." and the log says the cow did not deploy because it is airborne. The defect is now visible, but the FARP still never opens, and **Take off** then **Land here** meets the same refusal.
- **Piloted cow.** The pilot's own path lets a landed CH-47 through with the shared helper, and the deployment that follows then rejects it as "airborne", which the pilot's path turns into the catch-all "The Fat Cow FARP could not be deployed.". The pilot is on the ground with his crates in the hold, and reads that the deployment failed.

The tests cannot see any of this: they stub DCS's `inAir()` and the shared helper on **the same flag**, so the two are indistinguishable. A test needs a unit for which they disagree: the CH-47 at rest.

## Solution

The Fat Cow code asks the shared helper, like the rest of CTLD, at its three places:

- a cow that has landed deploys its FARP, AI or piloted, whatever DCS's raw answer;
- **Land here** tells a flight whose cow is already on the ground so;
- **Release the Fat Cow** leaves a landed cow where it is, its FARP open, and makes only a cow in the air orbit.

A cow that is really in the air is treated exactly as before.

## User Stories

1. As a pilot whose flight's AI cow has landed, I want its FARP to open when the delay runs out, so that I can rearm and refuel.
2. As a pilot of a piloted cow, I want my landed CH-47 to deploy its FARP from the crates in my hold, so that the FARP opens.
3. As a piloted cow's pilot, I do not want to read that the FARP could not be deployed when I am on the ground and everything is in order.
4. As a pilot, I want **Land here** to tell me "The Fat Cow is already on the ground." when it is, so that I do not re-task a cow that is where I want it.
5. As a pilot, I want **Release the Fat Cow** to leave a landed cow where it is, with its FARP open, as the guide says, so that another flight can use it.
6. As a pilot, I want a cow that is really in the air to orbit where it stands when I release it, so that this behaviour is unchanged.
7. As a pilot, I want **Land here** to still land a cow that is really in the air, so that the command keeps working.
8. As a server administrator, I want an AI cow that has landed not to be logged as "airborne", so that the log does not report a problem that is not one.
9. As a maintainer, I want the Fat Cow code to ask the same question about the ground as the rest of CTLD, so that one definition of "on the ground" applies everywhere.
10. As a maintainer, I want the deployment to keep refusing a cow that is really in the air with the reason "airborne", so that the contract is unchanged.
11. As a maintainer, I want tests with a unit for which DCS's raw answer and the shared helper disagree, so that the divergence can be seen and cannot come back unseen.
12. As a maintainer, I want no new setting, text or translation, so that the catalogue, the dictionaries and the saved configurations stay as they are.

## Implementation Decisions

- **Three places go through the shared helper**: the deployment of the FARP, the **Land here** guard, and the **Release the Fat Cow** test of whether to orbit. Nothing else in the Fat Cow code changes.
- **Rejected: the two places of the issue only.** It would leave **Release the Fat Cow** making a landed cow take off from its open FARP.
- **Rejected: also the mine field scene**, which has two raw calls of its own. It is another component, not analysed here and older than this lot; if it turns out to be a problem it deserves its own lot.
- **No other behaviour changes**: a cow really in the air is refused by the deployment with the reason "airborne" as before, **Land here** still lands it, and **Release the Fat Cow** still makes it orbit. Messages, labels and order are unchanged.
- **No live probe.** The premise (DCS's raw answer for a landed CH-47) is documented in the helper and not re-measured on the current DCS; measuring it would mean spawning a parked CH-47 far from the player and removing it again, and would not change the decision: going through the helper the rest of CTLD uses is right whether or not DCS still misreports. The pull request says the DCS behaviour was not re-measured; unit tests, not a measurement, prove the fix.
- **CHANGELOG**: one *Fixed* entry under `[Unreleased]`. No text, no configuration key, no catalogue shape, no dictionary change; the pilot guide is already right.

## Testing Decisions

- **A good test** observes what the cow does and what the flight reads, with a unit that tells DCS's raw answer apart from the shared helper's.
- **Seams**: the existing AI cow spec and the existing piloted cow spec. The mock is the one the issue describes: a unit whose raw `inAir()` says "in the air" while the helper says "on the ground", the CH-47 at rest.
- **Cases, red first for the right reason** (today the cow is taken for airborne):
  - an AI cow that has landed deploys its FARP when the delay expires;
  - a piloted cow with cow crates in its hold, landed, deploys its FARP and does not read "could not be deployed";
  - **Land here** on a landed cow answers "The Fat Cow is already on the ground." and gives no new landing task;
  - **Release the Fat Cow** on a landed cow gives no orbit task and leaves the FARP open;
  - controls with a cow really in the air (both answers say so): the deployment still refuses it as airborne, **Land here** lands it, **Release the Fat Cow** makes it orbit.
- **No live DCS check**; the pull request says so.

## Out of Scope

- The two raw calls of the mine field scene.
- Re-measuring DCS's `inAir()` for the CH-47.
- Changing the shared helper or the `groundAglThreshold` setting.
- Any other Fat Cow behaviour.

## Further Notes

- One ticket is planned; the `to-issues` quiz is short.
- Since the previous lot, a landed AI cow refused as "airborne" is at least reported to the flight and logged. That is what makes this defect visible on a server: a log line "did not deploy after the delay: airborne" for a cow standing on the ground is this lot's symptom.

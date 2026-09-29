# 10 — Live validation in DCS

**Status:** 🧑 waiting-human · **Type:** HITL

## Parent

[PRD — FIX-NATIVE-CARRY-DETECTION](../PRD.md). Stories 29, 30, 36.

## What to build

Everything the lot could not verify with doubles is checked against a live mission, before the PR
opens (project rule: live tests come before the PR, not after).

1. **Automated live scenario (`auto-check` tier)** with the C-130J-30: a vehicle loaded natively,
   unloaded through the ramp, and released in flight. It records the drift actually observed, where
   DCS places the released vehicle, whether the unit stays alive and linked, and that no duplicate
   unit appears.
2. **Box consistency check (read-only, no spawn):** reads the DCS box of every native-cargo type in
   the configuration and fails when a configured hold box is not contained in it.
3. **Manual checklist, run by the user, on the C-130J-30 and the Mi-8MT:**
   - a vehicle parked under the wing or the rotor disc is **not** loaded;
   - a vehicle driven into the cargo bay is loaded, and DCS unloads it back to `WAITING`;
   - a crate parked under the wing or rotor disc is **not** detected; a crate loaded through the DCS
     cargo UI **is** (and still converts or stays native as its type is configured);
   - a vehicle released in flight is reported as a parachute release.
4. The outcome, and any adjustment it forces (hold box values, drift threshold), is recorded in the
   PRD, and the "unverified in game" list of the PRD is updated to verified or refuted.

The DCS injection goes through the runner's HTTP path, not the MCP tool. No unit is spawned near a
live player aircraft.

## Acceptance criteria

- [ ] The C-130J-30 scenario passes against a live mission, or its failures are fixed and it is
      rerun.
- [ ] The box consistency check passes.
- [ ] Every line of the manual checklist is ticked by the user.
- [ ] The PRD records the results and the status of each unverified assumption.

## Blocked by

- [04 — Native vehicle release by drift](04-native-vehicle-release-by-drift.md)
- [05 — Re-arm lock](05-native-release-rearm-lock.md)
- [06 — Transport lost without a death event](06-native-transport-lost-without-death-event.md)
- [08 — Crate detection uses the resolved box](08-crate-native-detection-hold-box.md)
- [09 — Ship tuned hold boxes](09-ship-hold-box-defaults-tuned-visually.md)

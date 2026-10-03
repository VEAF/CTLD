# FIX-PARACHUTE-TROOPS-SPAWN-FAILURE — a failed troop parachute spawn is silent

**Status:** ✅ done (PR #242)

Formalizes GitHub issue #235 (automated code review of `develop`), re-read against the current code: the
defect is still present. Lot B of the review follow-up, after `FIX-REVIEW-HYGIENE-A`.

## Problem Statement

A pilot parachutes a troop group. The load is consumed immediately (removed from the transport and the F10
menu) and the player is told "Parachuting ... landing in ~Ns". If the ground spawn then fails when the
descent timer fires (unknown unit type, country inconsistent with the coalition, engine constraint), nothing
happens: no unit on the ground, nothing in `DCS.log` on the CTLD side, no message to the player, nothing for
"Extract from field" to find. `OnTroopsParachuteLanded` is still published, with the spawn error string in its
`spawnedGroup` field, so a subscriber calling a group method on it crashes far from the cause. In a mission
this reads as "CTLD lost my troops", with no way to tell a CTLD bug from a bad template. It is the only troop
spawn path that behaves this way: all the others log at ERROR/WARNING and return.

## Solution

When the spawn fails, the failure is logged at `ERROR` with the group name, the country and the cause, the
player is told the troops were lost, the parachute visual effect is closed, and `OnTroopsParachuteLanded` is
not published. The nominal path is unchanged.

## User Stories

1. As a pilot, I want to be told when my parachuted troops could not be spawned, so that I know they are lost
   and do not wait for them.
2. As a mission maker, I want an `ERROR` line in `DCS.log` naming the group, the country and the cause, so
   that I can tell a bad template from a CTLD bug.
3. As a mission maker, I want a failed drop not to leave a dangling parachute effect, so that no visual
   artefact outlives the drop.
4. As a mission-script author subscribing to `OnTroopsParachuteLanded`, I want the event only when troops
   really landed, so that `spawnedGroup` is always a DCS group and never an error string.
5. As a pilot, I want a successful drop to behave exactly as before (group registered as extractable, template
   mirrored, JTAC lasing started, post-spawn task assigned), so that nothing regresses.
6. As a pilot, I want a failed drop not to register a phantom extractable group, so that "Extract from field"
   never offers a group that does not exist.
7. As a CTLD developer, I want a busted test that forces `coalition.addGroup` to raise, so that the failure
   path is covered.
8. As a player of any language, I want the failure message translated, so that I understand it (FR/ES/KO).
9. As a maintainer, I want the events documentation to state that the event is not published on failure
   (EN + FR), so that integrators know.

## Implementation Decisions

- In the troop manager's parachute landing timer callback, the success boolean returned by the spawn helper
  (a `pcall` pair) is kept and checked. On failure: log `ERROR`, `outTextForGroup` to the player's group
  (new key "Parachute drop failed: troops lost.", 10 s), close the drop effect (`onLanded`), return — the
  event, the `_droppedGroups` / `_droppedTemplates` registration and the post-spawn steps are skipped.
- The load is **not** given back to the transport: the issue's proposed fix reports the loss rather than
  restoring it, and restoring would change the already-announced drop semantics. Out of scope.
- Only the explicit failure (`pcall` returning false) is handled. The case "spawn reported success but the
  group is not found" keeps its current behaviour (surgical mode, not in the issue).
- No legacy parity concern: the legacy script has no equivalent spawn-failure handling to preserve; this
  adds diagnostics and removes a malformed event payload.
- New i18n key added to the dictionaries (EN/FR/ES/KO) by the build, FR/ES/KO translated.
- `OnTroopsParachuteLanded` documentation (EN + FR) states it is not published on a failed spawn.

## Testing Decisions

- A good test observes external behaviour: log lines, player message, published events, registered groups.
- Seam: the existing `tests/ci/functional/parachute_spec.lua` troop block (synchronous timer stub, stubbed
  `coalition.addGroup` / `Group.getByName`). New cases force `coalition.addGroup` to raise and assert: an
  `ERROR` log naming the failed spawn, the player message, no `OnTroopsParachuteLanded`, no registered group
  or template. Written first, seen failing (3 of 4 fail before the fix; the 4th holds because nothing is
  registered without a group).
- Existing nominal tests (distinct names, registration, template mirroring) pass unchanged.
- No live-DCS test: the failure is forced by a stub, and the change is pure error handling.

## Out of Scope

- Giving the troops back to the transport after a failed spawn.
- The "spawn succeeded but group not found" path.
- Other findings of the same review (#234, #236, #238).

## Further Notes

Source issue: #235 (found at `8d37a58`). PR references it with `Fixes #235`.

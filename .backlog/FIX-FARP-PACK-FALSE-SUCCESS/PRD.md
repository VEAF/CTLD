# FIX-FARP-PACK-FALSE-SUCCESS — packing a FARP announces "packed successfully" without checking that a crate was created

**Status:** ✅ done (PR #268)

GitHub issue #263 (automated review of `develop` at `673b064`), decided with the maintainer on 2026-10-20 (message only; the order of the
operations is unchanged).

## Problem Statement

The *Pack <scene>* command of a deployed FARP destroys every object of the scene first (`CTLDSceneManager:packScene`), then creates the
crates. The creation can produce nothing or only part of the crates (DCS refuses an object, no position was computed). The first return value
of the crate creation, which is exactly the number of crates created, is thrown away: the pilot always reads "FARP packed successfully!".
A FARP can therefore disappear with no crate at all, and the warehouse share that should have travelled in the missing crates is lost, with
no trace except a server-side log line.

## Solution

The command reads the number of crates created. None: the pilot is told the pack failed, and an ERROR is logged. Fewer than expected: the
pilot is told how many were created, and a WARNING is logged. All of them: the message does not change. The creation is still attempted
after the scene is destroyed, as today.

## User Stories

1. As a pilot, I want to be told when packing a FARP produced no crate, so that I know the FARP is lost and why nothing is on the ground.
2. As a pilot, I want to be told how many crates were created when only some were, so that I know the pack is incomplete.
3. As a pilot, I want the "packed successfully" message when every crate was created, unchanged.
4. As a CTLD developer, I want a failed or partial pack logged (ERROR / WARNING), so that the failure leaves a trace.
5. As a CTLD developer, I want the same wording style as Request Equipment, so that failures read alike.
6. As a maintainer, I want the question of creating the crates before destroying the scene left to a separate decision.

## Implementation Decisions

- `refreshPackEquiptSection`'s Pack callback keeps the first return value of the crate creation and announces by its value: 0 → failure
  message + ERROR log; below the expected number → partial message (`%1` created, `%2` expected) + WARNING log; otherwise the existing message.
- Two new messages, through the translation function, translated FR/ES/KO (proposal for the maintainer to review): "Pack failed: the crates
  could not be created." and "FARP packed: %1 of %2 crates created.".
- Unchanged: the order (the scene is destroyed, then the crates are created), the warehouse snapshot carried by the crates that exist, the
  menu refresh after the pack, the scene manager, the catalogue.

## Testing Decisions

- A good test observes what the pilot reads and what is logged, not how the command is organised.
- The existing pack spec (`crate_scene_pack_placement_spec`, prior art: the menu builder and the real command with a double of the crate
  creation): new cases with a creation that makes none, only some, or all of the crates (control).

## Out of Scope

- Creating the crates before destroying the scene (a safer order, but it changes the order of a destructive action; own decision and ADR if
  wanted).
- Giving the FARP back when the creation fails.

## Further Notes

None.

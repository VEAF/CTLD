# 01 — Stop a scene that is still laying out before destroying it

**Status:** ✅ done (PR #304) · **Type:** AFK

## Parent

[PRD — FIX-SCENE-PACK-WHILE-LAYING-OUT](../PRD.md). Stories 1-7.

## What to build

A scene records that it completed when its last step finished. The scene manager's destroy of a scene, which every pack goes through, stops the scene first when it has neither completed nor been stopped: the steps that have not run yet are never run, so nothing is spawned after the pack. A scene that finished, or that was already stopped (the Fat Cow stops its own), is destroyed as before and is not stopped twice.

The *Pack* entry, the messages and the crates are unchanged.

## Acceptance criteria

- [ ] A scene packed while a step is still waiting for its timer never runs that step, and the objects already spawned are destroyed, both through the destroy and through the pack entry point.
- [ ] A scene that finished is destroyed without being stopped; a scene already stopped is not stopped a second time.
- [ ] The new cases fail before the change and pass after it; the existing Fat Cow and scene specs pass unchanged.
- [x] Live check in DCS: a Countryside FARP packed a few seconds after it starts leaves no object (group or static) in the mission sixty seconds later, the diagnostic that found the defect on 2026-11-09. Run on 2026-11-09 with the build of the PR branch: 6 objects tracked at pack time, the scene stopped by the pack, 0 object left 60 s later (6 orphans before the fix).
- [ ] CHANGELOG `[Unreleased]` entry; `busted tests/ci/` green; luacheck clean; no new translation key.
- [ ] The lot's line in `.backlog/README.md` ("in progress") is set to `merged (PR #NN)` in this PR.

## Blocked by

None - can start immediately.

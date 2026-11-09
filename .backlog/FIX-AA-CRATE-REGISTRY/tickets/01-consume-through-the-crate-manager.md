# 01 — AA repair and rearm consume their crate through the crate manager

**Status:** ✅ done (PR #302) · **Type:** AFK

## Parent

[PRD — FIX-AA-CRATE-REGISTRY](../PRD.md). Stories 1-6.

## What to build

When a pilot repairs or rearms an AA system, the repair or launcher crate is consumed the way the assembly consumes its parts: through the crate manager's destroy, by crate name. The DCS object goes, the crate's entry leaves the registry, and `OnCrateCleared` (reason "destroyed") is published so the F10 unpack menu refreshes for the pilots nearby.

The consumption stays after the creation of the new group (ADR 0028): a refused respawn keeps the crate and the damaged system, as today. Nothing else changes: messages, repair and rearm events, order of operations.

## Acceptance criteria

- [ ] Success of a repair: the repair crate is no longer in the crate manager's registry, and `OnCrateCleared` was published once for it with reason `destroyed`.
- [ ] Success of a rearm: the same for the launcher crate.
- [ ] The refusal cases (DCS refuses the new group) still keep the crate in the registry and publish nothing.
- [ ] The new cases fail before the change and pass after it; the existing AA cases pass unchanged.
- [x] The live scenario of FIX-CREATE-BEFORE-DESTROY asserts, in checks 4.3 and 5.2, that the registry entry is gone (replacing the "static destroyed" check and its comment). Run in DCS 2.9.30.28738 on 2026-11-09 with the build of `develop` at `a88b43f`: PASS 24/24, no ghost crate, no residue left in the mission.
- [ ] CHANGELOG `[Unreleased]` entry; `busted tests/ci/` green; luacheck clean; no new translation key.
- [ ] The lot's line in `.backlog/README.md` ("in progress") is set to `merged (PR #NN)` in this PR.

## Blocked by

None - can start immediately.

Status: ready

# 01 — `_activeHandles`: decouple DCS handles from logical tree + L1 tests

## Parent

`.backlog/FIX-MENU-DOUBLE-MULTICREW/PRD.md`

## What to build

Add a `_activeHandles` field (flat array, initialized to `{}`) to `ctld.Menu`. This list tracks
the opaque top-level DCS handles currently live in DCS for the group, independently of
`menu.children`.

Migrate `refreshMenuForGroup` to use `_activeHandles` for its cleanup pass (instead of iterating
`menu.children` nodes). After the DCS rebuild, repopulate `_activeHandles` with the new top-level
handles. Add an `INFO` log line when at least one handle is removed during cleanup.

With this change, `buildMenu`'s `menu.children = {}` reset has no impact on cleanup: handles
survive in `_activeHandles` regardless of what happens to the tree model.

## Acceptance criteria

- [ ] `ctld.Menu` instances have an `_activeHandles` field initialized to `{}` at creation.
- [ ] `refreshMenuForGroup` iterates `_activeHandles` to call `removeItemForGroup` on each live
      handle before rebuilding. After rebuild, `_activeHandles` is updated with the new top-level
      handles.
- [ ] A second `buildMenu` call for the same groupId (> 0.15 s after the first) results in
      exactly one `removeItemForGroup` call (the old handle) followed by exactly one
      `addSubMenuForGroup` call (the new "CTLD" root) — verified by L1 test in
      `menu_manager_spec.lua` with mocked `missionCommands`.
- [ ] `removeItemForGroup` is NOT called on the first `buildMenu` for a fresh groupId (no prior
      handles to clean up) — verified by L1 test.
- [ ] All existing `menu_manager_spec.lua` tests remain green.
- [ ] `busted tests/ci/` passes clean.

## Blocked by

None — can start immediately.

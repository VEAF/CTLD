Status: ⬜ ready

# 01 — Unique DCS names for parachuted groups/units

## Parent

[FIX-PARACHUTE-GROUP-NAME-COLLISION PRD](../PRD.md)

## What to build

Give every parachuted troop group and its units a unique DCS object name, so that two
troop groups loaded from the same template no longer collide when spawned by
`CTLDTroopManager:parachuteTroops`.

- **Group name**: suffix the template display name with the project's existing
  unique-id generator (the same one `CTLDObjectRegistry.spawnObject` already uses for
  every other spawn path) instead of using the raw template name as-is.
- **Unit names**: derive each unit's name from the group's own resolved unique name
  plus a 1-based index (`<groupName>-<unitIndex>`), matching standard DCS Mission
  Editor unit naming — a single unique-id allocation per group, not one per unit.
- **Bookkeeping**: the coalition's live-group tracking and the per-group template-info
  map (used to restore weight/troop-count/specific-params when a dropped group is
  later field-loaded back onto a transport) must be keyed off the group's actual
  resolved name, not the raw template name — matching how every other troop-drop path
  already keys them.
- **Unaffected by construction, verify don't break**: JTAC lasing after a parachute
  spawn resolves by position within the spawned group, not by name — no logic change
  needed there, just confirm it still works after the rename.
- **Unaffected**: every player-facing message keeps showing the plain template display
  name — only internal DCS object identifiers change. `disembark()` (fast-rope/ground
  drop) is untouched.

## Acceptance criteria

- [ ] Two troop groups loaded from the same template, parachuted one after the other,
      both survive as distinct live DCS groups (no collision-driven destruction of the
      first)
- [ ] Two same-template groups + one different-template group, parachuted in sequence,
      all three survive
- [ ] Single-group parachute drop (no collision possible) behaves identically to today
- [ ] The coalition's live-group tracking and the per-group template-info map are keyed
      off the actual spawned (resolved, unique) group name, not the raw template name
- [ ] A previously-parachuted group can still be field-loaded back onto a transport with
      its original weight/troop-count/specific-params restored correctly
- [ ] JTAC unit lasing still resolves the correct spawned unit after the naming change
- [ ] Player-facing messages (drop announcement, landing confirmation) still show the
      plain template name, unaffected by the internal naming change
- [ ] New busted test in `tests/ci/functional/parachute_spec.lua` reproduces the report
      (2 same-template + 1 different-template groups parachuted in sequence, all three
      end up alive), with a local synchronous override of `timer.scheduleFunction` and
      stubs for `coalition.addGroup`/`Group.getByName` to observe the spawn calls
- [ ] All existing `tests/ci/` pass (busted)
- [ ] luacheck clean on changed files
- [ ] `CTLD.lua` rebuilt via `merge_CTLD.ps1`

## Blocked by

None — can start immediately.

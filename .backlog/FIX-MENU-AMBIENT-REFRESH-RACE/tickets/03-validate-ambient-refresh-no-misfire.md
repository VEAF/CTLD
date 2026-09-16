# 03 — Validate: no misfire during an ambient refresh (busted + live dcs-bridge)

**Status:** ⬜ ready

**Blocked by:** ticket 02.

## What changes

### Busted (`tests/ci/unit/menu_manager_spec.lua`)

Extend the existing menu manager spec (mirrors the mocked-timer pattern already used for the
flight-state poller debounce in `player_spec.lua`). Cases:

- An ambient `menu:refresh()` removes the group's root handle synchronously (assert
  `missionCommands.removeItemForGroup` called before returning), but does **not** call
  `missionCommands.addSubMenuForGroup`/`addCommandForGroup` again until the mocked timer advances
  `AMBIENT_REBUILD_DELAY_S` seconds.
- Simulating a command execution against the group's menu *during* that window finds no matching
  DCS command registered (proves a click mid-gap has nothing to resolve against — the mechanism
  ticket 02 relies on, not just its side effect).
- A second ambient `menu:refresh()` call while one is already pending does not schedule a second
  timer (assert `timer.scheduleFunction` called only once across both calls) and does not remove
  handles a second time (nothing left to remove).
- `menu:refresh({ urgent = true })` rebuilds within the same call — no timer advance needed for
  the commands to reappear.
- An urgent `menu:refresh({ urgent = true })` while an ambient rebuild is pending: the pending
  timer is cancelled (assert `timer.removeFunction` called with the stored id) and the rebuild
  happens synchronously in that same call.
- A refresh triggered synchronously from inside a simulated command callback for group G (drive
  `wrapped` the same way `_rebuildMenuNode` does — set `_activeCommandGroupId`, call `menu:refresh()`
  with no explicit `opts`) rebuilds immediately, with no timer advance — proves the automatic
  same-group detector, not just the explicit `urgent` flag.
- The same, but the refresh targets a *different* groupId than `_activeCommandGroupId` (simulating
  `_refreshNearbyPlayers` reaching a bystander mid-callback): stays ambient — proves the detector is
  scoped by group, not "any command currently executing".
- `_activeCommandGroupId` is cleared after a simulated callback that errors inside `pcall` (raise
  inside the wrapped `fn`) — a subsequent ambient refresh for that same group afterward is still
  ambient, not stuck urgent.

### Live dcs-bridge scenario (`tests/dcs/pilotActive/`)

New scenario, `-- @tier: ia` (menu — needs a human click, self-verifying otherwise), built from
`tests/dcs/_template_pilotActive.lua`. Replays this lot's own live reproduction:

1. Precondition: a BLUE transport player parked inside a TRZ with pickup stock, no troops aboard
   (mirrors the reported case — an empty transport, so the troop submenu path has no conditional
   sibling that could shift F-key numbers, ruling out the "menu reshuffled" alternative explanation
   already eliminated in this lot's investigation).
2. On-screen instruction: navigate to `Troop Commands > Embark / Extract Troops > Load from
   <TRZ name>` and stop there.
3. Scenario forces one ambient refresh for that group (the same effect `_lgzGroundPoll` has today)
   at a script-controlled instant, and instructs the player to click "Load Standard Group" as
   displayed.
4. Verdict: `PASS` if either (a) nothing happened (click during the delay window — check via
   `hasTroops`/`inTransit` state unchanged and no unexpected side effect like a spawned smoke),
   or (b) `embarkFromTroopZone` actually ran (click landed after the rebuild, correct command).
   `FAIL` if any *other* CTLD command fired (the original misfire shape — e.g. a smoke drop) or if
   troops were loaded from a mismatched zone/template.

Run via `tools/integration-runner/run_manual_scenario.py --scenario <name>` (human present for the
physical F10 click; verification itself is scripted, matching this project's "human ≠ AI judgment"
tiering rule).

`CHANGELOG.md`: no separate entry — folded into ticket 02's Fixed entry (this ticket verifies it).

## Watch out

- Don't assert on `dcs.log` text in the busted specs — assert on the mocked
  `missionCommands`/`timer` call counts and arguments, same seam the existing specs already use.
- The live scenario must reset cleanly between runs (no residual `_pendingRefresh`/timer state) —
  reuse `tests/dcs/_reset_state.lua` if running it back-to-back with other scenarios via
  `--reset-before-each`.
- Tag `ia (menu)`, not `auto`/`auto-check` — a real F10 click is required and dcs-bridge cannot
  simulate one; don't mistag it into the headless sweep.

## Acceptance

- [ ] All busted cases above pass; `busted tests/ci/` green overall.
- [ ] `luacheck --config .luacheckrc src/` clean.
- [ ] The live scenario, run manually at least once against a real mission, confirms `PASS` —
  attach the run's verdict/log excerpt to this ticket or the PR description.
- [ ] `docs/developer/subsystems/menu.md` updated to describe the ambient/urgent split (the file
  currently documents only the atomic wipe+rebuild model and the 0.15s burst debounce — both still
  true, but incomplete after this lot).

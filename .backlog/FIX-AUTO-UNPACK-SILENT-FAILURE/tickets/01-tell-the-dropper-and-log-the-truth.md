# 01 — Tell the dropper, and log the truth, when a parachuted equipment crate cannot be unpacked

**Status:** ✅ done (PR #307) · **Type:** AFK

## Parent

[PRD — FIX-AUTO-UNPACK-SILENT-FAILURE](../PRD.md). Stories 1-12. GitHub issue #294.

## What to build

When a parachuted equipment crate lands and its equipment cannot be created, the pilot who dropped it reads why, and the log stops claiming a success.

- At the drop, CTLD records on each parachuted crate the unit name of the pilot who dropped it (the *dropper*). It is empty by default and cleared when the crate is loaded again.
- On landing, the automatic unpack passes the crate's dropper as the player to the equipment creation, which already sends the DCS refusal and the JTAC-limit reason to a player that exists in the world, and does nothing for a name that does not.
- The log line "auto-unpack (parachute) EQUIPMENT" is written only when the equipment was created. Otherwise a WARNING says it was not created, the cause (the group refused by DCS, or nothing attempted) and that the crates were kept.
- A crate released by the DCS cargo system itself has no dropper: nobody is told, the WARNING is the only trace.

When the equipment is created, nothing changes.

## Acceptance criteria

- [ ] A parachuted crate records the unit name of the pilot who dropped it, and loading it again clears it.
- [ ] A group refused by DCS, and the JTAC limit, are told to the dropper with the same wording as the menu path.
- [ ] A crate with no dropper tells nobody and logs the WARNING; a dropper who left the slot never raises an error.
- [ ] The unpack INFO line is written only on success; otherwise a WARNING names the cause and says the crates were kept. The success path is unchanged.
- [ ] The new cases fail before the change and pass after it; the existing cases pass unchanged.
- [ ] CHANGELOG `[Unreleased]` entry; `busted tests/ci/` green; luacheck clean; no new translation key.
- [ ] The lot's line in `.backlog/README.md` ("in progress") is set to `merged (PR #NN)` in this PR.

## Blocked by

None - can start immediately.

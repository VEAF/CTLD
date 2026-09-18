# 03 — Take the BIRTH safety net into the manager, delete `CTLDPlayerTracker`

**Status:** ✅ done

`CTLDPlayerTracker` has never been instantiated since `CTLD_core.lua` was written on 2026-04-02
(#150). Of the three things it had that `CTLDPlayerManager` lacks, one is worth keeping.

## What changes

**`src/CTLD_player.lua`, `CTLDPlayerManager:init`** — subscribe to `S_EVENT_BIRTH` beside the
existing ENTER/LEAVE registrations, and add the handler:

```lua
function CTLDPlayerManager:onBirth(event)
```

A strict net, not a second entry point: read the name through `ctld.utils.safeObjectName`, return
if it is already tracked, return if `getPlayerName()` is nil or unreadable (AI), then delegate to
`onPlayerEnterUnit` so there is exactly one registration path. The tracker's own comment gives the
reason the net exists — *"DCS may fire S_EVENT_BIRTH before world.addEventHandler is registered"* —
and a missed ENTER means no CTLD menu until the 30 s sweep catches up.

**`src/CTLD_core.lua`** — delete `CTLDPlayerTracker` entirely: the class, its `getInstance`, `init`,
three handlers, `_scanAllSlots`, four accessors, its comment block, the module header line that
lists it, and step 2 of the initialisation order that was never written.

## Watch out

- **Delegate, do not duplicate.** `onBirth` must end in `onPlayerEnterUnit`, so the whitelist logic
  from ticket 01 and `buildMenu` are not reimplemented in a second place — that divergence is how
  the tracker came to exist in the first place.
- BIRTH fires for **every** unit in the mission, AI included, and several managers already listen
  to it. Get out early and cheaply: tracked-name check before anything else.
- A released initiator reaches this handler like any other (#151): go through
  `ctld.utils.safeObjectName` and `pcall` the player-name read, never call methods outright.
- Do not resurrect the tracker's 3-minute `_scanAllSlots`: the manager's own sweep runs every 30 s
  for the whole mission and is strictly stronger.
- Nothing references the four accessors (`getPlayerByUnit`, `getUnitByPlayer`, `getAllPlayers`,
  `isPlayerUnit`) — verified across `src/` — so deleting them breaks no caller. Check again before
  deleting rather than trusting this line.

## Acceptance

- [x] A BIRTH for a player CTLD does not track yet registers him, with a menu.
- [x] A BIRTH for an already-tracked player changes nothing (no duplicate, no menu rebuild).
- [x] A BIRTH for an AI unit is ignored.
- [x] A BIRTH with a released initiator raises nothing (both shapes from #151).
- [x] `grep -r CTLDPlayerTracker src/ docs/` returns nothing.
- [x] Specs green, `CTLD.lua` rebuilt and loading under Lua 5.1.

# FEAT-NON-TRANSPORT-PILOTS — a fighter pilot gets the CTLD functions that concern him

**Status:** 🔄 in-progress (implemented, PR pending)

Closes #150. Asked for by Fulgas and Zip: **recon works for any pilot, aircraft included**, and a
non-transport pilot has no reason to be cut off from it — nor from smoke, beacon listing or JTAC
status.

## The deviation

Two settings decide who gets a CTLD menu:

- `addPlayerAircraftByType = true` (default) — every player whose aircraft type appears in
  `capabilitiesByType` is tracked. A fighter is tracked too, with `isTransport = false`.
- `addPlayerAircraftByType = false` — `onPlayerEnterUnit` returns **before registering the player**
  for any unit name absent from `transportPilotNames` ([CTLD_player.lua:375](../../src/CTLD_player.lua#L375)).

So a setting whose purpose is to restrict **transport** menus to a named list also cuts every
function that has nothing to do with transport. In that configuration a fighter pilot has no CTLD
menu at all, therefore no recon.

### The sections already know how to do this

Measured, not assumed: **17 `isTransport` / `canCarryVehicles` guards already exist** inside the
sections. In the default configuration a fighter pilot already carries a CTLD menu in which every
transport section closes itself:

| section | for a non-transport pilot today |
|---|---|
| `troops` (2 guards), `vehicles` (5), `crates` (6), `smoke` (1), `beacons` (1), `jtac` → Request Equipment (1) | closed |
| `recon`, `jtac` → Status + per-JTAC submenus, `fobs` → List active FOBs, `minefield_demine` | open |
| `Check Cargo` (fixed command, outside any section) | open |

That is why this lot needs **no** `requiresTransport` field and no section-by-section arbitration:
`isTransport` already carries exactly the meaning "this player may use transport functions", and
seventeen places honour it.

## The fix

**`transportPilotNames` stops deciding registration and starts deciding `isTransport`.**

A player absent from the list is registered like any other, with `isTransport = false` and
`canCarryVehicles = false` **forced regardless of aircraft type** — a Huey pilot off the list must
not recover the transport menus through `_detectCapabilities`, which would defeat the setting. From
there the seventeen existing guards do the work, and the `addPlayerAircraftByType = false` case
becomes identical to the default case, which is the one flown every day.

Four menu decisions on top, taken by Zip:

1. **`smoke` opens to everyone.** Verified: `doSmoke` drops at the player's own position through
   `trigger.action.smoke`, with no dependency on any cargo. Marking a position from a fighter is
   exactly what it is for.
2. **`beacons` splits.** `List Beacons` opens to everyone — `listBeacons()` reads only coalition and
   group id, and knowing a beacon's frequency is navigation information. `Drop Beacon` and
   `Remove Closest Beacon` stay transport-only.
3. **`jtac` already behaves**: Status is open, Request Equipment carries its own guard. Nothing to do.
4. **`Check Cargo` gets the guard it never had** — it would report an empty hold to a fighter.

`recon`, `List active FOBs` and the minefield demining keep today's behaviour: open.

## Also in this lot

- **`S_EVENT_BIRTH` as a safety net on `CTLDPlayerManager`.** The manager subscribes to
  ENTER/LEAVE and LAND/TAKEOFF only. `CTLDPlayerTracker` carried a BIRTH net with the reason
  written down — *"DCS may fire S_EVENT_BIRTH before world.addEventHandler is registered"* — and it
  applies to the manager just as much: a missed ENTER means no CTLD menu until the 30 s sweep
  catches up.
- **`CTLDPlayerTracker` is deleted** (~150 lines), with its comment block and step 2 of the
  initialisation order it was never wired into. Never instantiated since 2026-04-02; its reverse
  index has no consumer, and the one comment that claimed to use it
  (`CTLDVehicleSpawner:_checkNativeLoading`) was corrected in #151.

## Definition of done

- With `addPlayerAircraftByType = false`, a pilot **off** the list is tracked, has recon, smoke,
  `List Beacons`, `JTAC Status` and `List active FOBs`, and has **no** troop, crate, vehicle,
  beacon-drop or Check Cargo entry — whatever his aircraft type, a transport type included.
- A pilot **on** the list is unchanged in every respect.
- The default configuration (`addPlayerAircraftByType = true`) is unchanged, except for the four
  menu decisions above, which apply to every non-transport pilot.
- A BIRTH for a player CTLD does not know yet registers him; a BIRTH for an already-tracked player
  or for an AI unit changes nothing.
- `CTLDPlayerTracker` no longer exists anywhere, comments included.
- Specs green, `CTLD.lua` rebuilt and loading under Lua 5.1, `CHANGELOG.md` entry, and the
  mission-maker + developer documentation updated in **both** languages.

## Testing decisions

The seam is `onPlayerEnterUnit` called with a mock unit, plus reading the built menu model — the
same seam `player_spec.lua` and `menu_gating_spec.lua` already use.

- The off-list pilot: registered, `isTransport == false`, and the menu contains recon / smoke /
  List Beacons / JTAC Status but none of the transport entries. Enumerated over all nine sections,
  not sampled — the point of the lot is *which* entries appear.
- **A transport type off the list** is the case that would silently defeat the setting: a Huey
  pilot absent from `transportPilotNames` must come out with `isTransport == false`.
- The on-list pilot, and the default configuration, unchanged (negative controls — without them a
  fix that simply removes the gate passes everything else).
- BIRTH: unknown player registered, known player not duplicated, AI unit ignored, released
  initiator tolerated (the #151 shapes).

## Out of scope

- **A new setting to restore the old "no CTLD at all" behaviour.** Every function this lot opens
  has its own global switch already (`reconF10Menu`, `enableSmokeDrop`, `enabledRadioBeaconDrop`,
  `JTAC_jtacStatusF10`). Noted in *Further Notes* as the one place where that is not quite
  equivalent.
- **The minefield demining section**, open to any pilot on the ground near a minefield, today
  included. It is the only *action* among the open entries, flagged to Zip and deliberately left
  as is.
- `transportPilotNames`' second role — the AI transport list read by `CTLDCoreManager` INIT-A
  ([CTLD_core.lua:587](../../src/CTLD_core.lua#L587)) — is untouched: this lot only changes
  `onPlayerEnterUnit`.

## Further Notes

- **This contradicts a documented guarantee**, and the documentation moves with the code: *"CTLD-capable
  aircraft **not** listed join the mission normally but have no CTLD access"*
  (`docs/mission-maker/configuration.md`). It is now "no CTLD **transport** access".
- The one place the existing switches are not equivalent: `enableSmokeDrop = false` removes smoke
  from transports too, so a mission maker who wants smoke for transports but not for fighters has
  no setting for it. Judged not worth a new key until someone asks — CTLD's configuration surface
  is already large, and the case is hypothetical.
- No ADR: the lot applies an existing mechanism (`isTransport`, honoured in 17 places) to a case
  that bypassed it, and deletes dead code.

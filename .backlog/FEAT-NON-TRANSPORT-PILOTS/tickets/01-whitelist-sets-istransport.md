# 01 — `transportPilotNames` sets `isTransport`, it no longer blocks registration

**Status:** ✅ done

See the PRD. Short version: with `addPlayerAircraftByType = false`, a pilot off the whitelist is
never registered, so he has no CTLD menu at all — and therefore no recon, which any pilot is
supposed to be able to use.

## What changes

`src/CTLD_player.lua`, `CTLDPlayerManager:onPlayerEnterUnit`:

- The whitelist block stops returning. It computes a single boolean, `transportAllowed`.
- `_detectCapabilities(unit)` still runs, and its two results are **forced to false** when
  `transportAllowed` is false:

  ```lua
  local isTransport, canCarryVehicles = self:_detectCapabilities(unit)
  if not transportAllowed then
      isTransport, canCarryVehicles = false, false
  end
  ```

- The existing INFO log stays, reworded: the pilot now gets a menu, just not the transport one.

Nothing else moves. The seventeen `isTransport` / `canCarryVehicles` guards inside the sections do
the rest.

## Watch out

- **The forcing is the whole ticket.** A Huey pilot off the list has a type present in
  `capabilitiesByType`, so `_detectCapabilities` returns `true` for him; without the override he
  recovers every transport menu and the setting means nothing. That is the case to test first.
- Do **not** touch `transportPilotNames`' other role: `CTLDCoreManager` INIT-A reads the same list
  to drive AI transports ([CTLD_core.lua:587](../../src/CTLD_core.lua#L587)), independently of
  `addPlayerAircraftByType`. This ticket only changes `onPlayerEnterUnit`.
- Do not add a `requiresTransport` field to `registerMenuSection`. It was considered and dropped:
  `isTransport` already carries that meaning and is already honoured everywhere.
- `addPlayerAircraftByType = true` must come out byte-identical — that is the path every mission
  flies.

## Acceptance

- [x] `addPlayerAircraftByType = false`, pilot **off** the list, fighter type: registered,
      `isTransport == false`, `canCarryVehicles == false`.
- [x] Same, **transport type** (UH-1H): registered, `isTransport == false` — the type does not win
      over the list.
- [x] Pilot **on** the list: `isTransport` exactly as `_detectCapabilities` computes it.
- [x] `addPlayerAircraftByType = true`: unchanged for both a transport and a fighter.
- [x] Specs green, `CTLD.lua` rebuilt and loading.

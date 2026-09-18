# 02 — Open smoke and beacon listing to every pilot, hide Check Cargo from non-transports

**Status:** ✅ done

Ticket 01 gives a non-transport pilot a menu. This one decides what is in it. Three changes, all
decided by Zip after the section-by-section review in the PRD.

## What changes

**`src/CTLD_crate.lua`, `CTLDCrateManager:buildSmokeSection`** — drop the
`if not playerObj.isTransport then return end` opening line. Verified before deciding: `doSmoke`
drops at the player's own position via `trigger.action.smoke(pos, color)` with `pos` taken from
`unit:getPoint()` and the ground height under it. It reads no cargo, no crate, no transport state.
Marking a position from a fighter is the point.

Auto-resume (`CTLDSmokeManager:toggle` / `registerSmoke`) is keyed by unit name and equally
type-agnostic — it comes along for free, no change needed.

**`src/CTLD_beacon.lua`, `CTLDBeaconManager:buildMenuSection`** — the section-level guard becomes
per command:

| command | who |
|---|---|
| `List Beacons` | everyone — `listBeacons()` reads only `getCoalition()` and the group id, and a beacon's frequency is navigation information |
| `Drop Beacon` | transport only |
| `Remove Closest Beacon` | transport only |

The submenu itself is created for everyone, since it now has a command for everyone. Keep the
`enabledRadioBeaconDrop` configKey gate on the whole section: a mission maker who turned beacons
off gets no submenu at all, as today.

**`src/CTLD_player.lua`, `_buildMenuBody`** — wrap the fixed `Check Cargo` command in
`if playerObj.isTransport then ... end`. It lists crates, troops and vehicles aboard, so it can only
ever answer "nothing" to a fighter.

## Watch out

- `jtac` needs **nothing**: `JTAC Status` and the per-JTAC submenus are already open, and
  `Request JTAC Equipment` already carries `and playerObj.isTransport`
  ([CTLD_jtac.lua:1657](../../src/CTLD_jtac.lua#L1657)). Adding a guard there would be an
  opportunistic change.
- `recon`, `List active FOBs` and `minefield_demine` keep today's behaviour — open. The demining is
  the only *action* among them and was explicitly left alone; see the PRD's Out of scope.
- These three changes apply to **every** non-transport pilot, including in the default
  configuration — not only to the whitelist case. That is intended, and it is the user-visible part
  of this lot.
- Do not move `Check Cargo` into a registered section. It is a fixed command by design and moving
  it would change its ordering.

## Acceptance

- [x] A non-transport pilot's menu contains: `RECON`, `Smoke`, `Radio Beacons` → `List Beacons`,
      `JTAC` → `JTAC Status`, `FOBs List`.
- [x] It does **not** contain: `Check Cargo`, `Troop Commands`, `Crate Commands`,
      `Request Equipment`, `Vehicle Commands`, `Drop Beacon`, `Remove Closest Beacon`,
      `Request JTAC Equipment`.
- [x] A transport pilot's menu is unchanged — all of the above present, `Check Cargo` included.
- [x] `enabledRadioBeaconDrop = false` removes the whole beacon submenu, for both kinds of pilot.
- [x] Specs green.

# 01 — In-game spike: a runtime FARP, its finite stock, its vehicles

**Status:** 🧑 waiting-human — phase 1 done (2026-10-26), phase 2 (multiplayer client) not run yet · **Type:** HITL (live DCS, Zip)

## Parent

[PRD — FEAT-FAT-COW](../PRD.md). Decision 4.

## Questions

- **(a)** Does a FARP spawned mid-mission serve refuel/rearm to a player who was already in game?
- **(b)** Is a finite warehouse stock respected, and seen identically by the server and by a client?
- **(c)** Does DCS require a refuel/ammo vehicle in range of an Invisible FARP?

## Kit

- `tests/dcs/pilotActive/scenario_fatcow_spike.lua` — pure DCS API, no CTLD. An F10 menu per player group, "Fat Cow spike": 1 Invisible FARP under me · 2 Finite stock (300 kg, 2 Hellfire) · 3 Read stock + my aircraft · 4 Add fuel + ammo trucks · 5 Crates only (barrels + ammo crate) · 6 Remove everything · 7 Add FARP props (fuel depot, ammo dump, barrels, ammo crate) · 8 Barrels only · 9 Ammo crate only. Commands 5, 7–9 were added after the first runs (the single-pad variant and a fuel-truck-only command were dropped once moot). Every measurement goes to the screen and to `dcs.log`, prefixed `[FCSPIKE]`.
- `missions/Test_FatCow_Spike.miz` — Caucasus, a flat field 19 km from Senaki and from Kutaisi (no airfield ground crew in reach). Two AH-64D slots (`Apache-1`, `Apache-2`, 80 m apart), ground start with engines running (`TakeOffGroundHot`) on the field, 30 % fuel (342 kg), empty pylons: the spike needs no flying (Zip, 2026-10-26: no stick at hand). Trees at the exact spot are not checked by any file: a slot that explodes at spawn means a tree. The script is embedded and runs at mission start.
- Built with the VMCT `veaf-mission-editor` actions on a blank Caucasus mission (`veaf_libs.blank_mission`): `add_player_slot` ×2 (air start), `set_group_properties` `move_to` ×2 and `edit_route` `set` waypoint 1 to `TakeOffGroundHot` ×2 (`add_player_slot` refuses a ground start off an airfield), `add_startup_script_trigger` (`file_static`). To rebuild after a script change, redo these actions on a fresh blank mission.

The 300 kg of fuel is below the ~800 kg a 30 % Apache takes to fill up, and the 2 Hellfires below the 4 a rail takes: a cap shows as a partial service.

## Procedure — phase 1, single player (answers a, c, and b on one machine)

Press **Print Screen** (DCS screenshot, saved in `Saved Games\DCS\Screenshots`) where marked 📸: the screenshots and `dcs.log` are read afterwards, nothing has to be copied by hand.

1. DCS main menu → **MISSION** → `Test_FatCow_Spike.miz` → **OK**. If a slot is asked, take **Apache-1**.
2. You are on the ground, engines running. A message `[FCSPIKE] loaded` shows at start. Touch nothing.
3. `\` → **F10 Other** → **Fat Cow spike** → **F1** "1. Invisible FARP under me". Green smoke under you; lines `SPAWNED` and `INITIAL STOCK`. 📸
4. `\` → **F8 Ground Crew** → **F1 Rearm & Refuel**. The rearm window opens (or not). 📸 Close it.
5. `\` → **F10 Other** → **Fat Cow spike** → **F2** "2. Finite stock". Lines `SET STOCK` and `STOCK READ BACK`. 📸
6. `\` → **F8 Ground Crew** → **F1 Rearm & Refuel**. 📸 In the window: fuel to **100 %**, and **4 × AGM-114K** on one pylon. Confirm the window.
7. Wait until the ground crew is done (or says it cannot). 📸
8. `\` → **F10 Other** → **Fat Cow spike** → **F3** "3. Read stock + my aircraft". 📸
9. **Only if step 6 or 7 refused the service:** `\` → **F10 Other** → **Fat Cow spike** → **F4** "4. Add fuel + ammo trucks", then redo steps 6 to 8.
10. **Only if step 3 printed `getWarehouse() = nil`:** `\` → **F10 Other** → **Fat Cow spike** → **F6** "6. Remove everything", then **F5** "5. Single pad FARP ahead", hover-taxi onto the green smoke 40 m ahead, land, and redo steps 4 to 8. This step needs flight controls: without them, stop at step 9 and report.
11. Quit the mission. Say "phase 1 done".

## Procedure — phase 2, multiplayer (the client side of b)

Needs the mission on a dedicated server (the VEAF test server) and Zip joining it as a client: in single player the server and the client are the same process.

1. Load `Test_FatCow_Spike.miz` on the server. Join it as a client, slot **Apache-1**.
2. Steps 2 to 8 of phase 1.
3. Back to spectators (**Esc** → **Choose slot** → spectators), then take **Apache-1** again: a new birth. The script prints `STOCK AT BIRTH`.
4. `\` → **F8 Ground Crew** → **F1 Rearm & Refuel**. 📸
5. Quit. The server's `dcs.log` holds the `[FCSPIKE]` lines.

## Reading the results

| What is seen | Conclusion |
|---|---|
| Step 3 `INITIAL STOCK` prints numbers | (b) The Invisible FARP has a warehouse: the countryside scene's step 11 comment is wrong. |
| Step 3 prints `getWarehouse() = nil` | No finite stock on an Invisible FARP → step 10; if the single pad has one, decision 2 changes its FARP type (to Zip). |
| Step 4 window opens with nothing to take | (b) The runtime FARP starts empty, as the forum guide says: the cow must stock it, which it does anyway. |
| Step 6–7 serves, without trucks | (a) yes and (c) no vehicle needed: decision 2 holds. |
| Step 6–7 refuses, step 9 serves | (c) DCS needs vehicles: fallback, a vehicle hidden under the cow's fuselage. |
| Step 9 still refuses | (a) a runtime FARP does not serve a player already in game: stop, report to Zip (the RotorOps route, teleporting pre-placed FARPs, becomes the candidate). |
| Step 8: aircraft got ~300 kg and 2 Hellfires, stock 0 | (b) finite stock respected on the server. |
| Step 8: aircraft got full fuel and 4 Hellfires | (b) the stock is not enforced: stop, report to Zip (decision 3). |
| Phase 2: rearm window shows the same quantities as `STOCK NOW` | (b) client and server agree. |
| Phase 2: the client's window shows something else (empty, or unlimited) | (b) no network sync: the stock has to be re-applied on each birth, as VMCT does, and enforcement checked server-side. |

## Answers

### Phase 1 — single player, 2026-10-26 (Zip, DCS 2.9.30.28738, no stick: Apache on the ground, engines running)

From `dcs.log` and Zip's screenshots.

| Step | Measured |
|---|---|
| 3 | `INITIAL STOCK`: jet fuel 0, every Hellfire 0, inventory empty. `getWarehouse()` is not nil. DCS logs `NO ATC COMM HELIPAD + FCSPIKE_FARP_1:127500000` (a warning, no effect seen). |
| 4 | The Mission Resources window opens, loadout list empty. |
| 5 | `STOCK READ BACK`: jet fuel 300, `AGM_114K` 2, the two other Hellfire names 0. |
| 6–7 (no trucks) | Fuel 100 % + 4 × AGM-114K, OK: nothing happens, no message. |
| 9 (trucks) | Same request: the ground crew answers, works ~30 s, then "Unable to comply". |
| 9 again | Fuel 50 %: "We don't have this in stock". |
| 7 (props, new mission) | Fuel 100 % + 4 × AGM-114K: "Copy", then served; `STOCK NOW` 0, `AIRCRAFT` 634 kg and `AGM_114K` ×2. |
| 8 | `STOCK NOW`: jet fuel 0, `AGM_114K` 0. `AIRCRAFT`: fuel 631 kg / 1 140 kg (342 at spawn), `AGM_114K` ×2, `M230_HEDP M789` ×1 200 (already full). The window shows 56 % and 2 Hellfires on pylon 2. |

- **(a) Yes.** An Invisible FARP spawned by `coalition.addStaticObject` mid-mission serves a player already in game.
- **(b) Yes, on the server side.** The runtime FARP has a warehouse and starts empty. A finite stock set by script is served until it runs out, then refused: +289 kg for 300 kg in stock (the rest burnt at idle during the test), 2 Hellfires out of 4 asked. A request bigger than the stock is partly served, then answered "Unable to comply". Liquids are in kg. The Hellfire item is `weapons.missiles.AGM_114K`.
- **(c) A supplier is required, but statics are enough: no vehicle.** With the FARP alone the window opens but nothing is served and nothing is said. With an M978 HEMTT Tanker and an M 818 30 m away, it is served. With **statics only** (command 7: `FARP Fuel Depot`, `FARP Ammo Dump Coating`, `barrels_cargo`, `ammo_cargo`, 25–30 m away, no vehicle) the ground crew answers "Copy" and serves: fuel 342 → 634 kg, `AGM_114K` ×2, stock down to 0. Decision 2 holds as is, no hidden vehicle. Not separated: which of the four statics does it (fuel depot or barrels, ammo dump or ammo crate), and the range. The fuel-truck-only test (command 8) is moot.
- Where the rule lives: not in DCS's Lua files (`db.Units.lua` gives the M978 and M 818 only generic attributes, and the FARP statics none), nor as text in the clear DLLs of `bin/`; it is in the compiled engine, probably `Inter.dll` or `WorldGeneral.dll`. Measuring in game was preferred over decompiling.
- The countryside scene's step 11 comment ("Invisible FARP airbases … return nil for getWarehouse()") is wrong, measured.

No answer kills the design.

### Phase 2 — multiplayer client

Not run yet: needs the mission on a dedicated server with Zip joining it as a client.

## Acceptance criteria

- [x] (a), (b) on one machine, (c) answered from `dcs.log` and the screenshots, in this ticket and the PRD.
- [ ] (b) client side answered by phase 2, or marked not measured with the reason.
- [x] If an answer kills the design, reported to Zip before ticket 02 is written.

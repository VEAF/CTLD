# 06 — Live check in DCS

**Status:** 🧑 waiting-human · **Type:** HITL (live DCS, Zip)

## Parent

[PRD — FEAT-FAT-COW](../PRD.md).

## What to check

- Piloted: a CH-47F loads cow crates, lands, deploys; an Apache landed next to it is served up to the stock; pack; the hold mass went down.
- AI: an Apache requests a cow in a logistic zone, takes off, the cow follows, both land, the FARP deploys after 60 s, the Apache is served, takes off, the cow packs and follows; release sends it home.
- The range: how far from the cow an Apache can land and still be served (ticket 01 used 0 m).
- The 30 mm crate: whether `weapons.shells.M230_HEDP M789` is the warehouse item the Apache's gun reload draws from.
- The AI cow's DCS behaviour, which the unit tests only mock: the `Follow` task on a player flight, the `Land` task next to the leader on open ground, the take-off when re-tasked, the despawn at home.
- If a second player is available: the client side of ticket 01 (b).

## Kit

`Test_FatCow_LiveCheck.miz`, in `Saved Games\DCS\Missions` on Zip's machine and **not in the repository**: it embeds a built `CTLD.lua`, which `CLAUDE.md` forbids committing (and `CTLD_DEV_ROOT` loading needs a de-sanitised `os`, which this machine does not have).
Rebuild it after any `src/` change, with the VMCT `veaf-mission-editor` actions on a blank Caucasus mission (`veaf_libs.blank_mission`):

- `add_trigger_zone` `LGZ_cowbase_B` at x -290000, y 665150, radius 400 m: a logistic zone on a flat field 19 km from Senaki and from Kutaisi, so no airfield warehouse serves anyone;
- `add_player_slot` + `edit_route` (waypoint 1 → `TakeOffGroundHot`), all inside the zone, engines running: `Cow-1` (CH-47Fbl1) at y 665000; `Gunfighter` (AH-64D_BLK_II, 30 % fuel, empty pylons) 60 m east of it, `Apache-150m` 150 m east, `Apache-300m` 300 m east;
- `add_air_group` + `edit_route`: `Hawk`, an AI AH-64D 3 km south, taking off hot, landing (Land task) at x -291000, y 666500 for 300 s, then at x -292500, y 667500 for good; `Fat Cow Hawk`, a late-activated AI CH-47Fbl1 at y 665650 in the zone, taking off hot;
- `add_startup_script_trigger`: `file_static` of the built `CTLD.lua`, then `inline`: `CTLDConfig.get().settings["fatCowAICows"] = { { group = "Fat Cow Hawk", escort = "Hawk" } }` and `CTLDFatCowManager.getInstance():_activateMissionCows()` (the mission-placed cow, the VMCT contract, without a full config snapshot).

The `Hawk` run needs nobody: CTLD logs it (`CTLDFatCowManager:` lines in `dcs.log`) while the piloted checks go on.

## Procedure

**Print Screen** where marked 📸. Nothing to copy: `dcs.log` and the screenshots are read afterwards.

### A — Piloted cow and range (no flying)

1. **MISSION** → `Test_FatCow_LiveCheck.miz` → **OK**, slot **Cow-1**.
   The message `[Fat Cow live check] CTLD loaded…` shows.
2. `\` → **F10 Other** → **CTLD** → **Fat Cow** → **Request Fat Cow fuel tank (800 gal)**. 📸
   Then **Request Fat Cow Hellfires (x4)**.
3. `\` → **F10 Other** → **CTLD** → **Crate Commands** → **Load Crate** → the fuel tank; again for the Hellfires.
   If **Load Crate** is not there, load them with the DCS cargo window.
4. `\` → **F10 Other** → **CTLD** → **Fat Cow** → **Fat Cow stock**: expected 2400 kg of fuel, AGM_114K x4. 📸
5. `\` → **F10 Other** → **CTLD** → **Fat Cow** → **Deploy the Fat Cow FARP**.
   Wait for `Fat Cow FARP open: …` (a few seconds). **F2** (external view) to look at the layout. 📸
6. **Esc** → **Choose slot** → **Gunfighter** (60 m away).
   `\` → **F8 Ground Crew** → **F1 Rearm & Refuel** → **FUEL 100 %**, **4 × AGM-114K** on one pylon → **OK**. Wait for the ground crew. 📸
7. Same as 6 with **Apache-150m**, then **Apache-300m**: fuel only (the Hellfires are gone).
   Note for each what the ground crew says: "Copy", "Unable to comply", or nothing.
8. Back to **Cow-1**: `\` → **F10 Other** → **CTLD** → **Fat Cow** → **Fat Cow stock**. 📸
   Then **Pack the Fat Cow FARP**. 📸
9. Quit.

### B — Requested AI cow (needs flying)

1. **MISSION** → `Test_FatCow_LiveCheck.miz` → **OK**, slot **Gunfighter**.
2. `\` → **F10 Other** → **CTLD** → **Fat Cow** → **Request a Fat Cow**. A CH-47 appears 80 m behind you.
3. Take off, fly 2 km over open fields, land in the open. The cow should land about 120 m to your left and announce `Fat Cow FARP open` one minute after touching down. 📸
4. Rearm and refuel as in A6. 📸
5. Take off: the cow should pack and follow. Land again somewhere else: it lands next to you again.
6. `\` → **F10 Other** → **CTLD** → **Fat Cow** → **Release the Fat Cow**: it flies back to where it appeared and disappears.
7. Quit.

## Reading the results

| What is seen | Conclusion |
|---|---|
| A6: "Copy", fuel and 4 Hellfires served | Piloted cow works; 60 m is in range. |
| A7: "Copy" at 150 m but nothing at 300 m (or the other way) | The FARP's service range lies in between: the docs say to land within it. |
| A8: stock = 2400 minus what the three Apaches took; after pack the CH-47 is lighter | Pack reads the remainder back and the hold mass follows. |
| A5: depot, crates or soldiers under the rotor, or no `FARP open` message | Layout or scene problem: screenshot needed. |
| B3: the cow lands far away, hovers, or goes to an airfield | The AI `Land` task does not behave as VMCT measured: the cow's landing needs rework. |
| B5: the cow stays on the ground after the take-off | The re-task to `Follow` does not lift a landed AI helicopter. |
| `dcs.log`: `cow 'Fat Cow Hawk…' deployed`, then `packed` | The mission-placed cow (VMCT contract) works without a player. |

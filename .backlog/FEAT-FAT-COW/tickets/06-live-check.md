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

### Server variant (multiplayer, 2026-10-26)

`VEAF_OpenTraining_Syria_FatCowTest_ICAO_LTAG_20261026.miz` (Saved Games\DCS\Missions, not in any repository): the Syria Open Training v6 at its committed state, rebuilt in a copy (`D:\tmp\OT-Syria-FatCow`) with `published/src/scripts/community/CTLD.lua` replaced by this branch's build (`ctld.VERSION` `2.0.0-rc13-fatcow-d8da3839`, so develop's fixes since rc13 are in too) and the `fatCow*` block added to `ctld-config.yaml` (catalogue 2.3.0). Mission name `VEAF_OpenTraining_Syria_FatCowTest_ICAO_LTAG`, so it never replaces the production file. CH-47F and AH-64D dynamic slots at Hatay and FARP Reyhanli; every airfield and FARP ammo dump is a CTLD logistic zone. On a server, Zip is a client: the client side of ticket 01 (b) is measured by the same checks (the rearm window shows the cow's stock, served up to it).

### First server run — 2026-10-26 afternoon (Zip, Privé 1, client)

- Piloted CH-47F near Akrotiri (4.5 km from the airfield): deployed with 2 400 kg; an Apache landed at the FARP was refuelled and rearmed. A client on a dedicated server is served by a cow FARP: ticket 01 (b) client side answered in practice.
- The pilot changing slot leaves the FARP in place: kept on purpose (decision 4a).
- Findings, all addressed in the second build (`-v2`, `ctld.VERSION` `2.0.0-rc13-fatcow-5cd3286a`): loading one crate at a time is tedious (loadouts); the AI cow reported an empty stock until it landed (bug: it read crates it does not have); its request was refused outside a logistic zone (now from anywhere, from the nearest zone, with an ETA); it packed and left whenever the leader hopped onto its FARP (a player flight now commands it: Land here, Take off, Hold here, Join us); no way to know what the FARP you are at still holds (FARP status).
- Measurement for "FARP status on every FARP": the Open Training's mission FARPs (filled by VMCT) read jet fuel 1000000 and AGM_114K 1000000 through `getLiquidAmount` / `getItemCount`, while `getInventory` lists 0 weapon types. A follow-up can show such a warehouse as "full".

### Evening run — 2026-10-26 (Privé 1, Zip, Griffin, Paluche): findings

1. **The AI cow exploded on take-off** (21:06:29.9), under a second after its FARP was packed: the Invisible FARP under it was destroyed. Hypothesis, not measured: an AI aircraft sitting on an airbase dies when the airbase is destroyed (Zip's piloted CH-47 survived the same pack at 21:06:16).
2. **A packed FARP stays on the F10 map**: destroying a heliport static leaves its airbase. One ghost per deployment (`CS_FARP-55`, `-61`, `-67`, `-73`).
   Proposed for 1 and 2: one FARP per cow, never destroyed: packing removes the depot, dressing and crew and empties the warehouse; the next deployment re-adds the heliport under the same name at the new spot (RotorOps PERKS moves its Fat Cow FARPs this way).
3. **The cow's FARP became unlimited**: VMCT's `veafGrass.onBirth` refills every FARP warehouse (50 000 kg of each liquid, ~5 000 of every weapon) on every player birth; packs read 50 035 and 50 055 kg. Proposed: the cow's FARP named `CTLD_…`, VMCT's refill skips `CTLD_` FARPs (VMCT PR), and CTLD restores its own count if fuel or Hellfires go up.
4. **"Load: Max weapons + max fuel" refused on the French server**: CTLDConfig translates every config `desc`, so the crate is named "Réservoir Fat Cow (800 gal)" while the loadout names it in English. Proposed: look the crate up by its translated name, with a test in French.
5. **No CSAR menu in the CH-47F**: VMCT's `CSAR.lua` lists no `CH-47Fbl1` in `csar.aircraftType`, in every VMCT mission. Proposed: one line in the same VMCT PR.
6. **Radar missiles** (Zip): the cow should also carry AGM-114L (Longbow, radar).

Fixed on 2026-10-27, in this PR (Zip's lot 1):
- 1 and 2: one FARP per cow (`CTLD_FatCow_FARP_<n>`), never destroyed: packing removes the depot, dressing and crew and empties the warehouse; the next deployment adds the heliport again under the same name, where the cow is. To measure in game: that adding a static under an existing name moves the FARP and leaves no ghost.
- 3, CTLD side: a warehouse count that went up is put back to the cow's own, weapons the cow does not carry are removed, and the warehouses are written again 2 s after a birth too. The VMCT side (GRASS skipping `CTLD_` FARPs) is a separate VMCT PR.
- 4: a loadout no longer names crates: it lists fuel kg and items, and CTLD splits it into the crates that carry them.
- 5: VMCT side, the same VMCT PR.
- 6, and Zip's loadout profiles: four loadouts, each two 800 gal tanks (4 800 kg) with 40 Hellfires (25 laser, 15 radar) + 2 400 rounds, 60 (38 + 22) + 1 200, 40 laser + 2 400, 60 laser + 1 200 (crates of 20 laser, 20 radar, 1 200 rounds); an AI cow flies with 80 % internal fuel and carries the loadout the requesting flight picks (submenu). Masses from the DCS data mine: AGM-114K 45.3 kg, AGM-114L (warehouse name `weapons.missiles.AGM_114`, to check in game) 49 kg.
- F10 menus regrouped: a piloted cow's **Load** and **Request a crate** submenus, an AI request's loadout submenu.

## Procedure

**Print Screen** where marked 📸. Nothing to copy: `dcs.log` and the screenshots are read afterwards.

### A — Piloted cow and range (no flying)

1. **MISSION** → `Test_FatCow_LiveCheck.miz` → **OK**, slot **Cow-1**.
   The message `[Fat Cow live check] CTLD loaded…` shows.
2. `\` → **F10 Other** → **CTLD** → **Fat Cow** → **Request a crate** → **Fat Cow fuel tank (800 gal)**. 📸
   Then **Request a crate** → **Fat Cow laser Hellfires (x20)**.
3. `\` → **F10 Other** → **CTLD** → **Crate Commands** → **Load Crate** → the fuel tank; again for the Hellfires.
   If **Load Crate** is not there, load them with the DCS cargo window.
4. `\` → **F10 Other** → **CTLD** → **Fat Cow** → **Fat Cow stock**: expected 2400 kg of fuel, laser Hellfire x20. 📸
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
2. `\` → **F10 Other** → **CTLD** → **Fat Cow** → **Request a Fat Cow** → a loadout. A CH-47 comes from the nearest logistic zone.
3. Take off, fly 2 km over open fields, land in the open. The cow should land about 120 m to your left and announce `Fat Cow FARP open` one minute after touching down. 📸
4. Rearm and refuel as in A6. 📸
5. Take off: the cow should pack and follow. Land again somewhere else: it lands next to you again.
6. `\` → **F10 Other** → **CTLD** → **Fat Cow** → **RTB**: it flies back to where it appeared and disappears.
7. Quit.

### C — Lot 1 fixes (2026-10-27), on the server with the next build

1. CH-47F in a logistic zone: **Fat Cow** → **Load** → **40 Hellfires (25 laser, 15 radar), 2400 rounds**: 7 crates in the hold, the message lists 4800 kg of fuel, laser Hellfire x25, radar Hellfire x15, 30 mm rounds x2400.
2. Land elsewhere, **Deploy the Fat Cow FARP**; an Apache rearms with **radar** Hellfires (AGM-114L) and the gun: served, or "We don't have this in stock" (then the warehouse name `weapons.missiles.AGM_114` or the 30 mm name is wrong: tell the session).
3. Another player takes a slot, then **FARP status** at the cow: the stock has not jumped to 50 000 kg (VMCT's refill is undone).
4. Take off (the FARP packs), land 2 km further, deploy again: on the F10 map, **one** FARP for the cow, now at the new spot, and no new one at the old spot.
5. Apache: **Request a Fat Cow** → **60 laser Hellfires, 1200 rounds**; **Land here**, wait for the FARP, then **Take off**: the cow lifts off and does **not** blow up.

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

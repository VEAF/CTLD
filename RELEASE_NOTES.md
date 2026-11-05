# CTLD 2.0.0-rc17 — release candidate

## Installation

1. Download **`ctld-tools.exe`** below — it is the only file you need.
2. Run it: the tool opens in your browser, locally, with nothing to install.
3. Open your `.miz`, adjust what you want, then **Install into mission**: the tool writes CTLD, the beacon sounds and your configuration into it.

**Windows blocks it on the first run?** The tool is not code-signed, so SmartScreen stops it: click **More info** → **Run anyway**.
If the file came through a browser you may also need right-click → **Properties** → tick **Unblock** → **OK**.

Prefer doing it by hand? The files are attached to this release too — see the [documentation](https://veaf.github.io/CTLD/2.0.0-rc17/mission-maker/).

---

The Fat Cow release candidate: a CH-47 that lands in the field and becomes a forward refuel and rearm point for helicopters.
DCS still has no native Fat Cow, so CTLD brings its own.
Nothing breaks for an existing mission: the Fat Cow is a new F10 submenu, on by default, and works with a mission configuration written for an older CTLD.

## New since rc16

- **A piloted Fat Cow leaves its FARP open.**
  Taking off no longer packs the FARP: it stays open, with what is left, and the pilot is told its name on the F10 map and what it holds.
  It also stays open when the CH-47 is shot down, its pilot leaves, or another pilot takes the slot.
- **Packing sets the crates down on the ground.**
  **Pack the Fat Cow FARP**, from any piloted CH-47 of the coalition landed within 150 m, sets what is left down as Fat Cow crates next to it, to load and deploy elsewhere.
- **Load** > a loadout now sets its crates down next to the CH-47, to load like any CTLD crate, instead of putting them straight into the hold.
  **Deploy the Fat Cow FARP** takes the cow crates out of the hold: their content is the FARP's stock, and the helicopter is lighter.
- Each open FARP has its own name, so a pilot can open several. **Fat Cow stock** reports the crates in the hold; **FARP status** reports an open FARP.
- AI Fat Cows are unchanged.
- **Fixed: an aeroplane no longer gets the Fat Cow menu.** An A-10 could request a cow; the menu is now a helicopter's only.
- **The JTAC logs its laser code and its spot.** When it registers, a JTAC logs its code (imposed or from the pool) and its radio; each time it starts lasing, the code the spot carries, the target, the range, its altitude, and whether DCS returned a spot.
  A report like "the LSS finds nothing on 1511" can now be settled from `dcs.log`.

## Changed for pilots since rc16

A player-flown cow works differently: its loadout comes as crates on the ground to load, and taking off leaves the FARP behind instead of packing it.
Nothing changes in a mission configuration.

## Since rc15

- **A Fat Cow that loses its flight can be taken over**: it flies home, the helicopter flights of its coalition are told, and **F10 → CTLD → Fat Cow → Take over a Fat Cow** lists it, nearest first.
  **Release the Fat Cow** leaves a cow where it is for another flight; a cow sent home with **RTB** can be taken over until it has landed.
- Fixed: an AI Fat Cow sent home from the ground no longer vanishes on the spot, no longer lands into trees, and one killed without DCS reporting its death is forgotten within 10 s.
- Fixed since rc14: the Fat Cow works with a mission configuration written before it (a list CTLD added after your configuration's version takes its default).

## Fat Cow

- **A player-flown CH-47F** sets a ready-made loadout down as crates in a logistic zone (F10 → CTLD → Fat Cow → **Load**), loads them, lands, and **deploys its FARP**: helicopters around it refuel and rearm from what the cow carries, and nothing more.
  The FARP stays open when the cow takes off; **Pack** it, from any piloted CH-47 landed within 150 m, and what was not used is set down as crates on the ground.
- **Ready-made loadouts**, all with two 800 gal tanks (4 800 kg of fuel): Apache loadouts at the top (40 or 60 Hellfires, laser and radar, with 30 mm rounds), a **Russian** submenu (Vikhr for the Ka-50, Ataka or Shturm for the Mi-24P, with their rounds) and a **Mixed** one.
  Crates can also be requested one at a time.
- **Any helicopter pilot can request an AI Fat Cow**, choosing its loadout: an AI CH-47 comes from the nearest friendly logistic zone and follows the flight, which commands it from F10 (**Land here**, **Take off**, **Hold here**, **Join us**, **RTB**, **Release the Fat Cow**).
- **FARP status** tells what the Fat Cow FARP you are at still holds.
- **Mission makers** can place a late-activated CH-47 escorting a named flight (`fatCowAICows`, with the loadout to carry), and change the crates and loadouts (`fatCowCrates`, `fatCowLoadouts`, with a `menu` field for the Russian and Mixed submenus).
- The stock is finite and guarded: if another script refills the FARPs (as the VEAF Mission Creation Tools did on every player join), CTLD puts the cow's own count back.

See the pilot and mission-maker **Fat Cow** pages of the [documentation](https://veaf.github.io/CTLD/2.0.0-rc17/).

## Configuration

- New settings `fatCowEnabled`, `fatCowTypes`, `fatCowCrates`, `fatCowLoadouts`, `fatCowDeployDelay`, `fatCowAIType`, `fatCowAICows`; catalogue version `2.3.0`.
  An older configuration gets their defaults, from CTLD at mission start and from `ctld-tools` when it opens it.

## Other fixes

- **JTAC radio messages are translated** on a French, Spanish or Korean server; they came out in English.
- **Packing a FARP says how many crates were created**, instead of always reporting a success.
- **Unpack Crate no longer announces a success** when nothing was created (for example a JTAC refused by the coalition's limit).

## Known limits

- The Russian weapon names in the warehouse come from the DCS data, not yet from a flight: a weapon the ground crew reports as out of stock is a name to fix.

---

Thanks to the VEAF pilots who flew the Fat Cow on the Open Trainings, evening after evening, and checked every change of this release in game.

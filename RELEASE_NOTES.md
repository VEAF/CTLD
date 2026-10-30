# CTLD 2.0.0-rc16 — release candidate

## Installation

1. Download **`ctld-tools.exe`** below — it is the only file you need.
2. Run it: the tool opens in your browser, locally, with nothing to install.
3. Open your `.miz`, adjust what you want, then **Install into mission**: the tool writes CTLD, the beacon sounds and your configuration into it.

**Windows blocks it on the first run?** The tool is not code-signed, so SmartScreen stops it: click **More info** → **Run anyway**.
If the file came through a browser you may also need right-click → **Properties** → tick **Unblock** → **OK**.

Prefer doing it by hand? The files are attached to this release too — see the [documentation](https://veaf.github.io/CTLD/2.0.0-rc16/mission-maker/).

---

The Fat Cow release candidate: a CH-47 that lands in the field and becomes a forward refuel and rearm point for helicopters.
DCS still has no native Fat Cow, so CTLD brings its own.
Nothing breaks for an existing mission: the Fat Cow is a new F10 submenu, on by default, and works with a mission configuration written for an older CTLD.

## New since rc15

- **A Fat Cow that loses its flight can be taken over.**
  When an AI cow's flight is shot down or its last player leaves, the cow packs and flies home, and every helicopter flight of its coalition without a cow is told where it is, where it goes and what it holds.
  **F10 → CTLD → Fat Cow → Take over a Fat Cow** lists the cows on their way home, nearest first with their distance: the one picked joins the flight and obeys it as if it had requested it.
- **Release the Fat Cow**, next to **RTB**: the cow leaves the flight and stays where it is, FARP open on the ground or orbiting in the air, for another flight to take over.
  A cow sent home with **RTB**, empty or not, can also be taken over until it has landed at its base.
- **Fixed: an AI Fat Cow sent home from the ground no longer vanishes on the spot.** It now flies home and despawns only once there.
- **Fixed: an AI Fat Cow no longer lands into trees.** Told to **Land here**, or landing with its flight, it picks the nearest clearing around the point it was sent to.
- **Fixed: a Fat Cow killed without DCS reporting its death is forgotten** within 10 s, so its flight can request another one.

## Fixed since rc14

- **The Fat Cow works with a mission configuration written before it.**
  In rc14, a configuration saved with an older CTLD had no Fat Cow aircraft, crates or loadouts: CTLD read the missing lists as removed on purpose.
  A list CTLD added after your configuration's version now takes its default, and the startup message names it; opening the configuration in `ctld-tools` adds it for good.
  A list you removed yourself stays removed.

## Fat Cow

- **A player-flown CH-47F** loads a ready-made loadout in a logistic zone (F10 → CTLD → Fat Cow → **Load**), lands, and **deploys its FARP**: helicopters around it refuel and rearm from what the cow carries, and nothing more.
  **Pack** the FARP, or take off, and what was not used goes back into the hold.
- **Ready-made loadouts**, all with two 800 gal tanks (4 800 kg of fuel): Apache loadouts at the top (40 or 60 Hellfires, laser and radar, with 30 mm rounds), a **Russian** submenu (Vikhr for the Ka-50, Ataka or Shturm for the Mi-24P, with their rounds) and a **Mixed** one.
  Crates can also be requested one at a time.
- **Any pilot can request an AI Fat Cow**, choosing its loadout: an AI CH-47 comes from the nearest friendly logistic zone and follows the flight, which commands it from F10 (**Land here**, **Take off**, **Hold here**, **Join us**, **RTB**, **Release the Fat Cow**).
- **FARP status** tells what the Fat Cow FARP you are at still holds.
- **Mission makers** can place a late-activated CH-47 escorting a named flight (`fatCowAICows`, with the loadout to carry), and change the crates and loadouts (`fatCowCrates`, `fatCowLoadouts`, with a `menu` field for the Russian and Mixed submenus).
- The stock is finite and guarded: if another script refills the FARPs (as the VEAF Mission Creation Tools did on every player join), CTLD puts the cow's own count back.

See the pilot and mission-maker **Fat Cow** pages of the [documentation](https://veaf.github.io/CTLD/2.0.0-rc16/).

## Configuration

- New settings `fatCowEnabled`, `fatCowTypes`, `fatCowCrates`, `fatCowLoadouts`, `fatCowDeployDelay`, `fatCowAIType`, `fatCowAICows`; catalogue version `2.3.0`.
  An older configuration gets their defaults, from CTLD at mission start and from `ctld-tools` when it opens it.

## Other fixes

- **JTAC radio messages are translated** on a French, Spanish or Korean server; they came out in English.
- **Packing a FARP says how many crates were created**, instead of always reporting a success.
- **Unpack Crate no longer announces a success** when nothing was created (for example a JTAC refused by the coalition's limit).

## Known limits

- The Fat Cow was tested on a VEAF server on 2026-10-26; the fixes that followed that evening are in this release and have not been flown yet. Reports welcome.
- The Russian weapon names in the warehouse come from the DCS data, not yet from a flight: a weapon the ground crew reports as out of stock is a name to fix.

---

Thanks to the VEAF pilots of the 2026-10-26 Fat Cow evening for their reports.

# CTLD 2.0.0-rc14 — release candidate

## Installation

1. Download **`ctld-tools.exe`** below — it is the only file you need.
2. Run it: the tool opens in your browser, locally, with nothing to install.
3. Open your `.miz`, adjust what you want, then **Install into mission**: the tool writes CTLD, the beacon sounds and your configuration into it.

**Windows blocks it on the first run?** The tool is not code-signed, so SmartScreen stops it: click **More info** → **Run anyway**.
If the file came through a browser you may also need right-click → **Properties** → tick **Unblock** → **OK**.

Prefer doing it by hand? The files are attached to this release too — see the [documentation](https://veaf.github.io/CTLD/2.0.0-rc14/mission-maker/).

---

The Fat Cow release candidate: a CH-47 that lands in the field and becomes a forward refuel and rearm point for helicopters.
DCS still has no native Fat Cow, so CTLD brings its own.
Nothing breaks for an existing mission: the Fat Cow is a new F10 submenu, on by default, and `ctld-tools` adds its settings to an older configuration.

## Fat Cow

- **A player-flown CH-47F** loads a ready-made loadout in a logistic zone (F10 → CTLD → Fat Cow → **Load**), lands, and **deploys its FARP**: helicopters around it refuel and rearm from what the cow carries, and nothing more.
  **Pack** the FARP, or take off, and what was not used goes back into the hold.
- **Ready-made loadouts**, all with two 800 gal tanks (4 800 kg of fuel): Apache loadouts at the top (40 or 60 Hellfires, laser and radar, with 30 mm rounds), a **Russian** submenu (Vikhr for the Ka-50, Ataka or Shturm for the Mi-24P, with their rounds) and a **Mixed** one.
  Crates can also be requested one at a time.
- **Any pilot can request an AI Fat Cow**, choosing its loadout: an AI CH-47 comes from the nearest friendly logistic zone and follows the flight, which commands it from F10 (**Land here**, **Take off**, **Hold here**, **Join us**, **RTB**).
- **FARP status** tells what the Fat Cow FARP you are at still holds.
- **Mission makers** can place a late-activated CH-47 escorting a named flight (`fatCowAICows`, with the loadout to carry), and change the crates and loadouts (`fatCowCrates`, `fatCowLoadouts`, with a `menu` field for the Russian and Mixed submenus).
- The stock is finite and guarded: if another script refills the FARPs (as the VEAF Mission Creation Tools did on every player join), CTLD puts the cow's own count back.

See the pilot and mission-maker **Fat Cow** pages of the [documentation](https://veaf.github.io/CTLD/2.0.0-rc14/).

## Configuration

- New settings `fatCowEnabled`, `fatCowTypes`, `fatCowCrates`, `fatCowLoadouts`, `fatCowDeployDelay`, `fatCowAIType`, `fatCowAICows`; catalogue version `2.3.0`.
  `ctld-tools` gives them their default when it opens an older configuration.

## Other fixes

- **JTAC radio messages are translated** on a French, Spanish or Korean server; they came out in English.
- **Packing a FARP says how many crates were created**, instead of always reporting a success.
- **Unpack Crate no longer announces a success** when nothing was created (for example a JTAC refused by the coalition's limit).

## Known limits

- The Fat Cow was tested on a VEAF server on 2026-10-26; the fixes that followed that evening are in this release and have not been flown yet. Reports welcome.
- The Russian weapon names in the warehouse come from the DCS data, not yet from a flight: a weapon the ground crew reports as out of stock is a name to fix.

---

Thanks to the VEAF pilots of the 2026-10-26 Fat Cow evening for their reports.

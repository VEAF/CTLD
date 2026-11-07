# CTLD 2.0.0

## Installation

1. Download **`ctld-tools.exe`** below — it is the only file you need.
2. Run it: the tool opens in your browser, locally, with nothing to install.
3. Open your `.miz`, adjust what you want, then **Install into mission**: the tool writes CTLD, the beacon sounds and your configuration into it.

**Windows blocks it on the first run?** The tool is not code-signed, so SmartScreen stops it: click **More info** → **Run anyway**.
If the file came through a browser you may also need right-click → **Properties** → tick **Unblock** → **OK**.

Prefer doing it by hand? The files are attached to this release too — see the [documentation](https://veaf.github.io/CTLD/2.0.0/mission-maker/).

---

The first stable release of the new CTLD: the logistics pilots know, on an engine rewritten from the ground up, with a tool that installs it into a mission in one click.
It succeeds the legacy CTLD (1.x).

**Since 2.0.0-rc17, nothing has changed**: 2.0.0 is the rc17 code, flown on the VEAF Open Trainings and checked in game, published as stable.

## Coming from CTLD 1.x

- **A mission that calls CTLD from a DO SCRIPT keeps working.** Every v1 `ctld.*` function survives and forwards to the new engine, with a deprecation warning in the log — see the [v1 → v2 migration page](https://veaf.github.io/CTLD/2.0.0/developer/migration-v1-v2/).
- **The configuration is no longer edited in the Lua file.** `ctld-tools` edits it and writes it into the mission; a configuration written for an older CTLD gets the defaults of what was added since.
- **Each aircraft type declares what it can do** in one table (`capabilitiesByType`): crates, troops, parachute, slingload, whole vehicles, DCS native cargo, and its limits.
- "Repack" is now **pack**, in the menus and in the configuration.

## What 2.0.0 brings

- **`ctld-tools.exe`**: opens a `.miz`, edits the configuration it carries, reads the mission's zones back, and installs CTLD, its sounds and its configuration in one click. It carries its own CTLD and needs no network.
- **Fat Cow**: a CH-47 that lands in the field and becomes a forward refuel and rearm point for helicopters, flown by a player or requested as an AI cow that follows the flight.
- **Whole vehicles**: the C-130J-30 takes one through the DCS loadmaster tablet, and the helicopters that can (CH-47F, Mi-8MT) carry one through the CTLD menu.
  Requested crates appear within reach of the aircraft's DCS cargo interface.
- **Virtual slingload and parachute** for crates, troops and vehicles, without the DCS sling physics.
- **Scenes built from crates**: FARPs, FOB, minefield — and a FARP or a vehicle packed back into crates to move it elsewhere.
- **Zones by naming convention** (`LGZ_`, `TRZ_`, `WPZ_`, `EXZ_`, `EXTR_`) on a trigger zone, a unit, a static or a ship; a zone tied to a unit moves with it and disappears with it.
- **AI transport zones** (`aiZones`), with troop and vehicle stocks per template.
- **JTAC auto-lase** with a laser-code pool, imposed codes and radio, and a log of the code and the spot it lases.
- **Radio beacons** on VHF, UHF and FM, with sounds a Mission Maker can choose.
- **Every pilot gets what concerns them**: recon, smoke, the beacon list and the JTAC status are open to fighter pilots too; the transport menus stay with transport aircraft.
- **Four languages** in game: English, French, Spanish, Korean.

## Known limits

- The Russian weapon names in the Fat Cow warehouse come from the DCS data, not yet from a flight: a weapon the ground crew reports as out of stock is a name to fix.

See the [documentation](https://veaf.github.io/CTLD/2.0.0/) for pilots and Mission Makers.

---

CTLD 2.0.0 is the work of FullGas and Zip, of the VEAF.
Thanks to the VEAF pilots who flew every release candidate on the Open Trainings and checked each change in game.

# CTLD v2

**Combat Troops and Logistics Dispatcher** — DCS World mission scripting framework.

CTLD enables helicopter crews to transport troops, deploy FOBs, sling-load crates,
operate JTACs, and much more — all driven by an F10 menu and a modular Lua v2 engine.

## Quick links

- [Pilot Guide](pilot/index.md) — operate CTLD from the cockpit (F10 menu)
- [Mission Maker Guide](mission-maker/index.md) — configure CTLD in your mission
- [Developer documentation](developer/index.md) — architecture, subsystems, events, build & test

## Installation

1. Download `CTLD.lua` from the [releases page](https://github.com/VEAF/CTLD/releases).
2. Add a **MISSION START → DO SCRIPT FILE** trigger in the DCS Mission Editor pointing to `CTLD.lua`.
   CTLD runs on its built-in defaults — nothing else is required.
3. To customise anything, download `ctld-tools.exe` from the same release, adjust the configuration in
   your browser and let it inject a `CTLD_userConfig.lua` trigger **before** the `CTLD.lua` one — see
   [Configure with `ctld-tools`](mission-maker/ctld-tools.md).

## Compatibility

- DCS World (any map)
- Lua 5.1 (DCS sandbox)
- No MIST dependency required

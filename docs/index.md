# CTLD v2

**Combat Troops and Logistics Dispatcher** — DCS World mission scripting framework.

CTLD enables helicopter crews to transport troops, deploy FOBs, sling-load crates,
operate JTACs, and much more — all driven by an F10 menu and a modular Lua v2 engine.

## Quick links

- [Mission Maker Guide](missionmaker_guide.md) — configure CTLD in your mission
- [Developer Guide](dev-guide.md) — architecture, new modules, events, build & test

## Installation

1. Download `CTLD_Next.lua` from the [latest release](../../releases/latest).
2. Add a **DO SCRIPT FILE** trigger in the DCS Mission Editor pointing to `CTLD_Next.lua`.
3. Optionally add a second trigger with your `CTLD_userConfig.lua` to override defaults.

## Compatibility

- DCS World (any map)
- Lua 5.1 (DCS sandbox)
- No MIST dependency required

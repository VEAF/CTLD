# Mission Maker guide

This section is for **mission makers** — how to add CTLD to a mission and configure it in the DCS
Mission Editor and the `CTLD_userConfig.lua` file. If you want to *operate* CTLD from the cockpit
(the F10 menu), see the [Pilot guide](../pilot/index.md) instead.

## Getting started

1. Add `CTLD.lua` to your mission with a **MISSION START → DO SCRIPT FILE** trigger. CTLD runs on
   its built-in defaults, so this alone is enough to play.
2. To customise anything, produce a configuration with
   [`ctld-tools`](ctld-tools.md) and let it inject a `CTLD_userConfig.lua` trigger into your
   mission — **before** the `CTLD.lua` trigger.
3. Configure the pieces you need using the pages below.

All settings are read through `ctld.gs("paramName")` at runtime. Your configuration is a **complete
snapshot** carried by `ctld.configUser` in `CTLD_userConfig.lua`, not a list of overrides — see
[Configuration](configuration.md).

## Configuration topics

| Page | What you configure |
| --- | --- |
| [Configure with `ctld-tools`](ctld-tools.md) | The recommended way to configure CTLD: a local app, forms instead of Lua, injection into your `.miz` |
| [Configuration](configuration.md) | Global settings and per-aircraft capabilities (`capabilitiesByType`) |
| [Zone setup](zones.md) | Troop zones (TRZ, including extract objectives), logistics zones (LGZ), waypoint zones (WPZ), AI zones (AIZ) |
| [Scenes & FOB](scenes-fob.md) | Scene deployment (FARP, minefield…) and Forward Operating Bases |
| [Crate catalogue](crates-catalogue.md) | `spawnableCrates`, and the crate/vehicle/AA/JTAC definitions pilots can spawn |
| [Minefield](minefield.md) | Minefield scene setup |
| [Translations](translations.md) | Localisation and translation overrides |
| [Legacy API](legacy-api.md) | v1 `ctld.*` compatibility for existing mission scripts |

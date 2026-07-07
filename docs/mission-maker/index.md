# Mission Maker guide

This section is for **mission makers** — how to add CTLD to a mission and configure it in the DCS
Mission Editor and the `CTLD_userConfig.lua` file. If you want to *operate* CTLD from the cockpit
(the F10 menu), see the [Pilot guide](../pilot/index.md) instead.

## Getting started

1. Add `CTLD.lua` to your mission with a **DO SCRIPT FILE** trigger.
2. Optionally add a second **DO SCRIPT FILE** trigger loading your `CTLD_userConfig.lua` to
   override defaults.
3. Configure the pieces you need using the pages below.

All settings are read through `ctld.gs("paramName")` at runtime; you set them in
`CTLD_userConfig.lua` (`_cfg.settings[...]`).

## Configuration topics

| Page | What you configure |
| --- | --- |
| [Configuration](configuration.md) | Global settings and per-aircraft capabilities (`capabilitiesByType`) |
| [Zone setup](zones.md) | Troop zones (TRZ, including extract objectives), logistics zones (LGZ), waypoint zones (WPZ), AI zones (AIZ) |
| [Scenes & FOB](scenes-fob.md) | Scene deployment (FARP, minefield…) and Forward Operating Bases |
| [Crate catalogue](crates-catalogue.md) | `spawnableCrates`, and the crate/vehicle/AA/JTAC definitions pilots can spawn |
| [Minefield](minefield.md) | Minefield scene setup |
| [Translations](translations.md) | Localisation and translation overrides |
| [Legacy API](legacy-api.md) | v1 `ctld.*` compatibility for existing mission scripts |

# Mission Maker guide

This section is for **mission makers** — how to add CTLD to a mission and configure it in the DCS
Mission Editor and the `CTLD_userConfig.lua` file. If you want to *operate* CTLD from the cockpit
(the F10 menu), see the [Pilot guide](../pilot/index.md) instead.

## Getting started

**Download `ctld-tools.exe` from the [latest release](https://github.com/VEAF/CTLD/releases) and run
it.** That is the whole installation: the tool carries CTLD and its beacon sounds, and writes
everything into your mission.

1. **Run the tool.** It opens in your browser, locally — no installation, no account, nothing to
   configure first. If Windows blocks it on first launch, see [below](#windows-says-it-blocked-the-app).
2. **Open config or mission…** and pick your `.miz` — or start from the CTLD defaults if you are
   configuring before you have a mission. Opening a mission that already has CTLD brings its
   configuration back, ready to edit: that is how you resume work on a mission you set up weeks ago,
   with no side file to keep.
3. **Adjust what you need** (the pages below describe each area), then **Install into mission…**

The tool writes four things into the `.miz`: `CTLD.lua`, the two beacon sound files, your
configuration, and the MISSION START triggers that load them in the right order. It reports what it
wrote, and re-installing replaces rather than duplicates.

!!! info "Why a trigger plays the beacon sounds at mission start"
    One of those triggers plays both `.ogg` files at mission start. It is not there for you to hear:
    the Mission Editor discards any file no trigger refers to when it saves a mission, and without it
    your beacons would fall silent the next time you opened the mission in the editor. It runs before
    anyone is in a cockpit, so nobody hears it.

### Windows says it blocked the app

`ctld-tools.exe` is not code-signed — a certificate costs money a community project has no reason to
spend — so Windows treats it as coming from an unknown publisher. Nothing is wrong with the download;
you have to say so once:

- **"Windows protected your PC"** (the blue SmartScreen window) → click **More info**, then
  **Run anyway**.
- **Properties → Unblock.** If the file came through a browser, Windows tags it as downloaded from the
  internet. Right-click `ctld-tools.exe` → **Properties** → tick **Unblock** at the bottom of the
  General tab → **OK**, then run it.
- **Your antivirus quarantined it.** Single-file executables built with PyInstaller are a common false
  positive. Restore the file, and add an exclusion for it if your antivirus insists.

Every release is built by a public GitHub workflow from the tagged source, so you can check where the
executable comes from before running it.

??? note "Installing by hand"
    Everything the tool writes is also attached to each release, if you prefer doing it yourself:

    1. add `CTLD.lua` to the mission with a **MISSION START → DO SCRIPT FILE** trigger — on its own,
       CTLD runs on its built-in defaults, which is enough to play;
    2. add `beacon.ogg` and `beaconsilent.ogg` to the mission, or **beacons will be silent**;
    3. to customise anything, add your `CTLD_userConfig.lua` as a second `DO SCRIPT FILE` trigger,
       **before** the `CTLD.lua` one — the engine reads the configuration as it loads.

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

# CTLD

Complete Troops and Logistics Deployment for DCS World — **v2 modular rewrite**

CTLD lets players transport troops, vehicles and supply crates, build FOBs and FARPs, deploy JTACs,
radio beacons, smoke and minefields — all from the F10 radio menu. v2 is a full rewrite of the
original script into tested, modular Lua, delivered as a single `CTLD.lua`.

**📖 [Read the documentation](https://veaf.github.io/CTLD/)** — pilot, mission maker and developer
guides, in English and French.

---

## Installation

**Download [`ctld-tools.exe`](../../releases/latest) and run it.** That is the whole installation:
the tool carries CTLD and its beacon sounds, and writes everything into your mission.

1. **Run the tool.** It opens in your browser, locally — no installation, no account.
2. **Open config or mission…** and pick your `.miz`. Opening a mission that already has CTLD brings
   its configuration back, ready to edit.
3. **Adjust what you need**, then **Install into mission…**

The tool writes `CTLD.lua`, the two beacon sound files, your configuration, and the MISSION START
triggers that load them in the right order. Re-installing replaces rather than duplicates.

Full walkthrough: **[Mission maker guide](https://veaf.github.io/CTLD/dev/mission-maker/)**.

### Getting a newer CTLD

`ctld-tools.exe` **carries the CTLD it installs** — the `CTLD.lua` built from the commit its own
release was tagged on, embedded in the exe. It downloads nothing and never updates itself, so it runs
with no network and the same exe always installs the same engine.

A new CTLD therefore reaches your missions only once a **release is published**: day-to-day work
merged into the repository changes nothing on your side. To move to it, **download
`ctld-tools.exe` again** from the [Releases page](../../releases) and re-install into your mission.

While v2 is in release candidate, each release is published as a **pre-release** — GitHub keeps the
"Latest" badge for stable releases — so take the topmost entry on the Releases page.

### Windows says it blocked the app

`ctld-tools.exe` is not code-signed — a certificate costs money a community project has no reason to
spend — so Windows treats it as coming from an unknown publisher. Nothing is wrong with the download;
you just have to say so once:

- **"Windows protected your PC"** (SmartScreen blue window) → click **More info**, then
  **Run anyway**.
- **Properties → Unblock.** If the file came through a browser, Windows tags it as downloaded from
  the internet. Right-click `ctld-tools.exe` → **Properties** → tick **Unblock** at the bottom of the
  General tab → **OK**. Then run it normally.
- **Your antivirus quarantined it.** Single-file executables built with PyInstaller are a common
  false positive. Restore the file and add an exclusion for it if your antivirus insists.

Prefer to verify before running? The build is public: every release is produced by
[the release workflow](.github/workflows/release.yml) from the tagged source, on GitHub's runners.

### Installing by hand

Everything the tool writes is also attached to each release, if you prefer doing it yourself:

1. add `CTLD.lua` to the mission with a **MISSION START → DO SCRIPT FILE** trigger — on its own, CTLD
   runs on its built-in defaults, which is enough to play;
2. add `beacon.ogg` and `beaconsilent.ogg`, or **beacons will be silent**. Add them through two
   **Sound to Country** actions pointing at a country your mission does not use (Australia, say), so
   no player hears them at mission start — and so the Mission Editor keeps the files, which it drops
   when nothing refers to them;
3. to customise anything, add your `CTLD_userConfig.lua` as a second `DO SCRIPT FILE` trigger,
   **before** the `CTLD.lua` one — the engine reads the configuration as it loads.

---

## Documentation

| Guide | For |
|---|---|
| **[Pilot guide](https://veaf.github.io/CTLD/dev/pilot/)** | Flying with CTLD: troops, crates, slingload, parachute, beacons, JTAC, smoke, recon |
| **[Mission maker guide](https://veaf.github.io/CTLD/dev/mission-maker/)** | Setting up a mission: the tool, every setting, zones, crate catalogue, scenes & FOBs |
| **[Developer documentation](https://veaf.github.io/CTLD/dev/developer/)** | Architecture, events API, scripting reference, migration from v1, building and testing |

Each release also publishes its own copy of the documentation, so a mission built on an older CTLD
can be read against the pages that matched it — pick the version from the selector at the top of any
page.

---

## Features

- **Troops** — load, transport and deploy infantry groups via F10 menu; configurable group compositions (inf / MG / AT / AA / mortar / JTAC / civilian)
- **Vehicles** — load whole light vehicles into C-130 / IL-76 class aircraft and deliver them to any LZ
- **Crates** — spawn, hover-load, drop, and unpack supply crates to build vehicles and AA systems
- **Vehicle Pack** — pack a ground vehicle into crates for air transport, then reassemble it on the other side
- **Virtual Parachute** — drop troops, crates or vehicles by parachute with inertia and lateral drift simulation
- **Virtual Slingload** — simulate cargo sling loading without DCS sling-load physics bugs (hover detection, overspeed loss)
- **FOB Construction** — assemble a Forward Operating Base from dropped crates; becomes a new spawn and logistics point
- **FARP Deployment** — deploy a Forward Arming and Refuelling Point using a helicopter-carried crate sequence
- **FARP Pack** — pack a deployed FARP scene back into crates and redeploy it elsewhere; warehouse fuel levels snapshot and restore
- **Radio Beacons** — deploy homing beacons (VHF / UHF / FM) usable by all ADF-capable aircraft; battery timer; optional F10 map layer
- **JTAC Auto-Lase** — deploy JTAC units that auto-lase the nearest enemy, mark with smoke, give 9-lines, orbit (drones), optional SRS speech
- **Smoke Drop** — drop coloured smoke grenades from the F10 menu; optional auto-resume keeps smoke visible continuously
- **Recon** — scan areas for enemy contacts and display them as F10 map markers with configurable layer and auto-refresh
- **Minefield** — deploy a staggered landmine field in front of the transport; optional F10 map outline; player-triggered clear
- **AA Systems** — multi-crate assembly: HAWK, NASAMS (BLUE), KUB, BUK (RED), Patriot, S-300; repair crates; configurable limits per coalition
- **AI Zones** — pickup and dropoff zones for AI transports, independent of player zones; troops, vehicles, scenes and AA systems
- **Waypoint Zones** — automatically route deployed troops to an objective marker
- **Extract Zones** — count troops rescued to a zone; drive DCS flag triggers
- **i18n** — English (default), French, Spanish, Korean
- **No MIST dependency** — v2 runs standalone
- **Events API** — 38 typed events via `EventDispatcher`; subscribe per-event with callbacks
- **CI-built** — every commit produces a validated `CTLD.lua`; releases published on GitHub Releases

---

## Configuration

A mission's configuration is a **complete YAML snapshot** carried by `ctld.configUser`, written by
`ctld-tools` and read by the engine at load time. Every setting is documented, with its default and
its effect, in the **[configuration reference](https://veaf.github.io/CTLD/dev/mission-maker/configuration/)**.

Zones are declared in the Mission Editor by naming convention (`TRZ_`, `LGZ_`, `WPZ_`) and picked up
at init without any configuration — see **[zones](https://veaf.github.io/CTLD/dev/mission-maker/zones/)**.

## Coming from CTLD v1

Existing missions keep working: the 22 legacy `ctld.*` functions are preserved as wrappers that log a
deprecation warning and delegate to their v2 equivalent. The
**[migration guide](https://veaf.github.io/CTLD/dev/developer/migration-v1-v2/)** lists every mapping,
including the `addCallback` → typed events transition, and the deliberate departures from v1.

## Contributing

```powershell
powershell -ExecutionPolicy Bypass -File tools\build\merge_CTLD.ps1   # rebuild CTLD.lua
busted tests/ci/                                                      # run the test suite
```

`CTLD.lua` is generated — never hand-edit it. See
**[building and testing](https://veaf.github.io/CTLD/dev/developer/building-and-testing/)** for the
toolchain, the quality gates and the pull-request workflow.

---

## License

Originally created by Ciribob, maintained by Zip and the [VEAF Team](https://www.veaf.org).

Open-source and free (use, modify, fork, even commercial profit). Credit is appreciated.
Reach out to [Zip on Discord](https://discordapp.com/users/421317390807203850) to participate.
[Buy me a coffee](https://coff.ee/veaf_zip) if you'd like to support the work.

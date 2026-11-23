# CTLD 2.1.0

## Installation

1. Download **`ctld-tools.exe`** below — it is the only file you need.
2. Run it: the tool opens in your browser, locally, with nothing to install.
3. Open your `.miz`, adjust what you want, then **Install into mission**: the tool writes CTLD, the beacon sounds and your configuration into it.

**Windows blocks it on the first run?** The tool is not code-signed, so SmartScreen stops it: click **More info** → **Run anyway**.
If the file came through a browser you may also need right-click → **Properties** → tick **Unblock** → **OK**.

Prefer doing it by hand? The files are attached to this release too — see the [documentation](https://veaf.github.io/CTLD/2.1.0/mission-maker/).

---

CTLD 2.1.0 brings back several CTLD 1.x behaviours that 2.0.0 had lost, and makes pack and unpack safe when DCS refuses to create something.
A mission configuration written for 2.0.0 keeps working: open it in `ctld-tools` and the new settings get their defaults.

## Read this before you update

Three defaults change, to match CTLD 1.x again:

- **Dropped groups act on their own.** Troops and vehicles dropped by a pilot, by parachute or by an AI transport go for the nearest enemy within `maximumSearchDistance` (now 4000 m, as in 1.x), otherwise walk to a random point within the new `maximumMoveDistance` (2000 m). To keep them where they are dropped, set both distances to `0`.
- **Players can drive what CTLD creates.** Dropped troops, unloaded vehicles, unpacked crates and SAM systems are created drivable again, for Combined Arms players and game masters. The new setting `spawnedUnitsPlayerCanDrive: false` gives back the 2.0.0 behaviour.
- **Inactive zones stay inactive.** A `troopZones` or `wpZones` entry marked `no` was active from the start; it now waits for its activation, as in 1.x. Only `yes` (or `1`) opens a zone at load.

A SAM system's group is now named `<type>_CTLD_AA_<id>`: a mission script that looked for the old `<type>_CTLD_AA_<second>` name must be adapted.

## What changes in game

- **Nothing is lost when DCS refuses.** Pack a vehicle, a FARP or a Fat Cow FARP, unpack crates, assemble, rearm or repair a SAM: the new object is created first, and the old one goes only once the new one exists. If DCS refuses, you keep what you had and you get a message.
- **Parachuted troops keep their weapons.** Every parachuted group used to land as AK riflemen; a Mortar Squad now lands with its mortar, blue troops with blue weapons.
- **SAM repair crates** (HAWK, NASAMS, BUK, KUB, Patriot, S-300) can be requested from **Request Equipment** again.
- **Two SAM systems of the same type** built in the same second no longer replace each other.
- **Coalition messages name the pilot** ("Viper started building a FOB"), not the slot.
- **Fat Cow**: a landed CH-47 is no longer taken for an airborne one (its FARP opens, and **Release** no longer makes it take off); an AI cow that cannot open its FARP tells the flight why; the **Take over a Fat Cow** list numbers the cows and no longer changes under your finger; an empty `fatCowAIType` removes only **Request a Fat Cow**, not the whole menu.
- **A parachuted equipment crate** that cannot be unpacked on landing tells the pilot who dropped it why.
- **A FARP packed while it lays itself out** no longer leaves orphan objects behind.

## For mission makers

- New option `forbidUnpackInLogisticZone` (off by default): when on, ordinary crates cannot be unpacked in a friendly logistic zone, as with `minimumDeployDistance` in 1.x.
- The labels of the configuration (crate and group names) follow the configuration's own `i18n_lang`.
- The scripted troop drops `ctld.unloadTransport` and `ctld.unloadInProximityToEnemy` work again.

## For script and layer authors

- Four new events: `OnTroopsLoaded`, `OnTroopsUnloaded`, `OnTroopsExtracted`, `OnTroopsReturned` (the v1 troop callbacks map to them, see the [migration page](https://veaf.github.io/CTLD/2.1.0/developer/migration-v1-v2/)).
- `OnCrateUnpacked` now gives the `groupName` it created, and the SAM events give the `crateNames` they consumed.
- No field was renamed or removed.

See the [documentation](https://veaf.github.io/CTLD/2.1.0/) for pilots and Mission Makers, and `CHANGELOG.md` for the full list.

---

CTLD 2.1.0 is the work of FullGas and Zip, of the VEAF.
Thanks to the VEAF pilots who fly CTLD on the Open Trainings and report what goes wrong.

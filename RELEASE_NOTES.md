# CTLD 2.0.0-rc13 — release candidate

## Installation

1. Download **`ctld-tools.exe`** below — it is the only file you need.
2. Run it: the tool opens in your browser, locally, with nothing to install.
3. Open your `.miz`, adjust what you want, then **Install into mission**: the tool writes CTLD, the beacon sounds and your configuration into it.

**Windows blocks it on the first run?** The tool is not code-signed, so SmartScreen stops it: click **More info** → **Run anyway**.
If the file came through a browser you may also need right-click → **Properties** → tick **Unblock** → **OK**.

Prefer doing it by hand? The files are attached to this release too — see the [documentation](https://veaf.github.io/CTLD/2.0.0-rc13/mission-maker/).

---

The biggest release candidate so far.
F10 clicks fire the command you clicked, crates for native-cargo aircraft appear where the DCS cargo window can load them, native cargo is read from DCS itself, and missions without USA or Russia in their coalitions get their crates again.
Mission scripts that name zones or read zone events need a look: see **Breaking changes** at the end.

## An F10 click fires the command you clicked

Players reported clicking one F10 CTLD entry and getting another, sometimes another group's.
The cause is in DCS: when a menu entry is removed, its internal id goes to the next entry created anywhere on the server, and an F10 screen left open keeps the ids it was drawn with.
CTLD rebuilt its whole menu on every refresh, so a screen opened before a refresh pointed at ids now held by other commands.

A refresh now only touches the entries that changed: an unchanged entry keeps its id and fires itself.
A click on an entry that has just disappeared does nothing, instead of firing whatever took its place.
The 4-second blank menu after a background refresh, introduced in rc10 to work around this, is gone.

## Crates appear where a native-cargo aircraft can load them

Crates requested for a UH-1H, Mi-8MT, CH-47F, Mi-24P or C-130J-30 used to appear 20 m or more away, out of reach of the DCS cargo window.
They now stand in a row just clear of the hull: abeam for the helicopters, behind the C-130J-30.
**Request Equipment**, **Pack Vehicle**, packing a FARP and **Drop Crate(s)** all follow this rule; a dropped row stands a little farther (`crateDropExtraDistance`, 2 m) so you can taxi or lift off without touching it.
Every crate now stands parallel to the aircraft it was created for.

Where crates appear is declared per aircraft type in `capabilitiesByType` (`crateSpawnSector`, `crateSpawnDistance`), with defaults for the five types above; any other type keeps the previous layout.
In a `slingLoad: true` mission, crates keep the previous layout, since the sling container has no measured size.

## Native cargo is read from DCS itself

Crates and whole vehicles loaded through the DCS cargo window are now detected from the aircraft's own on-board cargo list, instead of a position test against a box far larger than any cargo bay.

- A vehicle released by DCS, on the ground or by parachute, is detected and its JTAC resumes lasing.
- **Unload Vehicles**, **Parachute Vehicle**, **Drop Crate(s)** and **Parachute Crates** apply only to what you loaded through the F10 menu: they no longer duplicate cargo DCS is carrying, and CTLD no longer adds that cargo's weight on top of DCS's own.
- On the UH-1H and CH-47F, a crate loaded through the cargo window is handed to CTLD only once DCS has actually released it, which needs the doors open on the ground. A new F10 action, **Crate Commands > Fit parachute**, does it when you are ready.
- The **CH-47F** now carries whole vehicles by default (the *Vehicle Commands* menu). Not yet checked in a live CH-47F.

## Missions without USA or Russia get their crates again

In a mission whose coalitions hold neither USA nor Russia (CJTF Blue and CJTF Red, for instance), a requested crate never appeared: CTLD created it under a country DCS refused.
Crates, vehicles, JTACs, troops and beacons are now created under the country of the requesting aircraft, or a country of its coalition.
A creation DCS refuses is now logged and reported to the pilot instead of passing in silence.

## JTAC: imposed laser codes and radios are respected

- A laser code imposed on a JTAC by a script is reserved: no automatic JTAC takes it, and a JTAC that already had it moves to another code and announces it.
- A radio passed to a JTAC by a script is used as given, as in CTLD 1.x.
- Automatic codes leave out the digits 0 and 9.
- A late-activated JTAC group is coded when it activates, not at mission start.

## Mission Editor naming

- `TRZ_<name>_<coalition>_<stock>_<flag>_<target>` now works on a static, a unit or a group, not only a trigger zone: name a bunker, a ship or a convoy and it becomes a troop pickup zone, which moves with it and disappears when it dies.
- A pre-placed group named `EXTR_<name>` is extractable without an `extractableGroups` entry.

## Configuration

- **`enableParachuteDrop`** (default `true`) removes every parachute action from the F10 menu mission-wide when set to `false`.
- **`ctld-tools` completes an older configuration** when it opens it: settings and fields added since it was saved get their default, listed in a summary with an Undo for each.
  A value you set is never changed.
  The header shows the configuration's version and the tool's catalogue version (now `2.2.0`).

## Other fixes

- Crate requests and troop loads from auto-discovered zones (`LGZ_`, `TRZ_`) work again; zones sharing a short name are no longer mistaken for each other.
- A troop zone whose anchor is gone, with or without a death event, is no longer offered.
- A failed equipment request or a failed troop parachute drop tells the pilot instead of doing nothing.
- The first seconds after entering an aircraft no longer lose clicks to a menu rebuild.
- The native-cargo messages are translated (FR, ES, KO).
- `onUnitDead` no longer floods the log.

## Breaking changes (mission scripts)

- **Zones are named by their full name.** `TRZ_`, `LGZ_` and `WPZ_` zones, and zones created by `createTroopZoneAtObject`, register under their full DCS name. The zone accessors of `CTLDZoneManager` and their legacy wrappers (`ctld.activatePickupZone`, `ctld.changeRemainingGroupsForPickupZone`…) expect that full name: a script passing the short name (`dropzone1` for `TRZ_dropzone1_B_0_nil_0`) no longer finds the zone.
- **Zone events** (`OnZoneSmokeRefreshed`, `OnTroopZoneUpdated`, `OnLogisticZoneUpdated`) identify every zone by `name`, its full name; the `fullName`, `zoneName` and `unitName` fields are gone.
- **A troop zone anchored to a unit, group or static is removed when its anchor dies**, as logistic zones already were, instead of staying usable at its last position.

---

Thanks to **FullGas** for the F10 report that led to the menu fix, and to the VEAF Syria Open Training for the JTAC findings.

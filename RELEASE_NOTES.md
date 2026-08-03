# CTLD 2.0.0-rc3 — release candidate

CTLD 2.0 is a **complete rewrite** of the CTLD v1 script: the monolith becomes a set of **testable**
Lua modules (Manager/Entity object design), covered by continuous integration — one build, more than
1,100 unit and functional tests, plus integration tests in a live DCS.

This **rc3** makes CTLD speak up. Most of what it brings comes down to one idea: what used to be
**silent or unreachable** is now said or callable. A logistic point is declared by aircraft type
instead of unit by unit, a beacon can be placed from a script with no pilot in a cockpit, a troop
pickup zone sitting on a carrier finally follows the carrier — and three situations that used to be
hidden from you are announced at mission start.

It also adds the **Gazelles and the Yak-52**, missing from the catalogue since the beginning.

## What's new

- **Declare your logistic points by aircraft type.** The new `logisticUnitTypes` setting takes DCS
  type names: every unit **and every static** in the mission whose type is listed becomes a logistic
  point, without you naming it. The zone follows the object, so a carrier keeps its logistic point
  under way. No more copying ten unit names from one mission to the next:

  ```yaml
  logisticUnitTypes:
  - Stennis
  - CVN_71
  - FARP Ammo Dump Coating
  ```

  A listed type that no object in the mission carries is not an error: this is a catalogue, reusable
  as it is from mission to mission.

- **Same for ship pickup points**, with `troopZoneShipTypes`. Every ship of a listed type becomes a
  troop pickup point with unlimited stock, anchored to the vessel.

- **A radio beacon can be placed by a script.** Until now everything went through a pilot's F10 menu:
  a FARP built by a script could not carry a beacon. `createAtPoint()` places one at any point and
  returns its three frequencies; `removeBeacon()` removes it by name:

  ```lua
  local beacon = CTLDBeaconManager.getInstance():createAtPoint(
      point, coalition.side.BLUE, country.id.USA,
      { name = "FARP Alpha NDB", batteryMinutes = -1 })
  -- beacon:freqText() → "245.00 kHz - 350.50 / 45.20 MHz"
  ```

- **Five more aircraft.** The four **Gazelles** (`SA342L`, `SA342M`, `SA342Minigun`, `SA342Mistral`)
  and the **Yak-52** finally have their capabilities declared: one soldier, no crates — what v1 gave
  them. Their pilots get troop transport, beacons and smoke back.

## Important for mission makers

⚠️ **The Ka-50 is no longer a transport.** In v1 it slung crates and carried soldiers — not by choice,
but because it appeared in neither capability table and inherited the defaults. CTLD 2 does not carry
that over: a single-seat attack helicopter is not a transport. Its pilots keep the CTLD menu, RECON
and JTAC status; they lose crates, troops and beacons. **If your mission needed it, add the entry
yourself** — that is configuration, not engine behaviour, and the migration guide explains how.

- **A troop pickup zone on a ship uses a 200 m radius**, v1's value, instead of following the
  `maximumDistancePackableUnitsSearch` setting. No effect unless you had changed that setting.

- **For script authors**: `createAtZone(..., batteryLife = -1, ...)` now means "never expires".
  Previously that value produced a beacon whose battery was already flat.

- **Three situations that used to be hidden from you are now announced at mission start**, in the
  CTLD report:
    - a v1 configuration still carrying `dropOffZones` — CTLD 2 does not read that setting, and the
      message names its replacement (an `aiZones` entry with `isDropoff: true`);
    - an AI zone ignored because its name is already taken by another zone;
    - a DCS type name that nothing in the mission could ever match, rejected by `ctld-tools` before
      the mission even runs.

## Fixes you will see in game

- **A troop pickup zone carried by a ship finally follows its ship.** It was frozen at the vessel's
  position at mission start: a carrier got under way and left its pickup point in the middle of the
  water, without a single message. v1 recomputed the position on every check; that behaviour is
  restored. Nothing to change in your missions.

- **An ignored `aiZones` entry now says so.** When its name was already used by another zone it was
  dropped in silence, and you got an AI zone that did nothing. The trap is easy to fall into: a
  `TRZ_dropzone1_B_0_nil_0` zone occupies the name `dropzone1`, so an AI zone called `dropzone1` —
  even though it points at a genuinely different editor zone — collided with it. The fix is two
  distinct names.

- **`ctld-tools` accepts the modded units you declare.** The `modTypes` setting exists precisely for
  that, but the tool still rejected a modded crate and blocked the export.

## Documentation

- The **v1 → v2 migration guide** gains two sections: what becomes of `dropOffZones` (with a
  before-and-after example), and which aircraft are transports — including the Ka-50 explanation.
- The **Zones** page states a rule that was written nowhere: `TRZ_`, `WPZ_`, AI zones and the legacy
  `troopZones` table share **one** name space, and the first zone registered wins.
- The **Configuration** page no longer claims that an aircraft absent from the catalogue has no CTLD
  menu at all: it has one, it simply carries nothing. "The menu is there but empty" now has a
  documented cause.

## Contributors

**FullGas** (lead developer), **Zip** (technical support) — VEAF.

This rc3 comes out of the integration audit run to move the **VEAF Mission Creation Tools** onto
CTLD 2: four gaps were found there, all fixed here, and three more defects were discovered along the
way.

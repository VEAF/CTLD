# FEAT-NATIVE-CRATE-SPAWN-NEAR — spawn crates just clear of a native-cargo aircraft so DCS can load them

**Status:** ⬜ ready

Follows `FIX-NATIVE-CARRY-DETECTION` (roadmap entry "Pack — distance de spawn des caisses trop grande pour un
chargement natif (Mi-8MT)") and a `grill-with-docs` session held 2026-10-01. See **ADR 0024** for the decision
and its reasoning, and the **Crate spawn clearance** glossary term in `CONTEXT.md`.

## Problem Statement

A pilot of a helicopter with a native cargo system (Mi-8MT, UH-1H, CH-47F, Mi-24P) requests crates from
Request Equipment, or packs a vehicle, and the crates appear 23 m or more from the aircraft: the first at the
secure distance plus 5 m (the horizontal diagonal of the model's UserBox, rotor disc included), every further
one another 5 m out. DCS loads a crate through its native cargo UI only when the aircraft is close to it. In a
live session a crate at 23 to 28 m answered "FAILED TO LOAD CARGO" and one at about 5 m loaded, so the pilot has
to taxi or hover next to each crate in turn. The distance is far larger than the real hull needs: at crate height
the Mi-8MT hull reaches 2.5 m to the side, the UH-1H 1.5 m.

## Solution

Crates for a native-cargo aircraft appear just clear of its real hull, on the side the aircraft is loaded from,
all within native loading range: the pilot requests (or packs) and loads them without repositioning. Each
aircraft type declares its own crate spawn sector and distance, computed from the model's collision shell plus a
1.5 m margin and confirmed in a live mission. A type that declares nothing keeps today's behaviour exactly.

## User Stories

1. As a Mi-8MT pilot, I want the crates I request to appear within native loading range, so that I can load them
   with the DCS cargo UI without moving the helicopter.
2. As a UH-1H pilot, I want my crates a few metres from the helicopter's side, so that a native load converts them
   into CTLD crates at once.
3. As a CH-47F or Mi-24P pilot, I want the same, so that every native-cargo helicopter behaves alike.
4. As a pilot packing a vehicle into crates, I want all the crates close to the aircraft, so that the last crate is
   as loadable as the first.
5. As a pilot requesting a set of crates, I want the whole set in a tidy row, so that I can load them one after
   the other from one spot.
6. As a pilot, I want crates never to touch the hull, the skids or the wheels of my aircraft, so that a spawn does
   not damage or detonate anything.
7. As a pilot, I want crates never to touch each other, so that none is pushed or damaged at spawn.
8. As a C-130J-30 pilot, I want my crates behind the ramp, as before, but much closer than 30 m, so that the
   loadmaster loads them quickly.
9. As a pilot of an aircraft that is not a native-cargo type, I want nothing to change, so that my crates appear
   where they always did.
10. As a pilot, I want vehicles to keep appearing clear of the rotor disc, so that no change to crates endangers my
    rotor.
11. As a pilot unpacking crates beside my aircraft, I want the built vehicle still to appear 50 m or more away, so
    that it never stands under the rotor.
12. As a pilot parked beside another aircraft, I want my crates not to spawn inside its volume, so that I get a
    clear spot on the other side.
13. As a mission maker, I want each type's crate spawn sector and distance in `capabilitiesByType`, so that I can
    tune them or add a modded type.
14. As a mission maker, I want a type with no value to keep the old rule, so that adding an aircraft never breaks
    its crates.
15. As a mission maker, I want the crate size and the gap between crates configurable, so that a new crate model
    is laid out correctly.
16. As a mission maker, I want the editor and the validation to know the new fields, so that I cannot mistype one.
17. As a maintainer, I want the distance of each type derived by a reproducible script from its collision shell, so
    that a DCS update can be re-measured.
18. As a maintainer, I want the layout computed by one pure function, so that it is testable without DCS.
19. As a tester, I want the native loading range of each owned helicopter measured in a live mission, so that the
    declared distances are proven reachable.
20. As a maintainer, I want the documentation to say which values are measured in game and which come from the file
    alone, so that nobody trusts an unverified type.

## Implementation Decisions

- **New capability fields** in `capabilitiesByType`: `crateSpawnSector` (`rear`, `side` or `front`) and
  `crateSpawnDistance` (metres, aircraft centre to the first crate). Both optional; a type declaring neither keeps
  the current rule (secure distance + 5 m, rear sector for native-cargo types, front otherwise, radial layout,
  `crateSpacing` between crates). The schema, the default configuration, the generated defaults, the editor and
  the documentation of `capabilitiesByType` carry the fields.
- **New settings:** `crateSizeByType` (largest horizontal extent in metres per crate DCS type, `ammo_cargo: 1.31`;
  unknown type: 1.5) and `crateSpawnGap` (0.5 m between neighbouring crates' edges).
- **Defaults by type** (hull radius at crate height plus 1.5 m): UH-1H side 3.0, Mi-8MT side 4.0, CH-47Fbl1 side
  3.7, Mi-24P side 5.1, C-130J-30 rear 11.3. `Hercules` and `76MD` have no native cargo and no value.
- **Layout.** One pure function takes the aircraft position and heading, the sector, the distance, the crate sizes
  and the number of crates, and returns the positions: the crates stand in a row perpendicular to the sector axis,
  centred on the aircraft, at the given distance; neighbours are `size/2 + gap + size/2` apart (sizes of the two
  crates concerned, so a mixed set stays collision-free). A row holds as many crates as fit along the aircraft's
  own box (length for the side sector, width for rear and front); the next row is one step further out. The side
  is chosen at random for the whole wave and flipped when the other aircraft's volume check says the first is
  taken; the existing avoid-box rotation remains the last resort.
- **Callers.** Crates requested as a set and crates produced by packing a vehicle (`spawnCratesAligned`), and the
  single crate of Request Equipment, use the new layout when the requesting aircraft's type declares a sector and
  a distance. Vehicles, crates dropped from the hold, scenes, troops and the vehicle unpack distance
  (`MIN_UNPACK_DIST`, 50 m) are unchanged, and `getSecureDistanceFromUnit` is not modified.
- **Derivation script.** A script reads each model's collision shell, keeps the static hull pieces, cuts them at
  crate height above the ground, and prints the hull radius per sector; it documents where each default comes
  from. The UH-1H comes from `ab-212_collision.edm` (the same model), the others from their own collision files.
- **Live calibration.** The native loading range of the Mi-8MT and the UH-1H is measured in a live mission with a
  runtime override of the distance, and the declared values are confirmed or lowered.

## Testing Decisions

- A good test drives the layout or the spawn through its public entry and asserts positions and counts (distance
  from the aircraft, spacing, side, row wrap, fallback), not the helper that computed them.
- **Seams, highest first:** (1) the crate spawn entry (`spawnCratesAligned` over doubles of an aircraft and the
  static spawn) for Pack and Request sets and the single crate path; (2) the pure layout function; (3) the
  configuration: defaults parse, schema and generated defaults agree (`config_defaults.json` round trip).
- Prior art: `crate_manager_spec.lua`, `crate_lifecycle_spec.lua`, `config_spec.lua` and the zone specs added by
  `FIX-ZONE-REGISTRY-KEY`.
- A live checklist (ticket 04) covers what doubles cannot: DCS's real loading range, no visual collision, and a
  full request-then-load on the Mi-8MT and UH-1H. The CH-47F, the Mi-24P and the C-130J-30 rear distance are not
  measured by the owner's session beyond what is available (C-130J-30 yes, CH-47F and Mi-24P no).
- Coverage gate is a ratchet and only goes up; luacheck stays clean.

## Out of Scope

- Vehicles, troops, scenes (FOB, AA systems), crates dropped from the hold, the vehicle unpack distance.
- Changing the native load range itself, or loading crates for the player.
- A hull or crate size read live from DCS.
- Fixed-wing types other than the C-130J-30 (`Hercules`, `76MD` have no native cargo), and any other helicopter
  with no collision shell available (such a type keeps the old rule until someone declares values).
- Adopting untracked cargo, converting vehicles and the other native-carry follow-ups already in the roadmap.

## Further Notes

- A heavy static spawned overlapping a hull can detonate (a C-130 was lost on 2026-09-16): values are derived from
  the real hull, never guessed, and every live measurement starts far and goes closer in steps, with a light crate
  on a clear site.
- The `Mi-24P` and `CH-47F` values come from their collision shell only; the project owner has neither module.
- `missions/Test_CTLDNEXT_01.miz` and `tests/dcs/dev/diag/diag_bbox_draw.lua` must not be committed.

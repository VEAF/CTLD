# FIX-CRATE-DROP-PLACEMENT

**Status:** merged (PR #248). Compacted from `FIX-CRATE-DROP-PLACEMENT/` on 2026-10-09; the ticket files live on in git history.

From the `dev/roadmap.md` entry noticed in the live check of `FIX-NATIVE-CRATE-CTLD-ACTIONS`: *Drop Crate(s)* ignored the crate spawn plan of ADR 0024 and the anti-collision that Request Equipment uses, so a crate dropped on a native-cargo helicopter landed 20 m or more away, out of DCS's loading range. Placement is now two shared routines (plan row; radial rule, both with anti-collision); Drop uses them with one size per crate. New setting `crateDropExtraDistance` (default 2 m, catalogue **2.2.0**) keeps the dropped row slightly farther so the aircraft can leave without touching it (ADR 0024 addendum). Not yet confirmed in game.

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-shared-placement-and-drop` | ✅ done (PR #248) | 01 — One placement rule shared by Request Equipment and Drop Crate(s) |
| `02-drop-extra-clearance-setting-and-finalization` | ✅ done (PR #248) | 02 — Extra clearance for dropped crates, catalogue 2.2.0 and finalization |

## PRD

## FIX-CRATE-DROP-PLACEMENT — Drop Crate(s) places crates by the same rule as Request Equipment

**Status:** ✅ done (PR #248)

Formalizes the `dev/roadmap.md` entry "Caisses — « Drop Crate(s) » ne suit pas la règle de position du spawn natif",
noticed in a live check on 2026-10-03 (UH-1H, crate dropped from the F10 menu landing elsewhere than a requested one).
Decisions come from a `grill-with-docs` session held the same day: one placement rule shared by Request Equipment and
Drop Crate(s), plus a small extra clearance for dropped crates.

### Problem Statement

Request Equipment and packing place crates by one rule (ADR 0024): an aircraft type that declares a crate spawn
plan gets its crates in a row just clear of its hull, within DCS's native loading range, with an anti-collision
that moves the row to the other side when it falls inside another aircraft's volume. Types without a plan keep the
older radial rule, also with an anti-collision.

**Drop Crate(s)** ignores all of this. It always uses the older radial rule (the aircraft's secure distance plus 5 m
for the first crate, 5 m more for each next one) with no anti-collision, so:

- on a native-cargo helicopter (UH-1H, Mi-8MT…) a crate dropped from the menu lands 20 m or more away, outside the
  range from which DCS loads a crate through its cargo UI (in game on 2026-10-01 a crate at 23 m was refused, one at
  8 m was loaded), so a pilot who drops crates cannot load them again without repositioning;
- it can land inside the volume of another aircraft parked nearby, which the anti-collision of Request Equipment
  exists to prevent (a crate overlapping an aircraft can trigger a false native load).

Placing dropped crates exactly at the hull-clearance distance raises a second concern, raised by the maintainer: the
aircraft has just landed and must be able to taxi away, or take off (helicopters), without touching the crates it
just dropped.

### Solution

Request Equipment, packing and Drop Crate(s) share one placement rule. Dropped crates stand in a row at the type's
declared distance with the same anti-collision, so they are reachable for loading again; types without a plan keep
the radial rule, now with the anti-collision. A dropped row is placed slightly farther from the aircraft than a
requested one, by a configurable extra distance, so the aircraft can leave without touching it.

### User Stories

1. As a helicopter pilot, I want crates I drop from the menu to land within native loading range, so that I can load
   them again through the DCS cargo UI without repositioning.
2. As a pilot, I want a dropped crate to stand where a requested crate would, so that "drop" and "request" behave
   alike.
3. As a pilot, I want the dropped crates in a tidy row beside the aircraft, so that each is as close as the first.
4. As a pilot, I want the dropped row slightly farther than the hull clearance, so that I can taxi or lift off
   without touching my own crates.
5. As a mission maker, I want the extra clearance to be a setting, so that I can tune it for my missions.
6. As a mission maker, I want a setting of zero to give exactly the requested-crate position, so that I can turn the
   extra clearance off.
7. As a pilot, I want a dropped row not to land inside another aircraft's volume, so that no false native load
   triggers.
8. As a pilot, I want the row to move to the other side when one side is blocked, as for requested crates, so that
   dropping works next to other aircraft.
9. As a pilot of a type without a declared plan, I want dropped crates to keep the current radial placement, so that
   nothing changes for types the plan does not cover.
10. As a pilot of such a type, I want the anti-collision to apply to dropped crates too, so that they avoid parked
    aircraft.
11. As a pilot dropping several crates, I want each crate placed with its own size, so that crates of different
    models do not overlap.
12. As a pilot, I want the "crates dropped at your N o'clock" message to name the real direction, so that I know
    where to look.
13. As a CTLD developer, I want one placement routine for requested, packed and dropped crates, so that the two can
    no longer drift apart.
14. As a CTLD developer, I want busted tests for the plan path, the extra distance, the anti-collision and the
    radial fallback, so that each half of the rule is covered.
15. As a maintainer, I want ADR 0024 to record the extension to dropped crates and the extra clearance, so that the
    reasoning is kept.
16. As a maintainer, I want the new setting in the configuration catalogue with its version tag and documentation
    (EN + FR), so that ctld-tools and the docs know about it.

### Implementation Decisions

- **One routine:** the placement of a wave of crates around an aircraft that declares a spawn plan (row layout,
  axis choice, other-side anti-collision) becomes a routine shared by the wave spawn and by Drop Crate(s); the radial
  rule (with its anti-collision) becomes a shared routine as well. Requested and packed waves behave exactly as
  before.
- **Drop Crate(s)** asks the crate manager for the positions of the crates being dropped, one size per crate (its own
  model), instead of computing them inline. The message keeps using the returned clock direction.
- **Extra clearance:** a new setting, `crateDropExtraDistance` (metres, default 2), is added to the distance of the
  plan for dropped crates only; requested and packed crates are unchanged. It applies only where a plan exists: the
  radial rule already stands the crates 20 m or more away. The loading range limits it: with the declared distances
  (UH-1H 3 m, Mi-8MT 4 m) the dropped row stands at 5 to 6 m, inside the range measured in game (8 m loaded, 23 m
  refused); the value is a default to be confirmed in game and tuned.
- **Radial fallback** keeps the existing axis rule; its anti-collision, already used by Request Equipment, now also
  applies to dropped crates. One behaviour difference to note: the axis rule of the radial path now follows the
  crate manager's "native-cargo-capable" test, as for requested crates, instead of the whole-vehicle capability the
  drop used inline.
- **Catalogue:** adding a setting increments `configVersion` (2.1.0 to 2.2.0), adds the version's shape snapshot and
  the default to `config_defaults.json`; the schema gains the label, unit and description (EN + FR).
- **Documentation:** ADR 0024 gets an addendum (extension to Drop Crate(s), extra clearance); the crate subsystem
  and catalogue pages (EN + FR) describe the shared rule and the setting.
- No i18n key is added.

### Testing Decisions

- A good test observes where the dropped crates end up (distance, side, row, clock direction), not how the routine is
  organised.
- Seam: a new functional spec driving the Drop Crate(s) menu callback of a type with a declared plan and of a type
  without, with a stubbed aircraft heading, collecting the positions handed to the unload. Written first and seen
  failing: with a plan the crates stand in a row at the plan distance plus the extra distance (not on the radial
  rule); a setting of zero gives the plan distance; the row moves to the other side when the first side is inside
  another aircraft's volume; a type without a plan keeps the radial distance and now passes the other aircraft's
  volumes to the radial routine; each crate uses its own size.
- Existing placement tests for requested and packed crates (the crate spawn config spec) pass unchanged: they are the
  guard that the refactor changed nothing for requests.
- ctld-tools: the catalogue version tests, the shape guard and the defaults oracle are updated for 2.2.0 (they run in
  CI; the Python dependencies are not installed on the maintainer's machine).
- Not verified in the cockpit by this lot: the default extra distance of 2 m is a proposal for the maintainer to
  confirm in game (load-again range, room to taxi or lift off).

### Out of Scope

- Changing the declared plan distances of any type.
- The placement of vehicles, or of crates produced by unpacking.
- Any change to what Drop Crate(s) drops (virtual-carry crates only, per `FIX-NATIVE-CRATE-CTLD-ACTIONS`).

### Further Notes

Source: `dev/roadmap.md` entry "Caisses — « Drop Crate(s) » ne suit pas la règle de position du spawn natif". No
GitHub issue to close.

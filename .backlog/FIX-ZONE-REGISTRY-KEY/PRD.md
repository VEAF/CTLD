# FIX-ZONE-REGISTRY-KEY — designate zones by their registry key in menus and event payloads

**Status:** ⬜ ready

Formalizes the `dev/roadmap.md` entry "Crate request menu — logistic zone looked up by short name
(regression of PR #210)" and a `grill-with-docs` session held 2026-10-01. See **ADR 0023** (extends
ADR 0020) for the decision and its reasoning, and the **Zone registry key** glossary term in
`CONTEXT.md`.

## Problem Statement

Since `FIX-AUTODISCOVERED-ZONE-FULLNAME-KEY` (PR #210, ADR 0020) the troop and logistic zone registries
are keyed by the zone's full DCS name, with no short-name fallback. Two F10 menus were not updated and
still hand the zone's **short name** to a registry lookup:

- A pilot who opens **Request Equipment** inside a logistic zone and asks for any crate gets "You are not
  close enough to friendly logistics to get a crate!" and nothing spawns, although the menu itself is
  displayed (confirmed live, 2026-09-30, C-130J-30 on the ground 137 m from the centre of a 200 m zone).
- A pilot who picks **Embark / Extract Troops > Load from <zone> > Load <template>** in an
  auto-discovered troop zone gets "Zone not found."

The registry key is also not a single field: it is the full DCS name for an auto-discovered zone, but the
unit or FOB name for a zone that has no DCS name, so a menu cannot simply read one field. Event payloads
that describe a zone are inconsistent in the same way: `OnZoneSmokeRefreshed` carries both a full and a
short name for troop zones but only a short name for logistic zones, and `OnTroopZoneUpdated` /
`OnLogisticZoneUpdated` carry the short name, so a consumer cannot reliably find the zone in the registry.

## Solution

A zone reports its own registry key. Every place that designates a zone (a menu callback argument, a
lookup, an event payload) uses that key; the short name stays a display label. Crate requests and troop
loads from auto-discovered zones work again, and event payloads identify zones the same way in troop and
logistic entries. Because CTLD is at the release-candidate stage, the payload change is a deliberate
breaking change with no compatibility field (ADR 0023).

## User Stories

1. As a pilot, I want Request Equipment to hand me the crate I picked when I am inside a logistic zone, so
   that I can do my logistics job at all.
2. As a pilot, I want a crate request from a logistic zone to still refuse me when I am outside that zone
   or the zone is inactive or destroyed, so that the proximity rule is unchanged.
3. As a pilot, I want vehicle-type and multi-crate entries of Request Equipment to work the same way as
   single crates, so that no category of request stays broken.
4. As a pilot, I want Load from <zone> to embark troops from an auto-discovered troop zone, so that troop
   pickup works from zones the mission maker only named in the editor.
5. As a pilot, I want troop loading from a FOB troop zone to keep working, so that FOBs stay usable.
6. As a pilot, I want zone names in the menus to stay short and readable, so that the menu does not turn
   into long `LGZ_..._B` strings.
7. As a mission maker, I want a zone placed by naming convention (TRZ_, LGZ_, WPZ_, EXZ_) to work in the
   menus without any extra configuration, so that the convention keeps its promise.
8. As a mission maker, I want zones created by script, by unit, by FOB or by ship to be reachable from the
   menus exactly like editor zones, so that the way a zone was created does not change what pilots see.
9. As a mission maker reading event payloads, I want `name` in a zone entry to be the registry key, in
   troop and logistic zones alike, so that I can look the zone up with one rule.
10. As a mission maker, I want `OnZoneSmokeRefreshed` to identify troop and logistic zones the same way, so
    that one handler serves both.
11. As a mission maker, I want `unitsAdded` / `unitsRemoved` entries to carry the same `name` key, so that
    zone updates are matched to the full zone list without guessing which field to use.
12. As a mission maker, I want the events documentation to show the new payload shape in English and French,
    so that I can update my scripts.
13. As a CTLD developer, I want a zone to answer `registryKey()` itself, so that a new registration path
    only has to make that one method correct.
14. As a CTLD developer, I want a round-trip test (`getXZone(zone:registryKey()) == zone`) over every
    registration path, so that a future change to a registration path cannot silently break the menus again.
15. As a CTLD developer, I want a busted reproduction of both menu callbacks written first, so that the
    regression is proven before it is fixed.
16. As a CTLD developer, I want an audit of every other zone lookup by short name, including the legacy
    compatibility layer, so that no third consumer of the registry is left behind.
17. As a CTLD developer, I want the legacy compatibility layer checked against the original monolith, so
    that I know whether a short-name caller there ever worked.
18. As a CTLD developer, I want the glossary and an ADR to state the rule, so that the next consumer of the
    registry does not reintroduce a short-name lookup.
19. As a maintainer, I want the stale roadmap entry removed when the fix lands, so that the roadmap lists
    only open work.
20. As a maintainer, I want a CHANGELOG entry that separates the bug fix from the breaking payload change,
    so that release notes are accurate.

## Implementation Decisions

- **`registryKey()` on the troop zone and logistic zone classes** returns exactly the key the zone manager
  files the zone under: the DCS name when the zone has one, otherwise the zone's own name field (the unit
  or FOB name). Troop zones fall back to their `zoneName`, logistic zones to their `name`. A troop zone
  created by `createTroopZoneAtObject` carries an explicit key (the `TRZ_` name), because its DCS name is
  the anchor object's, not the key (found by the round-trip test in ticket 03). Every
  registration path (auto-discovered TRZ/LGZ/WPZ/EXZ, FOB troop and logistic zones, logistic units, ship
  and unit-anchored troop zones, AIZ zones, scripted creation) must satisfy the round-trip rule; any path
  where it does not hold is fixed in this lot, not worked around.
- **Menus.** The Request Equipment menu and the Load from <zone> menu pass the zone's registry key as the
  callback's zone argument and keep their registry lookup, so liveness and in-zone checks run at click
  time. The menu label keeps the short name (and the existing `displayName` override for troop zones).
- **Payloads** (`OnZoneSmokeRefreshed`, `OnTroopZoneUpdated`, `OnLogisticZoneUpdated`, and the
  `unitsAdded` / `unitsRemoved` lists): `name` is the registry key for troop and logistic entries alike.
  The `fullName` field and the troop-zone `zoneName` payload field are removed. No short-name field is
  added. This is a breaking change accepted for the RC stage (ADR 0023).
- **Audit.** Every other consumer that passes a name to a zone accessor is checked, including the legacy
  wrapper layer, against `migration/source/CTLD.lua` for parity. A lookup found passing a short name is
  fixed by the same rule. Anything that is a payload or label rather than a lookup follows the payload
  decision above.
- **Documentation.** `docs/developer/events.md` (EN + FR) describes the new payloads; the zones subsystem
  docs (EN + FR) state the registry-key rule. `CONTEXT.md` and ADR 0023 are already written on the branch.
- **Roadmap.** The entry "Crate request menu — logistic zone looked up by short name" is removed from
  `dev/roadmap.md` by the last ticket.
- No i18n string is added or changed; no config schema change.

## Testing Decisions

- A good test drives the menu callback or the manager through its public interface and asserts external
  behaviour (a crate request spawns, a troop load embarks, a payload carries the key), not which private
  field was read.
- **Seams, highest first:** (1) the F10 menu callbacks of the crate and troop managers, built by the real
  menu builders over a real zone manager with an auto-discovered zone: this reproduces both bugs;
  (2) the zone manager's registration paths plus `registryKey()`, via the round-trip rule; (3) the
  published event payloads, captured through the event dispatcher.
- Order: the menu reproductions are written first and must fail before the fix.
- Prior art: `zone_fullname_discovery_spec.lua`, `zone_menu_refresh_spec.lua`, `zone_manager_spec.lua`,
  `troop_zone_scripted_api_spec.lua` and `crate_lgzpoll_spec.lua` (L1/L2, `tests/ci/`).
- No L3+ live-DCS scenario is required for the registry change; one live check of Request Equipment and
  Load from <zone> by the user is the acceptance for the two menus, run before the PR.
- Coverage gate is a ratchet and only goes up; luacheck must stay clean.

## Out of Scope

- A short-name fallback or compatibility field (rejected in ADR 0020 and ADR 0023).
- Renaming the zone objects' own `name` / `zoneName` fields.
- Changes to zone discovery, zone radius or the proximity rule.
- The native-carry work (`FIX-NATIVE-CARRY-DETECTION`), which is an independent lot.
- `ctld-tools` or any other external consumer of the payloads.

## Further Notes

- The roadmap entry reaches this branch through a cherry-pick of `50ed0a9` from `fix/native-carry-detection`,
  which will also carry it into that lot's PR; the later merge conflict is trivial.
- `missions/Test_CTLDNEXT_01.miz` and `tests/dcs/dev/diag/diag_bbox_draw.lua` must not be committed.
- Tickets: 01 `registryKey()` and the two menu fixes (reproduction first); 02 homogeneous payloads and
  events docs; 03 audit of remaining lookups and legacy parity, zones docs, roadmap entry removal.

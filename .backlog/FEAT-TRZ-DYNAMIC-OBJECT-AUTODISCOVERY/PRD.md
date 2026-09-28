# FEAT-TRZ-DYNAMIC-OBJECT-AUTODISCOVERY — `TRZ_` on any static/unit/group, F10 refresh, real anchor removal

**Status:** ready

Formalizes the `dev/roadmap.md` entries "TRZ_ automatique — création liée au spawn d'un objet" and
"Zones dynamiques — aucun rafraîchissement du menu F10 des joueurs déjà sur place" (grilled jointly,
`grill-with-docs` session 2026-09-28 — the two are coupled: an auto-created `TRZ_` hits the
menu-refresh gap far more often than today's occasional scripted call). Also cites **ADR 0021**
(anchor-death detection mechanism) and the `CONTEXT.md` "Auto-discovered zone" / "Anchor" entries
updated during that session.

## Problem Statement

A mission maker wants a transport pilot to be able to rendezvous with any named object in the
mission — a bunker, a convoy of trucks, a ship — to embark or drop off troops there, the same way a
pilot already can at a Mission-Editor-placed `TRZ_` zone. Today this only works through a script
(`CTLDZoneManager:createTroopZoneAtObject`), called by hand for every such object — there is no way
to just *name* the object and have CTLD pick it up, the way `EXTR_<name>` already works for an
extractable group.

Two related problems compound this:

- A pilot already parked exactly where such a zone appears mid-mission sees **nothing** added to
  their F10 menu until they take off and land again — the menu only rebuilds on those two events.
- When the object a `TRZ_` is anchored to (a ship, a truck) is destroyed, the pickup zone **never
  disappears** — it freezes at the wreck and stays fully usable forever, unlike the equivalent
  logistic zone, which is already correctly removed when its anchor dies.

## Solution

`TRZ_<name>_<coalition>_<stock>_<flag>_<target>` — the exact naming convention already used for a
Mission-Editor zone — is now also recognized when found on a **static object, a unit, or a group**,
continuously (at mission start and for anything that appears later, e.g. a late-activated convoy).
No new syntax, no config setting: naming the object is the only wiring a mission maker needs, the
same opt-in-by-name model as `EXTR_<name>`.

Whenever any dynamic zone — troop or logistic — is created or removed, every currently-tracked
ground transport player's F10 menu is refreshed, closing the "player already standing there" gap
for good, not just for this new discovery path but for the existing scripted API too.

When the object anchoring a troop zone is destroyed, the zone is now actually removed (its name
freed for reuse) instead of freezing forever at the wreck — bringing troop zones in line with how a
logistic zone already behaves, and fixing that pre-existing asymmetry for the zones that exist
today (ship, ground vehicle) as well as the new static/unit/group cases this lot adds.

## User Stories

1. As a mission maker, I want to name a pre-placed bunker `TRZ_<name>_<coalition>_<stock>_<flag>_<target>`
   in the Mission Editor, so that players can embark or drop off troops there without me writing a
   script.
2. As a mission maker, I want to name a convoy group the same way, so that a single `TRZ_` on the
   group produces one pickup zone that follows the convoy's lead unit — not one zone per truck.
3. As a mission maker, I want to name a single unit (an isolated vehicle, a ship) the same way, so
   that it works identically to the group case.
4. As a mission maker, I want this to work for an object present at mission start **and** for one
   that spawns or is activated later (a scripted convoy, a late-activation trigger), so that I don't
   have to fall back to `createTroopZoneAtObject` just because my object appears mid-mission.
5. As a mission maker, I want no global setting to turn this on — naming the object `TRZ_...` is
   already a deliberate act on my part, so a second switch would only add friction for no benefit.
6. As a mission maker, I want a `TRZ_` I place this way to carry the exact same fields (coalition,
   pickup stock, extraction flag, win-target) as one placed in the Mission Editor, so I don't have to
   learn a second syntax.
7. As a mission maker, I want a malformed `TRZ_` name on a static/unit/group to be logged and
   skipped (never crash CTLD), matching how a malformed Mission-Editor `TRZ_` is already handled.
8. As a mission maker, I want a `TRZ_` name that collides with one already registered (by the
   Mission Editor, by a script, or by this new discovery path) to be refused with a warning, not to
   silently overwrite the existing zone.
9. As a pilot, I want a `TRZ_` that appears while I'm already parked inside it to show up in my F10
   menu without me having to take off and land again.
10. As a pilot, I want the same immediate refresh when a **logistic** zone (a FOB, an `LGZ_`)
    appears or disappears while I'm already on the ground nearby, not just for troop zones.
11. As a pilot, I want a `TRZ_` removed by script (`removeExtractZone`) to disappear from my F10
    menu immediately if I was standing in it, not linger until my next takeoff/landing.
12. As a pilot, I want a troop pickup zone anchored to a ship or convoy that gets destroyed to
    actually disappear from my F10 menu, not remain usable forever at the wreck.
13. As a pilot, I want this same disappearing behavior for a bunker-anchored `TRZ_` when the bunker
    is destroyed, so a ruined position stops offering troop pickup like a working RV point.
14. As a mission maker, I want a destroyed anchor's zone name freed, so I could in principle reuse
    the same `TRZ_` name later without CTLD refusing it as a duplicate.
15. As a mission maker relying on a built FOB or FARP for troop pickup, I want their existing
    dedicated behavior (`troopPickupAtFOB`/`troopPickupAtFARP`) completely unaffected by this lot —
    they already have their own mechanism and stay out of this feature's scope.
16. As a developer maintaining CTLD, I want the new discovery path to reuse the exact object
    resolution and zone construction `createTroopZoneAtObject` already uses
    (`_resolveTroopZoneObject`, `CTLDTroopZone:new`), so a zone created this way is indistinguishable
    in every other respect from one created by script or by the Mission Editor.
17. As a developer maintaining CTLD, I want the F10 refresh to need no new proximity/geometry
    calculation, so that it reuses `CTLDTroopManager:refreshMenuSection`'s and `CTLDCrateManager:
    refreshCrateFlightSection`'s own existing zone-membership check rather than duplicating it.
18. As a developer maintaining CTLD, I want one mechanism to cover both zone families (troop and
    logistic) for the F10-refresh fan-out, since `CTLDZoneManager` already owns creation/removal for
    both — not two parallel, independently-maintained mechanisms.
19. As a developer maintaining CTLD, I want anchor-death detection to use whichever DCS signal is
    actually reliable for that object kind (`S_EVENT_DEAD` for a unit/group, `CTLDStaticWatcher`
    polling for a static) rather than forcing one uniform mechanism that would silently fail for
    statics, per **ADR 0021**.
20. As a developer maintaining CTLD, I want the startup log to distinguish a `TRZ_` registered by
    Mission-Editor discovery, by script, or by this new static/unit/group scan, so a mission maker
    or a bug report can tell which path produced a given zone — mirroring `EXTR_`'s own
    explicit-list-vs-convention source tagging.
21. As a CTLD contributor reading the developer docs, I want this discovery path documented next to
    `createTroopZoneAtObject` and the existing `TRZ_`/`EXTR_` conventions, so the "how a `TRZ_` can
    come to exist" story reads as one coherent place.

## Implementation Decisions

- **Discovery scan, `CTLDZoneManager`**: alongside the existing `env.mission.triggers.zones` scan
  for Mission-Editor `TRZ_` zones, a new pass scans `coalition.getStaticObjects(side)` and
  `coalition.getGroups(side)` for `side` in `{RED, BLUE, NEUTRAL}` — testing each static's or
  group's own name against the full `TRZ_` parser (`parseTRZ`), not a bare prefix test (a `TRZ_`
  needs its coalition/stock/flag/target fields regardless of anchor kind). A group match uses the
  group's own name and resolves to its first unit as anchor (`linkedUnit`), matching
  `_resolveTroopZoneObject`'s existing "group's first unit" branch — one zone per group, not one
  per member unit.
- **Late-activation**: `S_EVENT_BIRTH` (already registered on `CTLDDCSEventBridge`) is extended so
  `CTLDZoneManager` also reacts to a static or a unit born after init — for a static
  (`Object.getCategory(obj) == 6`), test its own name; for a unit, test both its own name and its
  group's name (the group-convoy case, guarded so only the first unit of a newly-born group
  triggers registration, not each member). A name already registered (Mission Editor, script, or
  the init scan) is skipped — same collision guard `createTroopZoneAtObject` already applies.
- **Reuse, not a new construction path**: both the init scan and the `S_EVENT_BIRTH` path build the
  zone through the exact same `_resolveTroopZoneObject` + `CTLDTroopZone:new` sequence
  `createTroopZoneAtObject` already uses — only the trigger differs (a name match during a scan,
  instead of a script calling the method directly).
- **No new config setting.** The `TRZ_` name itself remains the only opt-in, matching `EXTR_`.
- **F10 refresh, `CTLDZoneManager` → `CTLDPlayerManager`**: `CTLDZoneManager` already publishes
  `OnLogisticZoneUpdated` on a logistic zone's dynamic add/remove; it gains an equivalent publish
  for a troop zone's dynamic add/remove (create — including this lot's two new discovery paths and
  the existing scripted API — and remove). A single subscriber refreshes, for every currently
  on-ground tracked transport player, `CTLDTroopManager:refreshMenuSection` (troop event) or
  `CTLDCrateManager:refreshCrateFlightSection` (logistic event) — reusing the EventDispatcher
  pub/sub pattern already established for cross-manager fan-out in this codebase, instead of a new
  direct dependency from `CTLDZoneManager` into `CTLDTroopManager`/`CTLDCrateManager`. No proximity
  calculation is added: both refresh functions already recompute the calling player's own zone
  membership (`isInZone`) internally.
- **Anchor-death → real removal (ADR 0021)**:
  - **Unit/group anchor**: `CTLDZoneManager:onDead` (existing `S_EVENT_DEAD` handler, today only
    matching `_logisticZones` by a direct unit-name key) is extended to also scan `_troopZones` for
    an entry whose `_linkedUnit` or `_anchorUnitName` matches the dead unit, removing it the same
    way (entry cleared, name freed, the new troop-zone-removed event published per the point
    above). This applies retroactively to every existing `linkedUnit`-anchored troop zone (ship,
    ground vehicle via `createTroopZoneAtObject`) and to a Mission-Editor Moving-Zone-anchored
    `TRZ_` (its `_anchorUnitName` is already populated at discovery), not only to this lot's new
    static/unit/group cases.
  - **Static anchor**: `createTroopZoneAtObject` (and by extension the new discovery paths, which
    share its construction) registers a `CTLDStaticWatcher:watch(...)` at creation time whenever the
    resolved anchor is a static — `isExist()` polling, `S_EVENT_DEAD` being documented unreliable
    for statics elsewhere in this codebase. The watch's callback removes the zone by its actual
    `zoneName` (closure capture), mirroring the existing FARP troop-pickup path exactly.
- **Startup/registration log** distinguishes the source of a `TRZ_` (Mission Editor, script, init
  scan, or `S_EVENT_BIRTH`), mirroring `EXTR_`'s explicit-list-vs-convention log distinction.
- **`FOB`/`FARP` paths (`troopPickupAtFOB`/`troopPickupAtFARP`, `registerFOBAsTroopZone`,
  `unregisterTroopZone`) are untouched** — they already have their own dedicated, correct mechanism
  and are explicitly out of this lot's scope.
- **Developer docs**: this discovery path is documented next to `createTroopZoneAtObject` and the
  existing `TRZ_` convention (`docs/developer/subsystems/zones.md`/`.fr.md`,
  `docs/developer/api-reference.md`/`.fr.md`), and the "Anchor" / "Auto-discovered zone" entries in
  `CONTEXT.md` (already updated during the grill session) move from "proposed" to their final
  wording once implemented.

## Testing Decisions

- **Only external, public behavior is tested** — `CTLDZoneManager:getTroopZone`/
  `getTroopZonesForCoalition` results, a stubbed player's F10 menu content, never private table
  internals — matching this project's established discipline (`ship_troop_zone_anchor_spec.lua`,
  `troop_zone_scripted_api_spec.lua`, `FEAT-EXTR-GROUP-NAMING-CONVENTION`'s own tests).
- **Discovery**: new `busted` coverage (new or extended zone spec file) stubbing
  `coalition.getStaticObjects`/`coalition.getGroups`/`Object.getCategory`, covering: a static named
  `TRZ_...` registers at init; a group named `TRZ_...` registers once (not once per member unit); a
  late-born static/unit/group registers via the `S_EVENT_BIRTH` path; a malformed `TRZ_` name is
  skipped with a logged warning, nothing registered; a name colliding with an already-registered
  zone (any source) is refused, the original left untouched.
- **F10 refresh**: coverage asserting a stubbed on-ground transport player's troop/logistic menu
  section is rebuilt (not just that an event fired) after a dynamic zone create/remove — mirroring
  `menu_gating_spec.lua`'s existing assertion style.
- **Anchor-death removal**: a unit/group case driven by a simulated `S_EVENT_DEAD`, asserting
  `getTroopZone` returns `nil` afterward; a static case driven by advancing `CTLDStaticWatcher:_tick()`
  directly (bypassing the real timer, the same technique `FEAT-FARP-TROOP-PICKUP`'s own tests use)
  after stubbing `isExist()` to `false`. Includes a **regression case** for the pre-existing
  ship/truck anchor path: today's "frozen forever" behavior must become "removed" once this lot
  ships.
- A `tests/dcs` scenario (from `_template_scenario.lua`) confirming a static- or group-anchored
  `TRZ_` actually appears in a live F10 menu, and disappears on destruction, is recommended to close
  the loop end-to-end — existing coverage for the scripted-API and ship/truck-anchor cases already
  exercises the same DCS surface at the unit level.

## Out of Scope

- `LGZ_`/`WPZ_`/`EXZ_` gaining the same static/unit/group discovery — this widening is `TRZ_`-
  specific, driven by the troop-RV need; the other conventions stay trigger-zone-only.
- Any config toggle for this discovery path.
- A geometric "players within the new zone's radius" calculation for the F10 refresh — deliberately
  replaced by refreshing every currently-tracked ground transport player.
- `troopPickupAtFOB`/`troopPickupAtFARP` and their underlying mechanism — untouched.
- Position-tracking mechanics for a Moving-Zone (`dcsName`) anchor — only its removal-on-death
  gains coverage in this lot; how it tracks position is pre-existing and unchanged.
- A generic "zone ↔ owner" link registry (`dev/roadmap.md`'s deferred idea) — already rejected
  elsewhere (`FIX-ZONE-ANCHOR-DUPLICATION`) as premature with only one real composite-owner
  consumer; this lot doesn't reopen that question.

## Further Notes

- References **ADR 0021** (`dev/adr/0021-anchor-death-detection-event-vs-poll.md`) for the
  anchor-death detection split, and the `CONTEXT.md` "Auto-discovered zone" / "Anchor" entries
  updated in the same `grill-with-docs` session (2026-09-28) — both move from "proposed, not yet
  implemented" to final wording once this lot ships.
- This lot changes `src/`: a `CHANGELOG.md` `[Unreleased]` entry is required (the ship/truck
  anchor-removal fix is a behavior change worth its own line, separate from the new discovery
  capability).
- Direct precedent for shape and tests: `FEAT-TROOP-ZONE-SCRIPTED-API` (`createTroopZoneAtObject`),
  `FEAT-EXTR-GROUP-NAMING-CONVENTION` (naming-convention discovery, dual-source logging, dedup
  against an existing explicit path), `FEAT-FARP-TROOP-PICKUP` (`CTLDStaticWatcher`-driven removal).

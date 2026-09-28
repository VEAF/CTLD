# 03 — `TRZ_` auto-discovery on a static, unit, or group

**Status:** ready

**Blocked by:** [02](02-anchor-death-real-removal.md) — a zone discovered this way on a destructible
static/unit/group needs working removal from day one; it inherits ticket 02's fix for free only
because it reuses `createTroopZoneAtObject`'s construction path, which ticket 02 modifies.

## What to build

Recognize the existing `TRZ_<name>_<coalition>_<stock>_<flag>_<target>` naming convention on a
**static object, a unit, or a group** — not just a Mission-Editor trigger zone — continuously (at
mission start and for anything appearing later), with no new syntax and no config setting.

- **Init scan**: alongside the existing `env.mission.triggers.zones` scan, add a pass over
  `coalition.getStaticObjects(side)` and `coalition.getGroups(side)` for `side` in
  `{RED, BLUE, NEUTRAL}`. Test each static's or group's own name against the **full** `parseTRZ`
  parser (not a bare prefix test — a `TRZ_` needs its coalition/stock/flag/target fields regardless
  of anchor kind). A group match resolves to its first unit as anchor, producing **one** zone per
  group, not one per member unit.
- **Late activation**: extend the `S_EVENT_BIRTH` handling already registered on
  `CTLDDCSEventBridge` so `CTLDZoneManager` also reacts to a static or unit born after init — for a
  static (`Object.getCategory(obj) == 6`), test its own name; for a unit, test both its own name and
  its group's name, guarded so only the **first** unit of a newly-born group triggers registration.
- **Construction**: both paths build the zone through the exact same `_resolveTroopZoneObject` +
  `CTLDTroopZone:new` sequence `createTroopZoneAtObject` already uses (as modified by ticket 02) —
  only the trigger differs (a name match during a scan, instead of a script calling the method).
- **Dedup**: a name already registered — by Mission-Editor discovery, by a scripted
  `createTroopZoneAtObject` call, or by this scan's own init pass — is skipped, same collision guard
  `createTroopZoneAtObject` already applies (refuse + `WARN` log, first registration wins).
- **Logging**: the registration log line distinguishes the source (Mission Editor / script / init
  scan / `S_EVENT_BIRTH`), mirroring `EXTR_`'s explicit-list-vs-convention source tagging.
- **No config setting** — the `TRZ_` name is the only opt-in, same model as `EXTR_<name>`.

## Watch out

- Test the **full** name against `parseTRZ`, not just a `^TRZ_` prefix — an object named `TRZ_foo`
  with a malformed or missing field set must be logged and skipped, not crash CTLD or register a
  broken zone (matches how a malformed Mission-Editor `TRZ_` is already handled).
- Guard the group case carefully: `S_EVENT_BIRTH` fires per-unit, so a naive handler would try to
  register the same group-named `TRZ_` once per member unit born. Only the group's first unit
  (matching `_resolveTroopZoneObject`'s own "group's first unit" convention) should trigger it, and
  the existing dedup guard must make any subsequent attempt for the same group a no-op, not a
  duplicate-registration warning spam.
- `FOB`/`FARP` paths (`troopPickupAtFOB`/`troopPickupAtFARP`) are untouched and out of scope — don't
  route a FOB/FARP-built static through this scan; it already has its own dedicated mechanism.
- Don't build a new object-resolution helper — reuse `_resolveTroopZoneObject` as-is (per
  `FEAT-TROOP-ZONE-SCRIPTED-API`'s own explicit decision to keep it local and not generalize it
  prematurely).
- `LGZ_`/`WPZ_`/`EXZ_` stay trigger-zone-only — this widening is deliberately `TRZ_`-specific, don't
  extend the other conventions' scans as a "consistency" side effect.

## Acceptance

- A static (bunker), a unit (isolated vehicle, ship), or a group (convoy) named
  `TRZ_<name>_<coalition>_<stock>_<flag>_<target>` in the Mission Editor registers a working troop
  zone at mission start, with the exact fields the name encodes.
- The same works for an object that spawns or is activated **after** mission start (a scripted
  convoy, a late-activation trigger) — no takeoff/landing or script call required.
- A group named this way registers exactly **one** zone, anchored to its first unit — not one per
  member unit.
- A malformed `TRZ_` name on any of these object kinds is logged and skipped; nothing registers, no
  crash.
- A name colliding with an already-registered zone (any source) is refused with a warning; the
  original registration is untouched.
- The registration log line identifies which discovery path produced a given zone.
- A `FOB`/`FARP`-built static continues to go through its own dedicated mechanism, unaffected by
  this scan.

## Tests

New or extended `busted` coverage stubbing `coalition.getStaticObjects`/`coalition.getGroups`/
`Object.getCategory` (mirroring `troop_zone_scripted_api_spec.lua`'s per-test-case stub/restore
pattern). Cover: a static named `TRZ_...` registers at init; a group named `TRZ_...` registers once
(not once per member unit); a late-born static/unit/group registers via the simulated `S_EVENT_BIRTH`
path; a malformed `TRZ_` name is skipped with a logged warning, nothing registered; a name colliding
with an already-registered zone (from any source) is refused, the original left untouched. Only
external, public behavior asserted (`getTroopZone`/`getTroopZonesForCoalition` results), matching
this project's established discipline.

A `tests/dcs` live scenario (from `_template_scenario.lua`) confirming a static- or group-anchored
`TRZ_` actually appears in a live F10 menu is recommended but not required to close this ticket —
existing coverage for the scripted-API and ship/truck-anchor cases already exercises the same DCS
surface at the unit level.

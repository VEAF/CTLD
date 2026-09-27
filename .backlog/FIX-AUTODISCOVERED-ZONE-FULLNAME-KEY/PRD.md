# FIX-AUTODISCOVERED-ZONE-FULLNAME-KEY — register `TRZ_`/`LGZ_`/`WPZ_` under their full DCS name

**Status:** 🔄 in review (PR #210).

Formalizes `dev/roadmap.md`'s "Piège du nom court pour une zone auto-détectée par convention de
nommage" and a `grill-with-docs` session held 2026-09-27. See **ADR 0020** for the central
decision (full name, no short-name backward compatibility) and its reasoning.

## Problem Statement

`TRZ_`/`LGZ_`/`WPZ_` zones register in `CTLDZoneManager._troopZones`/`_logisticZones` under a
**short name extracted by parsing** their Mission Editor name — `TRZ_dropzone1_B_0_nil_0` occupies
the dictionary key `dropzone1`, not its own full name. `EXZ_` was deliberately built to avoid this
(`FEAT-EXZ-AUTODISCOVERY`). The gap is exploitable by accident: an `aiZones` config entry whose
`dcsZoneName` happens to equal that short key — naming a genuinely different Mission Editor zone —
silently loses to it. `FIX-AIZONE-NAME-COLLISION` (PR #88) only added detection (a startup `ERROR`)
for this; the root cause was never fixed, and `docs/mission-maker/zones.md` documents the trap as
a fact of life ("give the two zones different names") rather than something CTLD could just not do.

Verified during the grill session that the trap is wider than the roadmap entry assumed: **all
four** naming-convention/scripted registration paths share it, not just `_discoverTRZ` —
`_discoverLGZ`, `_discoverWPZ`, and the scripted API `createTroopZoneAtObject` (used by
`FEAT-FARP-TROOP-PICKUP`/`FIX-FOB-TROOP-PICKUP`, and reachable by external scripted integrations
such as VMCT) all register under a parsed/short field too.

## Solution

All four registration sites key their zone by the **full string**, not a parsed sub-field:
`_discoverTRZ`/`_discoverLGZ`/`_discoverWPZ` use the zone's actual Mission Editor name (`name`,
already in scope at each site); `createTroopZoneAtObject` uses the complete `trzName` string the
caller passed (which may not correspond to any real Mission Editor zone at all — the object it
anchors to is a unit/static/group/airbase, not a trigger zone), never `parsed.zoneName`.

Per **ADR 0020**, no backward-compatible short-name fallback is built. The seven public
`CTLDZoneManager` accessor methods (`getTroopZone`, `setTroopZoneActive`,
`changeRemainingGroups`, `activateWaypointZone`, `deactivateWaypointZone`, etc.) need **no code
change** — they already do a direct `self._troopZones[zoneName]` lookup; only what a caller must
pass as `zoneName` changes (the full name, going forward). `FIX-AIZONE-NAME-COLLISION`'s detection
code (`CTLD_zone.lua:918`) needs no change either — it naturally stops false-firing on the
short-name coincidence once the table it checks is keyed by full names.

## User Stories

1. As a Mission Maker, I want an `aiZones` entry never to lose silently to an unrelated `TRZ_`/
   `LGZ_`/`WPZ_` zone just because it happens to share that zone's parsed short name, so that the
   collision class `FIX-AIZONE-NAME-COLLISION` could only detect, not prevent, stops occurring.
2. As a developer calling `createTroopZoneAtObject` (directly, or via `FEAT-FARP-TROOP-PICKUP`/
   `FIX-FOB-TROOP-PICKUP`), I want the zone registered under the exact string I passed, so that a
   second call with a different `trzName` sharing the same parsed short field doesn't collide with
   the first one's registration the way it would today.
3. As a developer calling any of the seven public `CTLDZoneManager` accessors (directly, or via the
   legacy wrapper layer), I want to pass the zone's full name — the same string I'd read off the
   Mission Editor or wrote in my scripted `createTroopZoneAtObject` call — with no need to know
   about, or strip down to, a parsed sub-field that isn't the real name.
4. As a Mission Maker reading `docs/mission-maker/zones.md`, I want the "one name space" warning to
   describe the actual, current behavior — not a trap that no longer exists — so I don't waste time
   working around a bug that's already fixed.
5. As a developer maintaining CTLD, I want this documented as a deliberate, accepted breaking
   change (not silently shipped), so a future reader — especially past the point where CTLD has a
   public stable release — understands why no migration path was built and doesn't assume the same
   choice would be made again.

## Implementation Decisions

- **Four call sites changed**, each a small, localized edit:
  - `_discoverTRZ` (`CTLD_zone.lua`): `self._troopZones[parsed.zoneName] = zone` →
    `self._troopZones[name] = zone` (and the matching existence-check `elseif not
    self._troopZones[parsed.zoneName]` → `...self._troopZones[name]`), where `name` is the loop's
    own `zd.name` — the zone's real Mission Editor name, already in scope.
  - `_discoverLGZ`: same shape, `self._logisticZones[parsed.name]` → `self._logisticZones[name]`.
  - `_discoverWPZ`: same shape as `_discoverTRZ`, `self._troopZones[parsed.zoneName]` →
    `self._troopZones[name]`.
  - `createTroopZoneAtObject`: both the existence-check (`if self._troopZones[parsed.zoneName]
    then`) and the registration (`self._troopZones[parsed.zoneName] = ...`) key on `trzName` (the
    caller's full argument) instead of `parsed.zoneName`.
- **The zone entity's own `zoneName`/`name` field is unchanged** — `CTLDTroopZone`/
  `CTLDLogisticZone` keep storing the parsed short field (used for logging/display); only the
  *dictionary key* used to store and retrieve the object changes. `dcsName` (already present on
  `CTLDTroopZone`, already the full name) needs no new field added anywhere.
- **No change to `parseTRZ`/`_parseLGZ`/`_parseWPZ`** — these keep returning the parsed short
  field exactly as today; only what the *discovery* functions do with the result changes.
- **No change to the seven public accessors, or to `FIX-AIZONE-NAME-COLLISION`'s detection code**
  — see Solution above.
- **`docs/mission-maker/zones.md`'s "One name space for every kind of zone" warning box (lines
  ~59-76) is rewritten** to state that every naming-convention zone (including `TRZ_`/`LGZ_`/
  `WPZ_`, now matching `EXZ_`) registers under its full Mission Editor name, and that this
  collision class no longer occurs — dropping the now-inaccurate `TRZ_dropzone1_B_0_nil_0`/
  `dropzone1` example.
- **`docs/mission-maker/legacy-api.md`'s usage example is corrected**: `ctld.activatePickupZone
  ("TRZ_ALPHA")` never actually matched the pre-fix short-key behavior (the working short key
  would have been `"ALPHA"`) — replaced with a real, complete example name
  (`ctld.activatePickupZone("TRZ_ALPHA_B_0_nil_0")`).
- **CHANGELOG entry explicitly labeled as a breaking change** for the seven public accessors /
  legacy wrapper equivalents, per ADR 0020.

## Testing Decisions

- Only external behavior is tested — what key a zone ends up registered under after discovery/
  scripted creation, and whether a `getTroopZone`/similar lookup by full name succeeds.
- **`tests/ci/unit/troop_zone_scripted_api_spec.lua` needs systematic updates**: every assertion
  keyed by the old parsed short name (e.g. `zm._troopZones["camp1"]`, `zm:getTroopZone("findme")`)
  becomes the full `trzName` string that same test already passes to `createTroopZoneAtObject`
  (e.g. `zm._troopZones["TRZ_camp1_B_999_nil_0"]`). No test's *scenario* changes, only the key each
  assertion checks.
- **New coverage needed for `_discoverTRZ`/`_discoverLGZ`/`_discoverWPZ` directly** — checked: no
  existing spec exercises these three discovery functions against real `env.mission.triggers.zones`
  fixture data and asserts the resulting registration key; `zone_manager_spec.lua`'s `parseTRZ`/
  `_parseLGZ` tests only exercise the parsers in isolation, never discovery. Add direct tests
  (fixture a `TRZ_`/`LGZ_`/`WPZ_` zone in `env.mission.triggers.zones`, run the discovery function,
  assert the zone is retrievable by its full name and absent under the old short key) — this closes
  a real, pre-existing gap as a side effect of proving this fix.
- **`tests/ci/unit/aizone_name_collision_spec.lua` needs no code change** — it manually seeds
  `_troopZones` with a literal key (`"dropzone1"`) rather than exercising real discovery, so it
  keeps testing the collision-detection logic in the abstract, which is still correct. Its framing
  comment is updated to note the concrete scenario it simulates is no longer reachable through real
  `TRZ_` discovery after this fix (a synthetic case now, not the reported bug's literal reproduction).
- Full `busted tests/ci/` run plus a `CTLD.lua` rebuild + `luac5.1 -p` syntax check, as usual.

## Out of Scope

- Any backward-compatibility mechanism for the short-name lookup — explicitly rejected, see ADR
  0020.
- Deleting `FIX-AIZONE-NAME-COLLISION`'s now-effectively-unreachable detection code — kept as a
  harmless defensive check, see ADR 0020's Consequences.
- Any change to `_discoverLogisticUnitTypes`, `_discoverTroopZoneShipTypes`, `_loadLegacyZones`,
  `registerFOBAsTroopZone`, or `_loadAIZonesFromConfig` — verified during the grill session that
  none of these key by a parsed sub-field; they already use a real DCS object/unit name or an
  MM-configured value directly, and were never subject to this trap.
- Any change to `_discoverEXZ` or `_parseEXZ` — already correct, the model this fix now matches.

## Further Notes

**ADR 0020** (`dev/adr/0020-auto-discovered-zones-full-name-key.md`) already documents the central
decision — written during the grill session, ships with this lot's implementation commit.

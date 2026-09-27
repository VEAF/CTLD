# 01 — Register `TRZ_`/`LGZ_`/`WPZ_`/`createTroopZoneAtObject` under the full name

**Status:** ✅ done

**Blocked by:** none.

## What to build

Four call sites in `CTLD_zone.lua`, each keying by the full name instead of a parsed sub-field:
`_discoverTRZ`, `_discoverLGZ`, `_discoverWPZ`, `createTroopZoneAtObject`. Plus:
`tests/ci/unit/troop_zone_scripted_api_spec.lua`'s assertions updated to the new keys; new direct
discovery-registration tests for `_discoverTRZ`/`_discoverLGZ`/`_discoverWPZ`; a framing-comment
update in `aizone_name_collision_spec.lua`; `docs/mission-maker/zones.md`'s "One name space"
warning box rewritten; `docs/mission-maker/legacy-api.md`'s usage example corrected; a CHANGELOG
entry explicitly flagged as a breaking change.

## Watch out

- Don't touch `parseTRZ`/`_parseLGZ`/`_parseWPZ` themselves — only what the discovery functions do
  with the parsed result changes.
- Don't touch the seven public `CTLDZoneManager` accessors, or `FIX-AIZONE-NAME-COLLISION`'s
  detection code (`CTLD_zone.lua:918`) — both work unchanged once the table they read is keyed by
  full names. See PRD Implementation Decisions for why.
- `createTroopZoneAtObject`'s full name is `trzName` (the caller's argument), not `parsed.zoneName`
  — and not necessarily any real Mission Editor zone name either (the anchor object is a unit/
  static/group/airbase). Don't confuse this with the `name`/`zd.name` used by the three discovery
  functions.
- `_discoverEXZ`/`_parseEXZ` are already correct — don't touch them.
- `aizone_name_collision_spec.lua` needs a comment update, not an assertion rewrite — it manually
  seeds its fixture key, so it doesn't exercise the changed discovery path at all.

## Acceptance

- A `TRZ_`/`LGZ_`/`WPZ_` zone discovered from `env.mission.triggers.zones` registers under its full
  Mission Editor name; a lookup by the old parsed short name returns `nil`.
- `createTroopZoneAtObject("someObject", "TRZ_camp1_B_999_nil_0")` registers under the key
  `"TRZ_camp1_B_999_nil_0"`; `zm:getTroopZone("camp1")` returns `nil`,
  `zm:getTroopZone("TRZ_camp1_B_999_nil_0")` returns the zone.
- An `aiZones` entry whose `dcsZoneName` equals a `TRZ_`/`LGZ_`/`WPZ_` zone's *parsed short name*
  (not its full name) no longer collides with it.
- `busted tests/ci/` passes, including the updated `troop_zone_scripted_api_spec.lua` and new
  discovery-registration tests.
- `CTLD.lua` rebuilds and passes `luac5.1 -p`.
- `docs/mission-maker/zones.md` and `legacy-api.md` reflect the new behavior; `CHANGELOG.md` flags
  the breaking change explicitly.

## Tests

`tests/ci/unit/troop_zone_scripted_api_spec.lua` (rewritten assertions, same scenarios) +
new `_discoverTRZ`/`_discoverLGZ`/`_discoverWPZ` registration-key tests (new coverage, no prior art
existed for the discovery functions' registration key specifically — only their parsers were
tested in isolation) + `aizone_name_collision_spec.lua` (comment only, no assertion change).

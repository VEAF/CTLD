# FEAT-EXZ-AUTODISCOVERY — EXZ_ naming-convention discovery, plus a real per-mission config for the dev test mission

**Status:** open.

Formalizes the `grill-with-docs` session held 2026-09-23 on `dev/roadmap.md`'s "AIZ_ — pourquoi
une config explicite" entry, opened while diagnosing why `missions/Test_CTLDNEXT_01.miz`'s AI
zones silently stopped working during `FIX-UH1H-CAPABILITIES-REALISM`. Conclusions from that
session are recorded in `dev/roadmap.md` (that entry's "Grillé le 2026-09-23" note, plus the new
"Piège du nom court..." entry for the explicitly out-of-scope follow-up) and in `CONTEXT.md`'s
"Zones" section (the auto-discovered vs. config/API-referenced split). This PRD does not
re-derive those decisions — it formalizes them.

## Problem Statement

Two problems surfaced together while investigating the same symptom (a live DCS test scenario
silently broken for two months):

1. **The dev/test mission has no durable way to carry its own configuration.** Every other CTLD
   consumer — a real Mission Maker's exported mission, via `ctld-tools` — gets a per-mission
   `ctld.configUser` baked into the `.miz`, injected the same way the engine itself is. The
   project's own developer test mission (`Test_CTLDNEXT_01.miz`) never adopted that mechanism —
   it only loads the engine (`CTLD.lua`, via a `CTLD_DEV_ROOT` env-var trigger). Its `AIZ_` zones
   depended on `CTLD_userConfig.lua` being merged straight into `CTLD.lua`, until
   `USERCONFIG-LOADING` (PR #32, 2026-07-17) ended that merge — and nothing noticed for two
   months, because nothing connects a mission to the configuration it assumes.
2. **A Mission Maker who wants an extraction zone has no easy way to make one, and no
   documentation showing them how.** `TRZ_`/`LGZ_`/`WPZ_` zones are created by naming a DCS
   trigger zone in the Mission Editor — CTLD finds them itself. An extraction zone (`EXZ_`) has no
   such shortcut: the only way to create one is the scripted call `ctld.createExtractZone(...)`,
   undocumented anywhere with a concrete example, reachable only by already knowing it exists and
   reading source.

## Solution

1. Give `Test_CTLDNEXT_01.miz` a real, persistent per-mission configuration through the same
   mechanism a real Mission Maker's mission gets one (`ctld-tools embed --var configUser` +
   `ctld_tools.miz.inject_userconfig()`), declaring the `aiZones` entries the live DCS regression
   scenarios need. This is a one-time application of already-existing, already-tested tooling to
   one file — not a new mechanism.
2. Add `EXZ_` to the zones CTLD auto-discovers by Mission-Editor naming convention, alongside
   `TRZ_`/`LGZ_`/`WPZ_`, converging on the same zone-creation path the scripted API already uses.
3. Document `EXZ_` for Mission Makers with concrete examples, mirroring the existing `AIZ_`
   section's shape.

## User Stories

1. As a CTLD developer, I want the project's dev/test mission to carry its own configuration the
   same way a real exported mission does, so that a live regression scenario's dependency on that
   configuration is visible and durable, not a session-scoped fact only the person who last
   diagnosed it remembers.
2. As a CTLD developer running the live DCS regression suite after a cold restart of DCS, I want
   MT-08, MT-08B and MT-09 to pass without any manual configuration step, so that the suite is
   trustworthy on a fresh machine or after any restart.
3. As a CTLD developer reading `Test_CTLDNEXT_01.miz`'s own setup, I want its `aiZones`
   requirement to be declared in the mission itself (inspectable, versionable), not implied by
   which scenario happens to still be running in a live session.
4. As a Mission Maker, I want to create an extraction zone by naming a trigger zone in the Mission
   Editor, the same way I already do for a troop zone (`TRZ_`), so that I don't have to write a
   scripted trigger for a zone kind that behaves exactly like the ones I can already place by name.
5. As a Mission Maker who does want to script an extraction zone dynamically (e.g. tied to an
   object spawned mid-mission), I want the existing `ctld.createExtractZone(...)` API to keep
   working exactly as it does today, unaffected by the new naming convention.
6. As a Mission Maker naming an `EXZ_` zone, I want to skip the flag or the smoke color when I
   don't need one, the same way I already can for a `TRZ_`'s flag field, so that I'm not forced to
   invent a throwaway flag name just to satisfy the convention.
7. As a Mission Maker who names two different zones with the same underlying zone name for
   different purposes (an `AIZ_` config entry and something else, say), I want an auto-discovered
   `EXZ_` zone to never silently collide with an unrelated registration the way `TRZ_`'s short-name
   keying can, so that my mission's behaviour matches what I see in the Mission Editor.
8. As a developer maintaining `CTLDZoneManager`, I want the naming-convention path and the
   scripted-API path for extraction zones to construct the zone through one shared routine, so
   that the two ways of creating an `EXZ_` can never silently diverge in behaviour.
9. As a developer reading `docs/mission-maker/zones.md`, I want the `EXZ_` section to have the
   same shape as the `AIZ_` section (role table, declaration methods, parameters table, setup
   steps), so that the two sibling zone kinds read consistently.
10. As a translator maintaining the French mission-maker docs, I want the new `EXZ_` section
    mirrored in `zones.fr.md`, so that French-reading Mission Makers get the same guidance.
11. As a developer running `busted`, I want the new `EXZ_` naming-convention parser tested the
    same way the existing `AIZ_`/`TRZ_` collision and discovery logic already is, so that a
    regression in the parser or the registration key is caught before it reaches a live mission.

## Implementation Decisions

- **Per-mission config for the dev test mission**: a small YAML (shaped like the existing
  `docs/mission-maker/zones.md` `aiZones` examples — `dcsZoneName`, `coalition`, `isPickup`/
  `isDropoff`, `cargoType`, `troopStock`/`vehicleStock`) declares the three zones
  `AIZ_depot_B_P_V_10`, `AIZ_depot_B_P_TV_5_10`, `AIZ_livraison_B_D_G`. It is wrapped into
  `ctld.configUser = [[...]]` via `ctld-tools embed --var configUser` (the same mechanism already
  used for `ctld.configDefault`) and injected into `Test_CTLDNEXT_01.miz` as its own MISSION START
  trigger via `ctld_tools.miz.inject_userconfig()`. This trigger must precede the engine's own
  loading trigger — already guaranteed by DCS's own MISSION START-before-ONCE-at-t0 evaluation
  order, confirmed by reading `tools/ctld-tools/ctld_tools/install.py`'s own docstring ("the
  engine reads `ctld.configUser` as it loads"). The three scenario files' own defensive `aiZones`
  self-registration (added in `FIX-UH1H-CAPABILITIES-REALISM`) is left in place as a second safety
  net, not removed — this fix addresses the root cause at the mission level, on top of it.
- **`EXZ_` naming convention**: `EXZ_<name>_<flag>_<smoke>`, three required fields (no optional
  trailing field, unlike `LGZ_`/`WPZ_`'s style) — `<name>` is free, cosmetic text, never reparsed;
  `<flag>` is a DCS flag name/number or the reserved word `nil` (no objective counting, mirroring
  `TRZ_`'s own reserved-word convention for its flag field); `<smoke>` is `0`-`4`
  (`trigger.smokeColor.*`) or the reserved word `nil` (no smoke). Parsed from the **right** end of
  the name (last two `_`-delimited segments are `flag` then `smoke`), not the left, since `<name>`
  may itself contain underscores.
- **Registration key**: the auto-discovered zone registers under its **full, raw DCS zone name** —
  not a parsed short name. This is a deliberate divergence from `TRZ_`'s existing short-name
  keying, chosen specifically to not import the collision class documented in
  `docs/mission-maker/zones.md:55-60` (mitigated, not fixed, by the archived
  `FIX-AIZONE-NAME-COLLISION`, PR #88). Fixing `TRZ_`/`LGZ_`/`WPZ_`'s own keying is tracked
  separately (`dev/roadmap.md`, "Piège du nom court...") and is explicitly out of scope here.
- **One creation path**: the new discovery function builds the zone through the same routine
  `ctld.createExtractZone(...)` already uses (coalition fixed at "any", `objectiveFlag`, `smoke`)
  rather than duplicating it — the naming-convention path and the scripted-API path must produce
  behaviourally identical zones for equivalent parameters.
- **Validation**: a malformed `EXZ_` name (missing a required field) or a full-name collision with
  another registration is reported through the existing `ctld.startupReport` mechanism, following
  the pattern already used for `aiZones` validation — not a silent skip.
- **Docs**: `docs/mission-maker/zones.md` and `.fr.md` gain a new "Extraction zones (EXZ)" section
  mirroring the "AI transport zones (AIZ)" section's shape — role/trigger table, both declaration
  methods (scripted API and the new naming convention) with concrete example names, a parameters
  table, and setup steps.

## Testing Decisions

- New busted spec (e.g. `tests/ci/unit/exz_discovery_spec.lua`), on the seam and pattern already
  established by `tests/ci/unit/aizone_name_collision_spec.lua`: only external behaviour is
  asserted (zone registered under the expected key, with the expected fields), not internal parser
  mechanics. Cases: a well-formed name parses and registers correctly; `nil` in the flag and/or
  smoke position is honoured; a malformed name (missing a required field) is rejected and reported,
  not silently skipped; a name whose free-text `<name>` segment itself contains underscores still
  parses correctly (right-anchored parsing); an auto-discovered zone and a scripted
  `createExtractZone(...)` call with equivalent parameters produce the same zone shape; no
  collision against an existing full-name registration is introduced by the new discovery path.
- No new busted or Python test for the mission-configuration fix itself:
  `tools/ctld-tools/tests/test_miz.py` already covers `inject_userconfig()`'s mechanism generically
  (rank-1 placement, idempotent reinjection, round-trip). This is a one-time application of that
  already-tested tool to one mission file. Acceptance is a **live** re-run of MT-08, MT-08B and
  MT-09 against a **fully restarted** DCS (not merely a reloaded mission) with no manual `aiZones`
  injection — the signal that the persisted, mission-carried configuration actually took effect
  from a cold start, per `feedback_dcs-test-before-pr`.
- Docs change: no automated test; manual EN/FR parity review against the `AIZ_` section's
  structure.

## Out of Scope

- Changing `TRZ_`/`LGZ_`/`WPZ_`'s own short-name registration keying — tracked separately in
  `dev/roadmap.md` ("Piège du nom court pour une zone auto-détectée par convention de nommage").
- Any change to `AIZ_`'s own architecture. Confirmed during the grill that config-only is the
  right model for it — its per-template/per-type stock tables don't fit a naming convention — not
  a defect to fix.
- Adding a `coalition` field to `EXZ_` zones. The existing scripted API has none (coalition is
  fixed at "any"); the naming convention preserves that behaviour, it does not extend it.
- Reworking `FIX-AIZONE-NAME-COLLISION` (PR #88)'s detection code for `TRZ_`/`AIZ_` collisions —
  untouched by this lot.
- Any change to `Test_CTLDNEXT_01.miz`'s existing `CTLD_DEV_ROOT` engine-loading mechanism
  (`DEV-LOCAL-MIZ`) — only a configuration trigger is added alongside it.

## Further Notes

- Possible ADR candidate: the `EXZ_` naming-convention format (reserved-word, all-fields-required,
  full-name-keyed) is a real trade-off against the alternative shapes already in the codebase
  (`LGZ_`/`WPZ_`'s optional-trailing-field style, `TRZ_`'s short-name keying) and would likely
  surprise a future reader without the rationale captured somewhere more durable than a roadmap
  note. Left for the implementing ticket to decide whether it clears the bar (hard to reverse once
  Mission Makers adopt it; a real trade-off with alternatives considered) — the rationale is
  already captured in `dev/roadmap.md` either way.
- The full grill record — including the screenshot-verified `ctld-tools` `AiZonesEditor` UI, the
  `install.py` trigger-ordering finding, and every rejected alternative — lives in
  `dev/roadmap.md`'s two relevant entries and `CONTEXT.md`'s "Zones" section. Read those before
  breaking this PRD into tickets.

# ADR 0020 — Auto-discovered zones register under their full DCS name; short-name lookup is not preserved

**Date:** 2026-09-27
**Status:** Accepted
**Lot:** not yet formalized — decided during a `grill-with-docs` session on `dev/roadmap.md`,
"Piège du nom court pour une zone auto-détectée par convention de nommage"; to-prd/to-issues follow.

## Context

`TRZ_`/`LGZ_`/`WPZ_` zones (auto-discovered by Mission Editor naming convention) register in
`CTLDZoneManager._troopZones`/`_logisticZones` under a **short name extracted by parsing** — the
second field after the prefix (`parsed.zoneName`/`parsed.name`), not the zone's full DCS name.
`TRZ_dropzone1_B_0_nil_0` occupies the dictionary key `dropzone1`. Confirmed during this session:
all three conventions share this shape (the roadmap entry had only confirmed it for `TRZ_`, and
guessed `LGZ_`/`WPZ_` might differ — verified false: `_parseLGZ`/`_parseWPZ` extract the same kind
of short field).

This is exploitable by accident: an `aiZones` config entry whose `dcsZoneName` happens to equal
that short key (naming a genuinely different Mission Editor zone `dropzone1`) collides with it —
`FIX-AIZONE-NAME-COLLISION` (PR #88) only added detection (a startup `ERROR`) for this, the root
cause (a sub-name used as a dictionary key) was never fixed. `EXZ_` (`FEAT-EXZ-AUTODISCOVERY`)
was deliberately designed to register under its full name from the start, specifically to not
inherit this trap.

Seven public `CTLDZoneManager` methods take a `zoneName` parameter looked up directly against these
tables (`getTroopZone`, `setTroopZoneActive`, `changeRemainingGroups`, `activateWaypointZone`,
`deactivateWaypointZone`, plus the equivalent logistic-zone accessors) — also reachable through the
legacy wrapper layer (`ctld.changeRemainingGroupsForPickupZone`, etc.). A mission's `DO SCRIPT`
trigger calling one of these today with the short name (the only value that has ever worked) is a
real, if unquantifiable, category of existing usage.

## Decision

`TRZ_`/`LGZ_`/`WPZ_` are changed to register under their **full DCS zone name**, matching `EXZ_`'s
existing convention — eliminating the collision class structurally (DCS enforces unique zone names
per mission; a genuinely different zone can never share another zone's full name, unlike a
parsed sub-string of it) rather than continuing to only detect it after the fact.

**No backward-compatibility mechanism is built for the short-name lookup.** A mission script
calling any of the seven affected public methods (directly or via the legacy wrapper layer) with
the short name will silently stop finding the zone once this ships. A short-name fallback index
was designed during the grill session that would have preserved this (full name as the canonical,
collision-checked key; a separate short-name index consulted only as a fallback by the seven public
accessors) and was explicitly rejected in favor of the simpler, breaking fix.

## Considered options

- **Short-name fallback index alongside the full-name canonical key** (designed in detail during
  the grill session: a second table, populated at discovery time, consulted only by the public
  accessors, first-discovered-wins on a short-name collision between two zones). Rejected: real
  implementation cost (a new shared resolver method replacing 7 direct table lookups, a new table
  to keep in sync at every discovery/registration/removal site) for a compatibility guarantee this
  project does not yet need to honor.
- **Leave the short-name key as the only key, keep detecting the collision instead of eliminating
  it** (the status quo since PR #88). Rejected: this is exactly the gap this ADR exists to close —
  the roadmap entry that triggered this session flagged the detection-only fix as incomplete.

## Consequences

- **This is a breaking change, accepted deliberately because the project has not shipped a public
  release yet** (still in release-candidate stage, `2.0.0-rcN`). This reasoning does not carry
  forward automatically: once CTLD reaches a stable, publicly-depended-on release, a change of this
  shape (breaking a public API's accepted argument format with no migration path) should not be
  made the same way without re-evaluating whether backward compatibility now matters — this ADR's
  justification is time-bound, not a precedent for "breaking changes are fine here."
- `docs/mission-maker/legacy-api.md`'s existing usage example (`ctld.activatePickupZone("TRZ_ALPHA")`)
  already didn't match the pre-fix short-key behavior (the correct short key would have been
  `"ALPHA"`) — this lot corrects it to a real full-name example, which happens to become more
  intuitive for a Mission Maker (copy the zone's exact Mission Editor name, no stripping required).
- `FIX-AIZONE-NAME-COLLISION`'s detection code (`CTLD_zone.lua:918`, `self._troopZones[dzn]`) is not
  deleted by this change, but becomes effectively unreachable for the case it was written for (a
  short-key accident) — kept in place as a harmless defensive check rather than proven dead code
  removed outright, since "DCS never allows two zones to share a full name" is an assumption about
  the DCS Mission Editor's own behavior, not something this codebase asserts elsewhere with
  certainty.

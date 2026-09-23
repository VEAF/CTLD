# ADR 0016 — `EXZ_` naming-convention format for auto-discovered extraction zones

**Date:** 2026-09-23
**Status:** Accepted
**Lot:** FEAT-EXZ-AUTODISCOVERY, ticket 02

## Context

An extraction zone (`EXZ_`) could until now only be created by the scripted call
`ctld.createExtractZone(zoneName, flagNumber, smoke)` — no naming convention exists, unlike
`TRZ_`/`LGZ_`/`WPZ_`, which `CTLDZoneManager` auto-discovers by scanning
`env.mission.triggers.zones` for a prefix at init. Adding one raised two design questions with
real precedent already in the codebase to weigh against: what fields the convention encodes, and
what key the discovered zone registers under.

**Field shape.** `createExtractZone` takes exactly two meaningful parameters beyond the zone
itself — `flagNumber` (a DCS flag to increment, or none) and `smoke` (a colour index, or none).
No coalition parameter exists; the API hardcodes `coalition = 0` ("any"). This is a much smaller
surface than `TRZ_`'s five required fields or `AIZ_`'s per-template/per-type stock tables
(the latter's richness is exactly why `AIZ_` was confirmed, in the `grill-with-docs` session
behind this lot, to stay config-only rather than gain a naming convention of its own).

**Registration key.** `_discoverTRZ` registers a `TRZ_` zone under a **parsed short name**
(`parsed.zoneName`), not its full Mission-Editor name — `TRZ_dropzone1_B_0_nil_0` occupies the key
`dropzone1`. This is a known, documented trap (`docs/mission-maker/zones.md:55-60`): an unrelated
`aiZones` entry whose `dcsZoneName` happens to be `dropzone1` collides with it silently, detected
(not fixed) by `FIX-AIZONE-NAME-COLLISION` (PR #88). `createExtractZone` itself already registers
under the **exact, full name** it is given — the scripted API has never had this problem.

## Decision

`EXZ_<name>_<flag>_<smoke>` — three fields, all required (no optional trailing field, unlike
`LGZ_`/`WPZ_`'s style):

- `<name>` — free, cosmetic text. Never reparsed; may itself contain underscores. Parsing anchors
  on the **last two** `_`-delimited segments (`flag` then `smoke`), not the first, specifically so
  `<name>` is unconstrained.
- `<flag>` — a DCS flag name/number, or the reserved word `nil` (no objective counting) —
  mirrors `TRZ_`'s own reserved-word convention for its flag field.
- `<smoke>` — `0`-`4` (`trigger.smokeColor.*`), or the reserved word `nil` (no smoke).

The discovered zone registers under its **full, raw DCS zone name**, not a parsed short name —
achieved for free by having discovery call `createExtractZone(fullName, flag, smoke)` directly
rather than duplicating its zone-construction logic. This is a deliberate divergence from `TRZ_`'s
own short-name keying, not an oversight: fixing `TRZ_`/`LGZ_`/`WPZ_`'s existing keying is tracked
separately (`dev/roadmap.md`, "Piège du nom court...") and explicitly out of scope here — this
ADR only commits to not *importing* that trap into a brand-new mechanism.

## Considered options

- **An optional trailing field**, matching `LGZ_`/`WPZ_`'s `name_[R|B|N]` style (flag required,
  smoke optional). Rejected: with only two trailing fields to place, an optional one makes the
  parser ambiguous about which single trailing segment present it is — `TRZ_`'s "all fields
  required, reserved word for off" is unambiguous at the same field count and already has a
  precedent reader would recognise.
- **A parsed short name as the registration key**, matching `TRZ_`. Rejected: this is exactly the
  trap this lot exists to not repeat — `createExtractZone` never had it, and there is no reason
  for the naming-convention path to introduce it where the scripted path doesn't have it.
- **Adding a coalition field**, matching `TRZ_`/`LGZ_`/`WPZ_`. Rejected: the existing scripted API
  has none — a naming convention that added one would make the two ways of creating an `EXZ_`
  behave differently for the same zone, breaking the "one creation path" goal.

## Consequences

- A Mission Maker can create an extraction zone by naming a trigger zone, the same way they
  already do for `TRZ_`, without writing a scripted trigger.
- The scripted `ctld.createExtractZone`/`removeExtractZone` API is untouched — naming-convention
  discovery is a second way to reach the same creation path, not a replacement for the first.
- Two `EXZ_` zones cannot collide with each other or with anything else purely from a shared
  *short* name, because there is no short name — only DCS's own zone-name uniqueness constraint
  (which the Mission Editor already enforces) governs collisions.

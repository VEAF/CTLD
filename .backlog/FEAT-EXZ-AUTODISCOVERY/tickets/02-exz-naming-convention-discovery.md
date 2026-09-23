# 02 — `EXZ_` naming-convention auto-discovery

**Status:** ⬜ ready

**Blocked by:** none — independent of ticket 01.

## What to build

Add `EXZ_` (extraction zone) to the zones `CTLDZoneManager` auto-discovers by Mission-Editor
naming convention, alongside `TRZ_` (`_discoverTRZ`), `LGZ_` (`_discoverLGZ`) and `WPZ_`
(`_parseWPZ`) in `src/CTLD_zone.lua` — scanning `env.mission.triggers.zones` at init, the same way
the other three already do. Today the only way to create an extraction zone is the scripted call
`ctld.createExtractZone(zoneName, flagNumber, smoke)`; that API is untouched and keeps working
exactly as it does today.

Format: `EXZ_<name>_<flag>_<smoke>` — three required fields, no optional trailing field (unlike
`LGZ_`/`WPZ_`'s style):

- `<name>` — free, cosmetic text. Never reparsed; may itself contain underscores.
- `<flag>` — a DCS flag name/number, or the reserved word `nil` (no objective counting — mirrors
  `TRZ_`'s own reserved-word convention for its flag field).
- `<smoke>` — `0`-`4` (`trigger.smokeColor.*`), or the reserved word `nil` (no smoke).

Parse from the **right** end of the name (the last two `_`-delimited segments are `flag` then
`smoke`) so that `<name>` can safely contain underscores of its own.

**Registration key**: the discovered zone registers under its **full, raw DCS zone name** — not a
parsed short name. This is a deliberate divergence from `TRZ_`'s own short-name keying (see
`dev/roadmap.md`, "Piège du nom court..." — fixing `TRZ_`/`LGZ_`/`WPZ_`'s own keying is separate,
out-of-scope future work). Getting this right here is the point of the ticket, not incidental.

**One creation path**: the new discovery function must build the zone through the same routine
`ctld.createExtractZone(...)` already uses, not a duplicate of it — a naming-convention-created
`EXZ_` and a scripted-API-created one with equivalent parameters must be behaviourally identical
(coalition fixed at "any", same `objectiveFlag`/`smoke` handling).

**Validation**: a malformed `EXZ_` name (missing a required field, or a value that doesn't parse —
e.g. a `<smoke>` outside `0`-`4` and not `nil`) or a full-name collision with an existing
registration is reported through `ctld.startupReport`, following the pattern already used for
`aiZones` validation — not a silent skip.

**ADR**: write `dev/adr/00XX-exz-naming-convention.md` capturing the format decision and the two
alternatives it was weighed against (`LGZ_`/`WPZ_`'s optional-trailing-field style; `TRZ_`'s
short-name keying) — flagged as a likely ADR candidate in the PRD's Further Notes. The rationale
is already written up in `dev/roadmap.md`'s two relevant entries; this is transcription with
judgement, not new research.

## Watch out

- Do not touch `ctld.createExtractZone`/`ctld.removeExtractZone`'s own signatures or behaviour —
  this ticket adds a second way to reach the same creation path, it does not change the first.
- Do not give `EXZ_` a coalition field. The existing scripted API has none (coalition is fixed at
  "any"); the naming convention preserves that, it does not extend it.
- `<name>` being free text that can contain underscores means a naive left-to-right split on `_`
  will misparse — anchor the flag/smoke extraction from the end of the string, not the start.
- This ticket does **not** change `TRZ_`/`LGZ_`/`WPZ_`'s own registration keying — only the new
  `EXZ_` path uses full-name keying. Don't "fix it everywhere while you're in there."

## Acceptance

- A DCS trigger zone named e.g. `EXZ_frontline_flag42_nil` is discovered at init, registers under
  that exact full name, tracks flag `flag42`, and has no smoke.
- A zone named e.g. `EXZ_lz1_nil_2` is discovered, has no flag tracking, and smokes with
  `trigger.smokeColor.Red` (index `2`) at creation.
- A malformed name (e.g. `EXZ_lz1_nil` — missing the smoke field) is not registered and produces a
  `ctld.startupReport` entry explaining why.
- A naming-convention-discovered zone and a `ctld.createExtractZone(...)` scripted call with
  equivalent parameters produce zones with identical fields (coalition, `objectiveFlag`, `smoke`).
- `dev/adr/00XX-exz-naming-convention.md` exists and states the decision and the alternatives
  considered.

## Tests

New `tests/ci/unit/exz_discovery_spec.lua`, on the seam and pattern already established by
`tests/ci/unit/aizone_name_collision_spec.lua`: asserts external behaviour (the zone is
registered, under the expected key, with the expected fields) rather than internal parser
mechanics. Cases: well-formed name parses and registers; `nil` honoured in the flag and/or smoke
position; a malformed name is rejected and reported, not silently skipped; a `<name>` segment
containing underscores still parses correctly; naming-convention and scripted-API paths produce
identical zone shapes for equivalent parameters; no collision is introduced against an existing
full-name registration.

# 03 — migration guide, and the smoke decision recorded

**Status:** todo

Depends on: 01 (its finding decides half of this ticket).

## Why

`docs/developer/migration-v1-v2.{md,fr.md}` does not mention `dropOffZones` — verified, zero
occurrences in either language. The guide is where a v1 mission maker looks first, and it is silent on a
setting whose disappearance changes how their AI transports behave. The runtime NOTICE from ticket 02
tells them *at mission start*; the guide has to tell them *before* they get there.

The `zones.{md,fr.md}` pages already carry the correction shipped with `2.0.0-rc2` (a warning that
`dropOffZones` is not read, pointing at `aiZones` + `isDropoff`). That statement should be the short
form; the guide gets the full one.

## What changes

**Migration guide (EN + FR).** A `dropOffZones` entry: what it did in v1 (AI transports auto-unload
troops and vehicles inside the zone; the zone is smoked on the periodic refresh), what replaces it
(an `aiZones` entry with `isDropoff: true`, plus `aiDropMode` for ground / parachute / either), and a
worked before-and-after example — a v1 table of two zones, and the `aiZones` YAML that reproduces it.

**The smoke decision, recorded either way.** Ticket 01 establishes whether an AI zone can be marked.

- *If it cannot, and that is judged acceptable:* say so explicitly in the guide — an AI drop-off zone is
  not smoked, because it exists for AI routing and no pilot needs to find it. State it as a decision,
  not as an omission, so the next reader does not re-litigate it.
- *If it cannot, and that is judged a gap:* this ticket splits. An optional `smoke` colour on an
  `aiZones` entry is a schema change, a runtime change, an editor change and a `version-gap` entry — its
  own ticket, and arguably its own lot, since it is a feature rather than a migration fix.

Whichever way it goes, the reasoning belongs somewhere durable. If it is a decision about the shape of
the config model, [ADR 0011](../../../dev/adr/0011-complete-yaml-config-and-webapp-tooling.md) is the
right home; if it is a product judgement about AI zones, the guide suffices.

## Acceptance

- A v1 mission maker reading the migration guide learns that `dropOffZones` is gone, what it did, and
  what to write instead — without opening the source.
- The before-and-after example is valid YAML that `ctld-tools validate` accepts.
- The smoke question has a written answer, in the guide or in the ADR, and the `zones` pages agree with
  it.
- EN and FR say the same thing. Both languages get the example.

## Tests

None beyond the docs build (`mkdocs build --strict`). If the example YAML ships as a fixture, a
`ctld-tools` test that validates it is worth the few lines — a documented example that does not validate
is worse than none.

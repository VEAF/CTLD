# 02 — say it in the zone documentation, not only at runtime

**Status:** todo

Depends on: 01 (the message it documents).

## Why

The migration guide already warns about the collision, in the one place it bites hardest (the smoke
workaround for AI drop-off zones). But the rule it describes — *a zone name is a single namespace
shared by TRZ, WPZ, AIZ and the legacy tables, and the first registration wins* — belongs with the zone
documentation, where a mission maker names their zones, not buried in a migration note they may never
read.

## What changes

- **`docs/mission-maker/zones.{md,fr.md}`**: state the shared-namespace rule where the zone types are
  introduced. The page already says "two zones of the same prefix cannot share the same `name`" and
  that discovery wins over legacy config — both true, both narrower than the actual rule, since a TRZ
  registers under its *parsed* name and an `aiZones` entry uses a raw Mission Editor name.
- Name the failure mode and the message from ticket 01, so a mission maker who sees it in the startup
  report finds it in the docs.
- **`docs/developer/subsystems/zones.{md,fr.md}`**: the init sequence section is where the precedence
  order is explained; add what happens to the loser.

## Acceptance

- A mission maker reading the zones page learns that the name space is shared across all zone kinds
  before they hit the problem.
- The wording matches the runtime message from ticket 01 — same vocabulary for the same thing.
- The migration guide's existing warning is not duplicated, just cross-referenced.
- EN and FR say the same thing.

## Tests

None beyond `mkdocs build --strict`.

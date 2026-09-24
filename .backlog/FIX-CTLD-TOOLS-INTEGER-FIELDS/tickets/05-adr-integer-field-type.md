# 05 — ADR: `integer` field type as a deliberate exception to ADR 0011 Addendum 1

**Status:** ✅ done

**Blocked by:** tickets 01 and 02 (describes the real, shipped mechanism — write it once both are
true, not before).

## What to build

`dev/adr/00XX-ctld-tools-integer-field-type.md` documenting:

- The problem: `ctld-tools` had no way to distinguish an integer-only quantity from a continuous
  one, letting a Mission Maker type a fractional value into a field the engine needs as a whole
  number (GitHub issue #157).
- The decision: a real `'integer'` `EditorType`, supplied by **two distinct mechanisms** — a
  schema-declared `type: integer` annotation for scalar settings (ticket 01), and
  compile-time-hardcoded field lists for the three bespoke table editors (ticket 02) — not one
  unified abstraction forced onto both.
- **Why the schema annotation is a deliberate exception to ADR 0011 Addendum 1's "the tier is
  derived, not declared, from the shape of the default value" principle**: shape alone cannot
  distinguish a genuine integer count (`numberOfTroops: 10`) from a value that is legitimately
  continuous but merely happens to be a whole number today (`crateSpacing: 5`) — a human
  declaration is unavoidable for this specific distinction, unlike the Parameter/List tier
  Addendum 1 covers, which the shape of the value alone does determine.
- Alternatives considered: deriving "integer" some other way (rejected — no such signal exists in
  the data); a single mechanism for both scalar settings and bespoke table fields (rejected —
  scalar settings have arbitrary, schema-driven keys unknown at compile time, the bespoke editors
  don't; forcing one abstraction onto both was rejected during the `grill-with-docs` session).

## Watch out

- Cite the actual ticket 01/02 implementation once merged, not the PRD's proposed shape — if
  anything changed during implementation, the ADR should describe what shipped.
- Reference `ADR 0011` and its Addendum 1 explicitly; this ADR amends neither, it documents a
  scoped exception.

## Acceptance

- `dev/adr/00XX-ctld-tools-integer-field-type.md` exists, states the decision, the two-mechanism
  split, and the alternatives considered, and explicitly reconciles itself with ADR 0011
  Addendum 1 rather than silently contradicting it.

## Tests

Docs change: no automated test — manual review, matching this project's convention for
documentation-only tickets (e.g. `FIX-CTLD-TOOLS-AIZ-STOCK-GAP` ticket 04).

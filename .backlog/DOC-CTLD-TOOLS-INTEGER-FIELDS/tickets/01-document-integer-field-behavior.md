# 01 — Document whole-number field behavior in `ctld-tools.md`/`.fr.md`

**Status:** ✅ done

**Blocked by:** none — can start immediately.

## What to build

In `docs/mission-maker/ctld-tools.md` and `.fr.md`:

1. "Editing your configuration" section — extend "the right editor for its type — a switch for
   on/off, a dropdown for fixed choices, a number or text box otherwise" with a short clause: a
   whole-number field (a soldier count, a quota, a limit, a laser code) rejects/rounds a decimal,
   while a continuous one (a weight, a distance, a duration) does not.
2. "Validation" section — extend the example problem list ("unknown DCS unit types, duplicate
   crate weights, and so on") to mention a fractional value on a whole-number field (from a
   hand-edited YAML, or an older configuration) as one of the things the panel catches.

## Watch out

- Keep both edits short clauses within the existing sentences — no new admonition block, no
  per-field catalogue (see PRD Implementation Decisions for why).
- Keep EN and FR in sync, matching each file's existing tone and heading-anchor style (the FR file
  uses `{ #anchor }` suffixes on headings — don't touch those, only the prose inside).
- Don't touch `configuration.md`/`.fr.md` or `asset-validation.md` — out of scope, neither is stale.

## Acceptance

- `docs/mission-maker/ctld-tools.md` and `.fr.md`'s "Editing your configuration" section
  distinguishes whole-number fields from continuous ones.
- Both files' "Validation" section mentions the fractional-value-on-integer-field case.

## Tests

None — documentation only.

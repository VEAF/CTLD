# 04 — `spawnableCrates.side` (mixedSet branch) → RED/BLUE dropdown

**Status:** ⬜ ready

**Blocked by:** none — independent of the `integer`-type mechanism, can start immediately.

## What to build

`CratesEditor.svelte`'s `mixedSet`-only branch renders a bare `<input type="number">` for `side` (a
RED/BLUE coalition id). The *non*-mixedSet branch a few lines below already renders the correct
`<select>` (RED=1/BLUE=2) for the same field. Make the mixedSet branch use that same dropdown
instead of a free-typed number.

This is a pure UI consistency fix — not part of the `integer`-type mechanism (tickets 01/02); the
fix is "reuse the existing dropdown", not "add a step to the number input".

## Watch out

- Don't touch the non-mixedSet branch's existing `<select>` — copy/reuse it, don't reimplement it.
- `side` can be absent (both branches already treat "no value" as "both coalitions" elsewhere) —
  preserve that behaviour if the mixedSet branch's number input handled it differently.

## Acceptance

- The mixedSet branch renders the same RED/BLUE `<select>` the non-mixedSet branch uses, with
  identical options and value semantics.
- No regression to the non-mixedSet branch's own rendering.

## Tests

`web/src/lib/CratesEditor.test.ts` (vitest): the mixedSet branch renders a `<select>` with RED/BLUE
options instead of a number input, and setting it updates `side` the same way the non-mixedSet
branch's dropdown already does.

# 02 — The clearing search leaves a trace when it cannot do its job

**Status:** ✅ done (PR #316) · **Type:** AFK

## Parent

[PRD — FIX-FAT-COW-CLEARING-LOG](../PRD.md). Stories 1 to 13 and 15. GitHub issue #299.

## What to build

When the AI cow cannot land in a clearing, the log says why. The search tells its caller which of five outcomes it got, and both landing paths of the cow (its flight landing, and "Land here") log it. The point the cow lands on does not change in any case.

- **Found**: unchanged, the existing "lands in a clearing" line.
- **Singleton missing**: a `WARN`, once per mission, naming the cow.
- **Error raised**: a `WARN`, once per mission, carrying the error as it was raised.
- **Wrong shape**: a `WARN`, once per mission, saying what came back: something that is not a table, or a non-empty table none of whose entries is a well-formed point. The definition of *well-formed* is the one the probe of ticket 01 confirmed on the real output: a table whose `x` is a number and whose `z`, else `y`, is a number (real candidates are vec2 `{ x, y, course }`, `y` being the map's z).
- **No clearing**: an `INFO` at every landing, when the table is empty or every well-formed candidate is rejected by the filters (too close to the leader, in water, out of range) at the three clearances. It is the benign outcome and never a `WARN`.

The three `WARN` causes (missing, error, shape) are tracked independently, so that a first cause does not hide a later, different one. The exact texts are those of the PRD, in English and untranslated.

A `CHANGELOG` *Fixed* entry under `[Unreleased]` records it. No configuration key: no `configVersion` change, no catalogue shape, no dictionary regeneration.

## Acceptance criteria

- [x] With the singleton missing, a landing logs the `WARN` naming the cow; a second landing in the same mission does not log it again.
- [x] With a search that raises an error, the `WARN` carries the error text, once per mission.
- [x] With a return that is not a table, the shape `WARN` names its type; with a non-empty list of malformed entries, the shape `WARN` is logged; each once per mission.
- [x] With an empty list, and with well-formed candidates that are all rejected, an `INFO` "no clearing" is logged at every landing and no `WARN`.
- [x] The three `WARN` causes are independent (an error does not silence a later shape warning).
- [x] The success case still logs its line, and neither a `WARN` nor the "no clearing" line.
- [x] Both landing paths log alike, and the landing point is the same as before in every case (the existing assertions stay green).
- [x] The new cases fail before the change, for the right reason (nothing is logged today), and pass after it.
- [x] `busted tests/ci/` green; luacheck clean; the `CHANGELOG` entry is there.

## Blocked by

- [01 — Check the real output of the clearing search](01-probe-the-real-search-output.md) (the definition of *well-formed*; if DCS cannot be reached, this ticket may start on the code's assumption and the probe confirms it afterwards)

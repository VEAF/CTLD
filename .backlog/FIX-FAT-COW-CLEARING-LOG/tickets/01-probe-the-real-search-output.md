# 01 — Check the real output of the clearing search

**Status:** ✅ done (probe of 2026-11-18) · **Type:** AFK

## Parent

[PRD — FIX-FAT-COW-CLEARING-LOG](../PRD.md). Story 14. GitHub issue #299.

## What to build

A one-off, read-only probe of the real `Disposition.getSimpleZones`, run over the DCS bridge's HTTP API on the mission that is loaded (no mission reload, nothing created), so that the definition of a *well-formed candidate* used by ticket 02 rests on what DCS really returns and not on the code's assumption ("a candidate may be a vec2").

- Call the search near a point of the map far from the player, with the three clearances the cow uses (100, 50 and 30 m), a 300 m radius and 10 attempts, as `clearingAt` does.
- Record, for each call: whether the call succeeded, the type of what it returned, the number of candidates, and the exact shape of the first candidate (its type, its keys, vec2 or vec3, `x`/`z` or `x`/`y`).
- Say whether the points the code reads (a table with `x` and a `z`, else a `y`) are what DCS returns.
- If the real shape differs from that assumption, say what it is: ticket 02 then adjusts the definition of *well-formed* before it is written into the tests.

The probe script stays in the scratchpad; its output is pasted in this ticket. Nothing is committed but the ticket.

## Acceptance criteria

- [x] The probe ran against the live mission and its output (return type, candidate count, shape of the first candidate, for each clearance) is recorded in this ticket.
- [x] The ticket states whether the code's assumption about a candidate holds on the real output, and the definition of *well-formed* ticket 02 must use.
- [x] No group, object, setting or timer was created or changed in the mission.

## Blocked by

None - can start immediately.

## Result — probe of 2026-11-18

Run over the DCS bridge's HTTP API on `Test_CTLDNEXT_01.miz` (CTLD of the `develop` build loaded; the probe reads nothing of CTLD): `Disposition.getSimpleZones(point, 300, clearance, 10)` with a vec3 point, as `clearingAt` calls it, at four sites 6 to 11 km from the BLUE player, at the three clearances. The singleton exists (`type(Disposition) = table`, `getSimpleZones` is a function) and **12 calls out of 12 succeeded and returned a table**.

| Clearance | Returns, over the four sites |
| --- | --- |
| 100 m | `#r` = 0, 0, 0, 7 |
| 50 m | `#r` = 0, 9, 10, 5 |
| 30 m | `#r` = 0, 10, 10, 10 |

(A site over the sea gave 0 at every clearance. `#r` and the number of `pairs` agree: the table is a plain sequence.)

The shape of a candidate, identical in every sample (first and second entries):

```
table{course=number(0), x=number(-355930.0625), y=number(626050.625)}
```

- A candidate is a **vec2 with a `course`**: `x` and `y`, where **`y` is the map's z**; there is no `z` key. The code's reading (`x`, and `z` else `y`) is therefore right, and its comment "a candidate may be a vec2" is in fact the only case seen.
- The candidates are **not limited to the radius** that was asked: the first candidate was 77, 67, 640, 895, 907, 103 and 60 m from the asked point, so points beyond 300 m do come back, and the existing filter (`d <= 300`) does reject real candidates. A well-formed list whose candidates are all rejected, the benign "no clearing", is therefore a realistic outcome and not a corner case.
- They are not sorted by distance (the first one is not the nearest), which the existing code already handles by picking the nearest.

**Verdict.** The code's assumption holds on the real output. The definition of *well-formed* for ticket 02: **a table whose `x` is a number and whose `z`, else `y`, is a number.** (Requiring numbers is the only refinement: today a non-numeric coordinate would raise inside the distance arithmetic, outside any `pcall`; it will count as malformed instead. For every real candidate the choice of the point is unchanged.) A well-formed list that comes back empty, or all rejected, is benign; the shape `WARN` must not fire on the real output seen here.

Nothing was created or changed in the mission: no group, object, timer or setting. The probe script stayed in the scratchpad.

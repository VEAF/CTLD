# FIX-FAT-COW-CLEARING-LOG — the AI cow's clearing search can fail without leaving anything in the log

**Status:** ⬜ ready — decisions taken in the grill of 2026-11-18 (no ADR: reversible and unsurprising; no `CONTEXT.md` term: it has no Fat Cow vocabulary).

GitHub issue #299 (found by an automated review of `develop`).

## Problem Statement

`FIX-FAT-COW-AI-LANDING` (PR #278) makes the AI Fat Cow land in a clearing instead of on the raw point 120 m to the left of its leader. It searches the clearing with `Disposition.getSimpleZones`, an undocumented DCS singleton. Five situations make the cow land on the raw point, and **none of them leaves a trace in the log**:

1. the singleton is missing;
2. `getSimpleZones` raises an error: the `pcall` throws it away;
3. it returns something that is not a table;
4. it returns a non-empty table, but none of its entries is a well-formed point: everything is skipped without a word;
5. it finds nothing usable: an empty table, or every candidate rejected (too close to the leader, in water, out of range) at each of the three clearances.

The first four are an API failure; the fifth is benign. Only the case that works is logged ("lands in a clearing N m from the asked point").

A DCS patch that changes the signature, the argument order, the return type or removes the singleton would put CTLD back on the defect the batch was opened for: a cow struck a tree at 10 m, twice at the same place on 2026-10-30. Back then there was a clue (a destroyed cow, an `S_EVENT_HIT`, a FARP that did not open). Now the DCS log would say nothing at all and the diagnosis would start from scratch. The benign case cannot be told apart from an API failure either, when reading the log of a mission where a cow crashed on landing.

## Solution

Log the situations the silent fallback mixes up, and nothing else:

- an **API failure** (cases 1 to 4) is a `WARN`, **once per mission and per cause**, saying what happened and what the cow does instead;
- the **benign "no clearing"** (case 5) is an `INFO` at every landing, so that it reads as the normal outcome it is;
- the point the cow lands on does not change, in any case.

Log only: no start-up notice, no probe of the API at boot, no on-screen message.

## User Stories

1. As a mission maker, I want a warning in the log when the clearing search is unavailable, so that I know the AI cow lands on the raw point and not in a clearing.
2. As a mission maker, I want the error `getSimpleZones` raised written in the log, so that I can tell a changed signature from a removed singleton.
3. As a maintainer reading the log of a mission where a cow crashed on landing, I want to see whether the clearing search worked, failed or found nothing, so that I do not start the diagnosis from scratch.
4. As a maintainer, I want the "no clearing within the search radius" outcome logged as ordinary information, so that it is never mistaken for an API failure.
5. As a maintainer, I want a result that is not a list of points to be reported as an API failure, so that a changed return type does not pass for "no clearing".
6. As a maintainer, I want a non-empty list whose entries are all malformed to be reported as an API failure, so that a changed point format does not pass for "no clearing" either.
7. As a maintainer, I want a list with well-formed points that are all rejected (too close to the leader, in water, too far) to stay benign, so that an honest "nothing usable here" is not raised as a failure.
8. As a mission maker, I want each API failure warned once per mission and per cause, so that a broken API does not flood the log at every landing, yet a second, different cause is not hidden behind the first.
9. As a mission maker, I want the line to name the cow, so that I can link it to a landing.
10. As a maintainer, I want the three causes (missing, error, wrong shape) tracked independently, so that the singleton coming back and then failing differently is still seen.
11. As a pilot, I want the cow to land exactly where it landed before in every case, so that the logging changes nothing in the game.
12. As a pilot, I want both ways the cow lands (when its flight lands, and on "Land here") logged alike, so that no landing path stays silent.
13. As a maintainer, I want the existing success line kept as it is, so that nothing that reads it breaks.
14. As a maintainer, I want the real DCS output of the search checked once against the code's assumption about its shape, so that the new warning does not fire on a healthy game.
15. As a maintainer, I want the change to need no configuration key, so that the catalogue version and the dictionaries stay as they are.

## Implementation Decisions

- **One shared path.** The logging lives in the clearing helpers used by both landing paths of the cow manager, so that the flight landing and "Land here" are covered by the same change.
- **Five outcomes instead of two.** The clearing search tells its caller which of found / singleton missing / error / wrong shape / no clearing it got, instead of returning a bare point or nothing. The choice of the point is unchanged: the nearest well-formed candidate that passes today's filters, at the widest clearance that offers one.
- **Well-formed candidate** means what the search already accepts: a table with `x` and a `z` (or a `y`, the vec2 convention). A table with at least one well-formed candidate is never a shape failure, even when the filters reject them all.
- **Levels and frequency.** Singleton missing: `WARN`, once per mission. Error raised: `WARN`, once per mission, carrying the error as `tostring` gives it. Wrong shape (not a table, or a non-empty table without one well-formed candidate): `WARN`, once per mission, carrying a description of what came back (its type, or the type of the first entry of a list). No clearing: `INFO`, at every landing.
- **Three flags on the manager** (missing, error, shape), so that a first cause does not hide a later, different one. A single global flag was rejected.
- **Texts**, English, not translated (log lines are not in the dictionaries), with the level strings the file already uses:
  - missing: `CTLDFatCowManager: Disposition.getSimpleZones is not available: cow '%s' lands on the asked point, with no clearing search`
  - error: `CTLDFatCowManager: Disposition.getSimpleZones failed (%s): cows land on the asked point, with no clearing search`
  - shape: `CTLDFatCowManager: Disposition.getSimpleZones returned %s, not a list of points: cows land on the asked point, with no clearing search`
  - none: `CTLDFatCowManager: no clearing within %d m of the asked point: cow '%s' lands on it` (the search radius, 300 m)
- **No configuration change**: no new key, so no `configVersion` bump, no catalogue shape, no dictionary regeneration.
- **CHANGELOG**: one *Fixed* entry under `[Unreleased]`.

## Testing Decisions

- **A good test** asserts what an observer sees: the log lines (level and key words) and the point the cow lands on. It does not look at the helpers' return values or the flags.
- **Seam**: the existing Fat Cow AI landing spec, which already drives both landing paths with the singleton replaced by a double (absent, raising, returning an empty list) and checks the landing point. The log is captured the way other specs of the repository capture it.
- **Cases** (each red before the change, for the right reason: nothing is logged today):
  - singleton missing: the `WARN`, once; a second landing adds none;
  - error: the `WARN` with the error text, once;
  - return that is not a table: the shape `WARN` naming the type;
  - non-empty list of malformed entries: the shape `WARN`;
  - empty list, and well-formed candidates all rejected (one too close to the leader, one in water): the `INFO` at every landing and no `WARN`;
  - the three flags are independent (an error does not silence a later shape warning);
  - the success case still logs its line, neither `WARN`, nor the "no clearing" line;
  - the landing point is the same as before in every case: the existing assertions stay green.
- **Live probe** (ticket 02): one read-only call of the real search over the DCS bridge to confirm the shape of its output (see *Further Notes*).

## Out of Scope

- Probing the API at start-up, or any visible alert (notice, on-screen message).
- Changing which clearing is chosen, the clearances, the search radius or the fallback point.
- Replacing `Disposition.getSimpleZones`.
- The other Fat Cow issues (#295 to #298): the ground test of the cow, the return value of its deployment, the menu entries.

## Further Notes

- **Why a live probe.** The "wrong shape" warning rests on an assumption about the points the real API returns; the code itself only says a point "may be" a vec2. If the real shape were another one, the warning would fire at the first landing of every mission and the log would lie the other way. One read-only call near a point of the map, far from the player (clearances 100, 50 and 30 m, a 300 m radius, 10 attempts), records the type of the return, the number of candidates and the exact shape of the first. No group or object is created, and no mission reload is needed. If the real shape differs, the definition of "well-formed" is adjusted before the pull request and the ticket says so.
- Two tickets, in the order they run: 01 the live probe, which fixes the definition of *well-formed* on the real output; 02 the log lines, with their tests and the CHANGELOG entry.

# FIX-UNPACK-FALSE-SUCCESS — unpacking announces "unpacked successfully" when nothing was created

**Status:** ✅ done (PR #267)

GitHub issue #264 (automated review of `develop` at `673b064`), decided with the maintainer on 2026-10-20.

## Problem Statement

`CTLDCrateManager:_spawnUnpacked` returns three values: `true` (group created), `false` (DCS refused it, the pilot is told), `nil` (nothing
was attempted: missing data, JTAC drop disabled, JTAC slot limit reached). The Unpack Crate menu callback announces success when the
result is `~= false`, so `nil` counts as a success. A pilot who unpacks a JTAC crate while the coalition's JTAC limit is reached reads the
reason of the refusal, then "… unpacked successfully!" — two contradictory messages, with the crates already consumed and no JTAC created.
The same happens when the descriptor or the spawn position is missing and `_spawnUnpacked` is never called.

## Solution

The success message is announced only when the group was created (`true`). A refusal already reported to the pilot (DCS refusal, JTAC limit)
stays reported once. When the unpack could not even be attempted (no descriptor, no unit type, no spawn position), the click is logged.

## User Stories

1. As a pilot, I want no "unpacked successfully" message when the JTAC limit blocked the unpack, so that I am not told two opposite things.
2. As a pilot, I want still to be told why the JTAC was refused.
3. As a pilot, I want the success message when the equipment was really created.
4. As a pilot, I want a DCS refusal still reported as a failure, once.
5. As a CTLD developer, I want an unpack that could not be attempted logged, so that a silent click leaves a trace.

## Implementation Decisions

- The callback announces success on `spawned == true` only.
- When the descriptor, its unit type or the spawn position is missing, the callback logs it (nothing is attempted, as today).
- No change to `_spawnUnpacked`, to the messages, to the keys or to the catalogue.

## Testing Decisions

- A good test observes what the pilot reads and what is logged, not how the callback is organised.
- A functional spec over the real menu builder and the real callback (prior art: `crate_request_failure_spec`): JTAC limit reached → only the
  refusal reason; creation succeeds → the success message; DCS refuses → the failure message only; no spawn position → no success message and
  a log.

## Out of Scope

- The order of the operations (crates consumed before the spawn is attempted), unchanged.
- The FARP pack message (issue #263, own lot).

## Further Notes

None.

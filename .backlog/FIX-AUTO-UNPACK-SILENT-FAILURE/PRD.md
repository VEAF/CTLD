# FIX-AUTO-UNPACK-SILENT-FAILURE — a parachuted equipment crate that cannot be unpacked fails in silence and is logged as a success

**Status:** ⬜ ready — no open decision.

GitHub issue #294 (automated review of `develop` at `1b61b10`), decided with the maintainer on 2026-11-10 (who is told: the dropper).

## Problem Statement

A pilot parachutes an equipment crate (a vehicle, a static, a JTAC drone) above the objective. When it touches the ground, CTLD unpacks it by itself. If the equipment cannot be created — the coalition's JTAC quota is reached, or DCS refuses the group — nothing appears and **nobody is told**: not the pilot, on screen or over the radio, and not the log, which says it unpacked.

Two reasons, both on the automatic path of the parachute:

- The result of the equipment creation is ignored, and the log line "auto-unpack (parachute) EQUIPMENT" is written whatever happened. A server administrator who filters the log on "auto-unpack" to investigate a pilot's report finds the trace of a successful unpack, right after the warning that says the opposite.
- The two messages the creation sends to a pilot (the DCS refusal, the JTAC limit) go to a named player. The automatic path names nobody, so neither is ever sent.

Since the lot FIX-CREATE-BEFORE-DESTROY (PR #300) the crates are no longer lost in that case: they stay on the ground. The pilot can go and unpack them himself — if he knows.

The menu path has none of this: it reads the result and tells the pilot (PR #267).

## Solution

The pilot who dropped the crate is told. CTLD notes who dropped each parachuted crate at the moment of the drop, and when the crate lands and its equipment cannot be created, that pilot reads the same message as on the menu path: the DCS refusal, or the reason of the JTAC limit. A pilot who has left in the meantime is simply not told.

The log tells the truth: the unpack line is written only when the equipment was created; otherwise a warning says it was not created, why, and that the crates were kept.

A crate released by the DCS cargo system itself (CTLD does not see who) has no recorded dropper: the log alone then reports the failure.

When the equipment is created, nothing changes.

## User Stories

1. As a pilot who parachuted a vehicle crate, I want to be told when the vehicle could not be created, so that I do not wait for it.
2. As a pilot who parachuted a JTAC drone crate, I want to read the reason when the coalition's JTAC limit blocked it, so that I know what to do.
3. As a pilot, I want the same wording as the menu unpack, so that I recognise the message.
4. As a pilot who left the slot after the drop, I want nothing to break, so that a failed unpack never raises an error.
5. As a pilot, I want a parachuted crate that unpacked fine to stay silent as today, so that nothing changes when all goes well.
6. As a server administrator, I want the log to say "unpacked" only when it was, so that a filter on "auto-unpack" is trustworthy.
7. As a server administrator, I want a warning that names the equipment, the cause (refused by DCS, or nothing attempted) and the fact that the crates were kept, so that I can answer a pilot's report.
8. As a server administrator, I want the failure of a DCS-native release to be logged even though nobody can be told, so that it leaves a trace.
9. As a mission maker, I want the crates to stay on the ground after a failed auto-unpack, so that a pilot can unpack them by hand (already true since PR #300).
10. As a CTLD developer, I want the dropper recorded where the drop already knows it, so that no lookup is needed at landing.
11. As a CTLD developer, I want the dropper forgotten when the crate is loaded again, so that a later drop does not message a previous pilot.
12. As a CTLD developer, I want a test that fails when the failure is silent, so that the path cannot regress.

## Implementation Decisions

- A crate has a new, optional **dropper**: the unit name of the pilot who parachuted it. Empty by default; set by the CTLD parachute at the drop (the unit is known there); cleared when the crate is loaded again, like the existing parachute flag.
- The automatic unpack of an equipment crate passes the crate's dropper as the player to the equipment creation. The creation already sends the refusal and the JTAC-limit messages to that player when it exists in the world, and does nothing for an unknown name.
- The unpack line of the log is written only when the creation reported success. Otherwise a warning is written, with the cause: the group refused by DCS, or nothing attempted (missing data, JTAC drop disabled, JTAC limit).
- On success the equipment creation also refreshes the dropper's Load and Pack menu sections; that is harmless and nil-safe.
- The order of the operations (equipment first, crates consumed only if it exists, ADR 0028) is unchanged.
- No new message, no translation key, no configuration or catalogue change.

## Testing Decisions

- A good test observes what the pilot reads and what is logged, not how the manager is organised.
- Seam: the unpack result functional spec, whose parachute cases (added by PR #300) land a parachuted crate with the equipment creation doubled. New cases: a refused group tells a registered dropper the refusal; the JTAC limit tells the dropper the limit; a crate with no dropper tells nobody and logs the warning; a success logs the unpack line and no warning.
- Seam for the dropper itself: the parachute functional spec, where the crate drop is already driven with a transport double: the crate records the dropper's unit name; loading it again clears it.
- The new cases fail before the change and pass after it; the existing cases pass unchanged.

## Out of Scope

- A message to the dropper when the equipment **is** created.
- The scene and FOB branches of the automatic unpack (a stepped scene has its own failure path).
- The menu path (already honest since PR #267).
- Recording the dropper for a DCS-native release.

## Further Notes

The issue proposed passing the crate's original requester instead. The dropper was preferred: the pilot who requested a crate is not always the one who dropped it.

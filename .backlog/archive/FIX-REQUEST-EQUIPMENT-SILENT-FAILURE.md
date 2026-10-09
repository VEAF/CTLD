# FIX-REQUEST-EQUIPMENT-SILENT-FAILURE

**Status:** merged (PR #250). Compacted from `FIX-REQUEST-EQUIPMENT-SILENT-FAILURE/` on 2026-10-09; the ticket files live on in git history.

Raised by the maintainer in the live check of `FIX-CRATE-DROP-PLACEMENT`: a first Request Equipment produced nothing and the pilot had to ask again, with no message and no trace (same family as the silent parachute spawn failure, #235). A request that produces nothing — crate with no descriptor, crate or set whose creation failed, vehicle whose creation failed (which still announced "Vehicle ready for loading") — now tells the pilot (new key, FR/ES/KO) and logs an ERROR; a partial set logs a WARNING. The cause of the observed failure is undetermined.

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-report-a-failed-request` | ✅ done (PR #250) | 01 — A failed equipment request tells the pilot and the log |

## PRD

## FIX-REQUEST-EQUIPMENT-SILENT-FAILURE — a failed equipment request tells the pilot and the log

**Status:** ✅ done (PR #250)

Raised by the maintainer during the live check of `FIX-CRATE-DROP-PLACEMENT` on 2026-10-03: a first Request Equipment
produced nothing and the pilot had to ask again, with no message and no trace. Same family as the silent parachute spawn
failure fixed by `FIX-PARACHUTE-TROOPS-SPAWN-FAILURE` (#235).

### Problem Statement

The *Request Equipment* callback creates a crate, a set of crates or a whole vehicle for the pilot. When the creation fails,
the pilot is told nothing and nothing is logged by this code, so there is no way to tell a failed request from one that was
never made, and no way to diagnose it afterwards:

- a single crate whose descriptor cannot be found does nothing at all;
- a single crate whose static object cannot be created does nothing;
- a set of crates of which none could be created does nothing (a set where only some were created reports only the count);
- a whole vehicle whose creation fails still tells the pilot "Vehicle ready for loading", although nothing exists: a false
  success.

Each failed attempt also consumes an identifier, which is why the counter of created objects can run ahead of what exists in
the mission.

### Solution

When a request produces nothing, the pilot gets a clear failure message and the log gets an `ERROR` line naming the unit, the
requested item, the zone and the reason. A request that creates only some of the crates of a set is logged as a warning.
A vehicle that could not be created no longer reports success.

### User Stories

1. As a pilot, I want to be told when a crate I requested could not be brought out, so that I know to ask again rather than
   wait for it.
2. As a pilot, I want the same message when a set of crates could not be brought out, so that a set is treated like a single
   crate.
3. As a pilot, I want not to be told "Vehicle ready for loading" when no vehicle exists, so that I do not look for a vehicle
   that was never created.
4. As a pilot, I want the failure message in my language, so that I understand it (EN, FR, ES, KO).
5. As a pilot whose request succeeds, I want exactly the same messages as today, so that nothing changes when it works.
6. As a mission maker, I want an `ERROR` line in the log naming the unit, the item, the zone and the reason, so that I can
   tell a missing descriptor from a static the engine refused.
7. As a mission maker, I want a request that creates only some crates of a set logged as a warning, so that partial failures
   are visible too.
8. As a CTLD developer, I want busted tests for a failed single crate, a failed set, a failed vehicle and the successful
   controls, so that the failure paths are covered.
9. As a maintainer, I want a CHANGELOG entry, so that release notes mention the fix.

### Implementation Decisions

- The *Request Equipment* callback reports a failure through one local routine: an `ERROR` log line (item, unit, zone,
  reason) and a message to the pilot's group, then returns.
- Failure cases: the single crate has no descriptor; the single crate creation returns nothing (through the spawn-plan path or
  the radial path); a set creates no crate (including a set whose descriptors cannot all be found, when none remains); the
  vehicle creation returns nothing.
- Partial set (some created, some not): the existing count message is kept, and a `WARNING` line records how many of how many.
- The vehicle path checks what the creation returns before announcing success.
- New player message: "Request failed: the equipment could not be brought out." with FR, ES and KO translations (the build
  adds the key; the translations are filled in by hand and are a proposal for the maintainer to review).
- No change to any position, placement, weight, or to what a successful request does. No configuration or catalogue change.
- Out of scope: finding why a given request failed (this lot makes the next failure diagnosable), and restoring an identifier
  consumed by a failed attempt.

### Testing Decisions

- A good test observes what the pilot is told and what is logged for a given outcome of the creation, not how the callback is
  organised.
- Seam: a new functional spec built on the existing Request Equipment spec's harness (real menu builder over a real zone
  manager, the real callback read back from the menu node, doubles for the aircraft and the object creation). Cases written
  first and seen failing: a single crate whose creation fails, one whose descriptor is missing, a set that creates nothing and a
  vehicle whose creation fails each give the failure message and an `ERROR` line; the failure message is French when the
  language is French; the successful single crate, set and vehicle give no failure message (controls); a partial set logs a
  warning and still reports its count.
- Existing Request Equipment specs pass unchanged.
- No live-DCS test: the failure is forced by doubles.

### Out of Scope

- The root cause of the failed request seen on 2026-10-03 (undetermined: nothing was logged).
- The troop and vehicle-load menus.

### Further Notes

Raised in conversation on 2026-10-03; no GitHub issue.

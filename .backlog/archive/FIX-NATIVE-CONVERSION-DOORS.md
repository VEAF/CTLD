# FIX-NATIVE-CONVERSION-DOORS

**Status:** merged (PR #251). Compacted from `FIX-NATIVE-CONVERSION-DOORS/` on 2026-10-09; the ticket files live on in git history.

Raised by the maintainer in the live checks of 2026-10-03 (UH-1H): after a crate loaded through the DCS cargo UI was converted by CTLD, the cargo window still listed it (a "ghost"), the weight stayed above the maximum and the next load was refused. A 0.1 s probe showed DCS releases a cargo (`UnloadCargo`) only with the doors open and on the ground — ignored with the doors closed or in flight — while CTLD destroyed the static anyway. CTLD now verifies the cargo left the on-board list before taking the crate over; otherwise it stays DCS-native, the pilot is told to open the doors before takeoff to fit a parachute, and the release is retried on the ground. Live check by the maintainer pending.

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-hand-over-only-after-release` | ✅ done (PR #251) - live check by the maintainer passed 2026-10-03 | 01 — Hand a DCS cargo-UI crate over to CTLD only once DCS has released it |

## PRD

## FIX-NATIVE-CONVERSION-DOORS — a DCS cargo-UI load is handed over to CTLD only once DCS has really released it

**Status:** ✅ done (PR #251) - live check by the maintainer passed 2026-10-03

Raised by the maintainer during the live checks of 2026-10-03 (UH-1H): after a crate was loaded through the DCS cargo UI and
converted by CTLD, the DCS cargo window kept listing the crate and a new load answered "FAILED TO LOAD CARGO". Diagnosed live with a
0.1 s probe of the DCS cargo state; decisions taken with the maintainer the same day (a first design, an automatic retry on the ground, was
built and tried live, then replaced by an explicit action). See ADR 0025 and ADR 0026.

### Problem Statement

For an aircraft type with `convertNativeLoadToCTLD` (the UH-1H), a crate loaded through the DCS cargo UI is handed over to CTLD so that
CTLD's drop and parachute actions become available, as the type has no native parachute. The hand-over asked DCS to release the cargo
(`UnloadCargo`), waited 0.5 s, then destroyed the crate's static object and took the crate over.

Measured in a live UH-1H:

- **With the cargo-bay doors closed, DCS ignores the release**: the call returns success, nothing is released, the cargo stays on board.
  With the doors open on the ground, the release is instantaneous.
- **The release is impossible in flight**, even in a hover with the doors open (checked at 145 m / 32 m/s and at 42 m / 1 m/s).
- Loading through the cargo UI works with the doors closed (DCS shows a warning and loads anyway), so the common case is a load with the
  doors closed.

CTLD destroyed the static object whether or not DCS released the cargo. With the doors closed, DCS was left with an entry for a cargo that
no longer existed: its cargo window still listed the crate, the displayed weight stayed above the maximum, and the single cargo slot of
the UH-1H stayed taken, so the next load was refused. And the pilot's wish to parachute was not met: the crate was never really handed over.

A first fix retried the release automatically while the aircraft was on the ground. Live, it took the crate away the moment the pilot opened
the doors — which is also the gesture to unload it from the DCS cargo UI — before the pilot could unload it.

### Solution

CTLD never destroys a crate DCS still holds. After asking for the release it checks that the cargo has left the on-board list; if it has,
the hand-over completes as before. If it has not (doors closed), the crate stays in DCS-native carry — consistent with DCS, no ghost — and
CTLD tells the pilot how to fit a parachute: open the doors, then F10 > CTLD > Crate Commands > **Fit parachute**. That action, offered only
while such a crate waits and the aircraft is on the ground, asks DCS for the release and completes the hand-over when it succeeds; with the
doors closed it asks the pilot to open them and can be used again. Opening the doors alone does nothing, so the crate can still be unloaded
from the DCS cargo UI.

### User Stories

1. As a pilot loading a crate with the doors closed, I want to be told how to get it fitted with a parachute, so that I know what to do.
2. As a pilot, I want that message in plain words, so that I understand it.
3. As a pilot, I want an explicit action to add the parachute, so that CTLD does not take a crate away when I only open the doors.
4. As a pilot, I want to still unload the crate from the DCS cargo UI after opening the doors, so that the native path stays available.
5. As a pilot, I want the crate handed over on the spot when the doors are already open at loading, so that nothing changes for me then.
6. As a pilot, I want the DCS cargo window to show only what is really on board, so that I can load another crate.
7. As a pilot, I want the Fit parachute entry only while a crate waits and I am on the ground, so that the menu stays clean.
8. As a pilot, I want to be told to open the doors if I use Fit parachute with them closed, and to be able to try again.
9. As a pilot, I want no weight added twice for a crate still held by DCS, so that the aircraft is not heavier than it should be.
10. As a mission maker, I want the hand-over to keep publishing the same events once it completes, so that scripts keep working.
11. As a CTLD developer, I want the static object destroyed only after the cargo is seen leaving the on-board list, so that DCS can never be
    left with a dangling entry.
12. As a CTLD developer, I want an unreadable on-board list to be treated as "still on board", so that CTLD never destroys on a guess.
13. As a CTLD developer, I want busted tests with an aircraft double that releases only when its doors are open, so that each outcome is covered.
14. As a maintainer, I want the measurements and the decision recorded in ADRs and the glossary, so that the reasoning is kept.

### Implementation Decisions

- **Verify before destroying:** after the release request and the existing 0.5 s delay, CTLD reads the aircraft's on-board cargo list. The crate is
  handed over only if it is no longer on it. An unreadable list counts as "still on board".
- **Doors closed (not released):** the crate is marked loaded in DCS-native carry (the existing native path: native flag, `OnCrateLoaded` with
  method `dcs_native`, menu refreshes), flagged as awaiting the hand-over, and the pilot gets the new message instead of the "DCS native" one.
  Nothing is destroyed.
- **Fit parachute:** a new F10 entry under Crate Commands, present for the types with `convertNativeLoadToCTLD` and enabled only while a crate of
  the aircraft awaits the hand-over and the aircraft is on the ground. The action asks DCS for the release, marks the crates as being handed over
  so the release is not handled as a native unload, and after the delay completes the hand-over for each crate that has left the list (the crate
  returns to the ground state at its released position and goes through the existing CTLD load: static destroyed, weight, `OnCrateLoaded` /
  `OnCrateCleared`, and the existing "parachute-ready" message). If a crate is still on board the pilot is asked to open the doors.
- **No automatic retry, no door-state reading.** The flag is cleared when the crate is released natively (unloaded from the DCS cargo UI).
- **Weight and menus** follow from the native state (ADR 0025): the weight CTLD adds and the Drop / Parachute actions apply to handed-over crates
  only.
- **New texts (FR/ES/KO translated, a proposal for the maintainer to review):** the loading message, the entry label "Fit parachute" (FR "Ajouter
  le parachute") and the "open the doors, then use Fit parachute again" message.
- No configuration or catalogue change. Types without `convertNativeLoadToCTLD` are unchanged.

### Testing Decisions

- A good test observes what happens to the crate (state, flags, whether a load is performed, messages), not how it is organised.
- Seam 1: the existing native-cargo functional spec (on-board-list harness), whose aircraft double releases a cargo only when its doors are open
  (as measured). Cases written first and seen failing: doors closed at loading (no hand-over, the crate stays native, the new message, in French);
  opening the doors alone does nothing and the crate can still be unloaded natively; Fit parachute with the doors open hands the crate over; with
  them closed nothing is destroyed, the pilot is asked to open them and can retry; Fit parachute does nothing in flight; an unreadable list when
  verifying destroys nothing; doors open at loading hands over as before.
- Seam 2: a menu spec: the Fit parachute entry exists for a hand-over type, is enabled only while a crate waits and the aircraft is on the ground,
  is absent for a type that does not hand over, and its callback asks the crate manager to fit the parachute.
- Existing native detection, release and conversion specs pass unchanged (two conversion cases simulate the release explicitly).
- Live DCS: protocol with the maintainer in the UH-1H (load with the doors closed: message and clean cargo window; open the doors and unload
  natively; Fit parachute; load with the doors open; reload after a drop). Done in part on 2026-10-03.

### Out of Scope

- Any way of opening or closing the doors by script (none found on the unit object for a player aircraft).
- Releasing a crate in flight (impossible, measured).
- Other aircraft types, which were not measured.

### Further Notes

Raised in conversation on 2026-10-03; no GitHub issue.

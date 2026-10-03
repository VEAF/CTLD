# FIX-NATIVE-CONVERSION-DOORS — a DCS cargo-UI load is handed to CTLD only once DCS has really released it

**Status:** ⬜ ready

Raised by the maintainer during the live checks of 2026-10-03 (UH-1H): after a crate was loaded through the DCS cargo UI and
converted by CTLD, the DCS cargo window kept listing the crate and a new load answered "FAILED TO LOAD CARGO". Diagnosed live with a
0.1 s probe of the DCS cargo state; decisions taken with the maintainer the same day.

## Problem Statement

For an aircraft type with `convertNativeLoadToCTLD` (the UH-1H), a crate loaded through the DCS cargo UI is handed over to CTLD so that
CTLD's drop and parachute actions become available, as the type has no native parachute. The hand-over asks DCS to release the cargo
(`UnloadCargo`), waits 0.5 s, then destroys the crate's static object and takes the crate over.

Measured in a live UH-1H:

- **With the cargo-bay doors closed, DCS ignores the release**: the call returns success, nothing is released, the cargo stays on board.
  With the doors open on the ground, the release is instantaneous.
- **The release is impossible in flight**, even in a hover with the doors open (checked at 145 m / 32 m/s and at 42 m / 1 m/s).
- Loading through the DCS cargo UI works with the doors closed (DCS shows a warning and loads anyway), so the common case is a load
  with the doors closed.

CTLD destroys the static object whether or not DCS released the cargo. With the doors closed, DCS is left with an entry for a cargo that
no longer exists: its cargo window still lists the crate, the displayed weight stays above the maximum, and the single cargo slot of the
UH-1H stays taken, so the next load is refused. The same goes for the pilot's wish to parachute: the crate was never really handed over.

## Solution

CTLD never destroys a crate DCS still holds. After asking for the release it checks that the cargo has left the on-board list; if it
has, the hand-over completes as today. If it has not (doors closed), the crate stays in DCS-native carry — consistent with DCS, no ghost
— and CTLD tells the pilot, in plain words, to open the doors before takeoff to fit the crate with a parachute. While the aircraft is on
the ground CTLD retries the release every second; the moment the doors are opened the release succeeds and the hand-over completes. At
takeoff it stops retrying and the crate stays native.

## User Stories

1. As a pilot loading a crate with the doors closed, I want to be told how to get it fitted with a parachute, so that I know what to do.
2. As a pilot, I want that message in plain words, not in terms of the cargo system, so that I understand it.
3. As a pilot, I want the crate to be handed over to CTLD as soon as I open the doors on the ground, so that I do not have to do
   anything else.
4. As a pilot, I want the crate handed over on the spot when the doors are already open at loading, so that nothing changes for me then.
5. As a pilot, I want the DCS cargo window to show only what is really on board, so that I can load another crate.
6. As a pilot, I want a crate I did not hand over to stay a normal DCS-native crate, so that I can still unload it from the DCS cargo UI.
7. As a pilot taking off with a crate that was not handed over, I want CTLD to stop trying, so that nothing changes in flight.
8. As a pilot, I want no weight added twice for a crate still held by DCS, so that the aircraft is not heavier than it should be.
9. As a mission maker, I want the hand-over to keep publishing the same events once it completes, so that scripts keep working.
10. As a CTLD developer, I want the static object destroyed only after the cargo is seen leaving the on-board list, so that DCS can never
    be left with a dangling entry.
11. As a CTLD developer, I want an unreadable on-board list to be treated as "still on board", so that CTLD never destroys on a guess.
12. As a CTLD developer, I want busted tests with an aircraft double that releases only when its doors are open, so that each outcome is
    covered.
13. As a maintainer, I want a CHANGELOG entry and the pilot documentation updated, so that the behaviour is documented.

## Implementation Decisions

- **Verify before destroying:** after the release request and the existing 0.5 s delay, CTLD reads the aircraft's on-board cargo list. The
  crate is handed over only if it is no longer on it. An unreadable list counts as "still on board".
- **Doors closed (not released):** the crate is marked loaded in DCS-native carry (the existing native path: native flag, `OnCrateLoaded`
  with method `dcs_native`, menu refreshes), flagged as awaiting hand-over, and the pilot gets the new message instead of the "DCS native"
  one. Nothing is destroyed.
- **Retry on the ground:** each detection tick, a flagged crate whose carrier is on the ground gets another release request. A release
  seen by the existing native-release detection, for a flagged crate on the ground, completes the hand-over: the crate returns to the
  ground state at its released position and goes through the existing CTLD load (static destroyed, weight, `OnCrateLoaded` /
  `OnCrateCleared`), with the existing "parachute-ready" message.
- **Takeoff:** the flag is cleared; the crate stays native. Releases are impossible in flight (measured), so there is nothing to retry.
- **No door-state reading:** the retry relies on the measured behaviour (ignored when closed, immediate when open); the door argument of
  the aircraft is not read.
- **Weight and menus** follow from the native state: the weight CTLD adds and the Drop / Parachute actions apply to the hand-over crates
  only, as per `FIX-NATIVE-CRATE-CTLD-ACTIONS`.
- **Message (new key, FR/ES/KO translated, a proposal for the maintainer to review):** EN "Crate loaded. Open the doors before takeoff to
  fit it with a parachute." FR "Caisse chargée. Ouvrez les portes avant le décollage pour y ajouter un parachute." (wording approved by the
  maintainer).
- Known side effect: opening the doors on the ground with a waiting crate hands it over to CTLD, so a pilot who opened them to unload from
  the DCS cargo UI will use *Drop Crate(s)* instead.
- No configuration or catalogue change. Types without `convertNativeLoadToCTLD` are unchanged.

## Testing Decisions

- A good test observes what happens to the crate (state, flags, whether a load is performed, messages), not how it is organised.
- Seam: the existing native-cargo functional spec (on-board-list harness). Its aircraft double gets a release that works only when its doors
  are open (open by default, so the existing conversion cases are unchanged). New cases written first and seen failing: doors closed at
  loading — no hand-over, the crate stays native, the new message, no "parachute-ready"; doors opened on the ground afterwards — the release
  is retried, the crate is handed over and the "parachute-ready" message is given; takeoff with the doors closed — no more retry, the crate
  stays native; an unreadable list when verifying — nothing destroyed; doors open at loading — handed over as before.
- Existing native detection, release and conversion specs pass unchanged.
- Live DCS: protocol with the maintainer in the UH-1H (load with the doors closed: message and clean cargo window; open the doors on the
  ground: hand-over; load with the doors open; takeoff with a waiting crate). Not run by the automated suite.

## Out of Scope

- Any way of opening or closing the doors by script (none found on the unit object for a player aircraft).
- Releasing a crate in flight (impossible, measured).
- Other aircraft types, which were not measured.

## Further Notes

Raised in conversation on 2026-10-03; no GitHub issue.

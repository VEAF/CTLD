# ADR 0026 — A DCS cargo-UI load is handed over to CTLD by an explicit "Fit parachute" action

**Date:** 2026-10-03
**Status:** Accepted
**Lot:** `FIX-NATIVE-CONVERSION-DOORS`.

## Context

A type with no native parachute (the UH-1H) can still offer CTLD's drop and parachute actions: a crate loaded through the DCS cargo UI is
**handed over** to CTLD (`convertNativeLoadToCTLD`): CTLD asks DCS to release the cargo (`Unit:UnloadCargo`), then destroys the crate's static
object and takes the crate over as virtual carry. Live, on a UH-1H, this left DCS's own cargo window listing a crate that no longer existed, the
displayed weight above the maximum, and the single cargo slot taken, so the next load was refused ("FAILED TO LOAD CARGO").

A 0.1 s probe of the DCS cargo state, in the live mission, showed why:

| Situation | `Unit:UnloadCargo` |
|---|---|
| on the ground, doors closed | ignored: returns success, nothing is released (checked up to 20 s later) |
| **on the ground, doors open** | **released in the same frame**; the crate lands about 9.7 m from the aircraft |
| in flight (145 m / 32 m/s), doors open | ignored |
| in flight, hover (42 m / 1.1 m/s), doors open | ignored |

Loading through the cargo UI works with the doors closed (DCS shows a warning and loads), so the usual load had its release silently ignored, and
CTLD destroyed the static 0.5 s later regardless. No method to open or close the doors of a player aircraft exists on the unit object, and the
aircraft's door state does not need to be read to know whether a release worked: the cargo either leaves the on-board list or it does not.

## Decision

- **CTLD never destroys a crate DCS still holds.** After asking for the release it checks that the cargo has left the on-board list (an
  unreadable list counts as "still on board"); only then does it take the crate over.
- If DCS did not release it (doors closed), the crate stays in **native carry**, flagged as awaiting the hand-over, and the pilot is told how to
  fit it with a parachute.
- The hand-over is an **explicit pilot action**: the F10 entry *Fit parachute* (offered only while such a crate waits and the aircraft is on the
  ground) asks DCS for the release and completes the hand-over when it succeeds; with the doors closed the pilot is asked to open them and may try
  again. **Opening the doors alone does nothing**, so the crate can still be unloaded from the DCS cargo UI.

## Considered options

- **Retry the release automatically while the aircraft is on the ground.** Built and tried live. Rejected: opening the doors is also the gesture
  to unload from the DCS cargo UI, and the retry took the crate away the moment the pilot opened them, before the pilot could unload it natively.
- **Hand over only if the doors are open at loading, otherwise stay native for good.** Rejected: the usual load is made with the doors closed,
  so most crates would never get the parachute, which is what the hand-over exists for.
- **Release the cargo only when CTLD acts on it (drop or parachute).** Rejected: DCS does not release in flight, so a parachute drop from the hold
  could not be prepared there.
- **No hand-over for these types.** Rejected: it removes the parachute for aircraft that have none natively.
- **Read the door state and act on it.** Not needed: the on-board list answers the question, and the door draw argument is not known to be stable
  across aircraft types.

## Consequences

- No ghost entry can be left in DCS's cargo window, and the single cargo slot is never taken by a cargo that no longer exists.
- The pilot of a hand-over type gets the parachute with one extra step (open the doors, then *Fit parachute*), explained by the message at loading.
- Only the UH-1H was measured. The behaviour of other aircraft types (the CH-47F and Mi-24P among them) is unverified.

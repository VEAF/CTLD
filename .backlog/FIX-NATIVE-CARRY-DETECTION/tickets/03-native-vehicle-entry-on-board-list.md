# 03 — Native vehicle entry read from the DCS on-board cargo list

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-NATIVE-CARRY-DETECTION](../PRD.md). [ADR 0022](../../../dev/adr/0022-native-carry-detected-from-dcs-on-board-cargo-list.md).
Stories 5, 8, 13, 21, 22, 25, 26.

## What to build

The native scan that turns a `WAITING` vehicle into a **native-carry** vehicle no longer tests
positions. It reads the **on-board cargo list** of each candidate aircraft each tick and loads a
tracked vehicle that appears on it.

- **Candidates** are player-controlled units whose type declares a native cargo system, in **any
  category** (airplane or helicopter). AI units are never scanned. Whole-vehicle tracking also
  requires the type to be whole-vehicle capable.
- **Identity.** A whole vehicle shows up on the list through a companion entry named `CRG:`
  followed by its unit name. The prefix is stripped to find the tracked `WAITING` vehicle. Type,
  weight and count are not re-checked by CTLD: DCS decides what a native cargo system accepts.
- **Untracked entries** (cargo created by the loadmaster tablet, editor crates of an unknown type)
  are ignored, with one debug-level trace.
- **Unreadable list.** If reading the list fails for a type (error or function missing), one
  warning is logged for that type and the type is no longer watched. No geometric fallback.
- The idle case (no waiting or native-carry vehicle) still returns before any scan.

There is no box, ground, speed or coalition test and no drift reference: DCS is the authority.
`OnVehicleLoaded` keeps its payload, with method `dcs_native`.

The list-reading helper written here is reused by the crate ticket.

## Acceptance criteria

- [ ] A player Mi-8MT or CH-47F (helicopters) is scanned; an AI-flown aircraft never is.
- [ ] A `WAITING` vehicle whose `CRG:` entry appears on a candidate's list is loaded as native
      carry; nothing else about its position matters.
- [ ] An entry that is not a tracked vehicle is ignored with a debug trace and changes no state.
- [ ] An unreadable list logs exactly one warning per type and that type is skipped.
- [ ] The idle case still returns before any scan.
- [ ] The unused native tracking table and the positional entry code are removed; luacheck clean.
- [ ] Busted spec drives one tick with DCS doubles for each case above.
- [ ] `CHANGELOG.md` `[Unreleased]` has a `Fixed` entry.

## Blocked by

None - can start immediately.

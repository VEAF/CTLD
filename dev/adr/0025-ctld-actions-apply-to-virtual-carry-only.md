# ADR 0025 — CTLD's unload, parachute and weight apply to virtual carry only; DCS owns native carry

**Date:** 2026-10-03
**Status:** Accepted
**Lot:** `FIX-NATIVE-CRATE-CTLD-ACTIONS`.

## Context

A crate (or a whole vehicle) can be on board an aircraft in two modes (see **Virtual carry** and **Native carry** in `CONTEXT.md`). For
crates the code did not follow one rule for both: the F10 *Drop Crate(s)* action collected native-carry crates too and, for each, created a
second DCS object on the ground while the original stayed in the aircraft's cargo bay; *Parachute Crates* was enabled by native-carry crates and
destroyed the DCS object of a crate that was in the bay; and CTLD added the weight of native-carry crates to the aircraft's internal cargo, on
top of the weight DCS already counts for what is loaded through its own cargo UI (measured live on a C-130J-30: the displayed total rose by a
further 2205 lb, the crate's own mass, when CTLD pushed it). Whole vehicles already followed the opposite, correct, rule. The predicate that was
meant to tell the two modes apart (`isLoadedByCTLD`) had the same body as `isLoaded` and so told nothing.

## Decision

The rules, stated by the maintainer:

1. A crate in **native carry** is unloaded only through the DCS cargo UI, without respawn.
2. A crate in native carry on an aircraft that can parachute is parachuted only through the DCS cargo UI.
3. A crate in **virtual carry** (loaded through the CTLD F10 menu, or handed over to CTLD) has CTLD's unload and parachute actions.
4. DCS already handles the weights and limits of what it holds; **CTLD adds a weight only for what it virtualised.**

`isLoadedByCTLD()` means "loaded in virtual carry", and CTLD's *Drop Crate(s)*, *Parachute Crates* and the weight it adds use it. Loading a crate
clears the native flag, so a crate released natively and later loaded through the menu is not hidden from CTLD's actions by a stale flag.

## Considered options

- **Make CTLD's actions apply to every loaded crate, native ones included.** Rejected: DCS keeps the cargo in the bay, so CTLD can only
  duplicate it (a second object on the ground) or destroy an object DCS still tracks, and DCS's cargo window is left inconsistent.
- **Give `isLoadedByCTLD()` the meaning of "loaded, whatever the mode" and document it.** Rejected: it would keep two predicates with one meaning,
  and the call sites needed the distinction.
- **Keep adding the weight of native crates.** Rejected: measured as a double count against what DCS displays.

## Consequences

- Native carry and virtual carry behave the same for crates and whole vehicles.
- The distinction between modes lives in one predicate and one flag; the weight CTLD pushes to DCS is the weight of virtual-carry cargo only.
- A native-carry crate cannot be dropped or parachuted by CTLD; to give a type CTLD's actions, its crates must be handed over to CTLD
  (ADR 0026).

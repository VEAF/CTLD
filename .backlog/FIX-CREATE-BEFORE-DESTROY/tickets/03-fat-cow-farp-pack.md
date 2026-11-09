# 03 — Fat Cow FARP pack creates its crates before closing the FARP

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-CREATE-BEFORE-DESTROY](../PRD.md). Stories 6, 7, 12, 16, 17, 19-21.

## What to build

*Pack the Fat Cow FARP* from a landed piloted cow: the FARP's remaining stock becomes cow crates on the ground next to the cow and the FARP
closes, or — if the crates cannot all be created — the FARP stays open with its stock.

The order becomes: read the warehouse back into the cow's stock (a read, nothing is changed) → split that stock into the crates that carry it
→ create them through the helper of ticket 01 → only then empty the FARP, remove its scene, free its name and forget the piloted cow.

- A stock that no `fatCowCrates` entry can carry no longer ends as "lost": the FARP is kept, an ERROR is logged naming the missing kind, and the
  pilot is told the pack failed.
- An empty FARP (nothing to carry) still packs and closes, and gives no crate, as today.
- Anyone of the coalition may still pack the FARP; the distance rule and the message of a successful pack are unchanged.

## Acceptance criteria

- [ ] A refused or partial creation leaves the FARP open, its warehouse holding what the players left, its name still taken, and no crate on the ground; the pilot reads "Pack failed: the crates could not be created."
- [ ] A stock no crate entry carries leaves the FARP open with an ERROR; it is never logged as lost.
- [ ] On success the crates carry exactly the stock read back (full crates, a part-full last one of each kind), the FARP is closed and its name freed, as today.
- [ ] An empty FARP packs with no crate and closes.
- [ ] New cases in the Fat Cow spec fail before the change and pass after it; existing cases pass unchanged.
- [ ] CHANGELOG, `busted tests/ci/` green, luacheck clean, dictionaries regenerated if a key changed; the lot's index line amended.

## Blocked by

- [01 — All-or-nothing crate creation, ADR 0028, and the vehicle pack](01-helper-adr-and-vehicle-pack.md) (the helper)

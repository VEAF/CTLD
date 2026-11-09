# 04 — Unpacking crates into a unit keeps the crates until the unit exists

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-CREATE-BEFORE-DESTROY](../PRD.md). Stories 8, 9, 16, 19-21.

## What to build

Unpacking crates into a vehicle, a static or a JTAC — by the *Unpack Crate* menu command and by the auto-unpack when a parachuted load lands —
creates the equipment first and consumes the crates only once it exists.

Today the crate manager's unpack marks the crates unpacked, publishes `OnCrateUnpacked` and `OnCrateCleared`, and destroys the statics before the
caller asks DCS for the equipment; a refusal leaves the pilot with neither. The equipment creation reports one of three outcomes: created,
refused by DCS (the group is already told), or nothing attempted (missing data, JTAC drop disabled, JTAC limit reached). Only "created"
consumes the crates; the two others leave them on the ground, so the pilot can unpack again or move them.

- The `OnCrateUnpacked` and `OnCrateCleared` events are published when the crates are really consumed, not before.
- Messages: those of PR #267 stay (a refusal or limit is already reported to the group; success only on a created equipment). A refusal logs an ERROR naming the descriptor.
- The other unpack paths that start a stepped scene (FOB, FARP, any scene) are **out of scope** (PRD decision 3) and keep their order.
- The AA-system assembly path is ticket 05.

## Acceptance criteria

- [ ] Equipment refused by DCS: the crates are still on the ground and registered, no `OnCrateUnpacked` / `OnCrateCleared`, the pilot reads the refusal and not "unpacked successfully", an ERROR is logged.
- [ ] Nothing attempted (JTAC limit, JTAC drop disabled, no spawn position): the crates stay too.
- [ ] Created: the crates are consumed and the events published, as today; "%1 unpacked successfully!" unchanged.
- [ ] The same holds for the auto-unpack of a parachuted equipment crate.
- [ ] A multi-crate descriptor consumes all its crates or none.
- [ ] New cases in the unpack specs fail before the change and pass after it; existing cases pass unchanged.
- [ ] CHANGELOG, `busted tests/ci/` green, luacheck clean, dictionaries regenerated if a key changed; the lot's index line amended.

## Blocked by

- [01 — All-or-nothing crate creation, ADR 0028, and the vehicle pack](01-helper-adr-and-vehicle-pack.md) (ADR 0028 only; this ticket needs no helper, so it may start once the ADR is written)

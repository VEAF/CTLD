# 05 — AA system rearm and repair keep the old system until the new one exists

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-CREATE-BEFORE-DESTROY](../PRD.md). Stories 10, 11, 16, 19-21.

## What to build

Rearming or repairing an AA system respawns it at the same positions, types and headings. It now creates the new group first; only when it
exists does it destroy the old group, consume the rearm or repair crate, and replace the system in the manager's list of complete systems.

The same holds for the **assembly of a new system** from its crates: the group is spawned first and the crates are consumed only once it exists.

If the respawn fails the damaged system stays standing, still in the list, the crate stays on the ground, an ERROR is logged, and the
pilot is told the action failed, with the existing message "Unpack failed: the equipment could not be created." (no new key).
A refused rearm is reported as handled, so the same crates are not then used to assemble a second system.
The success path — the rearmed/repaired events, the coalition message — is unchanged.

The new group is created while the old one still stands on the same spots; DCS must accept it. If the live check shows it does not, this ticket
returns to the maintainer with the measurement instead of working around it.

## Acceptance criteria

- [ ] Respawn refused on a rearm or a repair: the old group is untouched and still tracked, the crate is still there, no "rearmed" / "repaired" event, an ERROR, the pilot is told.
- [ ] On success the old group and the crate are destroyed after the new group exists; the new system is tracked; events and message as today.
- [ ] Both `_rearm` and `_repair` covered, each with a refusal case that fails before the change and passes after it.
- [ ] CHANGELOG, `busted tests/ci/` green, luacheck clean, dictionaries regenerated if a key changed; the lot's index line amended.

## Blocked by

- [01 — All-or-nothing crate creation, ADR 0028, and the vehicle pack](01-helper-adr-and-vehicle-pack.md) (ADR 0028 only)

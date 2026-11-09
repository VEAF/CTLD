# 02 — FARP scene pack creates its crates before destroying the scene

**Status:** ✅ done (PR #300) · **Type:** AFK

## Parent

[PRD — FIX-CREATE-BEFORE-DESTROY](../PRD.md). Stories 4, 5, 12, 16, 17, 19-21.

## What to build

*Pack <scene>* on a deployed FARP: the pilot ends up with the FARP's crates on the ground and the FARP gone, or — if DCS cannot create all the
crates — with the FARP still open, warehouse stock included.

The scene manager's pack splits into its two halves: **capture** (the scene model's repack hook reads the live warehouse into a snapshot; it
changes nothing) and **destroy** (every spawned object goes, the scene leaves the active set). The pack command captures first, creates the
crates through the helper of ticket 01, gives each created crate the snapshot, and only then destroys the scene. A failed creation leaves the
scene active and untouched; the pilot reads "Pack failed: the crates could not be created." and an ERROR is logged naming the scene and the unit.

A pack whose scene model carries no repack hook, or no crate definition, behaves as today.

## Acceptance criteria

- [ ] A refused or partial creation leaves the scene deployed, its objects and warehouse intact, no crate on the ground, the message and an ERROR; the scene is still in the active set and can be packed again.
- [ ] On success the crates carry the warehouse snapshot taken before the destruction, as today, and the message "FARP packed successfully!" is unchanged.
- [ ] The partial-count message and its WARNING added by PR #268 are retired, since a partial creation can no longer happen; the key may stay in the dictionaries.
- [ ] A scene that fails midway through its own deployment, and every other caller of the scene manager's pack, still destroy as before.
- [ ] New cases in the FARP pack spec fail before the change and pass after it; existing cases pass unchanged.
- [ ] CHANGELOG, `busted tests/ci/` green, luacheck clean, dictionaries regenerated if a key changed; the lot's index line amended.

## Blocked by

- [01 — All-or-nothing crate creation, ADR 0028, and the vehicle pack](01-helper-adr-and-vehicle-pack.md) (the helper)

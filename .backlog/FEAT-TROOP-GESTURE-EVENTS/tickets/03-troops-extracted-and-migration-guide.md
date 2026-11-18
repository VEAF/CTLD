# 03 — Extraction in the field is announced (`OnTroopsExtracted`), and the migration guide tells the truth

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FEAT-TROOP-GESTURE-EVENTS](../PRD.md). Stories 5, 7, 9, 10, 13, 14, 15, 16, 17. GitHub issue #308.

## What to build

- **`OnTroopsExtracted`**: a dropped group picked up in the field, at the end of a successful extraction. It covers the nearest-group extraction and the extraction of a chosen group. Payload: the troop group, the carrier unit's name, the player (the slot unit name for a player transport, empty for an AI one), and a timestamp. A refused extraction (in the air, no group nearby, transport full) publishes nothing.
- **The events documentation (EN and FR)**: the troop section lists the six events, with the method that publishes each.
- **The migration guide (EN and FR)**: its v1 → v2 example subscribes to `OnTroopsDeployed` for "Troops landed!". It is corrected to say that `OnTroopsDeployed` covers the **parachute** drop, and to use `OnTroopsUnloaded` for a drop on the ground.
- **The CHANGELOG** gets one `[Unreleased]` entry under "Added" for the lot, listing the four events and what they carry.

## Acceptance criteria

- [ ] A successful field extraction publishes one `OnTroopsExtracted` with the group, the carrier, the player and a timestamp; extracting a chosen group publishes it too.
- [ ] No event on a refusal; an AI transport's extraction publishes it with an empty player.
- [ ] The new cases fail before the change and pass after it; the existing troop specs pass unchanged.
- [ ] The troop section of `events.md` and `events.fr.md` lists the six events.
- [ ] The migration guide example, in both languages, no longer implies that `OnTroopsDeployed` fires on a ground drop and points at `OnTroopsUnloaded`.
- [ ] CHANGELOG `[Unreleased]` entry; `busted tests/ci/` green; luacheck clean; no new translation key.
- [ ] The lot's line in `.backlog/README.md` ("in progress") is set to `merged (PR #NN)` in the PR that delivers the lot (the three tickets ship in one PR).

## Blocked by

- [02 — Loading in a pickup zone and returning to it are announced](02-troops-loaded-and-returned.md)

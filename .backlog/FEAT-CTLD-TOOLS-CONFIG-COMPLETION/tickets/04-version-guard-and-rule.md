# 04 — CI guard and written rule: a catalogue change increments the version

**Status:** ✅ done · **Type:** AFK

## Parent

[PRD — FEAT-CTLD-TOOLS-CONFIG-COMPLETION](../PRD.md). [ADR 0011](../../../dev/adr/0011-complete-yaml-config-and-webapp-tooling.md)
point 5. Stories 20, 21, 22.

## What to build

The completion of ticket 02 depends on the catalogue version moving whenever the catalogue gains a key or a list-entry
field. Nothing enforced that, which is how `enableParachuteDrop` and `crateSpawnGap` slipped in unnoticed. A
reference snapshot of the catalogue's keys and list-entry fields is kept for each version, and a test compares it with
the current catalogue: when they differ and the version was not incremented, it fails with a message that says what
changed and what to do. The rule is written in the contributor instructions and in the developer page.

## Acceptance criteria

- [x] A reference snapshot exists for the current version (`2.1.0`) and matches the catalogue.
- [x] Adding a key or a list-entry field to the catalogue without incrementing the version makes the test fail, with
      a message naming the added item and the step to take.
- [x] Incrementing the version and adding its snapshot makes it pass.
- [x] A fixture-based test proves the guard fails when it should (a deliberately changed copy of the catalogue).
- [x] The rule appears in `CLAUDE.md` and in the developer page, English and French.
- [x] `busted tests/ci/` and the ctld-tools tests pass.

## Blocked by

- [02 — Complete the missing fields of list entries](02-complete-list-entry-fields.md)

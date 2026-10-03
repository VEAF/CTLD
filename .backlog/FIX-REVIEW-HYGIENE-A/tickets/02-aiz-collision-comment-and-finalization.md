# 02 — aiZones collision comment rewritten, CHANGELOG and index finalized

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-REVIEW-HYGIENE-A](../PRD.md). Source: GitHub issue #239. Stories 10-14.
[ADR 0020](../../../dev/adr/0020-auto-discovered-zones-full-name-key.md).

## What to build

Rewrite the comment above the name-collision check in the zone manager's aiZones loader so it
describes today's behaviour, following the text proposed in #239 and ADR 0020: every auto-discovered
zone registers under its full DCS name, so the check can no longer fire by accident on a parsed
sub-name and now only catches a genuine duplicate of a full Mission Editor zone name; it is a
deliberately kept defensive check (that DCS never allows two zones to share a full name is an
assumption about the Mission Editor, not something this code asserts); the closing sentences on why it
lives in the aiZones loader and not in the zone-name validation are kept. **Comment only — the check
and its report are not touched.**

Close the lot:

- `CHANGELOG.md` `[Unreleased]`: one entry for the lot — the EXTR_ scan fix (behaviour) and the comment
  correction. Required by the `changelog-guard` job.
- Run `merge_CTLD.ps1` and confirm the i18n dictionaries are unchanged (no `ctld.tr` string touched).
- `.backlog/README.md` index line for this lot set to `merged (PR #NN)` in the delivering PR, both
  ticket statuses and the PRD status ✅.
- PR to `develop` referencing `Fixes #237` and `Fixes #239`.

## Acceptance criteria

- [ ] The comment states the full-name registration key, the defensive-guard intent and cites ADR 0020;
      the `src/` diff of this ticket is comment lines only.
- [ ] The existing aiZones collision tests pass untouched.
- [ ] `CHANGELOG.md` `[Unreleased]` entry present, covering both fixes.
- [ ] Dictionaries unchanged after the rebuild.
- [ ] Index line `merged (PR #NN)`; PRD and tickets marked ✅.
- [ ] `busted tests/ci/` green; luacheck clean.

## Blocked by

- [01 — EXTR_ scan matches the prefix with its underscore](01-extr-prefix-anchored-with-underscore.md)

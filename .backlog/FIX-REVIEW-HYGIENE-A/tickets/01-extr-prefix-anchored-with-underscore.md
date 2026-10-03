# 01 — EXTR_ scan matches the prefix with its underscore

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-REVIEW-HYGIENE-A](../PRD.md). Source: GitHub issue #237. Stories 1-9.

## What to build

The init-time scan of pre-placed groups registers a group as extractable only when its name starts with
exactly `EXTR_`. A name that merely begins with the four letters `EXTR` (`EXTRACTION Alpha`,
`EXTRA Fuel Trucks`, `EXTREME Recon 1`) is left alone, on every scanned side (RED, BLUE, NEUTRAL).

Write the failing busted cases first, in the existing `EXTR_ convention` block of the core-manager
unit spec: a group named `EXTRACTION_Alpha` and one named `EXTRACTION Alpha` must not be registered,
including a NEUTRAL one. Watch them fail against the current bare-prefix pattern, then fix it. The
existing cases (NEUTRAL `EXTR_Refugees`, substring name ignored, absent group skipped, dedup against
the explicit `extractableGroups` list) must pass unchanged.

The `getName()` read happening before `isExist()` in the same loop may be aligned with the
explicit-list path, only if it stays a one-line reorder with no behaviour change; otherwise leave it.

Re-read `docs/mission-maker/configuration.md` and `docs/developer/architecture.md` (EN + FR) and
correct them only if they imply looser matching than `EXTR_`.

## Acceptance criteria

- [ ] New busted cases fail before the fix and pass after it (test committed first).
- [ ] `EXTR_<name>` groups still register on RED, BLUE and NEUTRAL; dedup and `isExist()` behaviour
      unchanged.
- [ ] Docs checked; changed only if they contradicted the anchored prefix.
- [ ] `CTLD.lua` rebuilt locally; `busted tests/ci/` green; luacheck clean.

## Blocked by

None - can start immediately.

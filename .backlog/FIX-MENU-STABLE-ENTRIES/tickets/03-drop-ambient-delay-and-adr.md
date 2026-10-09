# 03 — Drop the ambient delay, record the decision

**Status:** ⬜ ready once D4 is settled · **Type:** AFK

## Parent

[PRD — FIX-MENU-STABLE-ENTRIES](../PRD.md). Source: GitHub issue #257. Decision D4.

Files: `src/CTLD_menu.lua` (`deferredRefreshForGroup`, `cancelPending`, `AMBIENT_REBUILD_DELAY_S`, `_pendingAmbient`, possibly `runUrgent`), `tests/ci/unit/menu_manager_spec.lua`, `dev/adr/0027-*.md` (new), `dev/adr/0015-*.md` (status: superseded), `dev/adr/README.md`, `docs/developer/subsystems/menu.md` (+ `.fr.md`), `CONTEXT.md` if it defines ambient / urgent refresh, `CHANGELOG.md`.

## What to build

- Every refresh applies the difference at once, behind the existing `DEBOUNCE_S` coalescing; the ambient wipe and its delayed rebuild go.
- ADR 0027: the measurement of #257 (and ticket 01), why the atomic rebuild and the ambient delay both reassign ids, the decisions D1-D4, what stays open (case 2, D5).
- ADR 0015 marked superseded by 0027; the developer menu doc rewritten where it describes "atomic, all-or-nothing rebuilds" and the ambient delay.

## Acceptance criteria

- [ ] busted: the specs that pinned the ambient wipe and its 4 s rebuild are replaced by specs of the immediate, diffed refresh.
- [ ] Docs EN + FR, ADR index, `CHANGELOG.md` `[Unreleased]`.
- [ ] luacheck clean; `busted` green.

## Blocked by

- 02.

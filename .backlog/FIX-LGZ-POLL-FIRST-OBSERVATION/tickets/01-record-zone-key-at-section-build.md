# 01 — Record the zone key when the Request Equipment section is built

**Status:** ✅ done (PR #252) - live check by the maintainer pending · **Type:** HITL (live check by the maintainer)

## Parent

[PRD — FIX-LGZ-POLL-FIRST-OBSERVATION](../PRD.md). Stories 1-5. ADR 0015.

## What to build

Share the logistics zone key between the section build and the poller; record it at the build so the poller's first pass does not see a
false change. Tests first. Then CHANGELOG, backlog index, PR, live check.

## Acceptance criteria

- [ ] New cases fail before the change and pass after it; the existing poller cases pass unchanged.
- [ ] A real zone entry or exit still rebuilds the section.
- [ ] luacheck clean; `busted` green; CHANGELOG entry.
- [ ] Live check by the maintainer: no menu rebuild after entering an aircraft outside any zone.

## Blocked by

None - can start immediately.

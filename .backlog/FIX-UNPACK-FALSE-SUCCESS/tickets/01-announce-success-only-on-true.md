# 01 — Announce "unpacked successfully" only when the group was created

**Status:** ✅ done (PR #267) · **Type:** AFK

## Parent

[PRD — FIX-UNPACK-FALSE-SUCCESS](../PRD.md). Stories 1-5. GitHub issue #264.

## What to build

In the Unpack Crate callback, announce success only when `_spawnUnpacked` returned `true`; log the click when nothing could be attempted.
Tests first (JTAC limit reached, creation succeeds, DCS refuses, no spawn position). Then CHANGELOG, backlog index, PR.

## Acceptance criteria

- [ ] New cases fail before the change and pass after it.
- [ ] A JTAC unpack blocked by the limit shows the refusal reason and no success message.
- [ ] luacheck clean; `busted` green; CHANGELOG entry.

## Blocked by

None - can start immediately.

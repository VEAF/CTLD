# 02 — Live weight check and finalization

**Status:** ✅ done (PR #NN) · **Type:** HITL (live DCS check with the maintainer in a native-cargo aircraft)

## Parent

[PRD — FIX-NATIVE-CRATE-CTLD-ACTIONS](../PRD.md). Stories 9-12, 18-19.

## What to build

- A diagnostic scenario (human tier) that, with a crate loaded through the DCS cargo UI, reports the weight CTLD
  contributes for it and the weights DCS lists, so the maintainer can compare with the total DCS shows.
- Run it **before** the change on the currently loaded build (baseline: CTLD counts the native crate) and
  **after** (CTLD counts zero for it), with a virtual crate also loaded for the mixed case. Record both in the PR.
- Remove the two roadmap entries, add the CHANGELOG entry, rebuild `CTLD.lua` and confirm the i18n dictionaries
  are unchanged, set the index line to `merged (PR #NN)` and the statuses to done, open the PR.

## Acceptance criteria

- [ ] Baseline and after-change results recorded in the PR, with what the maintainer read in DCS.
- [ ] Roadmap entries removed, CHANGELOG entry added, dictionaries unchanged, index line `merged (PR #NN)`.
- [ ] luacheck clean; `busted` green; CI green.

## Blocked by

- [01 — Virtual-carry-only actions](01-virtual-carry-only-actions.md)

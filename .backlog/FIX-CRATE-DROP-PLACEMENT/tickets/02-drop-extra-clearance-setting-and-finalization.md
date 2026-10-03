# 02 — Extra clearance for dropped crates, catalogue 2.2.0 and finalization

**Status:** ✅ done (PR #248) · **Type:** AFK

## Parent

[PRD — FIX-CRATE-DROP-PLACEMENT](../PRD.md). Stories 4-6, 15-16.

## What to build

Add the setting `crateDropExtraDistance` (metres, default 2): the dropped row stands that much farther than the
declared plan distance (plan path only; zero gives exactly the requested position). Tests first: with the plan, the
default setting puts the crates at the plan distance plus the extra distance, and zero puts them at the plan
distance. Then the catalogue process: increment `configVersion` to 2.2.0, add `tests/ci/data/catalogue_shapes/2.2.0.json`
and the default to `tests/ci/data/config_defaults.json`, the schema entry (label, unit, description EN + FR), and update the
ctld-tools tests that assert the real catalogue's version.

Finish the lot: ADR 0024 addendum, crate subsystem and catalogue docs (EN + FR), CHANGELOG, remove the roadmap
entry, index line `merged (PR #248)` and statuses done, open the PR (record that the default is not yet verified in the
cockpit).

## Acceptance criteria

- [ ] Extra-distance cases fail before the change and pass after it (test committed first).
- [ ] `configVersion` 2.2.0, shape snapshot, defaults and schema entry present; ctld-tools version tests updated; CI
      green (ctld-tools quality gate, oracle drift guard, config specs).
- [ ] ADR addendum, docs EN + FR, CHANGELOG entry, roadmap entry removed, index line `merged (PR #248)`.
- [ ] luacheck clean; `busted` green.

## Blocked by

- [01 — Shared placement and drop](01-shared-placement-and-drop.md)

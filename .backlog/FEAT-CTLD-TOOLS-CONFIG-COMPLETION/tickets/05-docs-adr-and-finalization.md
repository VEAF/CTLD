# 05 — Documentation, ADR addendum and finalization

**Status:** ✅ done · **Type:** AFK

## Parent

[PRD — FEAT-CTLD-TOOLS-CONFIG-COMPLETION](../PRD.md). [ADR 0011](../../../dev/adr/0011-complete-yaml-config-and-webapp-tooling.md).
Stories 19, 23, 24, 25, 26.

## What to build

The documentation says what the tool does after this lot, nothing else.

- **ADR 0011 Addendum 2:** completion on opening is automatic but always shown; it refines point 5's "surface the
  diffs to review before re-injecting" for additions, leaves the runtime a straight `or`, and records the version
  independence and the CI guard.
- **Docs, English and French:** the Mission Maker pages for ctld-tools (what happens on opening, the summary, undo,
  the versions shown, why a missing field is respected once saved) and for the crate catalogue, where the warning
  added by PR #221 telling Mission Makers to type the crate spawn fields by hand is **replaced** by the real
  behaviour; the developer pages (completion in the core, version rule, guard).
- **Changelog:** the `[Unreleased]` entries of the lot, consolidated.
- **Finalization:** the PRD status set to done and the lot's index line set to `merged (PR #NN)` in the delivering
  PR; the build regenerates the i18n dictionaries; `CTLD.lua` rebuilt.

## Acceptance criteria

- [x] ADR 0011 carries Addendum 2.
- [x] The English and French pages carry the same content and no longer tell the Mission Maker to enter the crate
      spawn fields by hand.
- [x] Every statement about opening, completion, versions and the guard matches the behaviour delivered by tickets
      01 to 04 (checked against the running tool).
- [x] `CHANGELOG.md` `[Unreleased]` covers the lot without duplicates.
- [x] The PRD status is done and the index line is `merged (PR #NN)`.
- [x] `busted tests/ci/`, luacheck, the ctld-tools tests, `ruff check` and `ruff format --check` pass on the whole
      branch.

## Blocked by

- [01 — Complete the missing scalar parameters](01-complete-scalar-parameters.md)
- [02 — Complete the missing fields of list entries](02-complete-list-entry-fields.md)
- [03 — Make the versions visible](03-version-visible-everywhere.md)
- [04 — CI guard and written rule](04-version-guard-and-rule.md)

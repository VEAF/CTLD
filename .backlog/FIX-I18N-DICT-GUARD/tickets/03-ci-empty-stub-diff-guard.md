Status: ready

# 03 — New-empty-stub diff detection + `skip-i18n` bypass

## Parent

`.backlog/FIX-I18N-DICT-GUARD/PRD.md` (ADR 0013)

## What to build

A new script, `tools/build/check_i18n_diff.py`, that compares each non-EN dictionary
(`CTLD_i18n_fr/es/ko.lua`) at the PR's base ref vs. its head: for each key, if the head value is
`""` where the base value was either non-empty or the key was absent from base entirely, that key
is reported as a newly-introduced empty stub — genuinely new to this PR, not part of the
pre-existing debt already on `develop`. The script reuses `tools/build/i18n_dict_utils.py` (from
ticket 02) for parsing, and exits non-zero listing the offending keys when any are found.

Extend the `i18n-guard` job added in ticket 01 with a new step running this script. Unlike the
`MISSING` check, this step is bypassable: read the PR's labels for `skip-i18n` into an env var
(same pattern `changelog-guard` already uses for `skip-changelog`) and skip the step entirely when
present.

## Acceptance criteria

- [ ] `check_i18n_diff.py` exists, reuses the shared parser from ticket 02, and correctly
      classifies: a key newly added and empty (flagged); a key already empty at the PR base and
      still empty at head (not flagged — pre-existing debt); a key translated at base then blanked
      at head (flagged); a key with a real translation (not flagged).
- [ ] Unit tests cover all four cases above using base/head text fixture pairs — no git or network
      access required for the core comparison logic.
- [ ] The `i18n-guard` job (ticket 01) runs this check as an additional step for every PR.
- [ ] The step fails the job when a newly-introduced empty stub is found in fr, es, or ko.
- [ ] The step is skipped (job passes regardless of stub content) when the PR carries the
      `skip-i18n` label.
- [ ] The existing `MISSING` check from ticket 01 is unaffected by the `skip-i18n` label — it still
      always runs and still always blocks.
- [ ] Manually verified with a throwaway test PR: a PR adding a new `ctld.tr()` call with an empty
      non-EN stub fails the job; applying `skip-i18n` makes it pass; filling in the translation
      instead of applying the label also makes it pass.

## Blocked by

- Ticket 01 (`01-ci-missing-key-guard`) — the `i18n-guard` job must exist to extend.
- Ticket 02 (`02-fix-translate-stub-detection`) — reuses `tools/build/i18n_dict_utils.py`.

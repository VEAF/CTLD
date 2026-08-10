Status: ready

# FIX-I18N-DICT-GUARD — CI-enforced i18n dictionary guard

Reported by **FullGas**: some F10 menu entries stay untranslated when switching CTLD's interface
to Korean. Grilled with docs on 2026-08-10 (**ADR 0013**).

## Problem Statement

A Mission Maker switching CTLD's language to Korean (or Spanish) sees some F10 menu entries fall
back to English — the entries themselves are fine, they simply were never translated. Nothing
during development or the PR process caught this: `develop` today carries 91 untranslated entries
in `CTLD_i18n_ko.lua` and 76 in `CTLD_i18n_es.lua`, and nothing stops a new PR from adding more.

The tooling meant to prevent exactly this doesn't work as documented:

- `generate_i18n_dicts.ps1 -Apply` (run by every `merge_CTLD.ps1`) adds a key missing from a
  dictionary as an empty stub (`= ""`) — it does not translate.
- `translate_i18n.py` (`BUILD-DICT-AI-TRANSLATE`, PR #60) is supposed to fill those stubs locally
  via Claude when `ANTHROPIC_API_KEY` is set, but its stub-detection only recognises a value
  identical to the English text as "untranslated" — never an empty string. So a freshly-added key
  is never selected for translation, with or without the API key.
- The only existing guard, `.githooks/pre-push` (`BUILD-DICT-AUTOSYNC`, PR #59), is opt-in
  (`git config core.hooksPath .githooks`, a manual post-clone step) and checks only that a key
  exists in every dictionary — an empty value already satisfies it.

## Solution

A new CI job, `i18n-guard`, blocks a PR that introduces an i18n key without an entry in all four
dictionaries (`MISSING`, unconditional — no bypass, costs nothing to fix) or leaves a *newly
introduced* non-EN entry empty (bypassable via a `skip-i18n` label, for contributors without local
`ANTHROPIC_API_KEY` access). It is diff-scoped against the PR's base, on the same model as the
existing `changelog-guard` job (`CHORE-DOC-GATES`, PR #39) — it only ever prevents *new* debt,
never retroactively fails a PR over the 167 entries already on `develop`.

`translate_i18n.py`'s stub detection is fixed in the same lot (a value of `""` is now also treated
as a stub) so a developer running `merge_CTLD.ps1` locally with `ANTHROPIC_API_KEY` set can
actually satisfy the guard — without that fix, the guard would be unsatisfiable by the very tool
built to satisfy it.

Full rationale and rejected alternatives (CI auto-translate, absolute/non-diff guard, no bypass,
extending the `build` job instead of a new one): **ADR 0013**.

## User Stories

1. As a Mission Maker playing CTLD in Korean, I want every F10 menu entry translated, so that I
   don't hit raw English fallback text mid-mission.
2. As a Mission Maker playing CTLD in Spanish, I want the same guarantee, so translation coverage
   isn't a Korean-only fix.
3. As a CTLD contributor adding a new `ctld.tr()` string, I want CI to tell me my PR is missing a
   dictionary key, so I don't ship an untranslatable string by accident.
4. As a CTLD contributor, I want CI to fail if the key I added stays untranslated in FR/ES/KO, so
   untranslated debt can't grow silently again.
5. As a CTLD contributor without `ANTHROPIC_API_KEY` available, I want an escape hatch, so a
   translation gap I can't personally close doesn't block an otherwise-ready contribution.
6. As a maintainer, I want the `skip-i18n` label to be a deliberate, visible action on the PR, not
   a default, so bypassing translation stays an exception a reviewer can see and account for.
7. As a maintainer, I want the `MISSING`-key check to have no bypass, so no key ever ships without
   at least an entry in all four dictionaries, label or not.
8. As a developer running `merge_CTLD.ps1` locally with `ANTHROPIC_API_KEY` set, I want
   `translate_i18n.py` to actually pick up and translate the stubs it just created, so the tool
   does what its own docstring says it does.
9. As a maintainer, I want the guard scoped to each PR's diff rather than the whole repository
   state, so the 167 pre-existing empty entries don't block unrelated PRs the day this ships.
10. As a maintainer, I want the pre-existing debt tracked explicitly rather than silently ignored,
    so a follow-up lot repays it deliberately instead of it being forgotten.
11. As a developer touching the new detection logic later, I want it covered by unit tests, so a
    future change to the stub or diff logic doesn't silently regress — `tools/build/` has zero test
    coverage today.
12. As a reviewer, I want the new CI job structured like `changelog-guard` (same trigger shape,
    same label-bypass mechanism), so the pattern is immediately recognisable rather than a one-off.
13. As a developer relying on the local `pre-push` hook, I want it to keep working exactly as
    before, so this lot doesn't slow it down or duplicate logic it doesn't need.
14. As a future contributor reading `dev/adr/`, I want the trade-offs behind "CI blocks but never
    auto-translates" recorded, so nobody "fixes" that as an oversight later.

## Implementation Decisions

- **New CI job `i18n-guard`** in `ci.yml`, PR-triggered only (`if: github.event_name ==
  'pull_request'`), `ubuntu-latest` (ships `pwsh` natively — no `windows-latest` needed),
  `fetch-depth: 0` checkout — same shape as `changelog-guard`.
- **`MISSING` check**: reuse `generate_i18n_dicts.ps1`'s existing dry-run (no changes to that
  script — its scan of `ctld.tr()` calls and the config YAML is already correct); the job greps
  its output for `MISSING` and fails unconditionally if found. `STALE` entries in that same output
  are ignored by this job, exactly as `.githooks/pre-push` already treats them (warn-only,
  non-blocking, unaffected by this lot).
- **New empty-stub check**: a new script, `tools/build/check_i18n_diff.py`, compares each non-EN
  dictionary's content at the PR base vs. head (`git show <base_sha>:<path>` vs. the checked-out
  file) and reports any key whose head value is `""` where the base value was non-empty or the key
  was absent — i.e. genuinely new to this PR, not pre-existing debt. Exits non-zero listing the
  offending keys when any are found.
- **Shared parsing**: the dict-file parser currently private to `translate_i18n.py`
  (`_parse_dict`) is extracted into a new small shared module, `tools/build/i18n_dict_utils.py`,
  and reused by both `translate_i18n.py` and `check_i18n_diff.py` — one parser, not two that can
  drift apart.
- **`skip-i18n` label bypass**: applies only to the new-empty-stub step, read from
  `github.event.pull_request.labels.*.name` into a `HAS_SKIP` env var, same pattern as
  `changelog-guard`'s `skip-changelog`. The `MISSING` step has no such condition — it always runs.
- **`translate_i18n.py` fix**: the stub-selection predicate (currently `lang_dict.get(k) == v`)
  is extended to also match `lang_dict.get(k) == ""`, for any key not listed in that dictionary's
  `__keep_en` block. This is the only change to `translate_i18n.py`'s behavior in this lot.
- **`generate_i18n_dicts.ps1`**: unchanged. Its `""`-for-missing-non-EN convention on `-Apply` is
  the existing contract; the fix targets the consumer (`translate_i18n.py`), not the producer.
- **`.githooks/pre-push`**: unchanged, out of scope — stays `MISSING`-only. CI becomes the single
  authoritative gate; the hook remains a best-effort, non-mandatory local pre-check.
- **CI Python setup**: the new job needs its own `actions/setup-python` step (it's a fresh
  `ubuntu-latest` job, separate from `python-quality`'s `tools/ctld-tools`-scoped environment).

## Testing Decisions

- Tests target external behavior (inputs → outputs of pure functions), not internal wiring —
  consistent with the rest of the repo's test philosophy.
- **`tools/build/i18n_dict_utils.py`** (the extracted parser): unit-tested against dict-file text
  fixtures (well-formed entries, escaped quotes, the `__keep_en` block).
- **`tools/build/check_i18n_diff.py`**'s core function (`find_new_empty_keys` or equivalent): unit
  tested with base/head text fixture pairs — cases: key newly added and empty (flagged); key
  already empty in base and still empty in head (not flagged — pre-existing debt, not new); key
  translated in base then blanked in head (flagged); key genuinely translated (not flagged).
- **`translate_i18n.py`**'s stub-selection predicate: unit tested standalone — empty value → stub;
  value identical to EN text → stub; a real translation → not a stub; a key in `__keep_en` → never
  a stub regardless of its value.
- This is the **first test coverage `tools/build/` has ever had** — no prior art inside that
  directory to follow; the nearest prior art is `tools/ctld-tools`'s own pytest suite (fixture- and
  `tmp_path`-based, no mocking of file I/O internals) for style, even though it's a separate
  package.
- **Not unit tested**: the CI job's YAML itself (trigger condition, label read, checkout/diff
  mechanics) — same as `changelog-guard`, which has no dedicated test either. Verified manually by
  opening a real test PR at merge time (adds/omits a key, with/without the label) rather than
  simulated in a test harness.
- **Wiring**: a new step in `python-quality.yml` (already triggered on `tools/build/**`) runs
  `pip install pytest` (no poetry — matches the existing "pip only" decision recorded for
  `translate_i18n.py`) then `pytest tools/build/`.

## Out of Scope

- **Repaying the 167 pre-existing empty entries** (91 KO + 76 ES) already on `develop`. This guard
  only prevents new debt. A follow-up lot to repay the existing debt must follow immediately —
  tracked as a priority follow-up, not covered by this PRD.
- **Auto-translating in CI** (a bot job calling Claude and committing back to the PR branch).
  Rejected in ADR 0013: would require `ANTHROPIC_API_KEY` as a shared CI secret and a
  write-capable token, reversing `BUILD-DICT-AI-TRANSLATE`'s deliberate "local-only" decision.
- **Changing which languages exist** (fr/es/ko stays the complete non-EN set; nothing here adds or
  removes a language).
- **Modifying `.githooks/pre-push`** or its activation story (still a manual
  `git config core.hooksPath .githooks` post-clone step, untouched by this lot).
- **Blocking on `STALE` keys.** Stays a non-blocking signal, as it already is locally.

## Further Notes

- Full trade-off record: **ADR 0013** (`dev/adr/0013-ci-i18n-dict-guard.md`).
- Prior art this lot builds directly on: `BUILD-DICT-AUTOSYNC` (PR #59, introduced
  `generate_i18n_dicts.ps1 -Apply` in the build + the `pre-push` hook), `BUILD-DICT-AI-TRANSLATE`
  (PR #60, introduced `translate_i18n.py` and the local-only `ANTHROPIC_API_KEY` decision this lot
  preserves), `CHORE-DOC-GATES` (PR #39, introduced the `changelog-guard` pattern this lot mirrors
  job-for-job).
- Debt baseline as of 2026-08-10, for the follow-up repayment lot to start from: 91 empty entries
  in `CTLD_i18n_ko.lua`, 76 in `CTLD_i18n_es.lua`, 0 in `CTLD_i18n_fr.lua` (filled by hand in
  `040bf8c`, outside the auto-translate path).

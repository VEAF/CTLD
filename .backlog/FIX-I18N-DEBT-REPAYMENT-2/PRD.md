Status: ready

# FIX-I18N-DEBT-REPAYMENT-2 — Repay the i18n debt revived by FIX-I18N-STALE-COMMENT-PARSING

Follow-up to `FIX-I18N-STALE-COMMENT-PARSING` (PR #119, merged), which revived 56 keys wrongly
marked `-- STALE:` in all four dictionaries. Reuses the decisions grilled for
`FIX-I18N-DEBT-REPAYMENT` (PR #116) without re-grilling — same task shape, same constraints.

## Problem Statement

Reviving those 56 keys restored English text everywhere and recovered every FR translation that
had been sitting inert in dead comments, but left genuine translation gaps behind: entries that
were never translated even before the STALE-marking bug existed. A Mission Maker playing in
Korean or Spanish still hits English fallback text for these.

## Solution

Fill the remaining empty stubs directly (translations produced and written into the dictionary
files without an external API/CLI call — no `ANTHROPIC_API_KEY` available, and the Claude Code CLI
fallback added by `TOOLING-I18N-CLAUDE-CODE-TRANSLATE` can't be invoked from inside the Claude Code
session doing this work, same nested-session constraint hit during `FIX-I18N-DEBT-REPAYMENT`).

## User Stories

1. As a Mission Maker playing CTLD in Korean, I want the remaining F10/vehicle-category menu
   entries translated, so I don't hit English fallback text for labels that have been live (just
   never translated) since before the STALE-marking bug.
2. As a Mission Maker playing CTLD in Spanish, I want the same for the 7 vehicle-category labels
   still empty there.
3. As a maintainer, I want the repayment scoped to whatever is empty at execution time (22 KO + 7
   ES counted right after `FIX-I18N-STALE-COMMENT-PARSING` merged), not a number frozen at lot
   creation — consistent with `FIX-I18N-DEBT-REPAYMENT`'s dynamic-scope decision.
4. As a maintainer, I want no dedicated KO/ES linguistic review, consistent with the accepted
   mechanism from `FIX-I18N-DEBT-REPAYMENT` and `BUILD-DICT-AI-TRANSLATE` — verification is
   mechanical (zero remaining empty stubs) plus normal PR diff review.

## Implementation Decisions

- Same as `FIX-I18N-DEBT-REPAYMENT`: translations produced directly (no `translate_i18n.py`
  invocation), written into `src/CTLD_i18n_ko.lua` / `src/CTLD_i18n_es.lua` only — `fr` and `en`
  are already complete after `FIX-I18N-STALE-COMMENT-PARSING`.
- Dynamic scope: every entry still empty at execution time, not a frozen list.
- No new tooling, no change to `translate_i18n.py`, `i18n_dict_utils.py`,
  `generate_i18n_dicts.ps1`, `check_i18n_diff.py`, or the `i18n-guard` CI job.

## Testing Decisions

- No new or changed logic — existing `tools/build/` test suite (24 tests) must stay green,
  untouched by this lot.
- Completeness verified mechanically: zero remaining empty entries in `CTLD_i18n_ko.lua` /
  `CTLD_i18n_es.lua` (outside `__keep_en`), and a clean `generate_i18n_dicts.ps1` dry-run (no
  `MISSING`, no unexpected `STALE`).

## Out of Scope

- Any change to i18n tooling code (translation content only).
- `CTLD_i18n_en.lua` / `CTLD_i18n_fr.lua` (already complete).
- The companion asset-check deprecation (separate roadmap item, David's call to defer).

## Further Notes

- Prior art: `FIX-I18N-DEBT-REPAYMENT` (PR #116) — identical task shape and decisions.
- Source of the debt: `FIX-I18N-STALE-COMMENT-PARSING` (PR #119) revived 56 keys; 29 of their
  KO/ES translations (22 KO, 7 ES) were never produced in the first place.

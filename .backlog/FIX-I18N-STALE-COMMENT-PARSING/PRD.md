Status: ready

# FIX-I18N-STALE-COMMENT-PARSING — i18n tooling stops treating `-- STALE:` lines as live

Grilled with docs on 2026-08-10. Idea originated in `dev/roadmap.md` during the roadmap cleanup
following `FIX-I18N-DEBT-REPAYMENT`.

## Problem Statement

CTLD's i18n dictionary tooling (`tools/build/i18n_dict_utils.py`, `generate_i18n_dicts.ps1`,
`translate_i18n.py`) is meant to leave a `-- STALE:`-commented entry alone — a dead key no longer
referenced by any `ctld.tr()` call in `src/`, deliberately kept as a disabled line rather than
deleted ("not deleted — confirm manually"). In practice, every regex-based scan in this tooling
matches a `ctld.i18n[...] = "..."` pattern regardless of a `-- ` comment prefix in front of it, so
a STALE line is indistinguishable from a live one to the code that's supposed to skip it.

Consequence, found concretely during `FIX-I18N-DEBT-REPAYMENT` (2026-08-10): 23 of the 93 KO stubs
and 8 of the 78 ES stubs counted at `FIX-I18N-DICT-GUARD`'s merge were actually `-- STALE:` keys in
`CTLD_i18n_en.lua` — dead, unused entries that `translate_i18n.py` would have spent API/CLI calls
translating and written into lines that are already disabled comments, had they not been manually
excluded from that lot's scope. A second, related symptom found while cleaning up the roadmap: the
KO/ES copies of these same dead keys are *not* marked `-- STALE:` themselves, even though
`CTLD_i18n_en.lua` already marks them — a cross-dictionary drift whose exact historical cause
couldn't be pinned down by static reading alone, but which shares the identical root defect
(`generate_i18n_dicts.ps1`'s own `Get-DictKeys` has the same comment-blind regex).

## Solution

Every place in the i18n tooling that reads a `ctld.i18n[lang][key] = "value"` line — the shared
Python parser, the PowerShell key-existence scanner, and the Python dictionary-writer — is
corrected to skip any line whose stripped text starts with `-- ` (a comment, `STALE`-marked or
otherwise). This is a parsing-correctness fix, not a behavior change to the STALE/MISSING
classification rules themselves: a dead key was always supposed to be invisible to translation and
diff tooling once marked; now it actually is. As a one-time cleanup in the same lot, the corrected
PowerShell scanner is run with `-Apply` to properly mark the currently-unmarked-but-dead KO/ES
entries, closing the drift this lot was written to investigate.

## User Stories

1. As a CTLD contributor running `merge_CTLD.ps1` locally with `ANTHROPIC_API_KEY` (or the Claude
   Code CLI fallback) available, I don't want translation calls spent on dead keys that no F10 menu
   will ever display, so my local build doesn't waste time or usage quota on nothing.
2. As a maintainer reading `i18n-guard` CI output on a PR, I want the `MISSING`/new-empty-stub
   checks to reason about genuinely live keys only, so a dead key commented `-- STALE:` in the PR's
   diff never confuses the diff-scoped comparison in `check_i18n_diff.py`.
3. As a future contributor running `generate_i18n_dicts.ps1` (dry-run or `-Apply`), I want its
   `STALE`/`MISSING` classification to be accurate for every one of the four dictionaries, not just
   whichever one happens to have been scanned most recently by a human.
4. As a maintainer inspecting `CTLD_i18n_ko.lua`/`_es.lua`, I want a dead key to be visibly marked
   `-- STALE:` there too, exactly as it already is in `CTLD_i18n_en.lua`, so the four dictionary
   files agree on which keys are alive without needing to cross-reference `CTLD_i18n_en.lua` by
   hand to find out.
5. As a developer touching this parsing logic later, I want it covered by unit tests exercising a
   `-- STALE:`-commented line explicitly, so a future regression here is caught before it silently
   wastes translation calls again.
6. As a maintainer, I want `translate_i18n.py`'s dictionary-writer to never touch a commented line
   even if invoked differently in the future, so this class of bug can't resurface through a
   different call path than the one that exposed it this time.
7. As a reviewer of this PR, I want the fix to be provably behavior-preserving for every currently
   live, non-commented entry, so the correction is trusted as a bug fix rather than a risk to
   already-working dictionaries.

## Implementation Decisions

- **Three call sites corrected in the same pass**, all sharing the identical defect (a regex or
  line scan that matches `ctld.i18n[...] = "..."` without checking for a leading `-- ` comment
  prefix):
  - `tools/build/i18n_dict_utils.py`: `parse_dict`, `parse_keep_en`, and the underlying
    `_ENTRY_RE`-based matching now skip any line whose stripped text starts with `--`.
  - `tools/build/generate_i18n_dicts.ps1`: `Get-DictKeys` (the function that determines whether a
    dictionary file currently contains a given key, driving both the `MISSING` and `STALE`
    classification) gets the same line-level filter.
  - `tools/build/translate_i18n.py`: `_apply_translations`'s write path is hardened the same way,
    even though it can no longer receive a STALE key in practice once the shared parser is fixed
    (`_collect_stubs` iterates `en_dict`, which will no longer include EN's own STALE keys) — kept
    consistent so the same defect can't resurface via a different caller later.
- **`check_i18n_diff.py` needs no code change.** `find_new_empty_keys` already calls the shared
  `parse_dict`, so it inherits the fix automatically.
- **No change to the `MISSING`/`STALE` classification rules themselves** — a key is still `STALE`
  when unused in `src/` and `MISSING` when absent from a dictionary. This lot only fixes how
  "present in a dictionary" is determined (a commented line no longer counts as present).
- **One-time real-file cleanup, same lot**: after `generate_i18n_dicts.ps1` is fixed, run it with
  `-Apply` once against the repo's actual dictionaries. Expected effect: the KO/ES entries already
  known to be dead in EN (23 KO + 8 ES, per the `FIX-I18N-DEBT-REPAYMENT` count) get their lines
  prefixed `-- STALE:` in `CTLD_i18n_ko.lua`/`_es.lua`, matching what `CTLD_i18n_en.lua` already
  shows. No dictionary *value* changes — only line prefixes on already-empty or already-translated
  dead entries.
- **Root cause of the historical cross-dictionary drift is not fully confirmed.** Static reading of
  `generate_i18n_dicts.ps1` shows the STALE re-marking step is safe against re-triggering on an
  already-commented line (its regex is anchored to line-start `ctld.i18n[...]`, which a `-- STALE: `
  prefix no longer matches) — so the bug being fixed here is not proven to be the direct cause of
  the specific drift observed. It is fixed regardless, on the "same structural defect, fix by
  precaution" reasoning from the grilling session, not on a confirmed causal chain.

## Testing Decisions

- Tests target external behavior of pure functions, consistent with the rest of `tools/build/`'s
  test suite (`test_i18n_dict_utils.py`, `test_translate_i18n.py`, `test_check_i18n_diff.py`).
- **`test_i18n_dict_utils.py`**: new cases — a `-- STALE:`-commented entry is absent from
  `parse_dict`'s result; a commented `__keep_en` block entry (if such a thing is constructed) is
  absent from `parse_keep_en`'s result; a mix of live and commented lines for different keys in the
  same text parses only the live ones.
- **`test_translate_i18n.py`**: new case — `_apply_translations` given a key whose only occurrence
  in the text is a `-- STALE:`-commented line performs no write and reports zero keys written
  (rather than silently uncommenting or corrupting the line).
- **No new test for `check_i18n_diff.py`** beyond what the shared parser's own tests already cover
  — it has no logic of its own affected by this fix.
- **No test against the real `src/CTLD_i18n_*.lua` files.** Fixtures stay synthetic and in-memory,
  matching the existing suite; coupling a unit test to live dictionary content would make it
  fragile to unrelated future dictionary edits.
- **Manual verification**: run the corrected `generate_i18n_dicts.ps1` dry-run against the repo,
  confirm it reports the expected `STALE` set without any `MISSING` regressions; run `-Apply` once
  and diff the result to confirm only line-prefix changes on the expected dead keys, no value
  changes; run `pytest tools/build/` to confirm the full suite (existing + new tests) stays green.

## Out of Scope

- **Deprecating the companion asset-check** (`tools/companion/asset_check.lua`) — a different
  roadmap item, explicitly deferred by David (2026-07-20) to its own lot.
- **Any change to `i18n-guard` CI job behavior.** It continues to check the same `MISSING`/new-empty
  signals; this lot only makes those signals computed correctly, not different.
- **Any new dictionary *content*/translation.** The one-time cleanup (Implementation Decisions)
  changes line prefixes on already-dead entries only, never a translated value.
- **Root-causing the historical drift with git archaeology.** Judged disproportionate for what is,
  going forward, a closed issue once this lot ships.

## Further Notes

- Idea source: `dev/roadmap.md`, "TOOLING — `i18n_dict_utils.py` ne distingue pas une entrée
  `-- STALE:` d'une entrée live" (replaced by a pointer to this lot once formalized).
- Prior art: `FIX-I18N-DICT-GUARD` (ADR 0013) established the `MISSING`/`STALE` vocabulary and the
  diff-scoped CI guard this lot's fix feeds into unchanged; `FIX-I18N-DEBT-REPAYMENT` is where the
  23/8 dead-key miscount was first observed; `TOOLING-I18N-CLAUDE-CODE-TRANSLATE` (ADR 0014) added
  the CLI fallback backend that would otherwise also waste calls translating these same dead keys.

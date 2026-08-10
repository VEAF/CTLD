Status: ready

# FIX-I18N-DEBT-REPAYMENT — Repay the pre-existing i18n translation debt

Follow-up to `FIX-I18N-DICT-GUARD` (PR #115, merged `cfb7cd6`), which explicitly deferred this
work: *"A follow-up lot to repay the existing debt must follow immediately"* (ADR 0013).

## Problem Statement

A Mission Maker running CTLD in Korean or Spanish still hits raw English fallback text on some
F10 menu entries today. `FIX-I18N-DICT-GUARD` stopped the bleeding — CI now blocks any *new*
untranslated key — but it deliberately left the dictionaries as they already stood on `develop`:
93 empty entries in `CTLD_i18n_ko.lua` and 78 in `CTLD_i18n_es.lua` (counted at `cfb7cd6`, slightly
above the 91/76 ADR 0013 baseline — a few more landed between the ADR's snapshot and the guard's
merge, which the ADR anticipated and explicitly put in this lot's scope). `CTLD_i18n_fr.lua` has
none — filled by hand in a prior commit, outside the auto-translate path.

## Solution

Run `tools/build/translate_i18n.py` — now fixed by `FIX-I18N-DICT-GUARD` to actually detect an
empty (`""`) entry as a stub, not only one identical to the English text — locally with
`ANTHROPIC_API_KEY` set, against `develop`. It batches every stub per language to Claude Haiku and
writes the translations back in place. Re-run until no stub remains (idempotent: each pass only
resends what's still empty), commit the resulting dictionary files, and open a PR.

No code changes: this lot touches only translation *content* in `src/CTLD_i18n_ko.lua` and
`src/CTLD_i18n_es.lua`.

## User Stories

1. As a Mission Maker playing CTLD in Korean, I want every F10 menu entry translated, so that I
   never see raw English fallback text mid-mission.
2. As a Mission Maker playing CTLD in Spanish, I want the same guarantee.
3. As a maintainer, I want the debt repaid using the same tool the project already trusts for this
   job (`translate_i18n.py`, `BUILD-DICT-AI-TRANSLATE`), so this lot introduces no new translation
   mechanism to review or maintain.
4. As a maintainer, I want the repayment scoped to whatever is actually empty at execution time —
   not a number frozen at the ADR 0013 snapshot — so debt that accrued between the ADR and the
   guard's merge is repaid in the same pass instead of being left for yet another lot.
5. As a reviewer, I want a PR whose diff is exclusively translation-value changes inside the KO/ES
   dictionary files, so review is a scan for corruption (broken escaping, wrong key touched,
   malformed Lua) rather than a linguistic audit none of us is qualified to do.
6. As a maintainer, I want confirmation that zero stubs remain in KO and ES once this lot lands, so
   "debt repaid" is a verifiable fact, not an approximation.
7. As a future contributor adding a new `ctld.tr()` key, I want this lot to leave `i18n-guard` and
   `translate_i18n.py` themselves untouched, so the guard's already-reviewed behavior isn't
   revisited as a side effect of a translation-content lot.

## Implementation Decisions

- **Tool**: intended to be `tools/build/translate_i18n.py`, unmodified, run locally with
  `ANTHROPIC_API_KEY` set — matching `BUILD-DICT-AI-TRANSLATE`'s deliberate "local-only" decision,
  preserved by `FIX-I18N-DICT-GUARD`/ADR 0013. **Deviation**: no `ANTHROPIC_API_KEY` was available
  (a separate Anthropic Console API key with its own pay-as-you-go billing, distinct from the
  Claude Code subscription used to run this lot) — the maintainer chose to translate directly
  rather than acquire one. Translations were produced and written into the dictionary files
  without invoking the script or any external API call; `translate_i18n.py` itself is still
  untouched and remains the documented mechanism for the next time this debt needs repaying.
- **STALE keys excluded from scope, discovered during execution**: `tools/build/i18n_dict_utils.py`'s
  parser (and by extension `translate_i18n.py`'s stub predicate) does not distinguish a live
  `ctld.i18n[...] = "..."` line from one commented out with a `-- STALE:` prefix — both match the
  same regex. Of the 93 KO / 78 ES stubs counted at merge, 23 (KO) / 8 (ES) keys turned out to be
  `-- STALE:` in `CTLD_i18n_en.lua` itself (no longer referenced by any `ctld.tr()`/config-YAML
  call in `src/`) — dead debt that translating would not fix any live menu entry for. Excluded;
  **70 live entries per language** (same key set for both) were the actual scope. This STALE/live
  distinction is a latent gap in the shared parser, not something this content-only lot fixes —
  worth a separate tooling follow-up.
- **`__keep_en` extended**: two of the 70 live keys (`JTAC`, a proper noun/sigil, and
  `%1 [%2] %3.`, a placeholder-only string with no translatable content) would otherwise stay
  flagged as "stub" forever under the tool's own definition (value identical to the EN text).
  Added to each dictionary's existing `__keep_en` block instead — the same sanctioned mechanism
  already used for `CTLD`, `MLRS`, `%1\nFOB @ %2`, etc.
- **Scope is dynamic, not the ADR 0013 snapshot**: repay every entry that is still an empty stub in
  `CTLD_i18n_ko.lua` and `CTLD_i18n_es.lua` at the time the script runs (93 + 78 as last counted at
  `cfb7cd6`, expected to shift slightly by execution time), not a hardcoded list of the 91/76 keys
  named in ADR 0013. `translate_i18n.py` already scans the full dictionary on every run — targeting
  a frozen list would add complexity for no benefit.
- **Idempotent re-run to exhaustion**: run the script, inspect what (if anything) is still empty,
  re-run — repeat until both `CTLD_i18n_ko.lua` and `CTLD_i18n_es.lua` have zero empty entries
  outside their `__keep_en` block. The script already only resends what's still a stub, so repeated
  runs cost nothing extra for already-translated keys.
- **No new tooling, no changes to `translate_i18n.py`, `i18n_dict_utils.py`, `check_i18n_diff.py`,
  or the `i18n-guard` CI job.** This lot is a data-only repayment on top of already-reviewed
  machinery.
- **`CTLD_i18n_fr.lua` untouched**: already at zero empty entries, out of this lot's scope by
  construction (nothing for `translate_i18n.py` to pick up there).
- **Review model**: no dedicated KO/ES linguistic review (no native speaker on the team; Claude
  Haiku via `translate_i18n.py` is the already-accepted mechanism for this exact case). Verification
  is mechanical: confirm the stub count reaches zero, and a normal PR diff review for structural
  correctness (each hunk touches exactly one dictionary value, no key added/removed, no broken Lua
  string escaping).

## Testing Decisions

- No new or changed logic ships in this lot — `translate_i18n.py` and its unit tests
  (`tools/build/test_translate_i18n.py`, `tools/build/test_i18n_dict_utils.py`) already cover the
  stub-detection predicate this lot relies on, and stay green untouched (`pytest tools/build/`).
- Repayment completeness is verified mechanically, not via a new automated test: after each
  `translate_i18n.py` run, confirm zero remaining empty entries in `CTLD_i18n_ko.lua` and
  `CTLD_i18n_es.lua` (outside `__keep_en`) by inspection — e.g. reusing the existing dict parser
  (`tools/build/i18n_dict_utils.py`'s `parse_dict`/`parse_keep_en`) in a throwaway check, or a
  direct grep for `= ""` cross-checked against each file's `__keep_en` block. This is a one-time
  verification for this lot's PR, not new permanent test coverage.
- `generate_i18n_dicts.ps1`'s dry-run (already run by the existing `i18n-guard` CI job on the PR)
  confirms no `MISSING` key was introduced by this lot — expected to report clean since no key is
  added or removed, only stub values filled in.
- No `src/` *logic* changes, so `busted tests/ci/` and `luacheck` are unaffected — run as routine
  CI, no new failures expected.

## Out of Scope

- **Any change to `translate_i18n.py`, `i18n_dict_utils.py`, `check_i18n_diff.py`, or the
  `i18n-guard` CI job.** Already delivered and reviewed in `FIX-I18N-DICT-GUARD`.
- **Linguistic review of the generated KO/ES text.** No native-speaker review process exists for
  this project; Claude Haiku via the existing tool is the accepted translation mechanism.
- **`CTLD_i18n_fr.lua`.** Already fully translated, nothing for this lot to do there.
- **Adding or removing a supported language.** fr/es/ko stays the complete non-EN set.
- **New automated test coverage.** No new logic is introduced; existing `tools/build/` tests
  already cover the mechanism this lot exercises.

## Further Notes

- Full rationale for why this debt was deferred rather than blocked immediately: ADR 0013
  (`dev/adr/0013-ci-i18n-dict-guard.md`).
- Prior art: `BUILD-DICT-AI-TRANSLATE` (PR #60) introduced `translate_i18n.py` and the
  local-only/`ANTHROPIC_API_KEY` decision this lot relies on without modification.
- `FIX-I18N-DICT-SYNC` (PR #57) is the precedent for a prior i18n debt-repayment pass (60+ FR menu
  labels filled by hand after a path bug), confirming this project has repaid dictionary debt as
  its own lot before.

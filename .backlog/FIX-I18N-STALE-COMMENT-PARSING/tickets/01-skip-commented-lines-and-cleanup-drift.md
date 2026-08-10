Status: ready

# 01 — Skip `-- STALE:`-commented lines in i18n parsing + clean up the real drift

## Parent

`.backlog/FIX-I18N-STALE-COMMENT-PARSING/PRD.md`

## What to build

Fix the identical defect in three places: a regex or line scan that matches
`ctld.i18n[lang][key] = "value"` regardless of a `-- ` comment prefix in front of it, so a
`-- STALE:`-commented dead key is currently indistinguishable from a live one.

- `tools/build/i18n_dict_utils.py`: `parse_dict`, `parse_keep_en`, and the underlying entry-matching
  logic now skip any line whose stripped text starts with `--`.
- `tools/build/generate_i18n_dicts.ps1`: `Get-DictKeys` (drives both `MISSING` and `STALE`
  classification) gets the same line-level filter.
- `tools/build/translate_i18n.py`: `_apply_translations`'s write path is hardened the same way, for
  defense-in-depth against a future caller passing it a stale key — even though it can no longer
  receive one in practice once the shared parser excludes STALE keys from `en_dict`, and therefore
  from `_collect_stubs`'s output.

No change to the `MISSING`/`STALE` classification rules — only to how "present in a dictionary" is
determined. `check_i18n_diff.py` needs no code change: it calls the shared `parse_dict` and inherits
the fix automatically.

As a one-time cleanup in this same ticket, once `generate_i18n_dicts.ps1` is fixed, run it with
`-Apply` against the repo's real dictionaries. This is expected to prefix `-- STALE:` onto the KO/ES
copies of the keys already known to be dead in `CTLD_i18n_en.lua` (23 KO + 8 ES, per the
`FIX-I18N-DEBT-REPAYMENT` count) — no dictionary value changes, only line prefixes on already-dead
entries.

## Acceptance criteria

- [ ] `parse_dict` excludes a `-- STALE:`-commented entry from its returned dict.
- [ ] `parse_keep_en` excludes a commented `__keep_en` entry the same way.
- [ ] A mix of live and commented lines for different keys in the same text parses only the live
      ones (no false exclusion of genuinely live neighbors).
- [ ] `Get-DictKeys` in `generate_i18n_dicts.ps1` no longer counts a commented line as a key the
      dictionary "has" — verified via the dry-run report on the repo's real dictionaries.
- [ ] `_apply_translations` given a key whose only occurrence is a `-- STALE:`-commented line
      performs no write and reports zero keys written, rather than uncommenting or corrupting it.
- [ ] Every currently live (non-commented) entry across all four dictionaries parses identically to
      before the fix — no behavior change for live content.
- [ ] Unit tests added to `test_i18n_dict_utils.py` and `test_translate_i18n.py` covering the cases
      above; no test added against real `src/CTLD_i18n_*.lua` files (fixtures stay synthetic).
- [ ] `pytest tools/build/` stays green (existing + new tests).
- [ ] `generate_i18n_dicts.ps1 -Apply` run once against the repo post-fix; resulting diff on
      `CTLD_i18n_ko.lua`/`_es.lua` contains only `-- STALE:` line-prefix additions on the expected
      dead keys, no value changes, no unrelated `MISSING` regressions reported.
- [ ] `CHANGELOG.md` `[Unreleased]` updated.

## Blocked by

None - can start immediately

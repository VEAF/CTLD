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
`-Apply` against the repo's real dictionaries.

**Actual outcome, larger than scoped**: this didn't just re-mark 23 KO + 8 ES entries as expected.
It surfaced that 56 keys were wrongly `-- STALE:`-marked in **all four dictionaries including
English** — every AA system component label (HAWK/BUK/KUB/NASAMS/Patriot/S-300), several F10 menu
labels, and 7 vehicle-category labels, all referenced only via `CTLD_config.yaml`'s `desc:`/`name:`
fields (not `ctld.tr()`), almost certainly marked stale by a version of the script predating that
scan. This is a live production bug (`ctld.i18n["en"]["HAWK Launcher"]` etc. were `nil` at
runtime), not a cosmetic drift. `-Apply` revived all 56 (EN's text restored automatically); the
FR/ES/KO translations sitting in the old commented lines were recovered by hand into the freshly
revived stubs rather than lost.

## Acceptance criteria

- [x] `parse_dict` excludes a `-- STALE:`-commented entry from its returned dict.
- [x] `parse_keep_en` excludes a commented `__keep_en` entry the same way.
- [x] A mix of live and commented lines for different keys in the same text parses only the live
      ones (no false exclusion of genuinely live neighbors).
- [x] `Get-DictKeys` in `generate_i18n_dicts.ps1` no longer counts a commented line as a key the
      dictionary "has" — verified via the dry-run report on the repo's real dictionaries (went from
      wrongly reporting these 56 keys as present/stale to correctly reporting them `MISSING`).
- [x] `_apply_translations` given a key whose only occurrence is a `-- STALE:`-commented line
      performs no write and reports zero keys written, rather than uncommenting or corrupting it.
- [x] Every currently live (non-commented) entry across all four dictionaries parses identically to
      before the fix — no behavior change for live content (confirmed via `luac -p` on all 4 files
      plus the full `pytest tools/build/` suite staying green).
- [x] Unit tests added to `test_i18n_dict_utils.py` and `test_translate_i18n.py` covering the cases
      above; no test added against real `src/CTLD_i18n_*.lua` files (fixtures stay synthetic).
- [x] `pytest tools/build/` stays green (24/24, 5 new tests).
- [x] `generate_i18n_dicts.ps1 -Apply` run once against the repo post-fix. Diff is larger than
      originally scoped (see above) but contains only line additions/prefix changes on the 56
      affected keys across all 4 dictionaries — no unrelated `MISSING` regressions; final dry-run
      reports `OK` for all four dictionaries.
- [x] `CHANGELOG.md` `[Unreleased]` updated, documenting the discovered production bug and its fix.

## Blocked by

None - can start immediately

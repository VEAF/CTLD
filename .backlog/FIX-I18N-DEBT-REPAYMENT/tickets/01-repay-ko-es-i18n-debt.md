Status: ready

# 01 — Repay KO + ES i18n stub debt

## Parent

`.backlog/FIX-I18N-DEBT-REPAYMENT/PRD.md`

## What to build

Originally scoped to run `tools/build/translate_i18n.py` locally with `ANTHROPIC_API_KEY` set. No
key was available (separate Anthropic Console billing, not the Claude Code subscription used to
run this lot) — translations were produced and written directly into
`src/CTLD_i18n_ko.lua` / `src/CTLD_i18n_es.lua` instead, without invoking the script or any
external API. `translate_i18n.py` itself is untouched.

Of the 93 KO / 78 ES stubs counted at `FIX-I18N-DICT-GUARD`'s merge (`cfb7cd6`), 23 / 8 turned out
to be `-- STALE:` in `CTLD_i18n_en.lua` (no longer referenced by any `ctld.tr()`/config-YAML call
in `src/` — the shared parser doesn't distinguish a live entry from a commented-out one, so they
still counted as raw stubs). Translating dead keys fixes no live menu entry, so they were excluded;
**70 live entries per language** (identical key set for both) were the actual scope.

Two of those 70 keys (`JTAC`, `%1 [%2] %3.`) have no translatable content and would stay flagged
as stubs forever under the tool's own "value == EN text" definition — added to each dictionary's
`__keep_en` block instead, the existing mechanism for exactly this case.

`CTLD_i18n_fr.lua` is already fully translated and was left untouched.

## Acceptance criteria

- [x] All 70 live (non-`STALE`) empty entries in `src/CTLD_i18n_ko.lua` translated.
- [x] All 70 live (non-`STALE`) empty entries in `src/CTLD_i18n_es.lua` translated.
- [x] `src/CTLD_i18n_ko.lua` has zero live entries equal to `""` outside its `__keep_en` block.
- [x] `src/CTLD_i18n_es.lua` has zero live entries equal to `""` outside its `__keep_en` block.
- [x] `src/CTLD_i18n_fr.lua` is unchanged (already fully translated).
- [x] No key added, removed, or renamed in any of the four dictionaries — only existing empty
      values filled in, plus two `__keep_en` additions (`JTAC`, `%1 [%2] %3.`) in KO and ES.
- [x] `pytest tools/build/` still passes (no logic touched by this ticket) — 17/17 green.
- [x] `generate_i18n_dicts.ps1` dry-run reports no `MISSING` key (nothing added/removed).
- [x] `CHANGELOG.md` `[Unreleased]` updated noting the debt repayment.
- [ ] PR opened against `develop`; diff contains only translation-value changes in
      `CTLD_i18n_ko.lua` / `CTLD_i18n_es.lua` (plus `CHANGELOG.md` and the backlog index line).

## Blocked by

None - can start immediately (`FIX-I18N-DICT-GUARD` already merged on `develop`)

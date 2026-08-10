Status: ready

# 01 — Repay KO + ES i18n stub debt (round 2)

## Parent

`.backlog/FIX-I18N-DEBT-REPAYMENT-2/PRD.md`

## What to build

Translate every remaining empty stub in `src/CTLD_i18n_ko.lua` and `src/CTLD_i18n_es.lua` directly
(no `ANTHROPIC_API_KEY`, Claude Code CLI unusable from a nested session), matching the exact method
used in `FIX-I18N-DEBT-REPAYMENT` ticket 01. Scope is dynamic — whatever is empty at execution time.

## Acceptance criteria

- [x] `src/CTLD_i18n_ko.lua` has zero entries equal to `""` outside its `__keep_en` block (22
      translated; `FARP / FOB` added to `__keep_en` instead of translated — acronym, no
      translatable content).
- [x] `src/CTLD_i18n_es.lua` has zero entries equal to `""` outside its `__keep_en` block (7
      translated; `FARP / FOB` added to `__keep_en` same as KO).
- [x] `src/CTLD_i18n_en.lua` / `src/CTLD_i18n_fr.lua` unchanged.
- [x] No key added, removed, or renamed — only existing empty values filled in, plus one
      `__keep_en` addition per language.
- [x] `pytest tools/build/` still passes (24/24, unchanged).
- [x] `generate_i18n_dicts.ps1` dry-run reports `OK` on all four dictionaries.
- [x] `CHANGELOG.md` `[Unreleased]` updated.
- [ ] PR opened against `develop`.

## Blocked by

None - can start immediately

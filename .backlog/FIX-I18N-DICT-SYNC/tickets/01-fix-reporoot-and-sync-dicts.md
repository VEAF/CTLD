Status: open

# Ticket 01 — Fix repoRoot bug and sync all dictionaries with FR translations

## Parent

[FIX-I18N-DICT-SYNC PRD](../PRD.md)

## What to build

Fix the one-line `$repoRoot` path bug in `tools/build/generate_i18n_dicts.ps1`, run the script
in `-Apply` mode to append all missing keys to the four dictionary files, then fill in the FR
translations for every newly-added key.

End-to-end behaviour: after this ticket, `i18n_lang: fr` in a user config produces a fully French
CTLD interface — all menu labels and messages appear in French with no English fallback.

## Acceptance criteria

- [ ] `generate_i18n_dicts.ps1` line 36: `$repoRoot = Split-Path -Parent $scriptDir` replaced by
      `$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..")`
- [ ] Dry-run after the fix reports ≥ 1 missing key (path resolves correctly)
- [ ] `-Apply` run appends all missing keys; second dry-run reports 0 missing keys
- [ ] All missing FR keys have non-empty translations (no empty string stubs in FR)
- [ ] ES and KO newly-added keys remain empty stubs (policy unchanged)
- [ ] `busted tests/ci/unit` passes with no regressions
- [ ] CHANGELOG.md `[Unreleased]` updated

## Blocked by

None — can start immediately.

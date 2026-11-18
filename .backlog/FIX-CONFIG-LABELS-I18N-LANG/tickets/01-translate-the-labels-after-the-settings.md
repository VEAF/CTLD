# 01 — Translate the labels of the configuration after the settings are in place

**Status:** ✅ done (PR #314) · **Type:** AFK

## Parent

[PRD — FIX-CONFIG-LABELS-I18N-LANG](../PRD.md). Stories 1-6. GitHub issue #310.

## What to build

Loading a configuration translates its labels (every `desc` and `name` string) into the language of the snapshot's own `i18n_lang`, not into the global language a host script may have aligned on the mission.

The load fills the settings first and translates the labels afterwards, so the language lookup that every other text goes through can read the snapshot's `i18n_lang`. A snapshot that sets none keeps using the global language, and the default configuration (no snapshot) is unchanged.

## Acceptance criteria

- [ ] A snapshot with `i18n_lang: fr` and a global language `en` gives the French label.
- [ ] A snapshot with `i18n_lang: en` and a global language `fr` gives the English label.
- [ ] A snapshot with no `i18n_lang` falls back to the global language, unchanged; the default configuration (no snapshot) is unchanged.
- [ ] The new cases fail before the change and pass after it; the existing configuration specs pass unchanged.
- [ ] CHANGELOG `[Unreleased]` entry; `busted tests/ci/` green; luacheck clean; no new translation key.
- [ ] The lot's line in `.backlog/README.md` ("in progress") is set to `merged (PR #NN)` in this PR.

## Blocked by

None - can start immediately.

# 01 — Make i18n_lang a first-class, MM-settable setting

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

- **`src/CTLD_config.yaml`**: add `i18n_lang: en` under `mm_facing`.
- **`src/CTLD_i18n.lua`**: `ctld.tr` resolves the active language via `ctld.gs("i18n_lang")`
  (config wins), falling back to the module global `ctld.i18n_lang`, then `"en"`. Keep the
  module global as the pre-config default (defensive when `gs` isn't ready yet).
- **`src/CTLD_config_schema.yaml`**: `i18n_lang: { choices: [en, fr, es, ko] }`.
- Rebuild `CTLD.lua`; regenerate the embedded `reference.json` (i18n_lang now in the catalogue).
- Docs (mission-maker configuration + ctld-tools) + CHANGELOG.

## Acceptance criteria

- [ ] busted: a user-config `i18n_lang: fr` makes `ctld.tr` translate in French; default `en`;
      unknown language warns and falls back to `en`.
- [ ] `i18n_lang` appears in `Reference.scalar_settings()` (default `en`) and
      `enum_choices("i18n_lang") == ["en","fr","es","ko"]`.
- [ ] The TUI "Add → Setting" picker lists `i18n_lang` with a value list (en/fr/es/ko).
- [ ] CTLD.lua rebuilt; reference.json regenerated; CHANGELOG + docs updated.

## Blocked by

None (follow-up to `CTLD-TOOLS-TUI`).

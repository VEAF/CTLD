Status: ready

# 01 — i18n startup-report wiring (Lua)

## What to build

During CTLD init, after the i18n dictionaries are loaded, call `ctld.i18n_auditAll()` and add
`INFO` entries to `ctld.startupReport` for any empty stubs in the active language
(`ctld.gs("i18n_lang")`). If the active language is `"en"`, skip silently.

The existing `ctld.i18n_check()` function (writes via `env.error/warning`) is not modified.
Only the pure-data `ctld.i18n_audit()` is used here.

Entry format: `"[i18n] N untranslated key(s) in <lang> — rebuild to translate"`.

## Acceptance criteria

- [ ] `ctld.initialize()` calls the audit after dicts are loaded
- [ ] When active lang is `"fr"` and N keys are empty stubs, N INFO entries appear in
      `ctld.startupReport` (log-only, no screen output)
- [ ] When active lang is `"en"`, no i18n entries are added to `ctld.startupReport`
- [ ] When all keys are translated, no i18n entries are added
- [ ] busted tests cover the three cases above
- [ ] `busted tests/ci/` clean

## Blocked by

None — can start immediately.

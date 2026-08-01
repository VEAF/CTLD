# CTLD-TOOLS-TUI-POLISH

**Status:** ✅ merged (PR #55). Compacted from `CTLD-TOOLS-TUI-POLISH/` on 2026-08-01; the ticket files live on in git history.

Make the CTLD interface language (`i18n_lang`) a first-class MM setting (defaults + `ctld.tr` via `ctld.gs`, schema `choices`); it was a bare global, unsettable via user-config and absent from the picker. **+** bilingual **setting descriptions** in `CTLD_config_schema.yaml` (seeded from the config docs, 73 settings), shown and **searchable** in the "Set setting" picker; `FilterablePicker` gains `(value, label, search)` items.

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-i18n-lang-as-setting` | 🧑 planned | 01 — Make i18n_lang a first-class, MM-settable setting |

## PRD

Status: in progress

## PRD — CTLD-TOOLS-TUI-POLISH

> Polish items surfaced while testing the ctld-tools TUI (2026-07-21): a runtime fix
> (interface language settable) plus three tooling improvements (setting descriptions,
> double-click launch, Unblock doc). Grouped in one lot / PR.
>
> **1. Interface language is a real setting.** The CTLD interface language (`i18n_lang`)
> cannot be set from the user-config, and ctld-tools
> doesn't offer it.

### Problem

`ctld.i18n_lang` selects the CTLD interface language (en/fr/es/ko). It is set as a bare
global in `CTLD_i18n.lua` (`ctld.i18n_lang = "en"`) and read only as a global by
`ctld.tr`. It is **not** a `CTLDConfig` setting, so:

- The user-config path can't drive it: `ctld.yamlConfigDatas` writes `ctld.i18n_lang`
  into `CTLDConfig.settings["i18n_lang"]`, but `tr` reads the global `ctld.i18n_lang`
  (never synced — the settings→ctld backfill is short-circuited by an early `return`
  when a user-config is present, i.e. the normal MM case). So setting the language via
  the user-config silently does nothing.
- ctld-tools' "Set setting" picker lists only the catalogue, so `i18n_lang` is absent.

It is the **only** MM-facing scalar that lives outside the settings catalogue (verified
by sweeping `ctld.<x> = <literal>` module-level assignments in `src/`).

### Solution

Make `i18n_lang` settable from the user-config **without breaking the legacy global**:

1. `ctld.tr` resolves the active language via `ctld.gs("i18n_lang")` (user-config wins),
   falling back to the module global `ctld.i18n_lang`, then `"en"`.
2. Declare it in `src/CTLD_config_schema.yaml` with `default: en` + `choices` (+ a
   description) so the TUI picker surfaces it. It is **deliberately NOT added to the
   engine defaults catalogue**: that would make `gs("i18n_lang")` always return `"en"`
   and shadow the legacy `ctld.i18n_lang = "fr"` method (it broke the F-103 i18n specs).
   Keeping it schema-only means `gs` is `nil` unless the user-config sets it — so the
   legacy global still works and the user-config wins when present.
3. `Reference` surfaces schema settings that carry a `default` into `scalar_settings`
   (so the picker and validation know `i18n_lang`).

The picker then lists `i18n_lang` (default `en`, value list), and a user-config value
changes the language at runtime.

### Out of scope

- The general "settings→ctld backfill short-circuit" (line 167 `return`): left as-is;
  this fix routes `i18n_lang` through `gs()` instead of relying on that backfill.
- Adding languages / translating dictionaries.

### Extension — setting descriptions in the picker (agreed 2026-07-21)

While testing, a second need: show a **description** per setting in the "Set setting"
picker, and make it **searchable**. Folded into this lot (same schema file):

- `CTLD_config_schema.yaml` gains a bilingual `description: { en, fr }` per setting,
  **seeded once** from the mission-maker config docs (`configuration(.fr).md`, 73
  settings) via a one-shot extraction — the schema is now their source of truth.
- `Reference.setting_description(name, lang)`; the picker shows "name — description" in
  the current language and the filter matches name **and** description (searchable).
- `FilterablePicker` now takes `(value, label, search)` items so the displayed label
  differs from the returned value and the searchable text.
- The schema (descriptions included) is embedded in `reference.json`.
- Remaining duplication (doc tables repeat these descriptions) → `dev/roadmap.md`:
  generate the doc tables from the schema.

### Extension — double-click launch + Unblock doc (agreed 2026-07-21)

- **Double-click → TUI** (VMCT approach): a command-less invocation in an interactive
  terminal (which a double-click from Explorer is — a fresh console) routes to `tui`,
  carrying any global options. `_bridge_target(args, is_tty)` (pure, tested); `--help`
  and non-tty stdout are left to Typer.
- **Docs**: `ctld-tools.md` (EN+FR) note the Windows **Unblock** step for a downloaded
  `.exe` and that double-clicking opens the editor.

### Testing

- busted: with a user-config setting `i18n_lang`, `ctld.tr` uses that language; default
  stays `en`; unknown language falls back to `en`.
- ctld-tools pytest: `i18n_lang` is in `scalar_settings()` with default `en`, and
  `enum_choices("i18n_lang") == [en, fr, es, ko]`; `setting_description` is bilingual;
  the settings picker is searchable by description.

Status: in progress

# PRD — CTLD-TOOLS-TUI-POLISH

> Polish items surfaced while testing the ctld-tools TUI (2026-07-21): a runtime fix
> (interface language settable) plus three tooling improvements (setting descriptions,
> double-click launch, Unblock doc). Grouped in one lot / PR.
>
> **1. Interface language is a real setting.** The CTLD interface language (`i18n_lang`)
> cannot be set from the user-config, and ctld-tools
> doesn't offer it.

## Problem

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

## Solution

Make `i18n_lang` a first-class setting:

1. Add `i18n_lang: en` to the engine defaults (`src/CTLD_config.yaml`, mm_facing).
2. `ctld.tr` resolves the active language via `ctld.gs("i18n_lang")` (config wins),
   falling back to the module global, then `"en"`. The `CTLD_i18n.lua` global becomes a
   pre-config default only.
3. Declare its allowed values in `src/CTLD_config_schema.yaml`
   (`i18n_lang: { choices: [en, fr, es, ko] }`) so the TUI offers a value list.

Then it appears **automatically** in the ctld-tools picker (it's in the catalogue), and
setting it from the user-config actually changes the language at runtime.

## Out of scope

- The general "settings→ctld backfill short-circuit" (line 167 `return`): left as-is;
  this fix routes `i18n_lang` through `gs()` instead of relying on that backfill.
- Adding languages / translating dictionaries.

## Extension — setting descriptions in the picker (agreed 2026-07-21)

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

## Extension — double-click launch + Unblock doc (agreed 2026-07-21)

- **Double-click → TUI** (VMCT approach): a command-less invocation in an interactive
  terminal (which a double-click from Explorer is — a fresh console) routes to `tui`,
  carrying any global options. `_bridge_target(args, is_tty)` (pure, tested); `--help`
  and non-tty stdout are left to Typer.
- **Docs**: `ctld-tools.md` (EN+FR) note the Windows **Unblock** step for a downloaded
  `.exe` and that double-clicking opens the editor.

## Testing

- busted: with a user-config setting `i18n_lang`, `ctld.tr` uses that language; default
  stays `en`; unknown language falls back to `en`.
- ctld-tools pytest: `i18n_lang` is in `scalar_settings()` with default `en`, and
  `enum_choices("i18n_lang") == [en, fr, es, ko]`; `setting_description` is bilingual;
  the settings picker is searchable by description.

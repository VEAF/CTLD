# FIX-TOOL-I18N-LANG — CTLD's interface language cannot be set from the tool

**Status:** done (shipped with `FEAT-ONE-CLICK-INSTALL`).

Opened 2026-08-01, reported by **FullGas**: there is no way to set CTLD's language — the engine's, not
the tool's — in `ctld-tools`.

## What was actually broken

Not the engine, and not the schema. Both were right:

- `CTLD_i18n.lua` resolves the language through `ctld.gs("i18n_lang")`, falling back to the
  `ctld.i18n_lang` global and then `en`. Writing `i18n_lang: fr` in a snapshot **works**.
- `CTLD_config_schema.yaml` declares it fully: `group: general`, `standard: true`, `default: en`,
  `choices: [en, fr, es, ko]`, with a bilingual label and description.

The app never showed it, because it builds its setting list from the keys of the **open catalogue**,
and `i18n_lang` is the only one of ~150 settings deliberately absent from the catalogue. It is absent
on purpose: a scalar in the default catalogue is a *parameter* under
[ADR 0011 Addendum 1](../../dev/adr/0011-complete-yaml-config-and-webapp-tooling.md), so the
completeness rule would demand it of every snapshot and every rc1–rc3 configuration would report a
missing setting at mission start. Both the schema comment and `validate.py` say so.

**A regression from the TUI → web app move.** The schema comment states the default is there to
"surface it in the TUI picker": the TUI listed *schema* keys, the web app lists *catalogue* keys.

## What changed

The app also offers settings the schema declares with a default that the engine catalogue does not
carry — exactly one today. Setting it writes it into the Mission Maker's configuration like any other,
in `mm_facing` rather than `advanced`, since a `standard:` setting is Mission-Maker-facing.

Rejected: adding `i18n_lang` to the catalogue. It fixes the symptom and reverses a decision recorded
in two places, at the cost of a startup NOTICE for every configuration written so far.

## Out of scope

- The tool's *own* interface language, which already follows the OS locale and is switchable in the UI.
- Making other schema-only settings appear. There are none; the rule is general so the next one is
  free rather than special-cased.

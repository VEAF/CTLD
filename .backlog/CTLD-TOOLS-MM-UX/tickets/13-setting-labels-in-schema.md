# 13 — Bilingual setting names in the schema

**Status:** done

## Why

Ticket 11 shipped a French UI, but with one hole: the **names of the settings themselves** stayed
English, because they were derived from the config key (`humanize`). A French Mission Maker got a
French description under an English name. David asked for the names too.

## Work

`label: { en, fr }` on **every** catalogue key in `src/CTLD_config_schema.yaml` — 137 entries
(121 scalar settings + 15 structured tables + `i18n_lang`). 41 keys had no schema entry at all and
got one created.

Each label is a short noun phrase (2–6 words, sentence case) that restates the setting's own name and
its existing `description`. Where a description exists it constrains the wording; where none does the
label is a faithful rendering of the key's own words. No label makes a new claim about behaviour.

Two things the authored labels buy beyond translation:

- **Better English than the derivation.** `enableAllCrates` derived as "Enable all crates"; the
  schema says *Show the "All crates" shortcuts*, which is what the setting actually does per its
  description. Same for `location_DMS`, `addPlayerAircraftByType`, `slingCutDestroyHeight`.
- **The `repack` ban is enforced in the UI.** `enableFARPRepack` would have rendered as "Enable FARP
  repack"; it now reads "Allow packing a FARP back into crates". A test asserts no label in either
  language contains "repack".

Plumbing: `Schema.label()`, `/api/schema` exposes `label` per key (honouring `?lang=`),
`settingLabel(key, authored)` in the frontend prefers it and falls back to `humanize`. Every place a
setting is named goes through it — rows, search, the validation panel, the version-gap dialog and the
data-table titles — so search now matches the **translated** name (verified live: "stationnaire"
finds the four hover settings).

## Done when

- No setting renders a derived name when the app is in French (asserted: zero unlabelled keys).
- Labels differ between EN and FR everywhere except a known short list of acronyms/proper nouns.
- The raw key stays visible next to every label — it is what the docs and forums name.

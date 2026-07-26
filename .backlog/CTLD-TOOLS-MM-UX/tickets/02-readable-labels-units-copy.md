# 02 — Readable labels, units and copy

**Status:** done

## Goal

Stop showing raw config keys as the primary label, and surface the unit a value is expressed in.

## Work

`src/lib/labels.ts`:

- `humanize(key)` — derive a sentence-case label from a config key. Handles camelCase
  (`enableCrates` → "Enable crates"), `SCREAMING_SNAKE` (`RIFLE_WEIGHT` → "Rifle weight"),
  prefixed keys (`JTAC_laseIntervalSeconds` → "JTAC lase interval seconds"), and digit runs.
- `LABEL_OVERRIDES` — a small map for cases the derivation cannot get right (acronyms that must stay
  upper: JTAC/FOB/FARP/AA/AI/DMS/FC3/AGL/MSL/RED/BLUE; awkward derivations).
- `unitOf(description)` — extract the unit from the **existing** schema description text, which
  already documents it: `(m)`, `(metres)`, `(kg)`, `(seconds)`. Returns `null` when the description
  says nothing. **Never infer a unit from the key name** — a wrong unit is worse than none.
- `UI` — one object holding every user-facing string in the app, so the later FR i18n lot is a
  mechanical substitution rather than a hunt through templates.

The raw key stays on screen, de-emphasised (mono, small) next to the label: it is what the docs,
the forum threads and the validation messages refer to.

## Done when

- Unit tests cover the derivation shapes above, the override path, and unit extraction (including
  "no unit documented" → nothing rendered).
- No template renders a bare config key as its main label.

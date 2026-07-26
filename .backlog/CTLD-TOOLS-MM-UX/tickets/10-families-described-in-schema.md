# 10 — Families named and described in the schema

**Status:** done

## Why

The PRD deferred "enriching the schema" wholesale, on the grounds that authoring metadata for 44
uncovered *settings* would mean inventing meaning. But that lumped two very different jobs together,
and David pushed back on the family half: *"On doit bien avoir ça quelque part…"*

He was right. `git log -S "tui.family"` turns up commit `3205ef6` (*group settings into 12 functional
families in the tree*), which added `tui.family.*` labels to the locale catalogs in **EN and FR**;
`dc45264` added Parachute. Those labels were lost when the TUI was retired, and this lot had been
re-inventing them as English-only constants in the frontend.

Family **descriptions** genuinely did not exist anywhere — the doc's per-family sections
(`docs/mission-maker/configuration.md`) are bare tables with no intro prose. But writing 16 of them
is not the same risk as writing 44 setting descriptions: a family's description is derivable from the
settings and tables it actually holds, and is verifiable by reading them.

## Work

New reserved `families:` section in `src/CTLD_config_schema.yaml`, one entry per family:

- `label: { en, fr }` — restored from the historical `tui.family.*` catalogs, plus the two families
  this lot introduced (`aircraft`, `zones`).
- `description: { en, fr }` — written from the family's actual contents.
- `order:` — the navigation rank, moving the domain ordering out of the frontend constant.

`schema.py`: `family_label()` / `family_description()` / `family_order()` / `family_meta()`, and
`families` joins `tableFields` in a `_RESERVED` set so it is never mistaken for a setting.

`/api/schema` gains `familyMeta` and honours `?lang=`. The frontend prefers it over its constants
(kept as fallback) and renders the description under the family title — useful orientation for
someone who arrived from search.

## Done when

- `families:` covers every family any `group:` refers to (asserted at the API level).
- `keys` never contains `families` or `tableFields`.
- FR labels/descriptions come back from `?lang=fr`.
- No `src/` behaviour change: the schema is authoring metadata, not consumed by the build (verified —
  `merge_CTLD.ps1` does not read it), so `CTLD.lua` needs no rebuild.

# CTLD-TOOLS-MM-UX — a Mission-Maker-first UI for `ctld-tools.exe`

## Why

The lot-3 web app (`CTLD-TOOLS-WEBAPP`, PR #67) delivered a **complete and correct** surface: every
setting is reachable, every structured table has an editor, validation and `.miz` injection are
wired. What it did not get was an authoring pass on the *experience*. It currently reads as a
developer's inspector over a YAML file, and the target user is a Mission Maker with very little
computing background.

Two goals, from the request:

1. Make it as easy, obvious and pleasant as possible for a non-technical Mission Maker.
2. Make it look like it belongs to its subject — DCS, rotary-wing logistics, military flight
   planning — instead of an unstyled form.

## Design review — what is wrong today

Ordered by how much it hurts a non-technical user.

| # | Finding | Why it hurts | Fix |
|---|---------|--------------|-----|
| 1 | **`Parameters` / `Data` split** is implementation vocabulary ("how CTLD behaves" vs "what CTLD operates on"). It tears every domain in two: `enableCrates` lives in *Parameters → Crates*, `spawnableCrates` in *Data → spawnableCrates*. | A MM who wants to "add a Humvee crate" has no way to guess which of the two screens owns it. The domain a user thinks in (*crates*) is split across two tabs. | Collapse into **one navigation by functional family**. A family owns both its settings and its tables. |
| 2 | **Raw config keys as labels** (`maximumDistanceToLoadCrate`, `JTAC_laseIntervalSeconds`). | camelCase identifiers are not a language non-technical users read. | Human labels derived from the key, with the raw key kept visible but secondary (it is still what the docs and the forums talk about). |
| 3 | **Empty screen on launch** — "Load the defaults or open a config file to begin." | The first thing the app does is ask a question the user cannot answer yet. A blank screen is a wall. | Load the defaults automatically on boot; `Open…` stays available. |
| 4 | **The actual goal is buried.** The point of the tool is to get a config into a `.miz`; `Inject to .miz…` is the 4th of 4 equal-weight buttons. | Nothing tells the user what the tool is *for* or where they are in the process. | A 3-step progress strip (Load → Adjust → Inject) and one visually primary action. |
| 5 | **No way back to a default.** Editing is a one-way door; a MM who has fiddled with a value cannot restore it. | Fear of touching anything. | Per-setting `Reset` + a "changed from default" marker, backed by a new `/api/defaults`. |
| 6 | **No search** across ~136 settings. | The only way to find a setting is to guess its family and scan. | Search over label + key + description, across all families. |
| 7 | **`Advanced` is as prominent as `Standard`** — 64 advanced settings are rendered inline, right under the 57 standard ones. | The distinction exists but buys nothing: the user still scrolls past everything. | Collapse `Advanced` behind a disclosure, closed by default. |
| 8 | **~44 settings have no `group:` in the schema** and land in a single `Other` bucket (`JTAC_*`, `parachute*`, `*_WEIGHT`, `beacon*`…). | The largest family in the nav is the meaningless one. | Prefix-derived family fallback in the UI (schema `group:` still wins). No invented metadata — the fallback reads the key name only. |
| 9 | **Validation findings are raw** (`where: key: message`) and only rendered on the Data screen. | A MM sees a technical dump, on one screen out of two, and cannot act on it. | One persistent validation panel, plain wording, always visible, with the count in the header. |
| 10 | **Saving is ambiguous.** Every edit PUTs immediately (in-memory), but `Save…` asks for a path. Nothing says whether work is safe. | "Did I save?" is unanswerable. | An explicit save-state indicator in the header. |
| 11 | **Units are invisible.** `maxDropHeight = 7.5` — metres? feet? | Silent misconfiguration. The schema descriptions already carry `(m)` / `(kg)` / `(seconds)`. | Extract the unit **from the existing description text** and show it in the field. Never guessed. |
| 12 | **No visual identity.** system-ui, `#f4f6fa`, default form controls. | Nothing connects the tool to DCS or to helicopter logistics. | A cockpit/kneeboard direction: dark instrument ground, olive-biased neutrals, caution-amber accent, condensed display face for labels, mono for values, NATO side colours for RED/BLUE. |

Deliberately **not** in this lot (kept as follow-ups):

- **UI i18n (FR)** — the backend already has an i18n layer (`ctld_tools/i18n.py`, EN+FR). The new UI
  strings are authored EN-only here; wiring them through a catalogue is its own lot. Every
  user-facing string is centralised in one module to make that migration mechanical.
- **Enriching `src/CTLD_config_schema.yaml`** with the ~44 missing `group:` entries (plus real
  `label:` / `unit:` fields). That is the durable home for this metadata and would let the doc
  tables be generated from it (already on `dev/roadmap.md`). Doing it properly means authoring
  bilingual descriptions for 44 settings — a lot of its own, and inventing them here would violate
  the zero-assumptions rule. The UI-side fallback is explicitly a stopgap.
- Replacing the raw `JsonEditor` fallback (`modTypes`, `aiZones`, …) with structured editors.

## Scope

`tools/ctld-tools/` only — the Svelte frontend plus one additive backend endpoint. No `src/` change,
so no `CTLD.lua` rebuild and no Lua behaviour change.

## Tickets

| # | Ticket | Addresses |
|---|--------|-----------|
| 01 | Design system + app shell (cockpit theme) | 12 |
| 02 | Readable labels, units and copy | 2, 11 |
| 03 | One navigation by functional family | 1, 8 |
| 04 | Setting search | 6 |
| 05 | Defaults endpoint, reset-to-default, changed marker | 5, 7 |
| 06 | Guided workflow: auto-load, step strip, primary action, save state | 3, 4, 10 |
| 07 | Plain-language validation panel + version-gap rewrite | 9 |
| 08 | Docs + CHANGELOG | — |
| 09 | CI job for the web app | found in flight: the frontend suite gated nothing |

## Acceptance

- A MM opening the exe lands on a populated, themed screen and can reach any setting in ≤ 2 clicks
  or one search.
- Every setting shows a human label, its unit when the schema documents one, and can be reset.
- One navigation; no `Parameters` / `Data` wording anywhere in the UI.
- `Other` holds only settings whose family cannot be derived from schema or key.
- Existing test suites stay green; new logic (labels, families, units, search, diff-vs-default)
  ships with unit tests.

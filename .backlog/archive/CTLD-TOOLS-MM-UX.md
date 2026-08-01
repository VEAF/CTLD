# CTLD-TOOLS-MM-UX

**Status:** merged (PR #68). Compacted from `CTLD-TOOLS-MM-UX/` on 2026-08-01; the ticket files live on in git history.

UI/UX pass on `ctld-tools.exe` for the non-technical Mission Maker + a visual identity rooted in the subject (DCS rotary-wing logistics). Drops the developer-vocabulary `Parameters`/`Data` split for **one navigation by functional family** (a family owns its settings *and* its tables), replaces raw config keys with human labels (units extracted from the existing schema descriptions, never guessed), boots straight onto the defaults, adds search across all 136 settings, reset-to-default + changed markers (new `GET /api/defaults`), a 3-step Load→Adjust→Inject strip with one primary action and an explicit save-state, and a plain-language validation panel. Cockpit/kneeboard theme (amber caution accent, NATO side colours). Deferred: UI i18n FR, enriching `CTLD_config_schema.yaml` with the ~44 missing `group:`.

## Tickets

| Ticket | Status | Title |
|---|---|---|
| `01-design-system-app-shell` | done | 01 — Design system + app shell (cockpit theme) |
| `02-readable-labels-units-copy` | done | 02 — Readable labels, units and copy |
| `03-one-navigation-by-family` | done | 03 — One navigation by functional family |
| `04-setting-search` | done | 04 — Setting search |
| `05-defaults-reset-changed-marker` | done | 05 — Defaults endpoint, reset-to-default, changed marker |
| `06-guided-workflow` | done | 06 — Guided workflow: auto-load, step strip, primary action, save state |
| `07-validation-panel-version-gap` | done | 07 — Plain-language validation panel + version-gap rewrite |
| `08-docs-changelog` | done | 08 — Docs + CHANGELOG |
| `09-ci-frontend-job` | done | 09 — CI job for the web app |
| `10-families-described-in-schema` | done | 10 — Families named and described in the schema |
| `11-ui-i18n-fr` | done | 11 — French UI |
| `12-rail-decoration` | done | 12 — A picture of what the tool is for |
| `13-setting-labels-in-schema` | done | 13 — Bilingual setting names in the schema |
| `14-units-traced-from-the-lua` | done | 14 — Units traced from the Lua, not guessed |
| `15-in-app-help` | done | 15 — In-app help, generated from the schema and the catalogue |

## PRD

## CTLD-TOOLS-MM-UX — a Mission-Maker-first UI for `ctld-tools.exe`

### Why

The lot-3 web app (`CTLD-TOOLS-WEBAPP`, PR #67) delivered a **complete and correct** surface: every
setting is reachable, every structured table has an editor, validation and `.miz` injection are
wired. What it did not get was an authoring pass on the *experience*. It currently reads as a
developer's inspector over a YAML file, and the target user is a Mission Maker with very little
computing background.

Two goals, from the request:

1. Make it as easy, obvious and pleasant as possible for a non-technical Mission Maker.
2. Make it look like it belongs to its subject — DCS, rotary-wing logistics, military flight
   planning — instead of an unstyled form.

### Design review — what is wrong today

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

#### Pulled back in (tickets 10–12)

The first three of these were deferred, then requested straight after the first review — the
"deferred" reasoning was partly wrong and worth recording:

- **UI i18n (FR)** → ticket 11. Deferring it was defensible but it was the single biggest remaining
  barrier for a francophone MM, and the backend machinery already existed.
- **Family metadata in the schema** → ticket 10. The blanket "authoring 44 descriptions would mean
  inventing meaning" conflated two jobs. Family **labels** already existed in EN+FR in the retired
  TUI's locale catalogs (`tui.family.*`, commit `3205ef6`) — this lot had been re-inventing them as
  English frontend constants. Family **descriptions** did not exist, but 16 of them are derivable
  from the settings each family holds, which is nothing like guessing at 44 individual settings.
  Lesson: check the history before declaring metadata absent.
- **Decoration** → ticket 12. Tickets 01–09 delivered a palette and functional icons but nothing
  depicting the subject.
- **`label:` per setting** → ticket 13. Ticket 11's French UI still showed English setting *names*;
  authoring 137 bilingual labels closed that. It also improved several English names over the naive
  derivation, and let the project's "no repack" convention reach the UI.

- **`unit:` per setting** → ticket 14. Reading the unit out of the description covered 40 of 80
  numeric settings; tracing each one to its consuming Lua code covered 66, and proved the other 14
  have no unit at all. I had filed this as needing engine knowledge I lacked — the answer was to go
  read the engine.

#### Still out of scope

- **The ~44 missing `group:` entries.** The name-derived fallback shrinks `Other` to 7, so the
  remaining value is mostly tidiness; the durable fix still needs authored descriptions.
- Replacing the raw `JsonEditor` fallback (`modTypes`, `aiZones`, …) with structured editors.

### Scope

`tools/ctld-tools/` — the Svelte frontend plus additive backend endpoints — and, from tickets 10 and
13, `src/CTLD_config_schema.yaml`. That file is **authoring metadata**: it is not read by
`merge_CTLD.ps1` (verified), so `CTLD.lua` needs no rebuild and no Lua behaviour changes. The
`changelog-guard` job does apply, and the lot has a CHANGELOG entry.

### Tickets

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
| 10 | Families named and described in the schema | pulled in from the deferred list (see below) |
| 11 | French UI | pulled in from the deferred list |
| 12 | A picture of what the tool is for | asked for after the first review |
| 13 | Bilingual setting names in the schema | closes the i18n hole left by ticket 11 |
| 14 | Units traced from the Lua, not guessed | 11 — the description-scraping covered only half |
| 15 | In-app help, generated from the schema and the catalogue | asked for at the end of the review |

### Acceptance

- A MM opening the exe lands on a populated, themed screen and can reach any setting in ≤ 2 clicks
  or one search.
- Every setting shows a human label — translated, from the schema — its unit when the schema
  documents one, and can be reset.
- Nothing user-facing is English-only when the UI is in French, apart from DCS's own type names.
- One navigation; no `Parameters` / `Data` wording anywhere in the UI.
- `Other` holds only settings whose family cannot be derived from schema or key.
- Existing test suites stay green; new logic (labels, families, units, search, diff-vs-default)
  ships with unit tests.

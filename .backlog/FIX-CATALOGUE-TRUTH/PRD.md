# FIX-CATALOGUE-TRUTH — the schema and the catalogue describe what the engine actually reads

**Status:** done — merged (PR #72).

> **Delivered.** All six tickets. `tableFields.aiZones` rewritten with the ten fields the engine reads
> and the three enums declared as `choices` seeded from its own `VALID_*` tables; `GROUND_UNIT` purged
> and `spawnAs` reduced to `choices: [GROUND, AIR]`; `modTypes` `{}` → `[]` with a real description and
> a family; the inert `category` gone from all three crate models; both hover-height settings now state
> their reference frame per use; `dropCrate` + `maxDropHeight` removed from the engine, catalogue,
> schema, docs and tests.
>
> The whole `dev/roadmap.md` "Runtime anomalies" section is gone — every one of its five entries is now
> resolved (1 in `FIX-CTLD-TOOLS-REVIEW`, 2 and 3 in `FEAT-CONFIG-PARAM-SEMANTICS`, 4 and 5 here). Lot A
> had closed 2 and 3 without deleting them; that bookkeeping is caught up here.
>
> **Verification.** 186 pytest tests + ruff clean, including a new `test_catalogue_truth.py` whose 15
> guards assert each block against the Lua that consumes it — the `aiZones` field set is compared to
> `entry.<field>` reads in `_loadAIZonesFromConfig`, and each enum to the engine's own table, so the UI
> cannot drift from the runtime. `luacheck` on `CTLD_crate.lua`: 5 warnings before and after. Lua unit
> tests remain CI's job (busted is not installed locally).

Lot **B** of the post-review program (2026-07-30). **Must ship before lot D** (`FEAT-EDITOR-COVERAGE`):
the editors are schema-driven, so the schema has to be right before anything is built on it. Closes
`dev/roadmap.md` item 5.

## Why

The previous lot set itself an acceptance criterion — *every catalogue key the UI exposes is a key the
engine actually reads* — and four violations survived it. Each one teaches a Mission Maker something
false, and one of them is why FullGas saw a raw JSON editor where he expected a list.

None of these change engine behaviour. This lot is data and documentation, with one exception noted
below.

| # | What is wrong | Verified |
|---|---|---|
| 1 | `tableFields.AIZones` describes a dead positional format (`zoneName`, `mode`, `side`) | Three fields the engine never read, in `src/` or the legacy monolith. PR #69 dropped the dead config key but left the schema block — [CTLD_config_schema.yaml:882](../../src/CTLD_config_schema.yaml#L882) |
| 2 | `spawnAs` advertises `GROUND_UNIT` | Not in `_SPAWN_CATEGORY_MAP`; unknown values fall back to `Group.Category.GROUND` ([CTLD_utils.lua:1255](../../src/CTLD_utils.lua#L1255)), so it yields the right result by accident while teaching an invalid value |
| 3 | `modTypes` ships `{}` (a map) | The engine iterates it with `ipairs` — a list ([CTLD_typeCollector.lua:170](../../src/core/CTLD_typeCollector.lua#L170)). Harmless while empty, but an MM following the shape writes a map and is silently ignored. Also why the app fell through to `JsonEditor`: it infers the editor from the value's shape |
| 4 | `spawnableCratesModels[*].category` | Never reaches DCS — `_spawnStatic` does not copy it into the data table ([CTLD_crate.lua:1713](../../src/CTLD_crate.lua#L1713)) and `dynAddStatic` forces `category = 'Cargos'` unless a differently-named `categoryStatic` is present. Doubly inert, matching the forced value by coincidence |

Plus two clean-ups the roadmap raised:

- **Hover-height reference frames** (roadmap item 5). The observation is correct and FullGas is still
  right to close it: `minimumHoverHeight`/`maximumHoverHeight` are measured against the *target object*
  at [CTLD_crate.lua:1152](../../src/CTLD_crate.lua#L1152) and [CTLD_vehicle.lua:1193](../../src/CTLD_vehicle.lua#L1193),
  but against *terrain AGL* at [CTLD_crate.lua:1463](../../src/CTLD_crate.lua#L1463). That is inherent,
  not accidental — the first two have an object to measure from and that is what the pilot cares about;
  the third releases a sling with no object present, so terrain is the only reference. And the two
  tests never apply at the same moment: one governs pickup, the other release. **Not a bug — an
  ambiguous description.** Fix the wording, delete the roadmap entry so the contradiction with the
  previous PRD does not outlive this conversation.
- **`dropCrate` is superseded.** No caller in `src/`, absent from `legacy_api.lua`, and absent from the
  legacy monolith entirely. The airborne drop it implements is served by `parachuteCrates`, which is
  fully wired from the flight-state-aware F10 menu ([CTLD_crate.lua:905-914](../../src/CTLD_crate.lua#L905),
  [:2290](../../src/CTLD_crate.lua#L2290), [:2981](../../src/CTLD_crate.lua#L2981)) and handles a short
  descent as well as a long one. It was not prepared for the parachute feature — it is what the
  parachute feature replaced. Decided: remove it.

**Note on scope:** ticket 06 (removing `dropCrate`) touches `src/`, so this lot is not strictly
data-only. It is placed here by decision rather than by nature.

## Out of scope

- Building the editors that consume this schema — lot D.
- Enriching the ~44 settings still missing a `group:` (deferred by `CTLD-TOOLS-MM-UX`).
- Making the `choices` this lot authors reach the UI. The YAML side is here; widening the API and
  frontend contract so the dropdowns read them is lot D ticket 02.

## The schema owns the vocabularies

Every closed value set this lot touches is declared in the schema as a `choices` list, not left to the
frontend. The reason is documentation: **nothing stops a Mission Maker editing the YAML by hand**, and the
schema is the document that explains the config to them. A value list living only in a Svelte component
helps users of the app and no one else.

This is safe to author now. `/api/schema` collapses a table field with
`(meta or {}).get(language) or (meta or {}).get("en")`
([app.py:117](../../tools/ctld-tools/ctld_tools/web/app.py#L117)) — it reads the language key and drops
every other, so a `choices:` sibling of `en`/`fr` is ignored by today's code rather than breaking it. No
flag day with lot D.

## Definition of done

- No schema block describes a field the engine does not read.
- Every enum this lot documents is declared as `choices`, seeded from the engine's own tables.
- `modTypes` is a list in the catalogue, and the app dispatches it to a list editor without further
  change.
- `GROUND_UNIT` appears nowhere in the repository.
- The two hover-height settings state their reference frame per use, in EN and FR.
- `dropCrate`, `maxDropHeight` and their documentation and tests are gone; the coverage ratchet still
  passes.
- The roadmap entries for items 4 and 5 are deleted, not left as stale contradictions.

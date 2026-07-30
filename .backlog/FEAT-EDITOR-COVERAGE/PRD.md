# FEAT-EDITOR-COVERAGE — every complex config key gets a real editor

**Status:** done — all six tickets delivered.

> **Delivered.** The datamine bundle now maps every type to its category (it was already in the
> directory layout and being discarded), `/api/schema` serves a table field's `choices` beside its tip,
> `CratesEditor` gained an `isJTAC` checkbox and a strict `GROUND`/`AIR` select whose `AIR` resolves to
> AIRPLANE or HELICOPTER from the unit type, and `aiZones`, `spawnableCratesModels` and `modTypes` all
> have real editors. No config key falls through to `JsonEditor` any more except by decision.
>
> **A bug the tests caught in the new editor**: `setStock` filtered empty keys, so a freshly added stock
> row vanished before it could be named — you could never add one. The local model now keeps the empty
> row and strips it on the way out, since an empty key would reach the engine as a template named "".
>
> **Verification.** 119 frontend tests (13 files) + 0 svelte-check errors + a clean `vite build`; 202
> pytest tests + ruff clean. All run locally.

Lot **D** of the post-review program (2026-07-30). **Depends on lot B** (`FIX-CATALOGUE-TRUTH`): the
editors are schema-driven, so the schema must be correct before anything is built on it. Independent of
lots A and C.

## Why

FullGas audited the web app's editor dispatch after PR #68 and filed a gap analysis on
[PR #69](https://github.com/VEAF/CTLD/pull/69#issuecomment-5092982380) (2026-07-27). Every complex config
key routes to a dedicated component or falls through to `JsonEditor` — a raw JSON textarea. Four keys were
short:

| Key | Today | Missing |
|---|---|---|
| `aiZones` | `JsonEditor` | No editor at all — named records, so `ZonesEditor` would corrupt them |
| `spawnableCratesModels` | `JsonEditor` | No editor at all — a fixed-key object, no rows to add or remove |
| `spawnableCrates` | `CratesEditor` | `isJTAC` and `spawnAs` are preserved but not editable |
| `modTypes` | `JsonEditor` | Wrong catalogue shape and no schema entry |

Two of FullGas's four items were resolved by decision rather than by building the editor he proposed, and
have left this lot:

- **`specificParams`** — he proposed a conditional four-input sub-panel. Decided instead to remove the
  concept and replace it with four global settings → lot **C** (`FEAT-JTAC-DRONE-GLOBALS`).
- **The schema fixes** he listed as independent of editor work — `tableFields.AIZones`, the `modTypes`
  shape and description, `GROUND_UNIT` — → lot **B**, precisely because they are independent and because
  this lot builds on them.

## Decisions

### `isJTAC` and `spawnAs`, together

The engine has no gap: `_dispatchPostSpawn` starts lasing for any `isJTAC` descriptor regardless of
`spawnAs` ([CTLD_crate.lua:2257](../../src/CTLD_crate.lua#L2257)), and the catalogue already ships two
**ground** JTACs — Hummer (1001.01) and SKP-11 (1001.11), neither carrying a `spawnAs`. Only the editor
is short.

They ship together, not in sequence: `spawnAs` is what decides whether a JTAC is an orbiting aircraft or
a ground vehicle. Shipping the checkbox alone would let an MM flag an aircraft type as a JTAC and get a
broken ground spawn with no message.

**The dropdown is strict and offers exactly `GROUND` and `AIR`.** A strict dropdown is a promise that
every listed value works, so nothing else is listed:

- `AIR` is a **UI convenience, not an engine value**. The tool resolves it on save to `AIRPLANE` or
  `HELICOPTER` from the unit's category; the YAML carries the resolved value and the engine is unchanged.
- DCS cannot build a manned aircraft from a raw Lua table — only ground units, statics, helicopters and
  drones. The legacy monolith never pretended otherwise: it hardcoded the two drone type names in an
  inequality and sent everything else to `Group.Category.GROUND`
  ([migration/source/CTLD.lua:10351-10367](../../migration/source/CTLD.lua#L10351)). `spawnAs` is a
  CTLD-next generalisation of that special case and still serves only those two drones.
- `STATIC` is not offered: it is broken through the crate path — `buildGroupUnitDef` says it does not
  handle statics ([CTLD_utils.lua:1274](../../src/CTLD_utils.lua#L1274)) yet returns a group definition
  that then goes to `coalition.addStaticObject` — no catalogue crate uses it, and nothing blocks
  `isJTAC` + `STATIC`, which would lase an object with no controller. The engine's `STATIC` branch stays;
  `CTLDObjectRegistry` uses it legitimately for scene objects.

Strictness matters because the current failure is silent: an unknown `spawnAs` falls back to
`Group.Category.GROUND` ([CTLD_utils.lua:1255](../../src/CTLD_utils.lua#L1255)), so a typo spawns a ground
unit without a word.

### Every vocabulary comes from the schema, never from a component

`spawnAs` and the three `aiZones` enums are declared as `choices` lists on their `tableFields` entries
(authored by lot B, surfaced here by ticket 02). The reason is documentation, not plumbing: **nothing stops
a Mission Maker editing the YAML by hand**, and the schema is the document that explains the config to
them. A value list living only in a Svelte component helps users of the app and no one else — and it lets
the UI drift from the engine.

This needs one contract change. `/api/schema` currently collapses a table field to a single localised
string ([app.py:117](../../tools/ctld-tools/ctld_tools/web/app.py#L117)) and the frontend types it as
`Record<string, Record<string, string | null>>`; both widen to carry tip + optional choices. Because that
comprehension reads only the language key and drops every other, lot B can author the `choices` first with
no breakage — there is no flag day between the two lots.

### `aiZones` gets a real editor, driven by the engine's own vocabularies

Fields come from [`_loadAIZonesFromConfig`](../../src/CTLD_zone.lua#L705) and the enums from the engine's
own tables ([CTLD_zone.lua:1492-1494](../../src/CTLD_zone.lua#L1492)) — `RED/BLUE/NEUTRAL`, `T/V/TV`,
`G/P/GP`. Two traps the editor must respect:

- **`coalition` is a string here**, whereas everywhere else in the catalogue a coalition is the numeric
  `side` (1 = RED, 2 = BLUE). Reusing the `side` widget would write a number into a field that expects a
  word — the same data-corruption class as the `boolean`-typed `jtac` field fixed in the previous lot.
- **`troopStock` / `vehicleStock` carry two magic values**: the key `All` (everything, unlimited) and the
  value `-1` (unlimited for that entry). A bare `KeyValueEditor` surfaces neither.

### `spawnableCratesModels` and `modTypes`

Three fixed rows for the former, no add or remove; the existing `StringListEditor` for the latter, which
already serves `transportPilotNames` and `extractableGroups`. Both follow from lot B making the catalogue
shapes honest.

## Out of scope

- **`mixedSet` editing.** FullGas deferred it — a complex sub-table of crate references. It stays a
  read-only badge.
- **A `validate` rule refusing manned-aircraft types on a crate.** `spawnAs` is an abstraction nobody has
  yet used; the guard waits for a real case rather than being written speculatively.
- **`SHIP` / `TRAIN` / `STATIC` through the crate path.**
- **Dynamic schemas for MM-added plugins.** The web views are not made flexible enough for plugins added
  at runtime, after the tool is compiled. Considered and deferred: not worth the cost yet.
- **Server exiting when the browser page closes.** Considered and dropped: the editing session lives in
  server memory ([state.py:16](../../tools/ctld-tools/ctld_tools/web/state.py#L16)), so closing a tab today
  is *recoverable* — reopening the URL restores every edit. Killing the process would make it
  unrecoverable, and doing it correctly needs a heartbeat (a `sendBeacon` on unload also fires on F5) plus
  the `beforeunload` guard the app lacks. The console window remains the lifecycle owner.

## Definition of done

- No config key the app exposes falls through to `JsonEditor` except by deliberate decision, and
  `mixedSet` is the only such case.
- No editor can write a value of the wrong type or the wrong vocabulary — in particular
  `aiZones.coalition` stays a string, and the `aiZones` enums match the engine's `VALID_*` tables.
- No closed value set is literal in a component: every select reads its options from the schema, so a
  hand-editing Mission Maker and the app see the same vocabulary.
- The `spawnAs` dropdown offers only values that work, and `AIR` reaches the YAML resolved.
- `dcs_types.json` carries the unit category, generated from the same datamine run as the names.
- The `aiZones` stock editors make `All` and `-1` discoverable rather than lore.

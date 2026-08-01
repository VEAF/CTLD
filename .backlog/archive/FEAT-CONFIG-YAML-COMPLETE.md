# FEAT-CONFIG-YAML-COMPLETE

**Status:** merged (PR #65). Compacted from `FEAT-CONFIG-YAML-COMPLETE/` on 2026-08-01; the ticket files live on in git history.

Lot 1/3 — runtime: complete `configUser or configDefault` YAML loading (no merge; missing = removed), harden `parseYAML` for the full catalogue + round-trip parity test, bake AA crates into the YAML (drop the runtime injection loop), version tag, remove `ctld.userSetup`/`CTLD_userSetup.lua`.

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-externalisation-audit` | 📋 todo | 01 — Externalisation audit + scope checkpoint |
| `02-parseyaml-hardening` | ✅ done | 02 — parseYAML hardening + round-trip parity test |
| `03-build-embed-configdefault` | ✅ done | 03 — Build embeds configDefault YAML string |
| `04-complete-config-or-loader` | ✅ done | 04 — Complete-config `or` loader |
| `05-aa-bake-in` | ✅ done | 05 — AA bake-in + injection-loop removal (last lupa use) |
| `06-userset-removal-version-tag` | ✅ done | 06 — userSetup removal + version tag |

## PRD

## Lot FEAT-CONFIG-YAML-COMPLETE — complete-YAML runtime config model

Status: 📋 planned
Branch: `feature/config-yaml-complete` → PR → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`).
ADR: [0011](../../dev/adr/0011-complete-yaml-config-and-webapp-tooling.md) (supersedes 0008 + 0009 pts 2 & 3).
Lot **1 of 3** in the ctld-tools v2 program. Runtime-only; no tool work here.

### Problem Statement

CTLD resolves its config through an **ops/diff** model (ADR 0008/0009): the MM's `user-config`
compiles to a runtime helper API (`ctld.userSetup` + `ctld.addCrate/patchCrate/…`) that mutates the
default catalogue. This carries a runtime surface that exists only to serve the diff abstraction, and
AA crates are materialised at runtime by a generative loop. ADR 0011 replaces the diff with a
**complete configuration** resolved by a plain `or`.

### Solution (this lot = the runtime half)

0. **Externalisation audit (opening work).** Inventory every hardcoded config-like knob still in
   `src/` and classify each by the rule **"would a mission-maker want to tune this per mission?"**:
   yes → externalise into the YAML + schema (an *advanced* section if it is niche, e.g. AA distances
   `_ASSEMBLY_DIST`/`_REARM_DIST`); no → it is engine-internal, stays in code (e.g. `objectRegistry`
   `shape_name`/`namePrefix` — DCS engine identifiers, not settings). Externalisation is
   **behaviour-preserving** (same defaults). This defines the definitive catalogue that lots 2 & 3
   edit. Conservative by default (surgical ethos — do not inflate the config surface). Ends on a
   **scope-validation checkpoint** (the classified inventory reviewed) before externalisation lands.
1. **Complete-config loading.** At init, resolve `configUser or configDefault` and parse the winner
   into the settings table. **No merge.** A missing element = intentional removal.
   - **Malformed-`configUser` policy (decided, ticket 04): hard error.** If a `configUser` is present
     but parses to an empty settings map, `load()` raises a Lua error and aborts — no silent fallback
     to `configDefault`. Rationale: `ctld-tools` validates a snapshot before export, so a broken
     `configUser` is a real authoring fault the MM must see, not paper over. (`configDefault` is
     build-generated and always valid, so the no-`configUser` path never hits this.)
   - **i18n labels.** The parsed YAML holds literal `desc`/`name` values; `load()` re-applies
     `ctld.tr()` to every `desc`/`name` string at any depth (same rule as gen-config `_I18N_FIELDS`),
     so runtime labels stay translated in every language.
2. **YAML-at-runtime.** Both documents are YAML strings; `configDefault` is the engine YAML embedded
   verbatim by the build, `configUser` is the (optional) MM snapshot set by a mission-start trigger.
3. **Harden `CTLDConfig.parseYAML`** to the full nested catalogue: quoted strings containing `:`,
   float-valued keys, i18n punctuation, lists of maps, nested tables. Guard with a **round-trip
   parity test** (emit the default YAML → parse in Lua → compare to the reference table).
4. **Bake AA into the YAML.** Expand `CTLDCrateAssemblyManager.injectAACrates` once into ordinary
   crate entries written into the default YAML; **delete** the runtime injection loop + `TEMPLATES`
   materialisation path. (mixedSet consistency is enforced by the tool's `validate` in lot 2.) This
   one-shot expansion is the **last use of `lupa`** in the codebase (run it once, commit the YAML).
   The build stops calling `gen-config` and instead **embeds the YAML string** into a Lua module.
   (The now-dead `gen-config`/`gen-reference`/`extract` commands + the `lupa` dependency itself are
   deleted in lot 2, the tool-package cleanup.)
   **Lot 2 cleanup checklist** (dead after this lot — see `⚠️ DEAD CODE` markers in the sources):
   `gen-config`, `gen-reference`, `extract`, and the **entire gen-user / TUI edit chain** —
   `ctld_tools/genuser.py` (emits the retired `userSetup`/`yamlConfigDatas` model), `editmodel.py`,
   `scaffold.py`, the `cli` `gen-user` command, the `tui/` package, and their tests
   (`test_editmodel`, `test_scaffold`) — all removed and replaced by the web tool that emits
   `ctld.configUser` YAML. Plus the `lupa` dependency. (Ticket 06 only deletes `test_genuser.py`,
   the one test that executed the now-removed `userSetup` runtime.)
5. **Version tag** on the default YAML (and schema). Stored so a `configUser` can record the version
   it was authored against (consumed by the tool in lot 2).
6. **Retire** `src/CTLD_userSetup.lua` and the `ctld.userSetup` API. Clean break (pre-2.0.0). The
   v1 Legacy API (ADR 0004) is untouched.

### Definition of Done

- CTLD loads a complete `configUser` YAML (full snapshot) with `or` semantics; omitted element is
  absent at runtime. Parity with legacy behaviour preserved for the default (no `configUser`) path.
- `parseYAML` round-trip parity test green (busted, CI). luacheck + lua5.1 clean.
- AA crates present in the default catalogue with no runtime injection; existing AA scenarios pass.
- `ctld.userSetup` / `CTLD_userSetup.lua` removed; build (`merge_CTLD.ps1`) embeds the YAML string.
- CHANGELOG `[Unreleased]`; ADR 0011 referenced; docs touch-ups deferred to lot 3 (tool-facing).

### Out of scope

- Any ctld-tools change (lots 2 & 3).
- The version-gap popup / diff review UX (lot 2/3 — this lot only stores the tag).

### Tickets

Authored when the lot starts (tracer-bullet slices). Expected spine: (a) externalisation audit +
inventory + externalise in-scope knobs; (b) `or` loader + settings copy; (c) parseYAML hardening +
round-trip parity test; (d) AA bake-in + injection-loop removal; (e) version tag; (f) userSetup
removal + build embed.

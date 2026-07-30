# ADR 0011 — Complete-YAML config model and web-app tooling for ctld-tools

## Status

Accepted (2026-07-24). **Amended 2026-07-30 — see [Addendum 1](#addendum-1--the-two-config-tiers-2026-07-30).**
**Supersedes ADR 0008 entirely and ADR 0009 points 2 & 3.**

Point 1 of ADR 0009 (a standalone, offline `ctld-tools` distributed to MMs) and point 4 (`.miz`
trigger injection) stand. The YAML-as-single-source-of-truth *intent* of ADR 0009 stands; what
changes is how the YAML reaches the runtime and how the MM authors it.

## Context

Two lines of work diverged and forced a decision:

- The `develop` line (ADR 0008 + ADR 0009) modelled the MM's `user-config` as an **ops/diff
  document** (`add` / `remove` / `patch` against the default catalogue), compiled by ctld-tools into
  a runtime helper API (`ctld.userSetup` + `ctld.addCrate/patchCrate/…`), edited in a Textual **TUI**.
- A parallel branch (`feature/ux-ctld-tools-v2`, FullGas) rebuilt the tool as a **tkinter GUI**
  editing the **full catalogue** (values + data) rather than a diff.

Field use (TUI-EDIT-MODE-UX, PR #63) exposed that the diff model is hard to present unambiguously:
the UI kept looking like the effective list while editing a diff. The ops model also carried a
non-trivial runtime surface (the `ctld.userSetup` helper API) and a tooling surface (an ops editor,
per-op validation, a separate `reference.json` slice) that exist only to serve the diff abstraction.

A discussion (David + FullGas, 2026-07-23 evening) concluded to drop the diff abstraction on both
sides — runtime and tool — in favour of a **complete configuration** the tool edits in full, and to
replace both the TUI and the tkinter GUI with a **local web app**.

## Decision

### Runtime — complete YAML config, resolved by a plain `or`

1. **The config is one complete YAML document, not a diff.** The engine ships its default catalogue
   as YAML embedded verbatim into the deliverable (the `configDefault` string). A mission may supply
   a **complete** `configUser` YAML — a full snapshot, not a set of operations. **A missing element
   means intentional removal.** — *Amended: this holds for lists, not for scalar parameters. See
   [Addendum 1](#addendum-1--the-two-config-tiers-2026-07-30).*

2. **Loading is a straight `or`, never a merge.** At init CTLD resolves `configUser or configDefault`
   and parses the winner into the settings table. The runtime never deep-merges user over default;
   the winning document is authoritative in full. This keeps the runtime trivial and makes element
   removal free (omit it).

3. **YAML stays the runtime representation; the tool never emits Lua tables.** The user config is
   shipped as a YAML **string** in a mission-start trigger (run before CTLD), authored by ctld-tools.
   The tool's only Lua output is the trivial one-line assignment wrapping that string. This keeps the
   MM-facing surface **non-Lua** (an MM can eyeball or tweak readable YAML in the ME without the tool
   and without Lua knowledge — the founding motivation of ctld-tools), keeps a **single canonical
   format** end to end, and removes any Lua-table serializer (and its round-trip parity burden) from
   both the build and the tool. The cost — the runtime YAML parser must handle the full nested
   catalogue — is bought down by hardening `CTLDConfig.parseYAML` and a **round-trip parity test**
   (emit YAML → parse in Lua → compare to source).

4. **AA crates are baked into the YAML (static data), not generated at runtime.** The AA catalogue
   entries (produced today by the generative `CTLDCrateAssemblyManager.injectAACrates` loop over
   `TEMPLATES`) are expanded **once** and written **as ordinary crate entries** into the default YAML.
   The runtime injection loop is removed. `validate` checks the "All crates" mixedSets stay
   consistent (every referenced weight exists). The AA catalogue changes rarely, so the loss of
   auto-derived consistency is acceptable and covered by validation.

5. **Version tag + tool-driven re-migration.** The default YAML **and** its schema carry a version
   tag. A `configUser` records the version it was authored against. On a CTLD upgrade the runtime
   still does a plain `or` (the frozen snapshot loads as-is); ctld-tools, on opening a stale
   `configUser`, **detects the version gap, warns the MM in a popup, and surfaces the diffs** (new /
   changed defaults) to review before re-injecting. Upgrade flow is thus a deliberate, tool-assisted
   re-migration — never a silent runtime merge.

6. **Retired.** The `ctld.userSetup` API and `src/CTLD_userSetup.lua` (ADR 0008) are removed, along
   with the runtime AA injection. This is a **clean break** (pre-2.0.0, no released consumers). The
   **v1 Legacy API (ADR 0004)** is orthogonal and untouched.

### Tooling — a local web app, single console exe

7. **ctld-tools becomes a local web app** — a **FastAPI** backend + a **Svelte + Vite + TypeScript**
   frontend. The needs are far lighter than Walker: single user, ephemeral, **no DB, no auth, no
   migrations**. Svelte was chosen over React on merit (smaller bundle to embed in the exe, less
   ceremony to maintain) rather than familiarity. It edits the complete catalogue in full — adopting
   FullGas's schema-driven
   editors and his **12 functional families** as the navigation, **plus** a higher-level split into
   two screens: **Parameters** (how CTLD behaves) vs **Data** (what CTLD operates on).

8. **Distribution mirrors VMCT's `veaf-tools.exe`.** A **single console-mode** PyInstaller exe is the
   real CLI (headless `validate` / config embed / `gen` for build & CI) **and** the GUI launcher. On
   a bare invocation / double-click — detected by walking the parent process tree (`explorer.exe` vs
   a terminal process), the pattern lifted from VMCT's `_is_double_clicked` — it boots a local
   `uvicorn` on `127.0.0.1` and opens the browser. The console window stays as the server-lifecycle
   window ("close to quit"). No `--noconsole`; build/CI keep invoking the Python package directly.
   File open/save uses a **native OS dialog** driven by the local backend (which runs as the MM).

## Considered alternatives

- **Keep the ops/diff model (ADR 0008/0009), just clarify the UI** (the TUI-EDIT-MODE-UX path).
  Rejected: the diff abstraction is the root source of the ambiguity and of two whole surfaces
  (runtime helper API + ops editor). Removing it is simpler than perpetually disambiguating it.
- **Runtime deep-merge `configDefault ⊕ configUser`** so upgrades auto-flow. Rejected: it makes
  element removal require explicit remove-ops again (the complexity we are dropping) and contradicts
  "missing = intentional removal". Upgrade flow is handled by tool-driven re-migration (point 5).
- **Tool emits a Lua table** (no runtime YAML parser). Rejected: it puts Lua back on the MM surface,
  needs a faithful Lua-table serializer in two places (build + tool) with round-trip parity, and
  reverses the current direction (the runtime already parses user YAML). See point 3.
- **Keep the AA generative loop, run it at build to emit YAML.** Rejected (point 4): it keeps a
  second representation (template vs materialised entries) — the very duplication the model removes —
  for data that changes rarely.
- **Keep FullGas's tkinter GUI** (it is nearly complete). Rejected: capability/ergonomics ceiling
  (menus, icons, layout); the web stack is already mastered (Walker). The schema-driven editor logic
  and the 12-families taxonomy are salvaged; the tkinter UI layer is not.
- **`--noconsole` GUI-only exe with the CLI split to the package.** Rejected after checking VMCT:
  a single console exe that auto-launches the UI on double-click is one artifact, keeps a working
  CLI, and is the ergonomics the maintainer already validated in veaf-tools.

## Consequences

- **Runtime**: `CTLDConfig.parseYAML` must robustly parse the full nested catalogue (quoted strings
  containing `:`, float-valued keys, i18n punctuation) — guarded by a round-trip parity test.
  `src/CTLD_userSetup.lua` and the runtime AA-injection path are deleted. The default YAML gains the
  AA entries and a version tag. An **externalisation audit** (lot 1) sweeps `src/` for any remaining
  hardcoded config-like knob and externalises the MM-tunable ones into the YAML + schema
  (behaviour-preserving; conservative — internal engine identifiers stay in code), so the YAML is
  genuinely the complete config.
- **Build**: no Lua-table generation for the defaults — the build **embeds the YAML string** into a
  Lua module. `gen-config` (YAML→Lua-table) is retired; `reference.json` / `gen-reference` collapse
  into "the tool reads the one default YAML". **`lupa` is removed entirely** (dependency dropped from
  `pyproject`) along with the `extract` / `gen-config` / `gen-reference` commands and
  `Reference.from_src`: nothing reads Lua any more (the runtime never did, the build embeds a string,
  the tool reads YAML). Its last use is the **one-shot AA bake-in** in lot 1; after that lupa goes.
- **Tool**: the ops editor (`editmodel.py`, ops logic in `gen-user`), the Textual TUI and the tkinter
  GUI are removed. New: web backend + frontend, version-gap detection, native file dialog, complete
  catalogue editing, mixedSet-consistency validation. **No editing gaps**: every schema-declared
  parameter and data family is editable — including `capabilitiesByType` (datamine-backed aircraft
  types) and `transportPilotNames` — enforced by a **blocking** schema-coverage test. A **generic
  fallback editor** (typed raw field) guarantees every key renders *something*, so the gate is
  painless; bespoke editors are added progressively. A key deliberately hidden from the MM goes on an
  **explicit, reviewed allowlist** — never a silent skip.
- **Docs**: `docs/mission-maker/ctld-tools.{md,fr.md}` and the `user-config` / `ctld-tools` glossary
  in `CONTEXT.md` are rewritten (glossary done in this decision's move).
- **Delivery**: three sequenced lots — (1) `FEAT-CONFIG-YAML-COMPLETE` (runtime), (2) `CTLD-TOOLS-CORE`
  (UI-agnostic tool core + demolition), (3) `CTLD-TOOLS-WEBAPP` (web presentation + exe). The lot-2/
  lot-3 boundary is **logic vs interface**: lot 2 delivers a library, lot 3 the web layer over it —
  no business logic is written twice.
- **Superseded lots**: `FEAT-USERCONFIG-API`, `CTLD-TOOLS-CONFIG`, `CTLD-TOOLS-USERCONFIG`,
  `CTLD-TOOLS-TUI`, `CTLD-TOOLS-TUI-POLISH`, `TUI-EDIT-MODE-UX`, and FullGas's `UX-CTLD-TOOLS-V2`
  contributed the groundwork but their diff/TUI/tkinter surfaces are retired here.

## Addendum 1 — the two config tiers (2026-07-30)

Point 1 above says "a missing element means intentional removal" without distinguishing the two kinds
of thing the config holds. For a list that sentence is exactly right. For a scalar it has no meaning —
the engine needs a number to compute with — and the code proves it: three settings are read with no
fallback and fed straight into arithmetic or a comparison, so an incomplete document **crashes the
mission** instead of expressing a removal.

| Setting | Site | Failure |
|---|---|---|
| `JTAC_searchIntervalSeconds`, `JTAC_laseIntervalSeconds` | `CTLD_jtac.lua:905-906`, then `t + searchInterval` | error on every JTAC tick |
| `slingCutDestroyHeight` | `CTLD_crate.lua:1503`, `agl > ctld.gs(...)` | error on every slingload release |

This is reachable through a path the project already tools for — a `configUser` authored against an
older catalogue, to which the engine has since added keys, which is precisely what the version-gap
detection of point 5 exists to find. It is also reachable because **nothing obliges a Mission Maker to
use ctld-tools**: point 3 deliberately makes the YAML hand-editable, so a config may never meet
`validate` at all.

### The two tiers

- **Parameter** — a key whose default value is a **scalar**. It must be present. If it is absent the
  engine resolves it from `configDefault` and reports it. **Never a removal**: "no value" is not a
  state the engine can compute with.
- **List** — a key whose default value is a **list or a map**. Omitting the key, or omitting one of its
  elements, is an intentional removal. Unchanged from point 1.

The tier is **derived, not declared** — read from the shape of the default value. No new metadata to
maintain, and no drift surface between the engine and the tool, which apply the same rule to the same
document.

### This does not reopen the rejected deep-merge

The considered alternative "runtime deep-merge `configDefault ⊕ configUser`" stays rejected, and its
stated objection is why: merging *"makes element removal require explicit remove-ops again"*. That is an
argument about **lists**, and lists keep point 1's semantic untouched. Nothing is merged here — a
parameter absent from the winning document resolves to one value from the default, and no list is ever
combined with another. Point 2's "never a merge" holds for every list; it gains an exception for scalars,
where there was never anything to merge.

### Enforced at two layers

Because a hand-written config never meets the tool, one layer is not enough:

- **Design time** — `validate` reports a missing parameter as an `ERROR`, which blocks export.
- **Runtime** — the engine defaults it and emits a startup **NOTICE**, on screen rather than log-only:
  for a hand-written config that is the only signal its author will ever get.

A corollary: with the default reachable at runtime, per-site `or <literal>` fallbacks on parameters
become duplicate defaults and are deleted. Two had already drifted from the catalogue
(`maximumSearchDistance` 3000 vs 10000, `maximumDistanceLogistic` 200 vs 500). The `or {…}` guards on
lists stay — for a list, absent still means empty.

Implemented by lot `FEAT-CONFIG-PARAM-SEMANTICS`.

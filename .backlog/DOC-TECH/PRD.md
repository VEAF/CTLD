# Lot DOC-TECH — technical documentation refonte

Status: ✅ done
Branch: feature/doc-tech → PR → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`)

## Problem Statement

The developer-facing documentation is scattered and inconsistent:

- `docs/dev-guide.md` (1145 l., 19 sections) is the de-facto developer manual but has broken
  sub-section numbering (`### 7.x` under `## 9`, `### 8.x` under `## 10`) and a flat single-file
  shape that does not scale.
- `docs/api-reference.md` (309 l.) is a separate per-Manager reference.
- `migration/specs/` (9 files, ~4000 l.) holds the deep design specs authored during the v2
  migration (DesignSpec, Events_Catalog, Menu ×3, JTAC lifecycle, TroopZones, i18n_rules, vehicle
  transport). The dev-guide often just summarises them, so the same knowledge lives in two places.
- The mkdocs site (DOC-MKDOCS) is flat and EN-only; there is no `docs/developer/` section.
- Pre-existing broken links / content gaps inherited from the Fulgas docs (flagged in DOC-MKDOCS).

There is also **no page documenting the development workflow** (the `.backlog/` process, Git Flow,
TDD, quality gates, and the authoring skills used to run this program).

## Solution

Consolidate `docs/dev-guide.md` + `docs/api-reference.md` + `migration/specs/` into a single
coherent, multi-page `docs/developer/` section published by mkdocs, **bilingual EN (default) + FR**.
Fix the numbering, broken links and content gaps in the process; add the missing **Development
workflow** page. `migration/specs/` is retired once its unique content has migrated (single source
of truth).

## Scope

Target `docs/developer/` tree (each page is `*.md` = EN default + `*.fr.md` = FR, per the mkdocs
`docs_structure: suffix` i18n config):

| Page | Consolidates |
|------|--------------|
| `index.md` | landing + architecture overview (dev-guide §1–2) |
| `workflow.md` **(NEW)** | `.backlog/` process, Git Flow, TDD, build, quality gates, the Matt Pocock skills (`grill-with-docs`, `to-prd`, `to-issues`) |
| `architecture.md` | repo structure, CoreManager init, module pattern, internal libs (§1–3, §19) |
| `building-and-testing.md` | build (`merge_CTLD.ps1`), busted, coverage ratchet, CTLD.log, debug config (§7–8, **excluding** Witchcraft/integration-testing) |
| `events.md` | event system (§4) + `CTLD_Events_Catalog` |
| `subsystems/*.md` | one page per subsystem — scenes, crates, troops-jtac, zones, vehicles, beacons, recon, menu, players, aa (§5–6, §11–18 + matching specs) |
| `i18n.md` | §10 + `i18n_rules` |
| `migration-v1-v2.md` | §9 (v1→v2 wrapper, migration table, examples) |
| `api-reference.md` | `docs/api-reference.md` moved + refreshed |
| `design-spec.md` | `CTLD_DesignSpec` kept as reference |

Plus: mkdocs `nav` rewired with a Developer section/sub-pages; broken links and gaps fixed;
`docs/dev-guide.md`, `docs/api-reference.md` and `migration/specs/` removed after migration.

## Decisions (validated with David)

- **Bilingual EN + FR** for the developer docs (not EN-only). FR pages authored once EN structure
  is locked, to avoid re-translating on structure changes.
- **Archive `migration/specs/`** after consolidation — its unique content migrates into
  `docs/developer/`; the directory is removed. Single source of truth.
- **Integration testing (Witchcraft §8.2–8.3 + `recette-procedure.md`) is out of scope** — left to
  the `DCS-BRIDGE-MCP` lot, which retires Witchcraft. Not rewritten twice here.
- **`Repack` → `pack`** wording fixed wherever it appears (e.g. dev-guide §5.3 "FARP Repack flow").

## Testing Decisions

- `pip install -r docs/requirements.txt` + `mkdocs build --strict` succeeds and produces both `en`
  and `fr` trees with **no link warnings** (the DOC-MKDOCS pre-existing warnings must be gone).
- No `src/` change → no `CTLD.lua` rebuild, no busted/coverage impact.

## Out of Scope

- Pilot / mission-maker role docs (`missionmaker_guide.md`) → `DOC-USER-ROLES`.
- Integration-testing / Witchcraft retirement → `DCS-BRIDGE-MCP`.
- The chatbot (bonus, future).

## Further Notes

`migration/source/` (the legacy monolith) is immutable and stays untouched — only
`migration/specs/` (migration scaffolding) is retired.

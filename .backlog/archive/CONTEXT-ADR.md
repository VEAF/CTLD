# CONTEXT-ADR

**Status:** delivered. Compacted from `CONTEXT-ADR/` on 2026-08-01; the ticket files live on in git history.

Retroactive ADRs 0001–0005 in `dev/adr/` (PR #4).

## Tickets

| Ticket | Status | Title |
|---|---|---|

## PRD

## Lot CONTEXT-ADR — retroactive ADRs + domain memory

Status: ✅ done
Branch: feature/context-adr → PR → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`)

### Problem Statement

The major architectural decisions of the v2.0.0 rewrite live only in a long
`migration/MODERNIZATION-PLAN.md` and scattered `migration/history/` notes (French, session-scoped).
There is no concise, discoverable record of *why* the codebase is shaped the way it is, which the
domain-aware skills (`grill-with-docs`, `improve-codebase-architecture`) expect at `dev/adr/`.

### Solution

Capture the key structural decisions as concise, retroactive ADRs under `dev/adr/`, grounded in the
kept seeds (`AS-IS-ANALYSIS.md`, `repack_to_pack_mapping.md`). Keep `CONTEXT.md` as the ubiquitous
language glossary. Deliberately light (4–5 key ADRs), per the "backlog allégé" decision — not an
exhaustive backfill of every past task.

### Scope

- ADR 0001 — modular source tree + merge build
- ADR 0002 — OOP Manager+Entity + unified coalition handling
- ADR 0003 — drop MIST → in-house `ctld.utils`
- ADR 0004 — legacy compatibility API
- ADR 0005 — rename repack → pack
- `dev/adr/README.md` index; `CONTEXT.md` already in place from PROCESS-SCAFFOLD.

### Out of Scope

- An ADR per minor implementation detail (scene engine internals, i18n mechanics).
- Exhaustive conversion of `MODERNIZATION-PLAN.md` into backlog tickets (kept as a historical journal).

### Further Notes

Seeds `migration/history/AS-IS-ANALYSIS.md` and `repack_to_pack_mapping.md` remain as raw material;
they may be retired once the ADRs and technical docs fully absorb them (DOC-TECH lot).

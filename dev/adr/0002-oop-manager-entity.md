# 2. OOP with a Manager + Entity pattern, and unified coalition handling

Status: Accepted (retroactive — documents a v2.0.0 decision)
Date: 2026-07-07

## Context

Legacy CTLD was fully procedural: 100+ public functions on the global `ctld` table, zero local
functions, all state in ~34 global tables. Worse, most state was **duplicated per coalition**
(`...RED` / `...BLUE` table pairs), producing 50+ `if coalition == 1 then … else …` branches and
near-duplicated troop/vehicle code paths.

## Decision

Adopt object orientation via a minimal in-house class framework (`src/core/class.lua`:
`class(base)` → `:new()` calling `init()`, inheritance through metatables). Structure each domain
as a **Manager** (singleton, `getInstance()`/`get()`) plus an **Entity** (per-instance) — e.g.
`CTLDCrateManager`/`CTLDCrate`, `CTLDTroopManager`/`CTLDTroopGroup`. Coalition is carried as entity
state rather than duplicated tables, collapsing the RED/BLUE branching.

## Consequences

- State is encapsulated in managers; the global surface shrinks to the `ctld` namespace plus
  sanctioned accessors (`ctld.gs(...)`).
- Coalition-specific logic lives in one place, keyed by the entity's coalition.
- New domains follow the same shape, keeping the codebase predictable and AI-navigable.
- Config is read only through `ctld.gs("param")`; direct getters are disallowed.

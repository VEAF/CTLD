# 1. Modular source tree with a merge build

Status: Accepted (retroactive — documents a v2.0.0 decision)
Date: 2026-07-07

## Context

Legacy CTLD was a single `CTLD.lua` monolith (~8,700 lines): the source file *was* the
deliverable. It was impossible to navigate or review efficiently, and there was no build system.
DCS World, however, loads a single Lua file via a mission trigger — the shipped artifact must stay
one file.

## Decision

Split the source into a modular tree under `src/` (~32 focused files, one per domain plus a
`core/` foundation), and concatenate them into a single deliverable `CTLD.lua` via a
PowerShell build (`tools/build/merge_CTLD.ps1`). Concatenation order is controlled by
`tools/build/listToMerge.txt`. The output is written in **UTF-8 without BOM** (required by the DCS
Lua engine) and is a **generated artifact — never hand-edited**.

## Consequences

- Source is reviewable and testable per module; the single-file constraint is still honored at
  ship time.
- A rebuild is mandatory after any `src/` change; CI builds the artifact from the same script
  (single source of truth — see [0002](0002-oop-manager-entity.md) for the runtime structure).
- The build is PowerShell (Windows-first tooling); this is acceptable because tooling is free to
  be non-Lua while the deliverable stays pure Lua 5.1.

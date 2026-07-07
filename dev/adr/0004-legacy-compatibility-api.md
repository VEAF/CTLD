# 4. Legacy compatibility API for v1 missions

Status: Accepted (retroactive — documents a v2.0.0 decision)
Date: 2026-07-07

## Context

Existing missions call CTLD v1 through `ctld.*` functions from DO SCRIPT triggers. The v2 rewrite
moved that behavior into managers/entities (see [0002](0002-oop-manager-entity.md)), which would
break every existing mission if the old entry points disappeared.

## Decision

Provide a thin **legacy compatibility layer** (`src/legacy/legacy_api.lua`): a set of delegate
wrappers exposing the historical `ctld.*` signatures (troops, zones, crates, beacon, JTAC) that
forward to the new managers. It is loaded last in the merge order so it can bind to fully
initialized managers.

## Consequences

- v1 missions keep working without changes; the migration is non-breaking for mission makers.
- The wrappers are intentionally thin (no logic) — behavior lives in the managers, so parity is
  maintained against `migration/source/` (the immutable legacy reference).
- The legacy surface is a compatibility contract: changes to it are treated as potentially breaking
  for existing missions.

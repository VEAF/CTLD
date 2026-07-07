# 3. Drop the MIST dependency for an in-house utility layer

Status: Accepted (retroactive — documents a v2.0.0 decision)
Date: 2026-07-07

## Context

Legacy CTLD bundled and hard-depended on MIST (~91 `mist.*` calls: math/vectors, distance,
headings, coordinate formatting, spawning, routes, LOS, scheduling). It `assert`-crashed at init
if MIST was absent, and shipping a second large library alongside CTLD bloated the deliverable and
coupled it to MIST's lifecycle.

## Decision

Remove the MIST dependency entirely. Reimplement only the functions CTLD actually uses in an
in-house `ctld.utils` layer (vectors/geometry, distance, a self-managing scheduler with
register/cancel, logging). No external Lua dependency at runtime.

## Consequences

- The deliverable is self-contained; no MIST version coupling, no init crash on missing MIST.
- `ctld.utils` is small and purpose-built (only what CTLD needs), and is unit-tested with the rest
  of `src/`.
- Any future need for a MIST-only capability must be reimplemented in `ctld.utils` rather than
  reintroducing the dependency.

# 01 — date the lists, default the newer ones

Status: done

See the [PRD](../PRD.md).

## Acceptance

- A `2.2.0` snapshot without `fatCowCrates` reads the catalogue's crates, reported by `getDefaultedParameters()`.
- A `2.3.0` snapshot without it reads nothing; `aiZones` (not dated) stays removed at any version.
- `complete()` adds `fatCowCrates` to a `2.2.0` configuration, not to a `2.3.0` one.

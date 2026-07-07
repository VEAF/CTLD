# 04 — API reference & design spec pages (EN)

Status: ⬜ ready
Type: AFK

## What to build

- `docs/developer/api-reference.md` — move `docs/api-reference.md` into the developer section and
  refresh it against the current `src/` (verify each Manager's public methods still match; fix any
  drift). Keep the per-Manager structure.
- `docs/developer/design-spec.md` — port `migration/specs/CTLD_DesignSpec.md` as the design-spec
  reference (the "why" behind the architecture). Trim migration-only scaffolding prose; keep the
  durable design rationale.

## Acceptance criteria

- [ ] `api-reference.md` lives under `docs/developer/` and matches current `src/` Managers.
- [ ] `design-spec.md` preserves the durable design rationale from `CTLD_DesignSpec.md`.
- [ ] Old `docs/api-reference.md` removed (in ticket 06's nav/link sweep).

## Blocked by

01 (section skeleton).

## What this changes

Brief description of the change and the lot/ticket it belongs to (`.backlog/<LOT-ID>/`).

## Checklist

- [ ] Deliverables in English; `CTLD.lua` stays pure Lua 5.1
- [ ] `CTLD.lua` rebuilt if `src/` changed (`tools/build/merge_CTLD.ps1`)
- [ ] Unit tests added/updated (`busted tests/ci/`) — TDD
- [ ] `luacheck --config .luacheckrc src/` clean (or relying on CI)
- [ ] `CHANGELOG.md` `[Unreleased]` updated
- [ ] Docs updated if user-facing behavior changed

## Notes

Anything reviewers should know (integration-test impact, follow-ups, handoffs).

# 03 — Events, i18n, migration & build/test pages (EN)

Status: ✅ done
Type: AFK

## What to build

Four EN pages consolidating the remaining dev-guide sections + specs:

- `docs/developer/events.md` — event system (§4) + `CTLD_Events_Catalog.md`.
- `docs/developer/i18n.md` — i18n (§10) + `i18n_rules.md`.
- `docs/developer/migration-v1-v2.md` — v1→v2 (§9: wrapper principle, migration table,
  `ctld.addCallback` replacement, complete example, pack vehicle).
- `docs/developer/building-and-testing.md` — build (`merge_CTLD.ps1`, §7), busted (§8.1), coverage
  ratchet, CTLD.log setup (§8.3), debug config (§8.4), test output format (§8.5), cleanup (§8.6).
  **Exclude** Witchcraft (§8.2) and the dynamic-loading-in-DCS dev workflow that depends on it —
  left to `DCS-BRIDGE-MCP`.

## Acceptance criteria

- [ ] The four pages exist, EN, faithful to their sources.
- [ ] `building-and-testing.md` contains no Witchcraft / integration-testing content.
- [ ] Migration numbering fixed (was mis-numbered `### 7.x` under `## 9`).

## Blocked by

01 (section skeleton).

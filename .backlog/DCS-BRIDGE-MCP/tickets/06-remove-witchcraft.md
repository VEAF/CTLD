# 06 — Remove Witchcraft from the tooling

Status: ✅ done (also swept tests/ci/, tests/dcs/util/, tests/dcs/dev/, tests/manual_test_sequences.md — beyond original scope, approved)
Type: AFK

## What to build

Remove every Witchcraft reference now that scenarios run on the bridge:

- Delete `.claude/witchcraft-workflow.md` (superseded by the `integration-testing` skill).
- Remove the `DCS-Witchcraft: Execute Global` task from `.vscode/tasks.json` (and any related
  Witchcraft entries).
- Purge Witchcraft mentions from `CLAUDE.md`, `CONTEXT.md`, and `docs/` (developer + procedure
  pages), replacing them with the bridge / `integration-testing` skill where a pointer is needed.
- Leave `migration/` history files untouched (immutable legacy reference).

Verify with a repo-wide `grep -ri witchcraft` — the only remaining hits should be in
`migration/` (historical) and this lot's own backlog files.

## Acceptance criteria

- [ ] `.claude/witchcraft-workflow.md` deleted.
- [ ] `.vscode/tasks.json` has no Witchcraft task.
- [ ] No Witchcraft references in `CLAUDE.md`, `CONTEXT.md`, `docs/`, `src/` comments, or
      `tests/dcs/` (scenarios migrated in ticket 04).
- [ ] `grep -ri witchcraft` outside `migration/` and `.backlog/DCS-BRIDGE-MCP/` returns nothing.

## Blocked by

Tickets 04 (scenarios migrated) + 05 (skill exists as the replacement doc).

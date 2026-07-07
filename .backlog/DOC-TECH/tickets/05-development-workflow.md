# 05 — Development workflow page (NEW, required deliverable)

Status: ✅ done
Type: AFK

## What to build

`docs/developer/workflow.md` (EN) — the missing page documenting how development is run on this
repo:

- **Backlog process** — `.backlog/` as single source of truth (one dir per lot: `PRD.md` +
  `tickets/`), the `Status:` vocabulary, archiving closed lots, `dev/agents/issue-tracker.md`.
- **Git Flow** — `feature/*` / `fix/*` off `develop`, one branch / one PR per lot, Conventional
  Commits, `develop` → `master` releases.
- **TDD** — failing busted test first, coverage ratchet.
- **Build & quality gates** — `merge_CTLD.ps1`, Lua 5.1 only, luacheck, CI jobs.
- **Authoring skills** — the Matt Pocock skills used to drive the program: `grill-with-docs`
  (stress-test a plan against the domain model + docs), `to-prd` (turn context into a PRD),
  `to-issues` (break a plan into tracer-bullet issues). Explain when each is used in the flow.

## Acceptance criteria

- [ ] `docs/developer/workflow.md` exists (EN) and covers backlog, Git Flow, TDD, build/gates.
- [ ] The three Matt Pocock skills are documented with their role in the workflow.
- [ ] Consistent with `CLAUDE.md`, `dev/agents/`, and the actual `.backlog/` layout.

## Blocked by

01 (section skeleton).

# Issue tracker configuration

This project does **not** use GitHub Issues as its tracker. It uses a **local markdown backlog**
under `.backlog/`. The `to-prd` and `to-issues` skills (tracker-agnostic) write here.

## Layout

- One lot = one directory `.backlog/<LOT-ID>/`.
- PRD = `.backlog/<LOT-ID>/PRD.md` (problem statement, solution, decisions, scope, definition of
  done, out of scope). The PRD cites its ADR(s) when relevant.
- Tickets = `.backlog/<LOT-ID>/tickets/<NN>-<slug>.md`, numbered from `01` in dependency order
  (tracer-bullet vertical slices).
- Status = a `Status:` line at the top of each PRD / ticket file.
- Index = `.backlog/README.md`, a hand-maintained table of all lots + status (no generator).
  The index line for a lot is moved to `merged (PR #NN)` **within the delivering PR** (so the update
  is covered by review), never left at `pending merge` for a separate post-merge commit.
- Lots closed for more than 3 days are compacted into `.backlog/archive/<LOT-ID>.md` (the ticket
  table is preserved).

## Lot ID convention

Semantic prefixes: `FEAT-*`, `FIX-*`, `DOC-*`, `TOOLING-*`, `UX-*`, `RELEASE`.
Example: `FEAT-JTAC-DRONE-ORBIT`, `FIX-MENU-REFRESH`, `TOOLING-INTEGRATION-TEST-RUNNER`.

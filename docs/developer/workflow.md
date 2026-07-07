# Development workflow

This page documents how development is run on CTLD: the backlog process, Git Flow, test-driven
development, the build and quality gates, and the authoring skills used to drive the work. It is
the operating manual for contributors — the "how we work", complementing the "how it is built"
of the rest of this section.

## Backlog process

CTLD does **not** use GitHub Issues as its tracker. It uses a **local markdown backlog** under
`.backlog/`, versioned with the code. This keeps planning in the same review flow as the change
itself.

- **One lot = one directory** `.backlog/<LOT-ID>/`. A *lot* is a coherent unit of work that ships
  as a single branch and pull request.
- **PRD** — `.backlog/<LOT-ID>/PRD.md` holds the problem statement, solution, decisions, scope,
  definition of done, and out-of-scope notes. It cites its ADR(s) when relevant.
- **Tickets** — `.backlog/<LOT-ID>/tickets/<NN>-<slug>.md`, numbered from `01` in dependency order
  as tracer-bullet vertical slices.
- **Index** — `.backlog/README.md` is a hand-maintained table of every lot and its status (no
  generator).
- **Archiving** — lots closed for more than three days are compacted into
  `.backlog/archive/<LOT-ID>.md`, preserving the ticket table.

### Lot ID convention

Semantic prefixes: `FEAT-*`, `FIX-*`, `DOC-*`, `TOOLING-*`, `UX-*`, `RELEASE`. For example
`FEAT-JTAC-DRONE-ORBIT`, `FIX-MENU-REFRESH`, `TOOLING-INTEGRATION-TEST-RUNNER`.

### Status vocabulary

A `Status:` line at the top of each PRD / ticket file is the source of truth for its lifecycle
state; `.backlog/README.md` mirrors it in the index.

| Status | Emoji | Meaning |
| --- | --- | --- |
| ready | ⬜ | ready to be picked up |
| in-progress | 🔄 | being worked on |
| waiting-human | 🧑 | needs a human decision or more information |
| done | ✅ | delivered |
| wontfix | 🚫 | deliberately not done |

The tracker configuration lives in `dev/agents/issue-tracker.md`; the status vocabulary in
`dev/agents/triage-labels.md`.

## Git Flow

- Work happens on `feature/*` or `fix/*` branches cut from `develop`. Never commit directly to
  `develop` or `master`.
- **One branch / one PR per lot** — all of a lot's tickets land together, even though the backlog
  slices them individually.
- Commits follow **Conventional Commits** in English.
- `develop` is the integration branch; releases are promoted from `develop` to `master`
  (see the release process).

## Test-driven development

New or changed logic ships **test-first**: write a failing [busted](building-and-testing.md) spec,
make it pass, then refactor. The coverage gate is a **ratchet** — CI enforces a floor that only
ever rises, so coverage cannot regress.

See [Building & testing](building-and-testing.md) for the concrete commands, the coverage ratchet,
logging, and debug configuration.

## Build & quality gates

- **Deliverable** — only `CTLD.lua` must be pure **Lua 5.1** (DCS runs Lua 5.1; no 5.2+ syntax).
  It is *generated* by `tools/build/merge_CTLD.ps1` and must never be hand-edited; rebuild after
  any `src/` change.
- **CI gates** (on push to `develop` and on PRs targeting it):
    - `lua-lint` — syntax check with `luac5.1 -p`.
    - `luacheck` — `--config .luacheckrc src/` must be clean.
    - **busted** tests + coverage ratchet.
    - **gitleaks** secret scan.
    - Merge build — `CTLD.lua` is produced one canonical way from `src/`.
- **Docs** — when a behaviour or interface changes, the relevant `docs/` pages change in the same
  PR.

## Authoring skills

The re-tooling program is run with three tracker-agnostic authoring skills (they write into the
local `.backlog/`, not GitHub):

| Skill | Role in the flow |
| --- | --- |
| `grill-with-docs` | Stress-tests a plan against the project's domain model and documented decisions (`CONTEXT.md`, ADRs), sharpens terminology, and updates that documentation inline as decisions crystallise. Used **before** committing to a design. |
| `to-prd` | Turns the resulting conversation/context into a `PRD.md` for the lot. Used to **open** a lot. |
| `to-issues` | Breaks the plan/PRD into independently-grabbable tickets as tracer-bullet vertical slices. Used to **fill** a lot's `tickets/`. |

Typical sequence for a new lot: `grill-with-docs` (converge on the design) → `to-prd` (write the
PRD) → `to-issues` (slice the tickets) → implement on a `feature/*` branch (TDD) → PR to `develop`.

## Default end-to-end sequence

1. Sync `develop` (`git pull --ff-only`).
2. Create the lot in `.backlog/` (PRD + tickets).
3. Branch (`feature/*` or `fix/*`).
4. Implement with tests (TDD); rebuild `CTLD.lua` if `src/` changed; update `docs/`.
5. Run `busted tests/ci/` and `luacheck`.
6. Update `CHANGELOG.md` `[Unreleased]`.
7. Commit + push; open a PR to `develop`.
8. Address review / CI; merge; return to `develop`.

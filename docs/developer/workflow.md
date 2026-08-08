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
- `develop` is the integration branch; `master` is reserved for stable milestone merges and is not
  wired to any release automation. See [Release process](#release-process) below.

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

## Release process

Releases are **tag-driven**, not branch-driven — no push to `develop` or `master` publishes
anything. The interactive Claude Code skill **`release`** (invoke it with `/release`) drives the
whole process step by step: consolidation interview, community-facing `RELEASE_NOTES.md`, version
bump, channel-aware `CHANGELOG` update, rebuild, release PR, and the final tag commands. The steps
it walks through:

1. On a `release/x.y.z` branch from `develop`: draft `RELEASE_NOTES.md`, bump `ctld.VERSION` in
   `src/CTLD_config.lua`, update `CHANGELOG.md`, rebuild `CTLD.lua`. The PR targets **`develop`**.
2. After merge, push the tag **`published-vx.y.z`** manually — this triggers
   `.github/workflows/release.yml`, which rebuilds and publishes the GitHub Release with `CTLD.lua`
   attached.

Two channels, selected by the version string:

- **Pre-release** (`x.y.z-rcN`, e.g. `2.0.0-rc1`) → published as a GitHub *pre-release*.
  `## [Unreleased]` stays open (post-rc fixes keep landing there) and the floating `published-latest`
  tag is **not** moved — users tracking it stay on the last stable.
- **Stable** (`x.y.z`) → a normal release; `## [Unreleased]` is frozen to `## [x.y.z] — date`, and
  `published-latest` is advanced to it — a permanent "last stable `CTLD.lua`" download pointer.

## Dev builds

A release is the only thing a Mission Maker is told to download — but between two releases there
has to be *something* to hand a tester. Every merge into `develop` therefore runs
`.github/workflows/dev-build.yml`, which produces a complete `ctld-tools.exe` from that commit
(frontend, schema, default catalogue and engine all from the same source) and publishes it twice:

- as an **action artifact** (`ctld-tools-dev`, kept 14 days) — traceable per run, but downloading
  it needs a GitHub session and it arrives zipped;
- as a floating **`dev` pre-release**, rewritten on each merge — anonymous download, stable link,
  the `.exe` itself. That is the one to send someone.

Such a build stamps its commit into `ctld.VERSION`: `--version` prints `2.0.0-rc6-a1b2c3d`, and so
do the install report and the mission's copy of the engine, so a bug report names its build. The
suffix comes from `merge_CTLD.ps1 -VersionSuffix`, used by that workflow alone — a local build and
a release keep the version as written in `src/CTLD_config.lua`.

The `dev` tag does not match `published-v*`, so refreshing it never triggers the release workflow,
and `published-latest` still points at the last stable release.

!!! warning "Not a release"
    A dev build has no release notes, no published documentation of its own, and no guarantee
    beyond the CI that ran on its commit. Handing one to a Mission Maker who did not ask for it is
    how you end up debugging a version nobody can identify.

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

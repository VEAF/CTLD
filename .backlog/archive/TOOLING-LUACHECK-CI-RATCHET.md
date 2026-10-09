# TOOLING-LUACHECK-CI-RATCHET

**Status:** merged (PR #204). Compacted from `TOOLING-LUACHECK-CI-RATCHET/` on 2026-10-09; the ticket files live on in git history.

Formalizes the `dev/roadmap.md` "luacheck n'est en réalité vérifié nulle part" entry + a `grill-with-docs` session (2026-09-27): a new dedicated CI job runs `luacheck` for real, gated by an inverted ratchet (`LUACHECK_WARNING_CEILING`, starts at 89 — today's true count — only ever decreases, mirroring `busted`'s `COVERAGE_FLOOR`), with 0 errors always non-negotiable. The local `PostToolUse` hook stops being a silent no-op when `luacheck` isn't installed — a one-time visible notice instead, via a plain `.git/`-local marker (no session identifier exists to key a real "once per session" on). Paying down the 89 warnings themselves stays a separate future cleanup lot.

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-ci-job-and-ratchet` | ✅ done | 01 — New `luacheck` CI job with an inverted warning-count ratchet |
| `02-visible-local-hook` | ✅ done | 02 — Local hook: one-time visible notice instead of a silent no-op |

## PRD

## TOOLING-LUACHECK-CI-RATCHET — a real luacheck gate, and a visible local hook

**Status:** ✅ done (PR #204).

Formalizes the `dev/roadmap.md` entry "luacheck n'est en réalité vérifié nulle part (ni local, ni
CI)" and a `grill-with-docs` session held 2026-09-27 that resolved every point the entry had left
open. The roadmap entry's own 2026-08-26 update already quantified the debt this PRD ratchets
against: **89 warnings, 0 errors, 33 files** — reverified fresh during the grill session (still
exactly 89/0/33 despite the `src/` changes merged since).

### Problem Statement

`CLAUDE.md` states `luacheck --config .luacheckrc src/` must be clean, "rely on CI if not installed
locally." Neither half of that safety net actually exists:

- **No CI job runs `luacheck`.** `.github/workflows/ci.yml`'s `lua-lint` job only runs `luac5.1 -p`
  (parse/syntax), not static analysis.
- **The local `PostToolUse` hook (`tools/hooks/luacheck-on-edit.sh`) is a silent no-op** when
  `luacheck` isn't installed (`command -v luacheck` failing exits the case branch with no output) —
  exactly the situation on a Windows machine without it on `PATH`. A contributor in that position
  gets no signal that the promised check never ran, locally or in CI.

### Solution

Two independent fixes, addressing local and CI separately:

1. A new, dedicated CI job (`luacheck`) that fails on any `luacheck` **error** (unconditional, `0`
   tolerated) and on the **warning count exceeding a ceiling** — a ratchet, exactly mirroring the
   existing `busted` job's `COVERAGE_FLOOR` pattern, but inverted: `LUACHECK_WARNING_CEILING`
   starts at `89` (today's true count) and may only ever be lowered, never raised, as the
   pre-existing debt gets paid down over time. This blocks any *new* regression from day one
   without requiring the existing debt to be cleared first.
2. The local hook prints a one-time, visible notice to stderr when `luacheck` is not installed,
   instead of silently doing nothing — so a contributor without it locally knows the local check
   didn't run (CI is now the real backstop either way). "One-time" is approximated with a plain
   marker file under `.git/` (never git-tracked, local to the clone), not a true session
   boundary — a `PostToolUse` hook is a stateless script re-invoked on every edit, with no session
   identifier exposed to it (only `$CLAUDE_PROJECT_DIR` is documented). The marker is never
   auto-reset; it persists until manually deleted.

### User Stories

1. As a developer opening a PR that adds a new `luacheck` warning or error in `src/`, I want CI to
   fail, so that a regression is caught before merge instead of silently joining the existing debt.
2. As a developer opening a PR that touches `src/` but introduces no new warning, I want CI to
   pass exactly as it does today, so that this gate never blocks unrelated work on account of the
   pre-existing 89.
3. As a developer who pays down some of the existing 89 warnings in a future cleanup lot, I want to
   lower `LUACHECK_WARNING_CEILING` in that same PR, so that the ratchet actually tightens over
   time instead of just sitting at 89 forever.
4. As a developer without `luacheck` installed locally (e.g. on Windows without it on `PATH`), I
   want a visible notice the first time I edit a `src/*.lua` file, so that I know the local check
   isn't running for me and CI is what actually protects the codebase — not silence that could be
   mistaken for "nothing to report."
5. As that same developer, I want the notice to appear once, not on every single edit for the rest
   of my session, so that it informs without becoming background noise I start ignoring.
6. As a developer maintaining `CLAUDE.md`'s claim that `luacheck` "must be clean," I want that
   claim to be actually true going forward for the part that's enforceable today (no new
   regressions) — the existing 89 remain an acknowledged, quantified, separately-tracked debt, not
   silently redefined as "clean."

### Implementation Decisions

- **New CI job, not a step added to `lua-lint` or `busted`.** Matches this workflow's own one-job-
  one-concern convention (`lua-lint`, `gitleaks`, `frontend`, `build`, `smoke`, `busted`,
  `changelog-guard`, `i18n-guard` are each independent, separately-named checks in the PR checks
  list). Installs `luacheck` via `luarocks` on `ubuntu-latest`, the same install pattern the
  `busted` job already uses for its own LuaRocks packages.
- **`LUACHECK_WARNING_CEILING` env var**, set in the new job, starting at `89` — structurally
  identical to `busted`'s `COVERAGE_FLOOR: '59'`: a named env var with a comment stating the ratchet
  rule ("only ever decrease, never increase"), parsed from `luacheck`'s own summary line ("Total:
  N warnings / 0 errors in M files") the same way the `busted` job's step already parses `luacov`'s
  "Total" line with `awk`.
- **Any `luacheck` error fails the job unconditionally** — errors are already at `0` today and stay
  non-negotiable; only the warning count is ratcheted. (`luacheck`'s own exit code already
  distinguishes the two; the CI step checks both the parsed warning count against the ceiling and
  the parsed error count against zero, rather than relying solely on `luacheck`'s process exit
  code, mirroring `busted`'s own explicit numeric comparison rather than trusting a tool's raw exit
  status.)
- **No `skip-luacheck`-style label escape hatch.** Unlike `changelog-guard`/`i18n-guard` (which
  guard against a case that can legitimately not apply), a new `luacheck` warning is never
  "genuinely fine to skip" — it's either fixed, or (for a genuine false positive) permanently
  addressed in `.luacheckrc` itself (a new `read_globals`/`globals` entry, a per-file override),
  which is already the existing, correct mechanism for that — not a per-PR bypass.
- **Local hook (`tools/hooks/luacheck-on-edit.sh`)**: when `command -v luacheck` fails, check for a
  marker file at `$CLAUDE_PROJECT_DIR/.git/ctld-luacheck-notice-shown` (or similar); if absent,
  print a one-line notice to stderr ("luacheck not installed — local check skipped, CI enforces
  this") and create the marker; if present, stay silent as today. The marker is created
  unconditionally on first notice, never cleaned up or expired by the hook itself.
- **No ADR.** The inverted-ratchet CI mechanism directly mirrors `busted`'s already-documented
  `COVERAGE_FLOOR` pattern in the same file — not a surprising choice to a reader already familiar
  with this codebase's own conventions, and trivially reversible.

### Testing Decisions

- The CI job change itself is validated by observing real CI runs on the delivering PR (a CI
  workflow has no local unit-test harness in this repo) — confirm the job appears, passes at the
  current 89, and (as a manual sanity check during review, not a permanent test) that deliberately
  exceeding the ceiling locally would fail the parsing/comparison logic.
- The local hook's new notice-once behavior: `tools/hooks/README.md` already documents this hook's
  contract in prose (no busted/pytest coverage exists for shell hooks in this repo, checked — none
  of `tools/hooks/*.sh` has a test file). This lot follows the same precedent: no new automated
  test, verified manually (delete the marker, confirm the notice appears once and not on a second
  edit; confirm no notice at all when `luacheck` is present).
- `tools/hooks/README.md` gains an updated description of `luacheck-on-edit.sh`'s new one-time
  notice behavior — its table row currently says "Best-effort and non-blocking — no-op if luacheck
  is absent," which becomes inaccurate once this lot ships.

### Out of Scope

- Paying down any of the existing 89 warnings — tracked as its own future cleanup candidate (see
  `dev/roadmap.md`'s own note on this), deliberately separate from making the gate real.
- Any change to `.luacheckrc` itself (its globals, exclusions, or per-file overrides) — nothing in
  this PRD requires one; a future cleanup lot may need one, this one doesn't.
- A true "once per Claude Code session" mechanism for the local hook — no session identifier is
  exposed to a `PostToolUse` hook today; the marker-file approximation (never auto-reset) is the
  decided, deliberately simpler substitute — see Implementation Decisions.
- A `skip-luacheck` PR label — deliberately not built, see Implementation Decisions.

### Further Notes

No ADR (see Implementation Decisions). `dev/roadmap.md`'s entry is formalized and removed by this
lot; its already-quantified 89-warning breakdown (unused variables/shadowing across ~8 files, 2
empty `if` branches in `CTLD_vehicle.lua`, a simplifiable negation in `CTLD_jtac.lua`, and the bulk
in `legacy_api.lua`'s misleadingly-`_`-prefixed-but-actually-used parameters) stays there as the
reference for whoever picks up the cleanup lot later.

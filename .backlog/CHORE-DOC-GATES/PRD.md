# Lot CHORE-DOC-GATES — enforce CHANGELOG + backlog-index bookkeeping instead of relying on discipline

Status: ⬜ ready
Branch: chore/doc-gates → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`)
ADRs: none (process / tooling lot)

## Problem Statement

Two documentation-bookkeeping steps that the project *requires* are routinely skipped because
**nothing enforces them** — they rely entirely on the agent's or contributor's memory.

### 1. CHANGELOG `[Unreleased]` skipped on merged lots

Three consecutive lots merged into `develop` shipped **without any CHANGELOG entry**:

| Lot | PR | Touched `src/`? | `chore(backlog): close`? | CHANGELOG entry? |
|-----|----|-----------------|--------------------------|------------------|
| TEST-TYPENAME-VALIDATION | #36 | ✅ | ✅ | ❌ |
| FIX-LGZ-POLL-NIL-ISFLYING | #37 | ✅ | ✅ | ❌ |
| FIX-PLUGIN-CRATE-INSTANT-REFRESH | #38 | ✅ | ✅ | ❌ |

Verified: the last commit to touch `CHANGELOG.md` before this lot was `a50b6d8` (USERCONFIG-LOADING).
Every lot since made its `chore(backlog): close` commit but none amended the CHANGELOG.

The instruction is **already written twice**:
- [CLAUDE.md](../../CLAUDE.md) "Default workflow": `… → CHANGELOG.md [Unreleased] → commit`.
- [.github/pull_request_template.md](../../.github/pull_request_template.md): checklist item
  `[ ] CHANGELOG.md [Unreleased] updated`.

But **no gate makes it true**. The CI jobs are `lua-lint`, `gitleaks`, `merge-build`, `busted` —
none checks the CHANGELOG. The PR-template checkbox is decorative: nothing (no CI, no hook) verifies
it, so it can be ticked without an edit. The only project hooks are `block-protected-paths` and
`luacheck-on-edit`. On short fix/test lots the agent performs the *salient* closing gesture (closing
the lot in the backlog) and the *separate* artefact (the CHANGELOG, positioned earlier in the flow,
before the commit) falls through the cracks.

### 2. Backlog index left in a stale `pending merge` state after merge

The index [.backlog/README.md](../README.md) listed `CATCH-UP-PILOT-SCENARIOS` as
`✅ pending merge` long after its PR #24 was merged. Updating the index line from `pending merge`
to `merged (PR #NN)` is a **post-merge** action, but the modelled workflow
([CLAUDE.md](../../CLAUDE.md)) stops at `… → merge → back to develop`. The bookkeeping step is not
part of the modelled flow, so it is a deferred action that nothing triggers — by merge time the
contributor has already moved on. This has recurred across contributors, not just one.

## Solution

Replace "remember to do it" with **enforcement where automatable** and **an explicit modelled step
where not**.

1. **CI CHANGELOG guard** (new `ci.yml` job): on `pull_request`, fail if the diff touches `src/**`
   but not `CHANGELOG.md`. Escape hatch: a `skip-changelog` label on the PR (for the rare genuinely
   changelog-less code change). This is the only measure that would have stopped #36/#37/#38.
2. **Model the post-merge index step** and shift it earlier: the PR that delivers a lot updates its
   own index line to `merged (PR #NN)` **inside the PR** (covered by review), instead of a deferred
   commit on `develop`. Documented in `CLAUDE.md` and `dev/agents/issue-tracker.md`.
3. **Make the PR-template checkbox meaningful**: keep it, now backed by the CI guard; add a one-line
   pointer to the `skip-changelog` escape hatch.

## User Stories

- As a **maintainer**, I want CI to block a `src/`-touching PR that forgot its CHANGELOG entry, so
  released changes are always documented without me policing every PR.
- As a **maintainer**, I want a deliberate way to waive the CHANGELOG check (label) for the rare
  code change that genuinely warrants no entry, so the guard does not become friction.
- As a **contributor / agent**, I want the backlog-index update to be part of the PR I open, so the
  index never lingers in a stale `pending merge` state after merge.

## Implementation Decisions

- **CHANGELOG guard trigger = `src/**` only.** A change to shipped product code always warrants a
  CHANGELOG line. Test-only / tooling-only / docs-only PRs stay under discipline + review (extending
  the trigger to `tests/**` is noted as an open option in *Further Notes*, not adopted here).
- **Guard runs on `pull_request` events only**, not on `push` to `develop` — so the direct
  `chore(backlog): close` commits are unaffected.
- **Escape hatch = PR label `skip-changelog`**, read from `github.event.pull_request.labels`.
  Preferred over a text marker in the PR body (labels are reviewable and explicit).
- **Diff computation**: `git diff --name-only ${{ github.event.pull_request.base.sha }}...HEAD`
  (fetch depth 0), classify paths, fail with an actionable message naming the missing file and the
  label escape hatch.
- **Index bookkeeping is documentation, not CI-gated.** Automatically enforcing "a lot PR must edit
  its index line" is brittle (lot-to-line mapping) and is left out of scope; instead the workflow is
  reworded so the index update happens *in the delivering PR*.
- **Files touched**: `.github/workflows/ci.yml` (new job), `CLAUDE.md` (workflow wording),
  `dev/agents/issue-tracker.md` (index-in-PR convention), `.github/pull_request_template.md`
  (escape-hatch pointer). No `src/` change → this lot's own PR will not trip its own guard, which is
  correct.

## Testing Decisions

- The CHANGELOG guard is CI YAML, not busted-testable. Validate it behaviourally with two probe PRs
  (or one PR pushed in two states): (a) a `src/`-only change with **no** CHANGELOG edit → job **fails**;
  (b) the same plus a CHANGELOG line, or the `skip-changelog` label → job **passes**.
- No unit tests, no rebuild (no `src/` change), no DCS scenario. Coverage ratchet unaffected.

## Out of Scope

- Auto-enforcing the backlog-index update in CI (brittle lot→line mapping) — handled by workflow
  wording instead.
- Extending the CHANGELOG guard to `tests/**` or `docs/**` (see *Further Notes*).
- A local Claude Code hook mirroring the guard: CI is authoritative and contributor-independent; a
  hook would only fire inside Claude sessions and is redundant with the gate.
- Retro-filling CHANGELOG entries for #36/#37/#38 — already done as the standalone doc-update ahead
  of this lot (folded in or committed separately per the maintainer's call).

## Further Notes

- **Trigger breadth is intentionally conservative.** If test-only lots (which the project *does*
  changelog, e.g. TEST-PLUGIN-POSTINIT's F-124 entry) start slipping through, revisit extending the
  trigger to `tests/**` — deferred until there is evidence, to avoid forcing a CHANGELOG line on
  every trivial test fix.
- **Proposed ticket split** (tracer-bullet, each independently mergeable):
  1. `01` — CI CHANGELOG guard job + behavioural validation.
  2. `02` — workflow/doc rewording (`CLAUDE.md`, `dev/agents/issue-tracker.md`, PR template).
- The guard closes the loop the PR-template checkbox opened: the checkbox stops being an honour-system
  tick and becomes a statement CI verifies.

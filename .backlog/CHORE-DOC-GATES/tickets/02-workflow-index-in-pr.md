# 02 — Model the index-in-PR step + wire the CHANGELOG escape hatch into docs

Status: ✅ done
Type: AFK
Repo: CTLD
GitHub: —

## What to build

Reword the process docs so the backlog-index update stops being a deferred post-merge action and the
CHANGELOG waiver is discoverable.

1. **`CLAUDE.md` "Default workflow"** — the current flow ends at
   `… → PR to develop → address review/CI → merge → back to develop`, which never names the
   index update. Reword so the delivering PR sets its own index line to `merged (PR #NN)` **inside
   the PR** (covered by review), rather than a separate commit on `develop` after merge.
2. **`dev/agents/issue-tracker.md`** — document the convention: when a lot PR is opened, its
   `.backlog/README.md` index line moves to `merged (PR #NN)` within that PR; the index is never left
   in a stale `pending merge` state after merge.
3. **`.github/pull_request_template.md`** — on the existing `CHANGELOG.md [Unreleased] updated`
   checklist item, add a short pointer that a genuinely changelog-less `src/` change must carry the
   `skip-changelog` label (the waiver enforced by ticket 01).

No `src/` change, no rebuild, no tests. Documentation only.

## Acceptance criteria

- [ ] `CLAUDE.md` workflow states the index line is set to `merged (PR #NN)` within the delivering PR.
- [ ] `dev/agents/issue-tracker.md` documents the index-in-PR convention (no stale `pending merge`).
- [ ] PR template's CHANGELOG item references the `skip-changelog` label escape hatch.
- [ ] No `src/` change; wording is English, consistent with surrounding docs.

## Blocked by

None. Independent of ticket 01 (references the `skip-changelog` label by name; the label's behaviour
is delivered by 01 but the doc text stands on its own).

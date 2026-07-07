# 06 — Gitleaks secret scanning

Status: ⬜ ready
Type: AFK

## What to build

Add a `gitleaks` job on push and PR, scanning history, with a `.gitleaks.toml` if tuning is needed.
Protects the public VEAF repo from committed credentials.

## Acceptance criteria

- [ ] A gitleaks job runs on push and PR.
- [ ] The job flags a planted fake secret on a scratch branch.
- [ ] No false positives on the current tree (tune `.gitleaks.toml` if necessary).

## Blocked by

None - can start immediately.

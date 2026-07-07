# 03 — Remove the broken `docs` job (handoff to DOC-MKDOCS)

Status: ⬜ ready
Type: AFK

## What to build

Remove the `docs` job that runs `mkdocs gh-deploy` against a non-existent `mkdocs.yml`. Docs
publication is the responsibility of the DOC-MKDOCS lot; record the handoff in the CHANGELOG so the
intent is not lost.

## Acceptance criteria

- [ ] The `docs` job is removed from the workflow.
- [ ] CI no longer fails on a missing `mkdocs.yml`.
- [ ] A CHANGELOG note records that docs publication moves to DOC-MKDOCS.

## Blocked by

None - can start immediately.

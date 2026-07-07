# 05 — Stylua formatting check

Status: ⬜ ready
Type: AFK

## What to build

Add a `stylua --check` job and a `stylua.toml` consistent with the existing `.luacheckrc` /
`.editorconfig` intent (indentation, line width). This establishes stylua as the project formatter,
enforced in CI. Report existing formatting drift but do not reformat `src/` as part of this ticket
(a bulk reformat, if needed, is a separate, isolated change).

## Acceptance criteria

- [ ] `stylua.toml` exists and matches the project style intent.
- [ ] A CI job runs `stylua --check`.
- [ ] The job fails on a deliberately misformatted file.
- [ ] Any required baseline reformat is done in a dedicated commit, not mixed with logic.

## Blocked by

None - can start immediately.

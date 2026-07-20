# 06 — Docs, CHANGELOG, ADR, backlog index

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

Close the paperwork in the delivering PR (per `CHORE-DOC-GATES`).

- **Developer docs** (`docs/developer/`, EN + FR): document that engine defaults now live in
  `ctld-config.yaml` (source of truth), how `gen-config` fits the build, and that the generated Lua
  is not hand-edited. Update any page that told contributors to edit `CTLD_config.lua` defaults.
- **`tools/ctld-tools/` README**: usage of `gen-config`, the one-shot extractor, the parity test,
  and the local `lua5.1` skip behaviour.
- **`CHANGELOG.md`** `[Unreleased]`: entry for the YAML-sourced config (a `src/`-touching PR, so the
  `changelog-guard` requires it).
- **ADR 0009**: flip status *Proposed* → *Accepted*; update `dev/adr/README.md`.
- **`.backlog/README.md`**: set the `CTLD-TOOLS-CONFIG` index line to `merged (PR #NN)` in this PR.
- **`CONTEXT.md`**: confirm the "Config reference" term matches the shipped naming.

## Acceptance criteria

- [ ] Developer docs (EN + FR) describe the YAML-sourced config; no stale "edit `CTLD_config.lua`" guidance.
- [ ] Package README complete.
- [ ] `CHANGELOG.md` `[Unreleased]` entry added.
- [ ] ADR 0009 Accepted; ADR index updated.
- [ ] Backlog index line updated in-PR; `CONTEXT.md` naming confirmed.

## Blocked by

Ticket 05.

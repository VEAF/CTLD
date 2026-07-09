# 03 — README + skill cross-reference

Status: ✅ done
Type: AFK

## What to build

- `tools/integration-runner/README.md` (mirrors `tools/dcs-data/README.md`'s style): what the
  runner does, prerequisites (`dcs-serve` running, `dcs-client.yaml` present), full usage
  examples (`--no-ai`, `--tier`, `--dir`, `--scenario`, `--junit-out`), and the RUNNING/STARTED
  scope boundary from the PRD.
- Cross-reference from the `integration-testing` skill: a short "Automated runs" section
  pointing to `tools/integration-runner/` for headless `auto`/`auto-check` runs, distinct from
  the AI-driven `exec_lua` loop the skill otherwise documents.

## Acceptance criteria

- [ ] `tools/integration-runner/README.md` has a copy-pasteable example command.
- [ ] `integration-testing` skill links to it without duplicating the full flag reference.

## Blocked by

Ticket 01 (documents the actual flags).

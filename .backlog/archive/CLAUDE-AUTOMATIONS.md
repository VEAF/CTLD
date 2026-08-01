# CLAUDE-AUTOMATIONS

**Status:** delivered. Compacted from `CLAUDE-AUTOMATIONS/` on 2026-08-01; the ticket files live on in git history.

Project hooks (block protected paths, luacheck-on-edit) + subagents lua51/parity (PR #5).

## Tickets

| Ticket | Status | Title |
|---|---|---|

## PRD

## Lot CLAUDE-AUTOMATIONS — project hooks + review subagents

Status: ✅ done
Branch: feature/claude-automations → PR → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`)

### Problem Statement

Two of the project's hard rules live only as prose in `CLAUDE.md` with no enforcement: never edit
`migration/source/` (immutable legacy parity reference) and never hand-edit the generated
`CTLD.lua`. It is easy to violate them by reflex. There is also no specialized helper to
audit the two recurring risks of this codebase: Lua 5.1 compatibility and legacy parity.

### Solution

Add **project-level** Claude Code automations (committed, shared via git, inert for non-Claude-Code
users):

- A **PreToolUse hook** that blocks Edit/Write/MultiEdit on protected paths.
- A **PostToolUse hook** that runs luacheck on edited `src/` Lua (best-effort, non-blocking).
- Two **subagents**: `lua51-compliance-reviewer` and `legacy-parity-checker`.

### Scope

- `tools/hooks/block-protected-paths.sh` + wiring in `.claude/settings.json` (PreToolUse).
- `tools/hooks/luacheck-on-edit.sh` + wiring (PostToolUse).
- `.claude/agents/lua51-compliance-reviewer.md`, `.claude/agents/legacy-parity-checker.md`.
- `tools/hooks/README.md` (requirements, trust model, behavior).

### Testing Decisions

- Hook logic is verifiable by piping representative tool-call JSON to the script and asserting the
  exit code: protected paths → exit 2 (blocked); `src/` files → exit 0 (allowed); no false positive
  on names like `src/..CTLD..lua`. This was run locally before wiring.
- Subagents are prompt definitions; their value is validated in use, not by an automated test.

### Out of Scope

- Fixing the pre-existing `additionalDirectories: ["\\tmp"]` quirk in settings.json (left surgical).
- Any Lua source change.

### Further Notes

Hooks invoke `sh`, so a POSIX shell must be on PATH (Git Bash on Windows). Claude Code asks each
user to review/trust project hooks on first use. The build (`merge_CTLD.ps1`) writes `CTLD.lua`
via PowerShell, not the Write tool, so the block hook does not interfere with rebuilding.

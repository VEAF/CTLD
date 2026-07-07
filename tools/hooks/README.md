# Claude Code hooks

Project-level hooks wired in `.claude/settings.json` (committed, shared with everyone who uses
Claude Code on this repo). They are **inert for anyone not using Claude Code**.

| Hook | Event | What it does |
|------|-------|--------------|
| `block-protected-paths.sh` | PreToolUse (Edit/Write/MultiEdit) | Blocks edits to `migration/source/**` (immutable legacy reference) and `CTLD_Next.lua` (generated artifact). Exits 2 to veto the edit. |
| `luacheck-on-edit.sh` | PostToolUse (Edit/Write/MultiEdit) | Runs `luacheck` on an edited `src/**/*.lua` file. Best-effort and non-blocking — no-op if `luacheck` is absent (e.g. Windows without it installed). |

## Requirements & behavior

- The hook commands invoke `sh`, so a POSIX shell must be on PATH (native on macOS/Linux; Git Bash
  on Windows). If `sh` is unavailable the hook cannot run.
- On first use, Claude Code asks each user to **review and trust** these project hooks (a repo
  cannot silently run commands on your machine).
- `$CLAUDE_PROJECT_DIR` is provided by Claude Code and points at the repo root.

The scripts read the tool-call JSON on stdin and extract `file_path` (handling both `/` and `\`
paths). They were tested against representative inputs (protected paths blocked, `src/` files
allowed, no false positive on `src/...CTLD_Next...` names).

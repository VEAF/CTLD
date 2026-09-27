# Claude Code hooks

Project-level hooks wired in `.claude/settings.json` (committed, shared with everyone who uses
Claude Code on this repo). They are **inert for anyone not using Claude Code**.

| Hook | Event | What it does |
|------|-------|--------------|
| `block-protected-paths.sh` | PreToolUse (Edit/Write/MultiEdit) | Blocks edits to `migration/source/**` (immutable legacy reference) and `CTLD.lua` (generated artifact). Exits 2 to veto the edit. |
| `luacheck-on-edit.sh` | PostToolUse (Edit/Write/MultiEdit) | Runs `luacheck` on an edited `src/**/*.lua` file. Best-effort and non-blocking. If `luacheck` is absent (e.g. Windows without it installed), prints a one-time notice to stderr instead of staying silent — see below — and CI's `luacheck` job (`TOOLING-LUACHECK-CI-RATCHET`) is the real backstop either way. |

## Requirements & behavior

- The hook commands invoke `sh`, so a POSIX shell must be on PATH (native on macOS/Linux; Git Bash
  on Windows). If `sh` is unavailable the hook cannot run.
- On first use, Claude Code asks each user to **review and trust** these project hooks (a repo
  cannot silently run commands on your machine).
- `$CLAUDE_PROJECT_DIR` is provided by Claude Code and points at the repo root.
- `luacheck-on-edit.sh`'s "not installed" notice is shown **once**, not on every edit: a marker
  file at `.git/ctld-luacheck-notice-shown` (never git-tracked, local to this clone) is created the
  first time and checked on every run after. It never auto-resets — delete it by hand to see the
  notice again (e.g. after installing `luacheck`, to confirm the real check now runs instead).

The scripts read the tool-call JSON on stdin and extract `file_path` (handling both `/` and `\`
paths). They were tested against representative inputs (protected paths blocked, `src/` files
allowed, no false positive on `src/...CTLD...` names).

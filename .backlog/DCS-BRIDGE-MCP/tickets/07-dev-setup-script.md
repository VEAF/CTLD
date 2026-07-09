# 07 — dev-setup script for dcs-bridge (project-local venv)

Status: ✅ done — unblocked by VEAF-dcs-bridge LOT-012 (PR #15, merged to develop, v0.6.2)
Type: AFK

## What to build

`tools/dcs-bridge/install.ps1` — installs/upgrades VEAF-dcs-bridge into a project-local,
gitignored venv (`tools/dcs-bridge/venv/`), so `.mcp.json` can reference `dcs-client` by a
portable path (`${CLAUDE_PROJECT_DIR}`) instead of relying on the system PATH or a
machine-specific pipx install.

`.mcp.json` already wired accordingly:
```json
{
  "mcpServers": {
    "dcs-bridge": {
      "command": "${CLAUDE_PROJECT_DIR}/tools/dcs-bridge/venv/Scripts/dcs-client.exe",
      "args": ["mcp", "--config", "${CLAUDE_PROJECT_DIR}/dcs-client.yaml"]
    }
  }
}
```

## Blocker (found 2026-07-10)

`VEAF-dcs-bridge`'s `pyproject.toml` has no `[build-system]` table. `pip install
git+https://github.com/VEAF/VEAF-dcs-bridge.git@develop` builds a nameless/versionless
`UNKNOWN-0.0.0` wheel with **no console-script entry points** — `dcs-client.exe` /
`dcs-serve.exe` are never created, regardless of install target (PATH, pipx, or a
project-local venv as here). This is an upstream packaging bug, not something fixable
from the CTLD side.

Filed upstream as `VEAF-dcs-bridge` `.backlog/LOT-012`, fixed in PR #15 (`fix(packaging): add
[build-system] table to pyproject.toml`), merged to `develop`, version bumped to 0.6.2.

## Resolution (2026-07-10)

Re-ran `tools/dcs-bridge/install.ps1` against the fixed `develop` branch:
`dcs-bridge-0.6.2` installs cleanly, `dcs-client.exe` and `dcs-serve.exe` both present in
`tools/dcs-bridge/venv/Scripts/`. `dcs-client --help` lists `tui`/`web`/`mcp` subcommands.
`dcs-client mcp` starts without crashing even with no local `dcs-client.yaml` (config loader
falls back to defaults — `127.0.0.1:8080`, empty api_key — per `ClientConfig` design); it will
only fail when a tool call actually hits `dcs-serve`, which requires the machine-local
`dcs-client.yaml` (never committed) and a running `dcs-serve`.

## Acceptance criteria

- [x] `tools/dcs-bridge/install.ps1` successfully installs `dcs-client`/`dcs-serve` into
      `tools/dcs-bridge/venv/` from the (fixed) upstream source.
- [x] `dcs-client.exe` exists at `tools/dcs-bridge/venv/Scripts/dcs-client.exe` after running it.
- [x] `.mcp.json`'s `dcs-bridge` server starts (`dcs-client mcp` launches cleanly; full
      `exec_lua`/`get_units`/`spawn_unit`/`get_mission_info` round-trip requires a live
      `dcs-serve` + local `dcs-client.yaml`, out of scope for this ticket's automated check).
- [ ] `install.ps1`'s default `-Source` updated once a `published-v*` release or PyPI
      package exists (currently pinned to `@develop` — acceptable for now per the bridge's own
      Git Flow, revisit once a release is cut).

## Blocked by

None — resolved.

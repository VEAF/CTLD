# 01 — Wire `.mcp.json` + dcs-client config

Status: ✅ done
Type: AFK

## What to build

Add a project-level `.mcp.json` that launches `dcs-client mcp` (FastMCP over stdio), exposing
`exec_lua`, `get_units`, `spawn_unit`, `get_mission_info` to Claude. Document the prerequisite:
a running `dcs-serve` (holding the TCP connection from the live mission) and a `dcs-client.yaml`
whose `api_key` matches `dcs-serve.yaml`.

Do not commit any secret. `dcs-client.yaml` is machine-local (API key) — gitignore it and ship a
template / documented path instead.

## Acceptance criteria

- [ ] `.mcp.json` defines a `dcs-bridge` server invoking `dcs-client mcp` (command + args).
- [ ] The four MCP tools are reachable once `dcs-serve` is up (documented, not asserted in CI).
- [ ] `dcs-client.yaml` (or equivalent local config) is gitignored; no API key committed.
- [ ] Config/prerequisite steps documented (in the `integration-testing` skill, ticket 05, or a
      short section it links to).

## Blocked by

None — can start immediately.

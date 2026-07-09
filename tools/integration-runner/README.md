# Integration runner — headless dcs-bridge scenario runner

`run_scenarios.py` runs `tests/dcs/` integration scenarios against a live DCS mission without
an AI agent in the loop, for scenarios that don't need one (`auto`/`auto-check` tier — see the
`integration-testing` skill for the full `@tier` taxonomy).

**Dependency-free**: stdlib only (same convention as `tools/dcs-data/gen_dcs_types.py`). No
`pip install`, no venv — any system Python 3.9+ runs it directly.

## Prerequisites

- `dcs-serve` running, connected to a live DCS mission with the dcs-bridge Lua script injected.
- `dcs-client.yaml` at the repo root (gitignored) with `host`/`port`/`api_key` matching
  `dcs-serve.yaml` — the runner reads the same file the MCP server uses.

## Usage

```bash
# See what would run, no network calls
python tools/integration-runner/run_scenarios.py --list

# Run every auto / auto-check scenario (the "no AI needed" set), inject CTLD.lua first
python tools/integration-runner/run_scenarios.py --no-ai --inject-ctld

# Target a subset
python tools/integration-runner/run_scenarios.py --dir noPlayer --tier auto
python tools/integration-runner/run_scenarios.py --scenario F-178

# Custom report path / polling behaviour
python tools/integration-runner/run_scenarios.py --no-ai --junit-out out/results.xml \
    --poll-interval 1 --poll-timeout 30
```

Run `python tools/integration-runner/run_scenarios.py --help` for the full flag reference.

## Scope boundary — `RUNNING` vs `STARTED`

- `STARTED` scenarios (async, resolved by the scenario's own timers/`waitFor`) are polled
  automatically — this is what makes `auto-check` scenarios runnable headlessly.
- `RUNNING: step=N ...` scenarios need a **physical DCS-side action** between injections (e.g.
  an aircraft landing in a zone) before the next injection can advance. Every scenario using
  that pattern is tagged `ia` in this program (all live under `pilotPassive/`) — a `--no-ai` run
  never selects them. If a `RUNNING` token is ever seen (e.g. `--tier ia` explicitly requested),
  the runner reports it as a `FAIL` with an explanatory message rather than attempting
  re-injection, since re-injecting alone cannot make the physical action happen.

## Legacy relics

`tests/dcs/noPlayer/` still contains ~194 dead FullGas scenarios predating the `@tier`
convention (tracked as `CLEANUP-LEGACY-DCS-TESTS`). Discovery skips any file with no valid
`-- @tier:` header rather than failing — you'll see a one-line summary
(`Skipped N untagged file(s)...`); pass `--show-skipped` to list them.

## Tests

```bash
python -m unittest discover -s tools/integration-runner -p "test_*.py"
```

Covers all pure logic (tier extraction, verdict parsing, filtering, polling state machine,
JUnit XML shape, config reading) without needing a live `dcs-serve`. The one thing intentionally
untested here is the actual HTTP call (`urllib.request` to `/api/exec`) — exercising that needs
a real or mocked `dcs-serve`, out of scope for this lot.

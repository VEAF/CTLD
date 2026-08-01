# INTEGRATION-TEST-RUNNER

**Status:** delivered. Compacted from `INTEGRATION-TEST-RUNNER/` on 2026-08-01; the ticket files live on in git history.

Dependency-free `tools/integration-runner/run_scenarios.py`: discovers + tier-filters scenarios, drives them over dcs-serve REST, polls async ones, writes a JUnit report; `--no-ai` mode runs every `auto`/`auto-check` scenario headlessly. 31 stdlib unit tests. Closes the DCS-bridge triptych.

## Tickets

| Ticket | Status | Title |
|---|---|---|
| `01-runner-script` | ✅ done | 01 — `run_scenarios.py` core runner |
| `02-unit-tests` | ✅ done | 02 — Unit tests for the runner's pure logic |
| `03-docs` | ✅ done | 03 — README + skill cross-reference |

## PRD

## Lot INTEGRATION-TEST-RUNNER — headless runner for dcs-bridge scenarios

Status: ✅ done (pending commit/PR)
Branch: feature/integration-test-runner → PR (pending) → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`); third and final lot of
the DCS-bridge triptych (after `DCS-BRIDGE-MCP` and `INTEGRATION-TEST-TAGS`).

### Problem Statement

`DCS-BRIDGE-MCP` gave every scenario a parsable return contract; `INTEGRATION-TEST-TAGS` tagged
each with an automation tier. Nothing yet *drives* the scenarios without an AI agent manually
calling `exec_lua` — there's no headless way to say "run every `auto`/`auto-check` scenario
against a live DCS mission and tell me what failed."

### Solution

A single, dependency-free Python script — `tools/integration-runner/run_scenarios.py` — that:

1. Discovers scenarios under `tests/dcs/{noPlayer,pilotActive,pilotPassive}/`, reading each
   file's `-- @tier:` header.
2. Filters by tier (`--tier auto,auto-check`) and/or `--no-ai` (shorthand for `auto`+`auto-check`,
   the "run without AI" mode — `ia`-tier scenarios need a human/AI in the loop and are never
   run headlessly).
3. Optionally injects `CTLD.lua` first (`--inject-ctld`), waiting for init.
4. For each selected scenario: POSTs its source to `dcs-serve`'s `POST /api/exec`, parses the
   return contract's decisive token, and for `STARTED` scenarios polls
   `_G["_SCN_<ID>_RESULT"]` until a terminal verdict or a timeout.
5. Writes a JUnit XML report (`--junit-out`, one `<testcase>` per scenario, `<failure>` on
   FAIL/ABORT/timeout) and exits non-zero if anything failed.

Zero external dependencies (matches `tools/dcs-data/gen_dcs_types.py`'s convention) — `urllib`,
`json`, `argparse`, `xml.etree.ElementTree`, `re` only. Talks to `dcs-serve` directly over its
REST API (`/api/exec`), not through the MCP layer (the MCP server is for AI-agent-driven use;
the runner is a plain script a human or a scheduled job runs directly, no MCP client needed).

#### Reused config

Reads host/port/api_key from the same `dcs-client.yaml` (gitignored, already required for the
MCP server) via a minimal flat-YAML reader (the file's shape is a handful of `key: value` lines
— not general YAML, so no PyYAML dependency). CLI flags override.

#### RUNNING vs STARTED — scope boundary

The return contract also defines `RUNNING: step=N ...` (multi-step *re-injection* scenarios —
`farp_repack`-style, where each injection advances one step and something in DCS must change
between injections, e.g. an aircraft landing in a zone). Every scenario using that pattern is
tagged `ia` in this program (they all live under `pilotPassive/`) — a headless runner selecting
only `auto`/`auto-check` will never encounter `RUNNING`. The runner still recognizes the token
(so a misconfigured `--tier ia` run fails loud with a clear message) but does not attempt
re-injection — re-injecting alone can't make a physical DCS action happen.

### User Stories

1. As a developer, I want to run `python tools/integration-runner/run_scenarios.py --no-ai`
   against a live DCS mission with `dcs-serve` up, and get a pass/fail summary + JUnit report,
   so that I can validate a `src/` change without manually injecting 45 scenarios one by one.
2. As a developer, I want `--tier`/`--dir`/`--scenario` filters, so that I can run a targeted
   subset (e.g. just the scenarios covering the module I changed).
3. As a maintainer, I want the runner to have zero install step (no pip/poetry), so that any
   contributor can run it the moment they clone the repo.

### Non-goals

- Running in GitHub Actions CI — no live DCS instance there; this is a local/dev-machine tool
  run against a real mission.
- Automating `ia`-tier scenarios (F10 human steps, visual confirmation, multi-step re-injection
  needing a physical DCS action) — out of reach for a headless script by definition.
- Purging/tagging the ~194 dead FullGas relics — `CLEANUP-LEGACY-DCS-TESTS`.

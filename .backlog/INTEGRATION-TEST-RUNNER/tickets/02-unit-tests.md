# 02 — Unit tests for the runner's pure logic

Status: ✅ done
Type: AFK

## What to build

`tools/integration-runner/test_run_scenarios.py`, using only `unittest` (stdlib), covering the
logic that doesn't need a live `dcs-serve`:

- Verdict-token parsing: all forms (`PASS`, `PASS <p>/<t>`, `FAIL: <r>`, `FAIL <f>/<t>: <r>`,
  `ABORT: <msg>`, `RUNNING`, `RUNNING: <detail>`, `STARTED`), including tag variations
  (`[F-178]`, `[SCN-XXX]`).
- `_SCN_<ID>_RESULT` variable-name derivation from a scenario's `_RUNNING` global or bracketed
  tag (same rule as the `DCS-BRIDGE-MCP` migration playbook).
- `@tier` header extraction: valid single tag, missing tag (error), duplicate tag (error).
- Tier filtering (`--tier`, `--no-ai`, `--dir`, `--scenario`) against a small fixture set of
  fake scenario files (tmp dir), not the real 79.
- JUnit XML shape: given a list of fake per-scenario results, the generated XML has the right
  number of `<testcase>`/`<failure>` elements and round-trips through `ElementTree.parse`.
- Minimal flat-YAML config reader: valid file, missing file (defaults), malformed line (skipped
  or errors clearly — pick one and test it).

No network mocking needed — the HTTP call itself (`urllib.request` to `/api/exec`) is the one
piece intentionally left untested here (would need a live or mocked `dcs-serve`; out of scope).

## Acceptance criteria

- [ ] `python -m unittest tools/integration_runner/test_run_scenarios.py` (or equivalent
      discovery path) passes.
- [ ] Every case listed above has at least one test.
- [ ] No new dependency introduced (stdlib `unittest` only).

## Blocked by

Ticket 01 (tests the functions it defines).

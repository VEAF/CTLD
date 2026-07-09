# 01 — `run_scenarios.py` core runner

Status: ✅ done
Type: AFK

## What to build

`tools/integration-runner/run_scenarios.py`, stdlib-only Python 3.9+:

- **Discovery**: walk `tests/dcs/{noPlayer,pilotActive,pilotPassive}/*.lua`, extract the
  `-- @tier: <value>` header (first match; error loudly if a scenario has none or more than one).
- **Filtering**: `--tier auto,auto-check,ia` (comma list, default all); `--no-ai` shorthand for
  `--tier auto,auto-check`; `--dir noPlayer,pilotPassive` to restrict folders; `--scenario
  <glob-or-path>` to run specific file(s) instead of full discovery.
- **Config**: `--config dcs-client.yaml` (default: repo-root `dcs-client.yaml`), read via a
  minimal flat key:value reader (host/port/api_key only — not general YAML). `--host`/`--port`/
  `--api-key` CLI flags override.
- **Optional CTLD injection**: `--inject-ctld` reads `CTLD.lua` from repo root, POSTs it to
  `/api/exec`, sleeps `--init-wait` seconds (default 4).
- **Per-scenario execution**:
  1. POST scenario source to `/api/exec` (`{"code": "...", "timeout": <exec-timeout>}`).
  2. Parse the decisive token from the response `result` string (`PASS`/`FAIL`/`ABORT`/
     `RUNNING`/`STARTED`) via the tag-prefixed grammar in the `integration-testing` skill.
  3. `PASS`/`FAIL`/`ABORT` → terminal, record and move on.
  4. `STARTED` → poll: derive `_SCN_<ID>_RESULT` from the scenario's own `_RUNNING`/`_RESULT`
     global (grep the file, same derivation rule as the migration playbook), POST
     `{"code": "return _SCN_<ID>_RESULT"}` every `--poll-interval` seconds (default 2) until a
     terminal verdict or `--poll-timeout` (default 60) elapses (timeout → reported as FAIL).
  5. `RUNNING` → not automatable (needs a physical DCS-side action between injections); record
     as FAIL with an explicit "requires re-injection, not runnable headlessly" message. Should
     not occur in `--no-ai` mode (`RUNNING`-pattern scenarios are all tier `ia`).
- **JUnit XML** (`--junit-out`, default `test-results.xml`): one `<testsuite>`, one `<testcase
  classname="<folder>" name="<file>" time="<seconds>">` per scenario, `<failure message="...">`
  child on non-PASS.
- **Exit code**: 0 if every selected scenario is `PASS`, 1 otherwise. Print a one-line summary
  per scenario to stdout as it runs, plus a final `N passed, M failed, K skipped` line.

## Acceptance criteria

- [ ] `python tools/integration-runner/run_scenarios.py --help` documents every flag above.
- [ ] Zero imports outside the Python standard library.
- [ ] Discovery + tier filtering verified against the current 79 scenarios (43/2/34 split from
      `INTEGRATION-TEST-TAGS`) without hitting `dcs-serve` (dry-run / `--list` mode).
- [ ] Contract-parsing handles every verdict form documented in the `integration-testing` skill
      (with/without counts, with/without reasons).
- [ ] JUnit XML validates as well-formed (`xml.etree.ElementTree.parse` round-trips it).

## Blocked by

None.

# 01 — Bootstrap the `ctld-tools` Python package

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

Create the `ctld-tools` Python package under `tools/` (its own directory + venv/`requirements`,
mirroring `tools/dcs-bridge`), with a minimal CLI entry point exposing sub-commands (this lot only
implements `gen-config`; leave the dispatch ready for `validate` / `gen-user` in later lots). Set up
the `unittest` harness co-located with the sources (prior art:
`tools/integration-runner/test_run_scenarios.py`, run via `python -m unittest`).

Pin the YAML library dependency: `ruamel.yaml` (comment/order-preserving, benefits the later scaffold
lot) unless a lighter `PyYAML` is preferred and the scaffold need is deferred — record the choice in
the package README.

## Acceptance criteria

- [ ] `tools/ctld-tools/` package with a CLI dispatching sub-commands; `--help` lists them.
- [ ] Own `requirements` + venv setup documented in a package README.
- [ ] `python -m unittest` discovers and runs the (initially trivial) test suite green.
- [ ] YAML library choice pinned and justified in the README.
- [ ] No change to `CTLD.lua`, `src/`, or the build yet.

## Blocked by

None.

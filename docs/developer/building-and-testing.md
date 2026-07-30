# Building & testing

This page covers everything you need to turn `src/` into the shipping deliverable and to run
the automated test suite locally. Both are also enforced in continuous integration, so the
commands below mirror what CI does on every push.

Live-DCS integration testing — loading your build into the test mission and running scenarios
against it — is covered in [Integration testing](integration-testing.md). This page is
limited to the build pipeline and the busted-based tests that run entirely without DCS.

## Build pipeline

CTLD ships as a single file, `CTLD.lua`, at the repository root. It is **generated** by merging
the pure-Lua modules under `src/` in dependency order — never hand-edit it, and rebuild after any
`src/` change.

**Local build (Windows):**

```
powershell -ExecutionPolicy Bypass -File tools/build/merge_CTLD.ps1
```

Output: `CTLD.lua` at the repo root, written in **UTF-8 without BOM** (required by the DCS Lua
engine — the script aborts if a BOM is detected). The build:

- reads the merge order from `tools/build/listToMerge.txt` (comments and blank lines skipped);
- extracts `ctld.VERSION` from `src/CTLD_config.lua` and stamps a header comment
  (`Version`, `Built`, `Source`, `Licence`) plus `---@meta` / `---@diagnostic disable`;
- concatenates each listed file wrapped in `-- Start :` / `-- End :` markers;
- fails with a non-zero exit code if no files were merged or a BOM slipped in.

The order in `listToMerge.txt` is authoritative (foundations first, then domain managers, then
scenes, then `CTLD_core.lua`, `legacy/`, and `CTLD_bootstrap.lua` last). See
[Architecture](architecture.md) for the rationale and for how to slot a new module into the list.

**CI build:** the `build` job runs the same `merge_CTLD.ps1` on `windows-latest`, verifies the
output exists and is non-empty, and uploads `CTLD.lua` as a build artifact.

## Engine configuration (`ctld-tools`)

The engine defaults are **data**, not code: they live in `src/CTLD_config.yaml` (the single source
of truth, sectioned `mm_facing` / `advanced`). At build time `merge_CTLD.ps1` embeds the YAML
verbatim as a Lua string module — `src/CTLD_config_default_yaml.lua`, defining `ctld.configDefault`
(via `ctld-tools embed`) — which `CTLDConfig:load()` parses at runtime. **Edit the YAML** — the
generated Lua is a **build artifact (git-ignored)**, never hand-edited or committed.

To change a default: edit `src/CTLD_config.yaml`, rebuild (`merge_CTLD.ps1` re-embeds automatically),
commit the YAML. **The build needs Python**: run `poetry install` in `tools/ctld-tools` once (the
merge calls `ctld-tools`; it aborts with a clear message if poetry is missing).

`tools/ctld-tools/` is an isolated poetry project (typer, ruamel.yaml, pytest + ruff + mypy),
following the VMCT Python conventions. The `python-quality` CI job enforces an **oracle drift
guard**: the committed round-trip reference `tests/ci/data/config_defaults.json` (emitted by
`ctld-tools gen`) must equal a fresh emit from the YAML. The busted suite then checks the Lua
`CTLDConfig.parseYAML` reproduces that oracle — two independent parsers agreeing.

## Running tests (busted, no DCS)

The automated suite runs on [busted](https://lunarmodules.github.io/busted/). Every DCS API call
is stubbed, so no DCS installation is required.

```bash
# Install (one-time)
luarocks install busted

# Run the whole suite
busted tests/ci/

# Run only the functional specs
busted tests/ci/functional/

# Run a single spec
busted tests/ci/functional/troop_manager_spec.lua
```

The `.busted` config (repo root) sets `pattern = "_spec"` and names a `helper` loaded before every
spec: `tests/ci/helpers/init.lua`. That helper does two things, in order:

1. `dofile`s `tests/ci/helpers/dcs_stubs.lua` — injects the DCS API stubs into the global
   environment (globals must exist before any `src/` module loads).
2. `dofile`s `tests/ci/helpers/loader.lua` — loads all `src/` modules in the same dependency
   order as `listToMerge.txt` (idempotent, guarded by `_CTLD_LOADED`).

Specs live under two directories:

| Directory | Scope |
| --- | --- |
| `tests/ci/unit/` | Unit specs — one module in isolation (`*_spec.lua`) |
| `tests/ci/functional/` | Functional specs — several managers interacting through the event bus |

The loader silences file logging during tests by setting `ctld.debug = false` and pointing
`ctldLogPath` at the OS temp directory, so runs never touch a real `CTLD.log`.

When you add a module, mirror the change in **both** `tools/build/listToMerge.txt` and
`tests/ci/helpers/loader.lua`, then add specs under `tests/ci/unit/` or `tests/ci/functional/`
(test-first — write the failing spec before the code).

## Coverage ratchet

The `busted` CI job runs with coverage (`busted --coverage tests/ci/`), then `luacov` produces
`luacov.report.out`. The job parses the `Total` percentage and compares it against a floor stored
in the `COVERAGE_FLOOR` environment variable (currently `59`).

The floor is a **ratchet — it only ever goes up, never down**. It was seeded slightly below the
first measured coverage (61.56%). When you raise overall coverage, bump `COVERAGE_FLOOR` in
`.github/workflows/ci.yml` to lock the gain in; the job fails if coverage drops below the floor.

## Continuous integration

CI (`.github/workflows/ci.yml`) runs on every push and pull request to `develop` / `master`, and
can be triggered manually. Four independent jobs:

| Job | Runner | What it checks |
| --- | --- | --- |
| `lua-lint` | `ubuntu-latest` | Parse-checks every `src/**/*.lua` with `luac5.1 -p` — catches Lua 5.2+ constructs (`goto`, `<const>`, integer suffixes…) invalid in DCS |
| `gitleaks` | `ubuntu-latest` | Secret scan over the full history (config in `.gitleaks.toml`) |
| `build` | `windows-latest` | Runs `merge_CTLD.ps1`, verifies `CTLD.lua` is non-empty, uploads it as an artifact |
| `busted` | `ubuntu-latest` | Runs the suite with coverage and enforces the coverage ratchet |

Releases are handled by a separate workflow (`.github/workflows/release.yml`), not by this one.

`luacheck --config .luacheckrc src/` is available as a local static-analysis step; the syntax gate
enforced by CI is `luac5.1 -p` in the `lua-lint` job.

## Logging & debug configuration

CTLD writes a runtime log to `CTLD.log`. File logging is **gated on the `debug` setting** — it is
off by default and only opens the file when `debug` is true (and the DCS install is not sanitized).

Configuration is read-only at runtime and is always read through `ctld.gs("param")`; to enable debug
output you set these values in the configuration snapshot your mission carries — `ctld.configUser` in
`CTLD_userConfig.lua`, most easily produced with `ctld-tools`. All four live in the `advanced`
section:

```yaml
advanced:
  debug: true                  # opens CTLD.log and enables verbose logging
  ctldLogPath: ""              # path override; empty = DCS Saved Games folder
  debugScreenLog: true         # also echo each log line on screen via outText
  debugScreenLogDuration: 10   # on-screen display duration (seconds)
```

Notes:

- `debug = false` (the default) suppresses `CTLD.log` entirely — safe on sanitized servers.
- `ctldLogPath` only overrides **where** the file is written; it does not enable logging on its
  own. Leave it empty to use the default DCS Saved Games location. It is a local path, never
  committed.
- Log lines are emitted through `ctld.utils.log(level, fmt, ...)` (levels such as `INFO`, `WARN`,
  `ERROR`); each line goes to `env.info` and, when the file is open, to `CTLD.log`.

For diagnosing a script that fails to load or a feature that misbehaves inside a running mission,
use the `dcs-runtime-debug` workflow — the live, in-game debugging path is out of scope for this
page.

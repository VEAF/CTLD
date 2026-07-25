# 02 — exe launcher: double-click → serve

Status: 📋 todo
Type: tool (Python) + test

The single console exe is **CLI and GUI launcher** (ADR 0011 point 8), mirroring VMCT's
`veaf-tools.exe`. A bare invocation / double-click boots the web app; an explicit command runs the
CLI (`embed` / `validate` / `gen`).

- Detect a double-click by **walking the parent process tree** (`explorer.exe` vs a terminal
  process), the pattern from VMCT's `_is_double_clicked`. On double-click (or a bare `serve`):
  start `uvicorn` on `127.0.0.1:<free port>` and open the default browser at that URL.
- The **console window is the server-lifecycle window** ("close to quit"); no `--noconsole`. An
  explicit CLI command (with args) bypasses the launcher entirely — build/CI keep calling the
  package directly.
- Wire this into `cli.py`'s `main()` (the launcher branch), keeping `embed`/`validate`/`gen` intact.
- Tests: the double-click detector is unit-tested against a faked process tree; a bare-invocation
  path resolves to `serve`, an explicit command does not (no real uvicorn/browser in tests).

Files: `ctld_tools/web/launcher.py`, `ctld_tools/cli.py`, `tests/**`. Depends on: 01.

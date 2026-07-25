# 01 — Demolish the ops/TUI surface

Status: ✅ done
Type: tool (Python) + test

Remove the diff/ops + TUI surfaces retired by ADR 0011, keeping the still-needed pieces
(`datamine`, `miz`, `validate`, `i18n`, the CLI's `embed`/`validate`/`gen`). `gen-config`/`lupa`
stay until ticket 05 (they still serve the build + the round-trip oracle + the i18n scan).

- Delete `editmodel.py`, `genuser.py` (dead since lot 1 t06), `scaffold.py`, `ctld_tools/tui/*`
  (app/forms/filter/widgets), and their tests (`test_editmodel`, `test_scaffold`, `test_app`).
- Remove the `gen-user` and `tui` commands from `cli.py`; drop the now-unused imports.
- Package imports clean; `ruff` + `mypy` + `pytest` green (`python-quality` CI).

Files: `ctld_tools/{editmodel,genuser,scaffold}.py`, `ctld_tools/tui/`, `cli.py`, `tests/**`,
`pyproject.toml` (textual dep if now unused). Depends on: lot 1.
